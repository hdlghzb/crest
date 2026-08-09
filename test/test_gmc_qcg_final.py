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
    xtb_parser = (source_root / "src/parsing/parse_xtbinput.f90").read_text()
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
        "parse_qcg_final_constraints(calc,molin,env%qcg_final_cinp",
    ):
        if fragment not in qcg_misc:
            raise AssertionError(f"missing final optimizer contract: {fragment}")
    helper = qcg_misc.split("subroutine qcg_final_opt_internal", 1)[1].split(
        "end subroutine qcg_final_opt_internal", 1
    )[0]
    if "env%constraints" in helper:
        raise AssertionError("generic --cinp leaked into the final helper")
    if "qcg_final_cinp" in qcg_main:
        raise AssertionError("final-cinp field leaked into qcg_main")
    if qcg_misc.count("parse_qcg_final_constraints") != 2:
        raise AssertionError("final-cinp parser is not confined to the final helper")
    for fragment in (
        "unsupported block",
        "unsupported key",
        "distance",
        "angle",
        "dihedral",
        "force constant",
        "qcg_final_atoms_ok",
    ):
        if fragment not in xtb_parser:
            raise AssertionError(f"missing strict final-constraint contract: {fragment}")

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

        (workdir / "final.inp").write_text("$constrain\ndistance: 1,2,1.5\n$end\n")
        final_cinp = run(binary, workdir, "one.xyz", "--dry", "--qcg-final-cinp", "final.inp")
        if final_cinp.returncode != 0:
            raise AssertionError("accepted final-cinp path failed during dry-run parsing")
        if "final-only constraint file" not in final_cinp.stdout:
            raise AssertionError("final-cinp path was not recorded independently")

        for args in (("--qcg-final-cinp",), ("--qcg-final-cinp", "--dry")):
            missing_cinp = run(binary, workdir, "one.xyz", "--dry", *args)
            if missing_cinp.returncode == 0:
                raise AssertionError("missing final-cinp argument did not fail fast")

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
