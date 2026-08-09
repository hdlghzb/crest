#!/usr/bin/env python3
# Environment: system Python 3.10
"""Verify retained CREST hybrid runtime artifacts without changing them.

The checker deliberately treats CREGEN output as rigid-body equivalent: CREGEN
may reorient a molecule while preserving its structure.  No third-party
dependency is required, so the verifier can run beside a Release binary.
"""

from __future__ import annotations

import argparse
import math
import re
from dataclasses import dataclass
from pathlib import Path


_ENERGY_RE = re.compile(
    r"(?:^|\s)(energy|energy_raw|energy_restraint|energy_total)=([^\s]+)"
)


@dataclass(frozen=True)
class Frame:
    atoms: tuple[str, ...]
    xyz: tuple[tuple[float, float, float], ...]
    comment: str
    energy: dict[str, float]


def read_xyz(path: Path) -> list[Frame]:
    lines = path.read_text().splitlines()
    frames: list[Frame] = []
    i = 0
    while i < len(lines):
        if not lines[i].strip():
            i += 1
            continue
        try:
            nat = int(lines[i].strip())
        except ValueError as exc:
            raise ValueError(f"{path}: invalid atom count at line {i + 1}") from exc
        if i + 1 + nat >= len(lines):
            raise ValueError(f"{path}: truncated frame at line {i + 1}")
        comment = lines[i + 1]
        atoms: list[str] = []
        xyz: list[tuple[float, float, float]] = []
        for line_no, line in enumerate(lines[i + 2 : i + 2 + nat], i + 3):
            fields = line.split()
            if len(fields) < 4:
                raise ValueError(f"{path}: invalid coordinate line {line_no}")
            atoms.append(fields[0])
            xyz.append(tuple(float(value) for value in fields[1:4]))
        energy = {key: float(value) for key, value in _ENERGY_RE.findall(comment)}
        frames.append(Frame(tuple(atoms), tuple(xyz), comment, energy))
        i += nat + 2
    if not frames:
        raise ValueError(f"{path}: no XYZ frames")
    return frames


def components(frames: list[Frame], label: str, tolerance: float) -> None:
    required = {"energy", "energy_raw", "energy_restraint", "energy_total"}
    max_balance = 0.0
    for index, frame in enumerate(frames, 1):
        missing = required.difference(frame.energy)
        if missing:
            raise ValueError(f"{label}: frame {index} missing {sorted(missing)}")
        balance = abs(
            frame.energy["energy_total"]
            - frame.energy["energy_raw"]
            - frame.energy["energy_restraint"]
        )
        legacy = abs(frame.energy["energy"] - frame.energy["energy_total"])
        max_balance = max(max_balance, balance, legacy)
        if balance > tolerance or legacy > tolerance:
            raise ValueError(f"{label}: frame {index} violates energy decomposition")
    print(f"{label}: frames={len(frames)} metadata=valid max_balance={max_balance:.3e}")


def _matvec(matrix: tuple[tuple[float, ...], ...], vector: tuple[float, ...]) -> tuple[float, ...]:
    return tuple(sum(row[j] * vector[j] for j in range(len(vector))) for row in matrix)


def _normalize(vector: tuple[float, ...]) -> tuple[float, ...]:
    norm = math.sqrt(sum(value * value for value in vector))
    if norm == 0.0:
        raise ValueError("zero quaternion in rigid-body alignment")
    return tuple(value / norm for value in vector)


def _rotation_from_quaternion(q: tuple[float, float, float, float]) -> tuple[tuple[float, ...], ...]:
    w, x, y, z = q
    return (
        (1 - 2 * (y * y + z * z), 2 * (x * y - z * w), 2 * (x * z + y * w)),
        (2 * (x * y + z * w), 1 - 2 * (x * x + z * z), 2 * (y * z - x * w)),
        (2 * (x * z - y * w), 2 * (y * z + x * w), 1 - 2 * (x * x + y * y)),
    )


def aligned_rmsd(left: Frame, right: Frame) -> float:
    if left.atoms != right.atoms:
        return math.inf
    n = len(left.xyz)
    lc = tuple(sum(point[k] for point in left.xyz) / n for k in range(3))
    rc = tuple(sum(point[k] for point in right.xyz) / n for k in range(3))
    p = tuple(tuple(point[k] - lc[k] for k in range(3)) for point in left.xyz)
    q = tuple(tuple(point[k] - rc[k] for k in range(3)) for point in right.xyz)
    sxx = sum(a[0] * b[0] for a, b in zip(p, q))
    sxy = sum(a[0] * b[1] for a, b in zip(p, q))
    sxz = sum(a[0] * b[2] for a, b in zip(p, q))
    syx = sum(a[1] * b[0] for a, b in zip(p, q))
    syy = sum(a[1] * b[1] for a, b in zip(p, q))
    syz = sum(a[1] * b[2] for a, b in zip(p, q))
    szx = sum(a[2] * b[0] for a, b in zip(p, q))
    szy = sum(a[2] * b[1] for a, b in zip(p, q))
    szz = sum(a[2] * b[2] for a, b in zip(p, q))
    davenport = (
        (sxx + syy + szz, syz - szy, szx - sxz, sxy - syx),
        (syz - szy, sxx - syy - szz, sxy + syx, szx + sxz),
        (szx - sxz, sxy + syx, -sxx + syy - szz, syz + szy),
        (sxy - syx, szx + sxz, syz + szy, -sxx - syy + szz),
    )
    quat = (1.0, 0.0, 0.0, 0.0)
    for _ in range(80):
        updated = _normalize(_matvec(davenport, quat))
        if max(abs(a - b) for a, b in zip(updated, quat)) < 1.0e-14:
            quat = updated
            break
        quat = updated
    rotation = _rotation_from_quaternion(quat)

    def residual(matrix: tuple[tuple[float, ...], ...]) -> float:
        squared = 0.0
        for a, b in zip(p, q):
            mapped = tuple(sum(a[j] * matrix[j][k] for j in range(3)) for k in range(3))
            squared += sum((mapped[k] - b[k]) ** 2 for k in range(3))
        return math.sqrt(squared / n)

    return min(residual(rotation), residual(tuple(zip(*rotation))))


