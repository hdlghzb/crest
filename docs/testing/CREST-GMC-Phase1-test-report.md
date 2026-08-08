# CREST GMC Phase 1 Commit 2 test report

Record date: 2026-08-09

This report covers Commit 2 (`70531d5`): calculator energy-component
preservation, persistence, metadata invalidation, and the existing GMC
capability/provenance probe. CREGEN raw-energy ranking remains intentionally
unimplemented.

## Fixed inputs

```text
Repository: /home/zbhu/GloMinCluster/crest
Branch: glomincluster/crest-3.1-api-v1
Validated commit: 70531d5
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
- CMake tree: `/home/zbhu/GloMinCluster/crest-build/phase1-gmc-api-cmake-openblas-explicit`
- Meson tree: `/home/zbhu/GloMinCluster/crest-build/phase1-gmc-energy-debug-gnu-default`

## Results

| Check | Result | Evidence |
|---|---|---|
| CMake code build | PASS | 179/179 targets after the final source changes |
| CMake metadata rebuild | PASS | 24/24 post-commit targets; embedded `70531d5` |
| CMake crest-only CTest | PASS | 17/17, including optimization and GMC tests |
| CMake GMC energy tests | PASS | `crest/gmc_energy`, U1-U8, 1/1 |
| CMake capability test | PASS | `crest/gmc_capabilities`, 1/1; `fork_commit=70531d5` |
| Meson code build | PASS | 955/955 targets in the GCC14 Debug tree |
| Meson metadata relink | PASS | 65/65 after refreshing `crest_metadata.fh` |
| Meson targeted regression | PASS | energy, capability, optimization, irmsd, metadynamics, 5/5 |

The capability JSON reports `energy_components=true` and
`raw_energy_ranking=false`. The latter remains false because CREGEN has not yet
been changed to rank ensembles by raw energy.

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

- The full Meson dependency suite is not a Phase 1 primary acceptance gate;
  only the five direct regression tests above were run.
- Clean Release build/runtime validation is still pending.
- QCG plus xTB 6.7.0 modified-fork smoke validation is still pending.
- Official xTB 6.7.1 compatibility evidence remains documented provenance, not
  an API v1 capability field.
