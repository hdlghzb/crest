# CREST GMC Phase 2A test report

Record date: 2026-08-09

Status: **CLOSED** for the Phase 2A code/runtime acceptance scope. A1
final-optimizer controls, A2 final-only structural restraints, and A3
capability fields are implemented, regression-tested, standalone-equivalent,
clean-build validated, and runtime-smoke-tested with official xTB 6.7.0.

## Source identity

```text
Repository: /home/zbhu/GloMinCluster/crest
Branch: glomincluster/crest-3.1-api-v1
A1 source commit: b64768274d0f6861ab07e14bd46ec901652a7cee
A2 source commit: 5b63f63ef1e75cf8e9f4513517a3c930b656592b
A3 source commit: 96a9823f4e50d674c49bd91c854bd42ccffe25fe
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

## A3 implementation and evidence

Commit `96a9823f4e50d674c49bd91c854bd42ccffe25fe` adds the QCG final capability
contract without changing `gmc_api_version=1` or removing any Phase 1 fields:

- `qcg_final_optimizer`, `qcg_final_opt_level`, and `qcg_final_constraints` are
  `true`.
- `qcg_final_constraint_types` is the stable ordered list
  `['distance', 'angle', 'dihedral']`.
- The capability test checks the complete JSON object and the expected short
  source identity; no geometry, xTB, or normal CREST startup is required.

The A3 commit is present on `origin/glomincluster/crest-3.1-api-v1`. The source
was reconfigured and rebuilt after that commit in
`/home/zbhu/GloMinCluster/crest-build/phase2a-a1-cmake-relwithdebinfo-20260809`.

| Check | Result | Evidence |
|---|---|---|
| CMake reconfigure | PASS | `phase2a-a3-cmake-configure-20260809.log` |
| GCC14/OpenBLAS build | PASS | `phase2a-a3-cmake-build-20260809.log`, 42/42 |
| QCG-final targeted CTest | PASS | `phase2a-a3-targeted-20260809.log`, 3/3 |
| Capability JSON/provenance | PASS | `phase2a-a3-capabilities-20260809.json`, `fork_commit=96a9823` |
| Python capability contract | PASS | `test/test_gmc_capabilities.py`, expected `96a9823` |

The rebuilt binary reported API v1, the unchanged Phase 1 fields, all three
final capability flags, and the distance/angle/dihedral type list. The A3
checkpoint runtime checks used the explicit GCC14/OpenBLAS library path because
the system `libgfortran` does not provide `GFORTRAN_10`; the post-A3 QCG runtime
gate is recorded in the closure section below.

## Phase 2A acceptance closure

### Standalone equivalence

The A3 binary was compared with the standalone `optimize_geometry` path using
the same 15-atom propanol-water fixture, GFN2, `vtight`, one thread, and the
same final-only restraint file where applicable. The verifier is
`/home/zbhu/GloMinCluster/crest-build/phase2a-standalone-equivalence-20260809/verify_standalone_equivalence.py`;
its output is `standalone-equivalence.json`.

| Case | Translation-aligned RMSD (A) | Max component-energy difference (Eh) | d(1,2) difference (A) |
|---|---:|---:|---:|
| vtight, no final restraint | 1.22e-6 | 1.00e-10 | 1.39e-8 |
| vtight + distance restraint | 5.52e-3 | 2.22e-7 | 6.57e-6 |

Both cases passed the verifier tolerances of `0.01 A`, `2e-6 Eh`, and
`2e-4 A`. All QCG and standalone logs report `commit (96a9823)`.

### Clean CMake Release and Meson Release

| Check | Result | Evidence |
|---|---|---|
| Clean CMake Release configure/build | PASS, 1602/1602 | `phase2a-a3-clean-release-20260809/configure.log`, `build.log` |
| CMake crest-only CTest | PASS, 21/21 | `crest-only-ctest.log` |
| CMake full CTest | PASS, 74/74 | `full-ctest.log` |
| Clean CMake capability/provenance | PASS | `capabilities.json`, `crest_metadata.fh` |
| CMake dynamic linking | PASS | `ldd.txt`, GCC14/OpenBLAS paths, no missing libraries |
| Meson Release configure/build | PASS, 958/958 | `phase2a-a3-meson-release-20260809/setup.log`, `build.log` |
| Meson CREST suite | PASS, 21/21 | `crest-suite.log` |
| Meson capability/provenance | PASS | `capabilities.json`, `crest_metadata.fh` |
| Meson dynamic linking | PASS | `ldd.txt`, GCC14/OpenBLAS paths, no missing libraries |

Both build systems report API v1, `fork_commit=96a9823`, all Phase 1 fields,
and the A3 final capability fields. A broader Meson invocation over all 189
tests was not used as the CREST acceptance gate: it reached the unrelated
third-party `tblite:gfn1-xtb` 30-second test timeout. The project-scoped
`crest` suite passed independently and completely.

### Official xTB 6.7.0 QCG runtime

The clean CMake Release binary was run with
`/share/software/xtb/6.7.0/bin/xtb`, GCC/GFortran 14.2.0 and OpenBLAS 0.3.34
library paths, and one thread. Evidence root:
`/home/zbhu/GloMinCluster/crest-build/phase2a-qcg-runtime-20260809`.

| Case | Result | Runtime evidence |
|---|---|---|
| baseline | PASS | exit 0, normal QCG grow/final output |
| `vtight` without restraint | PASS | final-only opt level parsed, exit 0 |
| `vtight` + distance restraint | PASS | final-only constraint file parsed, exit 0 |

Each case reports CREST `96a9823`, xTB-docking `6.7.0 (08769fc)`, two
successful docking records, one finished-run marker, complete 15-atom
`best.xyz` and `best_after_gen.xyz`, `grow/cluster_optimized.xyz`, growth
completion, and normal CREST termination. The compact validation record is
`phase2a-qcg-runtime-20260809/validation.txt`.

Therefore:

```text
Phase 2A = CLOSED
closure = standalone equivalence, clean CMake/Meson Release gates, and all three official xTB 6.7.0 QCG runtime gates passed
non-goals = scientific benchmark/global-minimum validation, formal distribution release, and FeCN6 acceptance
```
