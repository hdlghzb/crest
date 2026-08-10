#!/usr/bin/env python3
"""Regression test for the no-input GMC capability/provenance probe."""

import json
import os
from pathlib import Path
import subprocess
import sys
import tempfile


EXPECTED = {
    "gmc_api_version": 1,
    "crest_version": "3.1.0",
    "upstream_base": "bd27e348ec001e27eab3177586843e8d86f66dc8",
    "energy_components": True,
    "raw_energy_ranking": True,
    "qcg_single_crest_orchestration": True,
    "qcg_aiss_external_xtb": True,
    "qcg_aiss_xtb_validated_version": "6.7.0",
    "qcg_final_method": True,
    "qcg_final_methods": ["inherit", "--gfn1", "--gfn2", "--gfnff"],
    "qcg_final_optimizer": True,
    "qcg_final_opt_level": True,
    "qcg_final_constraints": True,
    "qcg_final_constraint_types": ["distance", "angle", "dihedral"],
    "mtd_task_final_opt": True,
}


def main() -> int:
    if len(sys.argv) not in (2, 3):
        print(f"usage: {sys.argv[0]} CREST_BINARY [EXPECTED_COMMIT]", file=sys.stderr)
        return 2

    binary = str(Path(sys.argv[1]).resolve())
    expected_commit = sys.argv[2] if len(sys.argv) == 3 else None
    with tempfile.TemporaryDirectory(prefix="crest-gmc-capabilities-") as workdir:
        env = os.environ.copy()
        env["PATH"] = str(Path(workdir) / "empty-bin")
        env.pop("XTBPATH", None)
        env.pop("XTBHOME", None)
        result = subprocess.run(
            [binary, "--gmc-capabilities"],
            cwd=workdir,
            env=env,
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
            universal_newlines=True,
            check=False,
        )

    if result.returncode != 0:
        print(f"capability probe exit code: {result.returncode}", file=sys.stderr)
        print(result.stderr, file=sys.stderr, end="")
        return 1
    if result.stderr:
        print(f"unexpected stderr: {result.stderr!r}", file=sys.stderr)
        return 1

    try:
        payload = json.loads(result.stdout)
    except json.JSONDecodeError as exc:
        print(f"stdout is not JSON: {exc}: {result.stdout!r}", file=sys.stderr)
        return 1

    for key, value in EXPECTED.items():
        if payload.get(key) != value:
            print(f"{key}: expected {value!r}, got {payload.get(key)!r}", file=sys.stderr)
            return 1

    if expected_commit is not None and payload.get("fork_commit") != expected_commit:
        print(
            "fork_commit: expected "
            f"{expected_commit!r}, got {payload.get('fork_commit')!r}",
            file=sys.stderr,
        )
        return 1
    if not payload.get("fork_commit"):
        print("fork_commit must be non-empty", file=sys.stderr)
        return 1

    return 0


if __name__ == "__main__":
    raise SystemExit(main())
