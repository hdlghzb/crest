# CREST GMC Phase 1 Commit 3 test report

Record date: 2026-08-09

This report covers Commit 3 (`ff314d3`): CREGEN raw-energy ranking and the
associated C1-C7 regression suite, together with the Commit 2 energy-component
and capability regressions. CREGEN uses `coord%ranking_energy()` for scientific
ordering and filtering; legacy or invalid component metadata falls back to
`coord%energy`.

## Fixed inputs

```text
Repository: /home/zbhu/GloMinCluster/crest
Branch: glomincluster/crest-3.1-api-v1
Validated commit: ff314d3
Pinned upstream base: bd27e348ec001e27eab3177586843e8d86f66dc8
```

The source was clean at the implementation validation checkpoint. Both
capability tests compare the embedded `fork_commit` with
`git rev-parse --short=7 HEAD`.

## Toolchains and build trees

- GCC/GFortran `14.2.0`, OpenBLAS `0.3.34`
- CMake `3.31.10`, Ninja `1.13.0`, `RelWithDebInfo`
- Meson `1.11.2`, Ninja `1.13.0`, GNU-default Fortran dialect
  (`-Dfortran_std=none`), `Debug`
- CMake tree: `/home/zbhu/GloMinCluster/crest-build/phase1-cregen-raw-cmake-openblas`
- Meson tree: `/home/zbhu/GloMinCluster/crest-build/phase1-gmc-api-postcommit-meson`

## Results

| Check | Result | Evidence |
|---|---|---|
| CMake post-commit rebuild | PASS | 54/54 Ninja steps after refreshing build metadata |
| CMake crest-only CTest | PASS | 18/18, including all existing tests and GMC CREGEN |
| CMake GMC CREGEN tests | PASS | C1-C7, direct `crest-tester gmc_cregen`, 7/7 |
| CMake GMC energy tests | PASS | U1-U8, direct `crest-tester gmc_energy`, 8/8 |
| Periodic CREGEN regression | PASS | `crest/pbc_cregen`, including raw/total `pbc_identical` inversion |
| CMake capability test | PASS | `crest/gmc_capabilities`, `fork_commit=ff314d3` |
| Meson current-source rebuild | DIAGNOSTIC BLOCKED | baseline dependency `tblite/test_npz.f90` overflow and `msmod.f90` `findloc` compile errors |

The capability JSON reports `energy_components=true` and
`raw_energy_ranking=true`, with `fork_commit=ff314d3` and the fixed upstream
base `bd27e348ec001e27eab3177586843e8d86f66dc8`.

The CREGEN tests cover raw/total ranking inversion, raw EWIN in both directions,
molecular and periodic ETHR comparisons, raw-first representative selection,
legacy/constraint-off equivalence, and `env%elowest`. The periodic regression
also verifies that `pbc_identical` uses the raw ranking key rather than a
restraint-shifted total.

The calculator tests cover no-restraint identity, single and multiple
restraints, same-geometry raw-energy capture, coord copying, regular XYZ and
extxyz round trips, and legacy XYZ fallback. Existing optimization regression
also passes after ensuring the returned optimized geometry is the geometry for
which the final calculator components were evaluated.

For runtime checks the GCC14/OpenBLAS libraries were made explicit with:

```text
LD_LIBRARY_PATH=/share/software/gcc/14.2.0/lib64:/share/software/openblas/0.3.34/lib
```

## Known boundary and diagnostic status

- The CMake crest-only gate is the Phase 1 primary acceptance path. The full
  Meson dependency suite is not a primary acceptance gate.
- The current Meson tree was regenerated with GNU-default Fortran
  (`-Dfortran_std=none`), but its rebuild stops before linking CREST: GCC 14
  rejects `int(z'...')` constants in `subprojects/tblite/test/unit/test_npz.f90`
  and later rejects `findloc` in `src/msreact/msmod.f90`. These are build-route
  diagnostics outside the Commit 3 ranking changes; no stale Meson binary is
  used as Commit 3 evidence.
- Clean Release build/runtime validation is still pending.
- QCG plus xTB 6.7.0 modified-fork smoke validation is still pending.
- Official xTB 6.7.1 compatibility evidence remains documented provenance, not
  an API v1 capability field.
