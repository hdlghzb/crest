# CREST GMC Phase 1 hybrid-integration test report

Record date: 2026-08-09

This report covers Commit 4 (`ac4a94a`) plus the follow-up hybrid runtime fix
(`2a8bc79`): hybrid/multilevel energy-contract and XYZ/extxyz persistence
regression coverage, production `crest_oloop`/`crest_sploop` integration, and
the Commit 2/3 regressions and final Phase 1 executable gates. CREGEN uses
`coord%ranking_energy()` for scientific ordering and filtering; legacy or
invalid component metadata falls back to `coord%energy`.

## Fixed inputs

```text
Repository: /home/zbhu/GloMinCluster/crest
Branch: glomincluster/crest-3.1-api-v1
Validated implementation/test commit: 2a8bc79
Pinned upstream base: bd27e348ec001e27eab3177586843e8d86f66dc8
```

The source was clean at the implementation/test checkpoint. The hybrid-fix
Release binary was built from the same production-source state before the
test-only commit, so its embedded provenance is `fork_commit=c7ee708`; the
validated source/test commit is `2a8bc79`.

## Toolchains and build trees

- GCC/GFortran `14.2.0`, OpenBLAS `0.3.34`
- CMake `3.31.10`, Ninja `1.13.0`, `RelWithDebInfo` and `Release`
- Meson `1.11.2`, Ninja `1.13.0`, GNU-default Fortran dialect
  (`-Dfortran_std=none`), `Debug`
- RelWithDebInfo tree: `/home/zbhu/GloMinCluster/crest-build/phase1-commit4-cmake-relwithdebinfo-openblas`
- Release tree: `/home/zbhu/GloMinCluster/crest-build/phase1-commit4-release-final-openblas`
- Hybrid-fix Release tree: `/home/zbhu/GloMinCluster/crest-build/phase1-hybrid-fix-release-final-openblas`
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
| Hybrid-fix targeted CTest | PASS | optimization, GMC energy/CREGEN/hybrid/capability, pbc CREGEN: 6/6 |
| Hybrid-fix Release crest-only CTest | PASS | 19/19 |

The hybrid-fix Release capability JSON reports `energy_components=true` and
`raw_energy_ranking=true`, with `fork_commit=c7ee708` and the fixed upstream
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

## Hybrid integration HI1–HI5

The actual runtime binary was
`/home/zbhu/GloMinCluster/crest-build/phase1-hybrid-fix-release-final-openblas/crest`.
Both runs used the 12-atom neutral fixture `struc.xyz`, `-squick`,
`--imtdgc`, `-ewin 6.0`, and `-T 1`, with GCC14/OpenBLAS loaded explicitly.

### HI1: `--gfn2@gfnff`

Command:

```text
crest struc.xyz --gfn2@gfnff -squick --imtdgc -ewin 6.0 -T 1
```

The log identifies GFN-FF as the sampling/workhorse and GFN2 as the
`post_opt` quality stage. The actual quality-refined and CREGEN-sorted output
`crest_reopt.xyz.sorted` contains 23 frames with valid components and raw
energy order. The quality optimization changed the geometry relative to its
actual 27-frame workhorse input; the maximum rigid-body-aligned RMSD to a
matched input frame was `4.11e-2 Å`.

For the lowest sorted final frame, the hybrid `energy_raw` is
`-14.5585953055 Eh`; an independent GFN2 SP gives `-14.5585953053 Eh`
(difference `2e-10 Eh`), while independent GFN-FF gives `-1.6635781607 Eh`.
Thus the final raw energy is quality-stage GFN2, not stale GFN-FF.

### HI2: `--gfn2//gfnff`

Command:

```text
crest struc.xyz --gfn2//gfnff -squick --imtdgc -ewin 6.0 -T 1
```

The actual `crest_refine` input was captured at the final `ensemble
refinement` boundary as `captured-crest_rotamers_1.xyz` (80 workhorse
structures). The final `crest_rotamers.xyz` has 37 retained structures and
`crest_conformers.xyz` has 9 unique conformers. Matching the final structures
to the same-run pre-quality input with rigid-body alignment gives a maximum
RMSD of `3.36e-11 Å` (`5.07e-11 Å` for the 9 unique conformers), so quality SP
did not change coordinates.

For the lowest final frame, hybrid `energy_raw` is `-14.5574855711 Eh`; an
independent GFN2 SP gives `-14.5574855710 Eh` (difference `1e-10 Eh`), while
independent GFN-FF gives `-1.6646481022 Eh`. The quality/workhorse gap is
`12.8928374689 Eh`.

### HI3/HI4: persistence

The production `strucrd` round-trip verifier was run on the actual refined
ensembles. For the HI2 unique-conformer ensemble, both plain XYZ and extxyz
read-back preserved 9 frames, `energy_raw`, `energy_restraint`,
`energy_total`, and legacy `energy`; maximum metadata difference was `0 Eh`.
The corresponding HI1 sorted ensemble round trip also passed for 23 frames
with `0 Eh` maximum difference.

### HI5: refined ensemble and CREGEN

CREGEN processed the actual quality-stage HI2 ensemble. Its log reports the
quality-stage lowest energy `-14.5574855711 Eh`; the 9-frame
`crest_conformers.xyz` output is sorted by the final quality `energy_raw`, and
all output components remain valid. The independent verifier
`test/integration/verify_hybrid_runtime.py` additionally checked the
same-run geometry mapping, both persistence formats, energy decomposition,
quality/workhorse separation, and raw-energy sorting. It returned:

```text
PASS: hybrid runtime artifact checks
```

The source fix in `2a8bc79` refreshes the active calculator on a successful
ordinary geometry-optimization return before component validity is accepted.
It is guarded from Hessian/thermochemical and sampling correction paths. The
new `test_optimization` regression reproduces the hybrid quality-optimization
path and compares its final raw energy with an independent GFN2 evaluation.

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
