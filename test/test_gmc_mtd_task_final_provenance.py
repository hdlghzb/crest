#!/usr/bin/env python3
"""Runtime contract test for the E0 same-source provenance bridge."""

import hashlib
import subprocess
import sys
import tempfile
from pathlib import Path


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


def sha256(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def xyz_frame_count(path: Path) -> int:
    lines = path.read_text().splitlines()
    count = 0
    index = 0
    while index < len(lines):
        if not lines[index].strip():
            index += 1
            continue
        nat = int(lines[index].strip())
        if nat < 1 or index + nat + 1 >= len(lines):
            raise AssertionError(f"invalid XYZ frame in {path} at line {index + 1}")
        count += 1
        index += nat + 2
    return count


def parse_sidecar(path: Path) -> tuple[dict[str, str], list[dict[str, str]]]:
    metadata: dict[str, str] = {}
    rows: list[dict[str, str]] = []
    header = None
    for line in path.read_text().splitlines():
        if line.startswith("# "):
            key, value = line[2:].split("=", 1)
            metadata[key] = value
        elif line.strip():
            if header is None:
                header = line.split("\t")
            else:
                fields = line.split("\t")
                if len(fields) != len(header):
                    raise AssertionError("sidecar row width mismatch")
                rows.append(dict(zip(header, fields)))
    if header != [
        "local_token",
        "input_index",
        "optimization_status",
        "optimized_output_index",
        "final_selection_status",
        "final_output_index",
        "reason",
    ]:
        raise AssertionError(f"unexpected sidecar header: {header!r}")
    return metadata, rows


def main() -> int:
    if len(sys.argv) != 2:
        print(f"usage: {sys.argv[0]} CREST_BINARY", file=sys.stderr)
        return 2

    binary = str(Path(sys.argv[1]).resolve())
    source_root = Path(__file__).resolve().parents[1]
    search_source = (source_root / "src/algos/search_conformers.f90").read_text()
    provenance_source = (source_root / "src/gmc_task_final_provenance.f90").read_text()
    begin = search_source.index("call gmc_task_final_begin(trim(atmp),nall)")
    wrap = search_source.index("call crest_multilevel_wrap(env,trim(atmp),0)", begin)
    if wrap < begin or "call gmc_task_final_begin(trim(atmp),nall)" not in search_source[begin:wrap]:
        raise AssertionError("snapshot call is not on the native pre-task-final path")
    if "access='stream'" not in provenance_source or "form='unformatted'" not in provenance_source:
        raise AssertionError("snapshot implementation is not byte-preserving stream I/O")
    with tempfile.TemporaryDirectory(prefix="crest-gmc-task-final-provenance-") as tmp:
        workdir = Path(tmp)
        (workdir / "struc.xyz").write_text(FIXTURE)
        result = subprocess.run(
            [
                binary,
                "struc.xyz",
                "--gfnff",
                "--imtdgc",
                "-nci",
                "-squick",
                "-T",
                "1",
                "--optlev",
                "tight",
                "--gmc-mtd-task-final-opt",
                "on",
                "--gmc-mtd-task-final-provenance",
                "on",
            ],
            cwd=workdir,
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
            text=True,
            check=False,
        )
        if result.returncode != 0 or "CREST terminated normally." not in result.stdout:
            raise AssertionError(
                f"provenance runtime failed with code {result.returncode}:\n"
                f"{result.stdout[-3000:]}\n{result.stderr[-1000:]}"
            )

        snapshot = workdir / "gmc_task_final_normal_input.xyz"
        sidecar = workdir / "gmc_task_final_provenance.tsv"
        if not snapshot.is_file() or not sidecar.is_file():
            raise AssertionError("snapshot or provenance sidecar was not produced")

        metadata, rows = parse_sidecar(sidecar)
        required = {
            "schema": "glomincluster.crest.task-final-provenance.v1",
            "task_final_opt": "true",
            "source_geometry_level": "normal",
            "final_geometry_level": "tight",
        }
        for key, expected in required.items():
            if metadata.get(key) != expected:
                raise AssertionError(f"{key}: expected {expected!r}, got {metadata.get(key)!r}")

        final = workdir / metadata["final_artifact"]
        native = workdir / metadata["native_input_artifact"]
        if not final.is_file():
            raise AssertionError(
                f"sidecar artifact references are not present: metadata={metadata!r}, "
                f"files={[path.name for path in workdir.iterdir()]}"
            )
        if native.is_file() and sha256(native) != sha256(snapshot):
            raise AssertionError("snapshot is not an exact byte-preserving copy")

        input_count = int(metadata["input_count"])
        if len(rows) != input_count or xyz_frame_count(snapshot) != input_count:
            raise AssertionError("snapshot/provenance candidate count mismatch")
        tokens = [row["local_token"] for row in rows]
        if len(set(tokens)) != len(tokens) or any(
            len(token) != 16 or not token.startswith("GMC_TFI_") or not token[8:].isdigit()
            for token in tokens
        ):
            raise AssertionError("local occurrence tokens are not unique and valid")
        if sorted(int(row["input_index"]) for row in rows) != list(range(1, input_count + 1)):
            raise AssertionError("input indices are not a complete snapshot ordinal mapping")

        optimization_statuses = {
            "optimization_success",
            "optimization_failed",
            "partial_optimization_accepted",
        }
        final_statuses = {"retained", "filtered", "optimization_failed"}
        for row in rows:
            if row["optimization_status"] not in optimization_statuses:
                raise AssertionError(f"unrecorded optimization status: {row}")
            if row["final_selection_status"] not in final_statuses:
                raise AssertionError(f"unrecorded final selection status: {row}")
            optimized_index = int(row["optimized_output_index"])
            final_index = int(row["final_output_index"])
            if row["optimization_status"] == "optimization_success" and optimized_index < 1:
                raise AssertionError(f"successful optimization lacks output occurrence: {row}")
            if row["optimization_status"] != "optimization_success" and optimized_index != -1:
                raise AssertionError(f"non-success optimization has dumped output: {row}")
            if row["final_selection_status"] == "retained" and final_index < 1:
                raise AssertionError(f"retained source lacks final output index: {row}")
            if row["final_selection_status"] != "retained" and final_index != -1:
                raise AssertionError(f"filtered/failed source has final output index: {row}")

        retained = [row for row in rows if row["final_selection_status"] == "retained"]
        success_indices = sorted(
            int(row["optimized_output_index"])
            for row in rows
            if row["optimization_status"] == "optimization_success"
        )
        if success_indices != list(range(1, len(success_indices) + 1)):
            raise AssertionError("optimized output occurrence indices are not contiguous")
        if xyz_frame_count(final) != len(retained):
            raise AssertionError("final output count does not match retained provenance rows")
        final_text = final.read_text()
        for row in retained:
            if f"GMC_TFI={row['local_token']}" not in final_text:
                raise AssertionError(f"final output lost token {row['local_token']}")

    return 0


if __name__ == "__main__":
    raise SystemExit(main())
