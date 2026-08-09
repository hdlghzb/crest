# CREST GMC Phase 2A test report

Record date: 2026-08-09

Status: **NOT CLOSED**. A1 final-optimizer controls and A2 final-only
structural restraints are implemented and targeted-tested. Capability updates,
standalone equivalence, clean Release acceptance, and the post-implementation
QCG runtime gate remain pending.

## Source identity

```text
Repository: /home/zbhu/GloMinCluster/crest
Branch: glomincluster/crest-3.1-api-v1
A1 source commit: b64768274d0f6861ab07e14bd46ec901652a7cee
A2 source commit: 5b63f63ef1e75cf8e9f4513517a3c930b656592b
Pinned Phase 1 base: bd27e348ec001e27eab3177586843e8d86f66dc8
```

## A1 implementation

Commit `b647682` changes only the QCG grow-final no-wall path and its tests:

- QCG grow-final optimization now uses the existing internal
  `optimize_geometry`/calculator path.
- `--qcg-final-opt-level <level>` (and the normalized single-dash form) is
  final-only; `vtight` and existing optimization-level names are accepted.
- Missing and invalid values fail fast. An absent option preserves the QCG
  default optimization level.
- The final calculator explicitly clears freeze and constraint state so the
  grow-only whole-solute protection is not inherited.
- `cluster_optimized.xyz` is written only after successful final optimization.
- QCG setup/growth/aISS, preoptimization, ensemble/CFF, generic `--cinp`, and
  the xTB 6.7.0 target were not changed.

## A1 evidence

Evidence root: `/home/zbhu/GloMinCluster/crest-build`

| Check | Result | Evidence |
|---|---|---|
| CMake configure | PASS | `phase2a-a1-cmake-configure-20260809.log` |
| GCC14/OpenBLAS incremental build | PASS | `phase2a-a1-cmake-build-resume-20260809.log`, remaining 22/22 |
| A1 QCG-final targeted test | PASS | `phase2a-a1-targeted-20260809.log` |
| Phase 1 targeted baseline | PASS | same log; optimization, gmc_energy, gmc_cregen, gmc_hybrid, gmc_capabilities: 5/5 |
| CLI parser/scope checks | PASS | `phase2a-a1-parser-20260809.log` |
| `git diff --check` and source artifact audit | PASS | tester report |

The tests used GCC/GFortran 14.2.0, OpenBLAS 0.3.34, and the explicit runtime
library path required by the Phase 1 acceptance. No real QCG/xTB runtime was
run after A1 or A2, so final geometry/energy-component runtime behavior is not
yet accepted.

## A2 implementation

Commit `5b63f63` adds a strict final-only structural-restraint path:

- `--qcg-final-cinp <file>` is parsed independently from generic `--cinp` and
  loaded only by the QCG grow-final internal optimizer.
- Only numeric distance/bond, angle, and dihedral targets are accepted. The
  parser rejects `auto`, `reference`/`coord.ref`, `$wall`, unsupported blocks or
  keys, malformed values, missing files, non-solute indices, and repeated atom
  indices within one internal coordinate.
- Distance targets are converted from Angstrom to bohr; angle and dihedral
  targets reuse the existing calculator constraint constructors and their unit
  handling. No second restraint-energy implementation was added.
- The final helper clears grow-only freeze and constraint state before adding
  the explicitly requested final constraints. The existing grow/setup/aISS
  paths do not read `qcg_final_cinp`.

## A2 evidence

| Check | Result | Evidence |
|---|---|---|
| GCC14/OpenBLAS CMake build | PASS | `phase2a-a2-cmake-build-resume-20260809.log`, 144/144 |
| A2 + A1 targeted CTest | PASS | `phase2a-a2-targeted-20260809.log`, 6/6 |
| Final incremental rebuild after declaration cleanup | PASS | current A2 build tree, 8/8 link/build steps |
| Final targeted CTest rerun | PASS | current A2 build tree, 6/6 |
| `git diff --check` | PASS | tester report and final pre-commit check |

The first CTest attempt used the system Fortran runtime and failed before test
execution because `/lib64/libgfortran.so.5` lacked `GFORTRAN_10`. Re-running
with `LD_LIBRARY_PATH=/share/software/gcc/14.2.0/lib64:/share/software/openblas/0.3.34/lib`
passed all six tests; this was an environment-loading issue, not a source
regression. No real QCG/xTB runtime was run after A2, so geometry, energy
components, grow/aISS non-leakage, and rollback behavior remain unaccepted.

## Pending gates

- Capability JSON fields for the QCG final optimizer and constraint types.
- A1/A2 standalone mdopt-equivalence comparison and final energy-component
  checks on the returned geometry.
- Meson targeted and full regression, clean Release provenance, ldd,
  and official xTB 6.7.0 runtime smokes: baseline, vtight without restraints,
  and vtight with a distance restraint.

Therefore:

```text
Phase 2A = NOT CLOSED
blocker = capability, standalone-energy, Meson/Release, and official xTB 6.7.0 runtime gates are not complete
```
