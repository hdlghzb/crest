# CREST GMC Phase 2A test report

Record date: 2026-08-09

Status: **NOT CLOSED**. A1 final-optimizer controls are implemented and
targeted-tested. Final-only structural restraints, capability updates, clean
Release acceptance, standalone equivalence, and the post-implementation QCG
runtime gate remain pending.

## Source identity

```text
Repository: /home/zbhu/GloMinCluster/crest
Branch: glomincluster/crest-3.1-api-v1
A1 source commit: b64768274d0f6861ab07e14bd46ec901652a7cee
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
run after A1, so final geometry/energy-component runtime behavior is not yet
accepted.

## Pending gates

- A2 final-only numeric distance/angle/dihedral restraints, with no grow/aISS
  leakage and no `auto`/`coord.ref` support.
- Capability JSON fields for the QCG final optimizer and constraint types.
- A1/A2 standalone mdopt-equivalence comparison and final energy-component
  checks on the returned geometry.
- CMake/Meson targeted and full regression, clean Release provenance, ldd,
  and official xTB 6.7.0 runtime smokes: baseline, vtight without restraints,
  and vtight with a distance restraint.

Therefore:

```text
Phase 2A = NOT CLOSED
blocker = A2 and final acceptance gates are not complete
```

