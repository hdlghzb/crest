#!/usr/bin/env python3
"""Targeted parser and scope checks for the QCG grow-final optimizer."""

import subprocess
import sys
import tempfile
from pathlib import Path


def run(binary: str, workdir: Path, *args: str) -> subprocess.CompletedProcess[str]:
    return subprocess.run(
        [binary, *args],
        cwd=workdir,
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
        text=True,
        check=False,
    )


def main() -> int:
    if len(sys.argv) != 2:
        print(f"usage: {sys.argv[0]} CREST_BINARY", file=sys.stderr)
        return 2

    binary = str(Path(sys.argv[1]).resolve())
    source_root = Path(__file__).resolve().parents[1]
    qcg_main = (source_root / "src/qcg/qcg_main.f90").read_text()
    qcg_misc = (source_root / "src/qcg/qcg_misc.f90").read_text()
    if "call qcg_final_opt_internal(env,solu,clus,finalopt_io)" not in qcg_main:
        raise AssertionError("qcg_grow does not call the final-only helper")
    if "call opt_cluster(env,solu,clus,'cluster.coord',.false.)" not in qcg_main:
        raise AssertionError("grow pre-final optimizer call was changed")
    if "call opt_cluster(env,solu,clus,'cluster.xyz',.true.)" in qcg_main:
        raise AssertionError("grow-final still uses external opt_cluster")
    for fragment in (
        "if (allocated(calc%freezelist)) deallocate (calc%freezelist)",
        "calc%nfreeze = 0",
        "call optimize_geometry(molin,molout,calc",
        "env%qcg_final_optlev_set",
    ):
        if fragment not in qcg_misc:
            raise AssertionError(f"missing final optimizer contract: {fragment}")

    with tempfile.TemporaryDirectory(prefix="crest-gmc-qcg-final-") as tmp:
        workdir = Path(tmp)
        (workdir / "one.xyz").write_text("1\nH\nH 0.0 0.0 0.0\n")
        for option in ("--qcg-final-opt-level", "-qcg-final-opt-level"):
            result = run(binary, workdir, "one.xyz", "--dry", option, "vtight")
            if result.returncode != 0:
                print(result.stdout, file=sys.stderr, end="")
                print(result.stderr, file=sys.stderr, end="")
                raise AssertionError(f"accepted option failed: {option}")
            if "qcg-final-opt-level very tight" not in result.stdout:
                raise AssertionError(f"accepted level was not reported: {option}")

        absent = run(binary, workdir, "one.xyz", "--dry")
        if absent.returncode != 0:
            raise AssertionError("absent final-only option changed dry-run compatibility")
        if "qcg-final-opt-level" in absent.stdout:
            raise AssertionError("absent option unexpectedly changed parser output")

        for value in ("invalid-level",):
            invalid = run(binary, workdir, "one.xyz", "--dry", "--qcg-final-opt-level", value)
            if invalid.returncode == 0:
                raise AssertionError("invalid final opt-level did not fail fast")
        missing = run(binary, workdir, "one.xyz", "--dry", "--qcg-final-opt-level")
        if missing.returncode == 0:
            raise AssertionError("missing final opt-level did not fail fast")

    return 0


if __name__ == "__main__":
    raise SystemExit(main())
