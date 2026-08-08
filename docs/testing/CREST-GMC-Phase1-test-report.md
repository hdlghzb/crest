# CREST GMC Phase 1 test report

Record date: 2026-08-08

This report covers Commit 1 only: `crest --gmc-capabilities` and build-time fork
provenance. Energy component preservation and raw-energy ranking remain
`NOT IMPLEMENTED`.

## Fixed inputs

```text
Repository: /home/zbhu/GloMinCluster/crest
Branch: glomincluster/crest-3.1-api-v1
Pre-implementation HEAD: ff93ba50574c3790cf239a20df96cbcd602f9fb7
Pinned upstream base: bd27e348ec001e27eab3177586843e8d86f66dc8
```

The final acceptance identity is deliberately not hardcoded in this report:
`fork_commit` must equal `git rev-parse --short=7 HEAD` from the clean committed
source used for that acceptance build.

## Toolchains and build trees

- GCC/GFortran `14.2.0`, OpenBLAS `0.3.34`
- CMake `3.31.10`, Ninja `1.13.0`, `RelWithDebInfo`
- Meson `1.11.2`, Ninja `1.13.0`, GNU-default Fortran dialect, `Debug`
- CMake tree: `/home/zbhu/GloMinCluster/crest-build/phase1-gmc-api-cmake-openblas-explicit`
- Meson tree: `/home/zbhu/GloMinCluster/crest-build/phase1-gmc-api-debug`

## Results

| Check | Result | Evidence |
|---|---|---|
| CMake configure/build | PASS | 1594 Ninja actions completed (pre-commit build) |
| CMake capability test | PASS | `crest/gmc_capabilities`, 1/1; post-commit identity check also 1/1 |
| CMake crest-only CTest | PASS | 16/16 crest tests within full 69/69 CTest run, including capability test |
| CMake `--version` | PASS | version `3.1.0`, build commit visible |
| Meson configure/build | PASS | 686/686 targets completed in clean post-commit tree |
| Meson capability test | PASS | `crest/gmc_capabilities` |
| Meson targeted regression | PASS | GMC, `irmsd`, `metadynamics`, 3/3 |
| Meson `--version` | PASS | version `3.1.0`, build commit visible |

The pre-commit development binaries reported `fork_commit=ff93ba5`, matching the
source HEAD used at configure time. After the implementation commit
`0ea628d`, the CMake RelWithDebInfo tree was reconfigured and rebuilt for the
changed metadata/module targets, and a clean Meson Debug tree was built from
scratch. Both binaries reported:

```text
fork_commit=0ea628d
```

The post-commit capability tests compared this value with
`git rev-parse --short=7 HEAD`; neither acceptance result used the pre-commit
binary.

The capability test runs in a temporary directory with no geometry, removes
`XTBPATH`/`XTBHOME`, and replaces `PATH` with an empty location. It checks exit 0,
empty stderr, JSON parsing, fixed API fields, and the build-time commit value.

## Known boundary and diagnostic status

- The known Meson Debug `pbc_cregen` DGESVD/SIGFPE diagnostic is outside this
  targeted gate and is not modified by Commit 1.
- Official xTB `6.7.1` regression and the compatible `902b313...` development
  build remain documented provenance evidence, not API v1 JSON fields.
- `energy_components`: `NOT IMPLEMENTED` / `false`.
- `raw_energy_ranking`: `NOT IMPLEMENTED` / `false`.
