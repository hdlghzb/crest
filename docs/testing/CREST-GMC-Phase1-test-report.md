# CREST GMC Phase 1 Commit 4 test report

Record date: 2026-08-09

This report covers Commit 4 (`ac4a94a`): hybrid/multilevel energy-contract and
XYZ/extxyz persistence regression coverage, together with the Commit 2/3
regressions and final Phase 1 executable gates. CREGEN uses
`coord%ranking_energy()` for scientific ordering and filtering; legacy or
invalid component metadata falls back to `coord%energy`.

## Fixed inputs

```text
Repository: /home/zbhu/GloMinCluster/crest
Branch: glomincluster/crest-3.1-api-v1
Validated commit: ac4a94a
Pinned upstream base: bd27e348ec001e27eab3177586843e8d86f66dc8
```

The source was clean at the final validation checkpoint. The Release capability
test compares the embedded `fork_commit` with `git rev-parse --short=7 HEAD`.

## Toolchains and build trees

- GCC/GFortran `14.2.0`, OpenBLAS `0.3.34`
- CMake `3.31.10`, Ninja `1.13.0`, `RelWithDebInfo` and `Release`
- Meson `1.11.2`, Ninja `1.13.0`, GNU-default Fortran dialect
  (`-Dfortran_std=none`), `Debug`
- RelWithDebInfo tree: `/home/zbhu/GloMinCluster/crest-build/phase1-commit4-cmake-relwithdebinfo-openblas`
- Release tree: `/home/zbhu/GloMinCluster/crest-build/phase1-commit4-release-final-openblas`
- Meson tree: `/home/zbhu/GloMinCluster/crest-build/phase1-commit4-meson-debug-current-gcc14`

## Results

| Check | Result | Evidence |
|---|---|---|
| CMake RelWithDebInfo build | PASS | 1600/1600 Ninja steps |
| CMake RelWithDebInfo crest-only CTest | PASS | 19/19 |
| CMake GMC hybrid tests | PASS | H1-H5/P1-P3, 8/8 |
| Meson Debug targeted tests | PASS | metadynamics, irmsd, GMC energy/capability/hybrid, optimization, 6/6 |
| Meson `pbc_cregen` | DIAGNOSTIC | existing SIGFPE at `src/sorting/pbc_fingerprint.f90:117` under FPE traps |
| Clean CMake Release build | PASS | 1600/1600 Ninja steps |
| Release crest-only CTest | PASS | 19/19 |
| Release capability/identity | PASS | `fork_commit=ac4a94a`, `energy_components=true`, `raw_energy_ranking=true` |

The final Release capability JSON reports `energy_components=true` and
`raw_energy_ranking=true`, with `fork_commit=ac4a94a` and the fixed upstream
base `bd27e348ec001e27eab3177586843e8d86f66dc8`.

The CREGEN tests cover raw/total ranking inversion, raw EWIN in both directions,
molecular and periodic ETHR comparisons, raw-first representative selection,
legacy/constraint-off equivalence, and `env%elowest`. The periodic regression
also verifies that `pbc_identical` uses the raw ranking key rather than a
restraint-shifted total.

The calculator tests cover no-restraint identity, single and multiple
restraints, same-geometry raw-energy capture, coord copying, regular XYZ and
extxyz round trips, and legacy XYZ fallback. The new hybrid suite additionally
covers parser semantics, workhorse/quality raw-energy capture, restraint
decomposition, plain XYZ/extxyz round trips through CREGEN, and legacy fallback.
Existing optimization regression also passes after ensuring the returned
optimized geometry is the geometry for which the final calculator components
were evaluated.

For runtime checks the GCC14/OpenBLAS libraries were made explicit with:

```text
LD_LIBRARY_PATH=/share/software/gcc/14.2.0/lib64:/share/software/openblas/0.3.34/lib
```

## Runtime smoke

The final Release binary was
`/home/zbhu/GloMinCluster/crest-build/phase1-commit4-release-final-openblas/crest`.
Its `ldd` output resolved OpenBLAS 0.3.34 and GCC 14.2 `libgfortran`, `libgomp`,
and `libgcc_s`, with no `not found` entries.

The non-QCG runtime evidence is retained in
`/home/zbhu/GloMinCluster/crest-build/runtime-phase1-commit4-release-final-20260809`:

| Smoke | Result | Acceptance evidence |
|---|---|---|
| GFN2 single point | PASS | exit 0, total energy `-14.5574960501 Eh`, normal termination |
| standalone mdopt | PASS | 50/50 structures optimized, non-empty `crest_ensemble.xyz` |
| NCI-iMTD | PASS | normal termination, non-empty trajectory, no NaN/Inf |
| `gfn2@gfnff` | PASS | normal termination and non-empty best structure |
| `gfn2//gfnff` | PASS | normal termination and non-empty best structure |

The modified-fork QCG evidence is retained in
`/home/zbhu/GloMinCluster/crest-build/qcg-xTB-6.7.0-commit4-final-20260809`.
With module `xtb/6.7.0`, CREST exited 0 and terminated normally; retained
`qcg_tmp/tmp_grow/best.xyz` contains 15 atoms in 17 lines, and
`xtb_dock.out` contains at least two `Successful` records plus `* finished run`.

## Known boundary and diagnostic status

- The CMake crest-only gate is the Phase 1 primary acceptance path. The full
  Meson dependency suite is not a primary acceptance gate.
- Meson Debug targeted tests pass 6/6 after reconfiguration. The full dependency
  suite was not run; direct `pbc_cregen` remains the known FPE-trap diagnostic at
  `src/sorting/pbc_fingerprint.f90:117`. The CMake primary `pbc_cregen` test
  passes in both RelWithDebInfo and Release gates.
- The runtime results above are smoke evidence only; no scientific benchmark,
  constraint validation, MTD A/B, or formal release acceptance was performed.
- Official xTB 6.7.1 compatibility evidence remains documented provenance, not
  an API v1 capability field.