def verify_geometry(pre: list[Frame], final: list[Frame], tolerance: float) -> None:
    distances: list[float] = []
    for index, candidate in enumerate(final, 1):
        best = min(aligned_rmsd(source, candidate) for source in pre)
        distances.append(best)
        if best > tolerance:
            raise ValueError(f"geometry mismatch for final frame {index}: {best:.3e} Å")
    print(
        "geometry: "
        f"final={len(final)} pre={len(pre)} "
        f"max_aligned_rmsd={max(distances):.3e} Å"
    )


def verify_sorted(final: list[Frame], tolerance: float) -> None:
    raw = [frame.energy["energy_raw"] for frame in final]
    for index, (left, right) in enumerate(zip(raw, raw[1:]), 1):
        if left > right + tolerance:
            raise ValueError(f"raw-energy order decreases between frames {index} and {index + 1}")
    print(f"cregen: raw_energy_sorted=true first={raw[0]:.10f} last={raw[-1]:.10f}")


def verify_roundtrip(reference: list[Frame], candidate: list[Frame], label: str, tolerance: float) -> None:
    if len(reference) != len(candidate):
        raise ValueError(f"{label}: frame count changed ({len(reference)} != {len(candidate)})")
    maximum = 0.0
    for index, (left, right) in enumerate(zip(reference, candidate), 1):
        if left.atoms != right.atoms:
            raise ValueError(f"{label}: atom identity changed at frame {index}")
        for key in ("energy", "energy_raw", "energy_restraint", "energy_total"):
            maximum = max(maximum, abs(left.energy[key] - right.energy[key]))
    if maximum > tolerance:
        raise ValueError(f"{label}: metadata changed by {maximum:.3e} Eh")
    print(f"{label}: frames={len(candidate)} max_metadata_diff={maximum:.3e} Eh")


def verify_reference(final: list[Frame], path: Path, label: str, minimum_gap: float) -> None:
    reference = read_xyz(path)
    if not reference:
        raise ValueError(f"{label}: empty reference")
    value = final[0].energy["energy_raw"]
    reference_value = reference[0].energy.get("energy_raw", reference[0].energy.get("energy"))
    if reference_value is None:
        raise ValueError(f"{label}: reference has no energy")
    print(f"{label}: final={value:.10f} reference={reference_value:.10f} diff={value-reference_value:.3e} Eh")
    if label == "quality_reference" and abs(value - reference_value) > 1.0e-7:
        raise ValueError(f"{label}: final raw energy does not match reference")
    if label == "workhorse_reference" and abs(value - reference_value) < minimum_gap:
        raise ValueError(f"{label}: quality raw is not distinguishable from workhorse energy")


def verify_log_reference(final: list[Frame], path: Path, label: str, minimum_gap: float) -> None:
    matches = re.findall(r"TOTAL ENERGY\s+([-+0-9.Ee]+)", path.read_text())
    if not matches:
        raise ValueError(f"{label}: no TOTAL ENERGY in {path}")
    value = float(matches[-1])
    difference = final[0].energy["energy_raw"] - value
    print(f"{label}: final={final[0].energy['energy_raw']:.10f} reference={value:.10f} diff={difference:.3e} Eh")
    if label == "quality_log" and abs(difference) > 1.0e-7:
        raise ValueError(f"{label}: final raw energy does not match reference")
    if label == "workhorse_log" and abs(difference) < minimum_gap:
        raise ValueError(f"{label}: quality raw is not distinguishable from workhorse energy")


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--final", type=Path, required=True, help="actual refined ensemble")
    parser.add_argument("--pre", type=Path, help="same-run pre-quality ensemble")
    parser.add_argument("--plain", type=Path, help="plain XYZ round-trip")
    parser.add_argument("--extxyz", type=Path, help="extxyz round-trip")
    parser.add_argument("--quality-reference", type=Path)
    parser.add_argument("--workhorse-reference", type=Path)
    parser.add_argument("--quality-log", type=Path)
    parser.add_argument("--workhorse-log", type=Path)
    parser.add_argument("--geometry-tol", type=float, default=1.0e-8)
    parser.add_argument("--energy-tol", type=float, default=1.0e-8)
    parser.add_argument("--stage-gap", type=float, default=1.0e-4)
    args = parser.parse_args()

    final = read_xyz(args.final)
    components(final, "final", args.energy_tol)
    verify_sorted(final, args.energy_tol)
    if args.pre:
        verify_geometry(read_xyz(args.pre), final, args.geometry_tol)
    if args.plain:
        verify_roundtrip(final, read_xyz(args.plain), "plain_xyz", args.energy_tol)
    if args.extxyz:
        verify_roundtrip(final, read_xyz(args.extxyz), "extxyz", args.energy_tol)
    if args.quality_reference:
        verify_reference(final, args.quality_reference, "quality_reference", args.stage_gap)
    if args.workhorse_reference:
        verify_reference(final, args.workhorse_reference, "workhorse_reference", args.stage_gap)
    if args.quality_log:
        verify_log_reference(final, args.quality_log, "quality_log", args.stage_gap)
    if args.workhorse_log:
        verify_log_reference(final, args.workhorse_log, "workhorse_log", args.stage_gap)
    print("PASS: hybrid runtime artifact checks")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
