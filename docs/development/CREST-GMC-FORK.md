# CREST/GloMinCluster fork: API and provenance

Status: Phase 1 Commit 3, GMC capability/provenance, energy components, and CREGEN raw-energy ranking.

## Fixed source and runtime boundary

- Fork repository: `hdlghzb/crest`
- Fork branch: `glomincluster/crest-3.1-api-v1`
- Upstream repository: `crest-lab/crest`
- Pinned upstream source baseline: `bd27e348ec001e27eab3177586843e8d86f66dc8`
- CREST version: `3.1.0`
- GMC machine API version: `1`

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

## Scope and remaining work

`raw_energy_ranking=true` is backed by the Commit 3 C1-C7 regression suite and
the existing periodic CREGEN regression. QCG, constraint redesign, and MTD A/B
or vtight work remain outside this commit. Clean Release validation and the
modified-fork QCG plus xTB 6.7.0 runtime smoke remain pending.
