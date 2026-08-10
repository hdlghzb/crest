#!/usr/bin/env python3
"""Parser, capability, call-scope, and runtime checks for MTD task-final control."""

import subprocess
import sys
import tempfile
from pathlib import Path


OPTION = "--gmc-mtd-task-final-opt"
FIXTURE = """9
water cluster
H -1.091354 2.083948 0.561412
O -0.873213 1.360333 -0.037725
H -1.126153 -0.540943 0.037240
H 0.094609 1.245770 0.037306
O 1.614744 0.076014 -0.037729
O -0.741528 -1.436357 -0.037711
H -1.259101 -1.987119 0.561339
H 2.350402 -0.096756 0.561513
H 1.031565 -0.704748 0.037192
"""


def run(binary: str, workdir: Path, *args: str) -> subprocess.CompletedProcess[str]:
    return subprocess.run(
        [binary, *args],
        cwd=workdir,
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
        text=True,
        check=False,
    )


def require_fragments(source: str, fragments: tuple[str, ...], label: str) -> None:
    for fragment in fragments:
        if fragment not in source:
            raise AssertionError(f"{label}: missing {fragment!r}")


def main() -> int:
    if len(sys.argv) != 2:
        print(f"usage: {sys.argv[0]} CREST_BINARY", file=sys.stderr)
        return 2

    binary = str(Path(sys.argv[1]).resolve())
    source_root = Path(__file__).resolve().parents[1]
    classes = (source_root / "src/classes.f90").read_text()
    confparse = (source_root / "src/confparse.f90").read_text()
    search = (source_root / "src/algos/search_conformers.f90").read_text()
    api = (source_root / "src/gmc_api.f90").read_text()
    require_fragments(
        classes,
        (
            "logical :: gmc_mtd_task_final_opt = .true.",
            "self%gmc_mtd_task_final_opt = src%gmc_mtd_task_final_opt",
        ),
        "systemdata",
    )
    require_fragments(
        confparse,
        (
            "case ('-gmc-mtd-task-final-opt')",
            "case ('on')",
            "case ('off')",
            "'requires on or off'",
            "'task_final_opt=true'",
            "'task_final_opt=false'",
        ),
        "parser",
    )
    require_fragments(api, ('"mtd_task_final_opt":true',), "capability")

    iteration = search.split("mtdloop: do", 1)[1].split("end do mtdloop", 1)[0]
    require_fragments(
        iteration,
        (
            "call optlev_to_multilev(env%optlev,multilevel)",
            "call crest_multilevel_oloop(env,ensnam,multilevel,i)",
        ),
        "iteration scope",
    )
    final = search.split("!>--- final ensemble optimization", 1)[1].split(
        "!==========================================================!", 1
    )[0]
    require_fragments(
        final,
        (
            "if (env%gmc_mtd_task_final_opt) then",
            "call crest_multilevel_wrap(env,trim(atmp),0)",
            "GMC task final optimization skipped",
            "retaining normal iMTD geometry",
        ),
        "final scope",
    )
    if "if (env%gmc_mtd_task_final_opt) then" in iteration:
        raise AssertionError("task-final gate leaked into the iMTD iteration loop")

    with tempfile.TemporaryDirectory(prefix="crest-gmc-mtd-task-final-") as tmp:
        workdir = Path(tmp)
        (workdir / "three.xyz").write_text(
            "3\nH3\nH 0.0 0.0 0.0\nH 0.0 0.0 1.0\nH 0.0 1.0 0.0\n"
        )
        default = run(binary, workdir, "three.xyz", "--imtdgc", "--dry")
        if default.returncode != 0 or "task_final_opt=true" not in default.stdout:
            raise AssertionError("parser default did not preserve task_final_opt=true")
        for value in ("on", "off"):
            result = run(
                binary,
                workdir,
                "three.xyz",
                "--imtdgc",
                OPTION,
                value,
                "--dry",
            )
            expected = f"task_final_opt={'true' if value == 'on' else 'false'}"
            if result.returncode != 0 or expected not in result.stdout:
                raise AssertionError(f"explicit {value} was not accepted: {result.stdout}")
        invalid = run(binary, workdir, "three.xyz", "--imtdgc", OPTION, "maybe", "--dry")
        if invalid.returncode == 0 or "requires on or off" not in invalid.stdout:
            raise AssertionError("invalid task-final value did not fail fast")

        runtime = {}
        for value in ("on", "off"):
            runtime_dir = workdir / f"runtime-{value}"
            runtime_dir.mkdir()
            (runtime_dir / "struc.xyz").write_text(FIXTURE)
            result = run(
                binary,
                runtime_dir,
                "struc.xyz",
                "--gfnff",
                "--imtdgc",
                "-nci",
                "-squick",
                "-T",
                "1",
                "--optlev",
                "tight",
                OPTION,
                value,
            )
            if result.returncode != 0 or "CREST terminated normally." not in result.stdout:
                raise AssertionError(
                    f"runtime {value} failed with code {result.returncode}:\n"
                    f"{result.stdout[-2000:]}\n{result.stderr[-1000:]}"
                )
            runtime[value] = result.stdout

        completed = {
            value: output.count("completed successfully")
            for value, output in runtime.items()
        }
        if completed["on"] < 1 or completed["on"] != completed["off"]:
            raise AssertionError(f"MTD iteration counts changed: {completed}")
        require_fragments(
            runtime["on"],
            (
                "Final Geometry Optimization",
                "GMC provenance: task_final_opt=true source_geometry_level=tight",
            ),
            "runtime on",
        )
        require_fragments(
            runtime["off"],
            (
                "GMC task final optimization skipped; retaining normal iMTD geometry.",
                "GMC provenance: task_final_opt=false source_geometry_level=normal",
            ),
            "runtime off",
        )
        if "Final Geometry Optimization" in runtime["off"]:
            raise AssertionError("off runtime still performed the final optimization")

    return 0


if __name__ == "__main__":
    raise SystemExit(main())
