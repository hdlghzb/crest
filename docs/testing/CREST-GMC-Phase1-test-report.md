# CREST GMC Phase 1 final acceptance test report

Record date: 2026-08-09

This report records the final clean Release acceptance of the CREST/GMC fork.
The implementation-stage Commit 4 (`ac4a94a`) and hybrid runtime fix
(`2a8bc79`) remain cited below as historical implementation evidence; they are
not the final accepted source/binary identity. CREGEN uses
`coord%ranking_energy()` for scientific ordering and filtering; legacy or
invalid component metadata falls back to `coord%energy`.

## Final accepted inputs

```text
Repository: /home/zbhu/GloMinCluster/crest
Branch: glomincluster/crest-3.1-api-v1
Accepted source HEAD: 44bfec711151474c85be827d9b95b47e812b5a81
Accepted source short HEAD: 44bfec7
Pinned upstream base: bd27e348ec001e27eab3177586843e8d86f66dc8
Accepted binary: /home/zbhu/GloMinCluster/crest-build/phase1-final-clean-acceptance-release/crest
Accepted binary SHA256: e2c85812621a9b7e965c835ed7e2c1f9947836d23fbb2a18eaddfff8ee91f76f
Final runtime evidence root: /home/zbhu/GloMinCluster/crest-build/runtime-phase1-final-clean-acceptance-20260809
```

The accepted binary was built fresh from the clean accepted source state before
this documentation-only closeout. Its embedded `fork_commit=44bfec7` equals
the accepted source short HEAD. The current documentation HEAD is intentionally
later and distinct because this report is part of the docs-only closeout.

## Toolchains and build trees

- GCC/GFortran `14.2.0`, OpenBLAS `0.3.34`
- CMake `3.31.10`, Ninja `1.13.0`, `RelWithDebInfo` and `Release`
- Meson `1.11.2`, Ninja `1.13.0`, GNU-default Fortran dialect
  (`-Dfortran_std=none`), `Debug`
- Final clean Release tree: `/home/zbhu/GloMinCluster/crest-build/phase1-final-clean-acceptance-release`
- Historical RelWithDebInfo/Commit 4 trees are retained only for implementation evidence.
- Meson tree: `/home/zbhu/GloMinCluster/crest-build/phase1-commit4-meson-debug-current-gcc14`

## Results

| Check | Result | Evidence |
|---|---|---|
| Final clean CMake Release build | PASS | 1600/1600 Ninja steps |
| Release crest-only CTest | PASS | 19/19 |
| Release full CTest | PASS | 72/72 |
| Capability/provenance | PASS | `fork_commit=44bfec7`, API v1, components/ranking/QCG fields valid |
| No-input/no-xTB capability | PASS | empty/minimal PATH, JSON-only, exit 0, clean stderr |
| Dynamic `ldd` | PASS | no `not found`; GCC14/OpenBLAS 0.3.34 resolved |
| U1-U8 | PASS | 8/8 |
| C1-C7 | PASS | 7/7 |
| H1-H5/P1-P3 | PASS | 8/8 |
| Meson Debug targeted tests | PASS | metadynamics, iRMSD, GMC, optimization: 6/6 |
| Meson `pbc_cregen` | KNOWN DIAGNOSTIC | existing SIGFPE at `src/sorting/pbc_fingerprint.f90:117` under FPE traps |
| GFN2 single point | PASS | final binary, exit 0, `-14.5574960501 Eh`, normal termination |
| standalone mdopt | PASS | final binary, 50/50, component identity valid |
| NCI-iMTD | PASS | final binary, normal termination, trajectory non-empty, no NaN/Inf |
| HI1 `gfn2@gfnff` | PASS | final binary, 28/28 multilevel reoptimizations, raw-sorted output |
| HI2 `gfn2//gfnff` | PASS | final binary, quality SP did not change geometry |
| HI3/HI4 persistence | PASS | plain XYZ/extxyz, 9 frames, maximum metadata difference 0 Eh |
| HI5/verifier | PASS | energy decomposition, mapping, sorting, round trips |
| QCG + official xTB 6.7.0 | PASS | final binary, valid 15-atom `best.xyz`/`best_after_gen.xyz`, docking markers |

The final capability JSON reports `energy_components=true` and
`raw_energy_ranking=true`, with `fork_commit=44bfec7` and the fixed upstream
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

The final clean Release binary was
`/home/zbhu/GloMinCluster/crest-build/phase1-final-clean-acceptance-release/crest`.
Its `ldd` output resolved OpenBLAS 0.3.34 and GCC 14.2 `libgfortran`, `libgomp`,
and `libgcc_s`, with no `not found` entries.

The final non-QCG runtime evidence is retained in
`/home/zbhu/GloMinCluster/crest-build/runtime-phase1-final-clean-acceptance-20260809`:

| Smoke | Result | Acceptance evidence |
|---|---|---|
| GFN2 single point | PASS | exit 0, total energy `-14.5574960501 Eh`, normal termination |
| standalone mdopt | PASS | 50/50 structures optimized, non-empty `crest_ensemble.xyz` |
| NCI-iMTD | PASS | normal termination, non-empty trajectory, no NaN/Inf |
| `gfn2@gfnff` | PASS | normal termination, 28/28 reoptimized, raw-sorted quality output |
| `gfn2//gfnff` | PASS | normal termination, quality SP leaves geometry unchanged |

The final QCG evidence is retained in
`/home/zbhu/GloMinCluster/crest-build/runtime-phase1-final-clean-acceptance-20260809/qcg-official-xtb-6.7.0`.
The exact command was:

```text
/home/zbhu/GloMinCluster/crest-build/phase1-final-clean-acceptance-release/crest solute.xyz -qcg solvent.xyz -grow -nsolv 1 -maxsolv 1 -keeptmp -T 1
```

With GCC 14.2.0, OpenBLAS 0.3.34, xTB module `6.7.0`, and
`OMP_NUM_THREADS=1`, CREST exited 0 and terminated normally. The retained
`qcg_tmp/tmp_grow/best.xyz` and `best_after_gen.xyz` each contain 15 atoms in
17 lines. `xtb_dock.out` contains two `Successful` records and one
`* finished run` marker. The binary SHA256 is
`e2c85812621a9b7e965c835ed7e2c1f9947836d23fbb2a18eaddfff8ee91f76f`; its
capability probe reports `fork_commit=44bfec7`, `energy_components=true`,
`raw_energy_ranking=true`, and `qcg_aiss_xtb_validated_version=6.7.0`.

Historical Commit 4 QCG artifacts remain at
`/home/zbhu/GloMinCluster/crest-build/qcg-xTB-6.7.0-commit4-final-20260809`
as implementation evidence; they are not the final acceptance artifacts.

## Hybrid integration HI1–HI5

The actual final runtime binary was
`/home/zbhu/GloMinCluster/crest-build/phase1-final-clean-acceptance-release/crest`.
Both runs used the 12-atom neutral fixture `struc.xyz`, `-squick`,
`--imtdgc`, `-ewin 6.0`, and `-T 1`, with GCC14/OpenBLAS loaded explicitly.

### HI1: `--gfn2@gfnff`

Command:

```text
crest struc.xyz --gfn2@gfnff -squick --imtdgc -ewin 6.0 -T 1
```

The log identifies GFN-FF as the sampling/workhorse and GFN2 as the
`post_opt` quality stage. The actual quality-refined and CREGEN-sorted output
`crest_reopt.xyz.sorted` contains 28 frames with valid components and raw
energy order. The final runtime log records `28/28` successful GFN2 quality
reoptimizations and a normal CREST termination.

For the lowest sorted final frame, the hybrid `energy_raw` is
`-14.5585955075 Eh`; the runtime log identifies GFN2 as the quality stage and
the output contains no stale GFN-FF component. This is executable smoke
evidence, not a scientific benchmark.

### HI2: `--gfn2//gfnff`

Command:

```text
crest struc.xyz --gfn2//gfnff -squick --imtdgc -ewin 6.0 -T 1
```

The actual `crest_refine` input was captured at the final `ensemble
refinement` boundary. The final capture has 9 retained unique conformers;
matching those structures to the same-run 33-frame pre-quality input with
rigid-body alignment gives a maximum RMSD of `0.000e+00 Å`, so quality SP did
not change coordinates.

For the lowest final frame, hybrid `energy_raw` is `-14.5574805626 Eh`; an
independent GFN2 SP gives `-14.5574805629 Eh` (difference `3e-10 Eh`), while
the independent GFN-FF reference is `-1.6646494923 Eh`, a gap of about
`12.89 Eh`.

### HI3/HI4: persistence

The production `strucrd` round-trip verifier was run on the actual refined
ensembles. For the HI2 unique-conformer ensemble, both plain XYZ and extxyz
read-back preserved 9 frames, `energy_raw`, `energy_restraint`,
`energy_total`, and legacy `energy`; maximum metadata difference was `0 Eh`.
The corresponding HI1 sorted ensemble round trip also passed for 28 frames
with `0 Eh` maximum difference.

### HI5: refined ensemble and CREGEN

CREGEN processed the actual quality-stage HI2 ensemble. Its final log reports
the quality-stage lowest energy `-14.5574805626 Eh`; the 9-frame
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

- The final clean CMake Release crest-only gate is `19/19` and the full Release
  CTest is `72/72`; the full Meson dependency suite is not a primary acceptance
  gate.
- Meson Debug targeted tests pass 6/6 after reconfiguration. The full dependency
  suite was not run; direct `pbc_cregen` remains the known FPE-trap diagnostic at
  `src/sorting/pbc_fingerprint.f90:117`. The CMake primary `pbc_cregen` test
  passes in both RelWithDebInfo and Release gates.
- The runtime results above are smoke evidence only; no scientific benchmark,
  constraint validation, MTD A/B, or formal release acceptance was performed.
- Official xTB 6.7.1 compatibility evidence remains documented provenance, not
  an API v1 capability field.
