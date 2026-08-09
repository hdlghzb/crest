# CREST/GloMinCluster fork: API and provenance

Status: Phase 1 status: **RUNTIME SMOKE-TESTED**.

CREST GMC fork Phase 1 is runtime smoke-tested on the clean committed source
acceptance state. The final clean Release acceptance covered provenance,
no-input capability behavior, dynamic linking, crest-only and full CTest,
GFN2/mdopt/NCI-iMTD, both hybrid modes, persistence/CREGEN artifact checks,
and QCG with official xTB 6.7.0.

This status is not scientific benchmark validation, constraint scientific
acceptance, formal software release acceptance, static distribution
acceptance, or FeCN6 acceptance.

## Fixed source and runtime boundary

- Fork repository: `hdlghzb/crest`
- Fork branch: `glomincluster/crest-3.1-api-v1`
- Upstream repository: `crest-lab/crest`
- Pinned upstream source baseline: `bd27e348ec001e27eab3177586843e8d86f66dc8`
- CREST version: `3.1.0`
- GMC machine API version: `1`

## Final clean acceptance identity

The accepted binary was configured and built fresh from this clean committed
source state before the documentation-only closeout commit:

```text
Pinned upstream base:       bd27e348ec001e27eab3177586843e8d86f66dc8
Accepted source HEAD:       44bfec711151474c85be827d9b95b47e812b5a81
Accepted source short HEAD: 44bfec7
Accepted fork_commit:       44bfec7
Accepted binary:
  /home/zbhu/GloMinCluster/crest-build/phase1-final-clean-acceptance-release/crest
Accepted binary SHA256:
  e2c85812621a9b7e965c835ed7e2c1f9947836d23fbb2a18eaddfff8ee91f76f
```

The binary `fork_commit` equals the accepted source short HEAD exactly. The
current documentation HEAD is the later docs-only closeout commit and is
intentionally distinct from the accepted binary provenance.

The pinned upstream SHA identifies the scientific/source baseline. It is not the
fork build identity. A binary reports the short source commit used at build time
as `fork_commit`.

## Capability probe

```bash
crest --gmc-capabilities
```

The probe needs no geometry, calculator, external xTB, or normal CREST startup.
It writes one machine-readable JSON object to stdout and exits successfully. API
v1 currently reports:

```json
{
  "gmc_api_version": 1,
  "crest_version": "3.1.0",
  "fork_commit": "<build-time-short-sha>",
  "upstream_base": "bd27e348ec001e27eab3177586843e8d86f66dc8",
  "energy_components": true,
  "raw_energy_ranking": true,
  "qcg_single_crest_orchestration": true,
  "qcg_aiss_external_xtb": true,
  "qcg_aiss_xtb_validated_version": "6.7.0"
}
```

`qcg_aiss_xtb_validated_version` is the Phase 1 QCG runtime target validated by
strict compatibility testing. It is not a runtime version probe, minimum version,
or claim that CREST supports only that release.

## Build-time provenance

Both CMake and Meson populate the existing `crest_metadata.fh` mechanism. In a
Git checkout they run `git -C <source-root> rev-parse --short=7 HEAD` at configure
time. The installed binary never runs Git and remains identifiable outside the
checkout. The short SHA format is the existing `--version` metadata convention.

For a source archive without `.git`, set the explicit build-time override
`CREST_FORK_COMMIT` before configure. CMake also accepts
`-DCREST_FORK_COMMIT=<commit>`. If neither Git metadata nor an override is
available, the generated value is `unknown-commit`; no upstream SHA is substituted.

Dirty development builds retain the current HEAD identity and have no separate
dirty-state field in API v1. Clean committed builds are the acceptance reference.

The baseline binary showed `commit (unknown-commit)` because its CMake metadata
command ran from an out-of-tree build directory rather than the source checkout.
Commit 1 fixes the command's source-root resolution and reuses the same metadata
for `--version` and `--gmc-capabilities`.

## QCG xTB provenance

- Validated default compatibility target: xTB `6.7.0`.
- Official tagged xTB `6.7.1` has a known aISS compatibility regression and is
  retained as a strict A/B diagnostic, not as the default pin.
- Development commit `902b313678b95d793122174df09d590365a669d7` passed the recorded
  compatibility check, but is not the default runtime target.

## Commit 2 energy components

`coord` retains legacy `energy` as the calculator total and adds
`energy_raw`, `energy_restraint`, `energy_total`, and
`energy_components_valid`. The calculator captures the active method energy
before additive constraints, then records the restraint contribution and total
as one metadata update. Copies, parallel SP/optimization paths, refinement
invalidations, plain XYZ comments, and extxyz frames preserve or explicitly
invalidate the metadata. Files without all three component keys fall back to
legacy `energy`; `ranking_energy()` is available for that compatibility rule.

## Commit 3 CREGEN raw-energy ranking

Commit `ff314d3` changes CREGEN scientific ranking and filtering to use
`coord%ranking_energy()`: valid components rank by `energy_raw`, while legacy or
invalid component metadata falls back to the legacy `energy` value. The change
covers initial sorting and EWIN, molecular and periodic ETHR comparisons,
representative/lowest-structure selection, relative-energy and population
tables, Boltzmann weights, ENSO tags, iRMSD CREGEN, and the periodic
`pbc_identical` helper.

The generic `ensemble_qsort` default remains legacy total-energy sorting; only
CREGEN callers opt into ranking energy explicitly. Calculator/optimizer/MD
energies, `coord%energy`, and ordinary XYZ/extxyz `energy=` output remain total.

## Commit 4 hybrid and persistence regression coverage

Commit `ac4a94a` adds the `gmc_hybrid` suite to both CMake and Meson test
registries. It covers hybrid parser semantics (`gfn2@gfnff`, `gfn2//gfnff`, and
the explicit opt form), workhorse/quality raw-energy capture, restraint
decomposition, plain XYZ and extxyz component round trips through CREGEN, and
legacy XYZ fallback without component metadata. The suite is test coverage only;
it does not change the hybrid algorithm or QCG workflow.

## Follow-up hybrid runtime closure

The implementation-stage binary identities below are historical evidence. They
are retained to explain the `2a8bc79` fix, but they are not the final accepted
binary identity; use **Final clean acceptance identity** above for Phase 1.

The first actual `gfn2@gfnff` runtime exposed a stale-component edge case in
the quality post-optimization return: the final geometry was correct, but the
last component metadata was not guaranteed to describe that returned geometry.
Commit `2a8bc79` makes a guarded final active-calculator reevaluation for
successful ordinary optimizations and adds a focused hybrid optimization
regression plus the no-dependency runtime artifact verifier
`test/integration/verify_hybrid_runtime.py`.

The fix was validated by actual `--gfn2@gfnff` and `--gfn2//gfnff` workflows,
independent GFN2/GFN-FF single points, production XYZ/extxyz round trips, and
CREGEN on the refined ensemble. The hybrid-fix Release crest-only gate passed
`19/19`; the targeted fix gate passed `6/6`. The binary used for these runtime
smokes reports `fork_commit=c7ee708` because it was built from the same
production-source state before the test-only commit; the implementation/test
commit is `2a8bc79`.

Because the production optimizer changed, the QCG compatibility gate was then
rerun with the hybrid-fix binary and xTB `6.7.0`. The retained evidence is
`/home/zbhu/GloMinCluster/crest-build/qcg-xTB-6.7.0-hybrid-fix-20260809`;
CREST exited 0, `best.xyz` and `best_after_gen.xyz` were each valid 15-atom
XYZ files, and `xtb_dock.out` contained successful and finished-run markers.
The binary SHA256 was
`a1e7e4421f4004931f08403c010e883c47eb258a6d2c077cd00666dacaaee466`.

## Final Phase 1 scope and next stage

`raw_energy_ranking=true` is backed by the final Release C1-C7 regression
(`7/7`) and the periodic CREGEN regression. The final Release build used
GCC/GFortran 14.2.0, OpenBLAS 0.3.34, CMake 3.31.10, and Ninja 1.13.0;
configure selected the explicit OpenBLAS 0.3.34 library and the complete build
passed `1600/1600`. Crest-only CTest passed `19/19`, full Release CTest passed
`72/72`, and the final capability probe reports `fork_commit=44bfec7`.

The final runtime evidence is retained under
`/home/zbhu/GloMinCluster/crest-build/runtime-phase1-final-clean-acceptance-20260809`.
All GFN2, mdopt, NCI-iMTD, hybrid, verifier, and QCG records reference the
same final binary SHA256 listed above. Meson Debug targeted tests passed `6/6`;
the direct Meson `pbc_cregen` SIGFPE at
`src/sorting/pbc_fingerprint.f90:117` remains the known non-blocking Debug
diagnostic, while CMake Release `pbc_cregen` passed.

These are executable runtime-smoke results, not scientific benchmarks.
Constraint redesign, QCG final optimizer work, MTD A/B or vtight workflow work,
and formal release readiness remain outside Phase 1.

Next stage: **Phase 2 — structural constraints + QCG final optimizer**.
