# CREST 3.1 GloMinCluster fork baseline

## 最终结论

**PASS WITH DEBUG DIAGNOSTICS**

核心 baseline acceptance 已通过：CMake `RelWithDebInfo` 构建、upstream-equivalent
crest-only CTest、binary identity、基础 runtime smoke 以及 xTB QCG compatibility
均已完成。Meson Debug 的数值诊断保留，不把诊断性失败写成核心 acceptance 失败。

本文件只记录已经实际执行的结果。未执行的项目保持 `NOT TESTED`，不以配置成功、
编译成功或 mock 结果替代真实 runtime 验证。

记录日期：2026-08-08

## 固定对象

```text
Repository: hdlghzb/crest
Upstream: crest-lab/crest
Source: /home/zbhu/GloMinCluster/crest
Branch: glomincluster/crest-3.1-api-v1
HEAD: bd27e348ec001e27eab3177586843e8d86f66dc8
Tag: gmc-crest-3.1-base-bd27e34
```

固定 baseline 的 branch、HEAD 和 tag 均已核对。构建和原始运行证据保留在：

```text
/home/zbhu/GloMinCluster/crest-build/
```

## Preflight 与递归 submodule

执行并保留以下检查：

```bash
git branch --show-current
git rev-parse HEAD
git describe --tags --exact-match HEAD 2>/dev/null || true
git status --short
git diff
git diff --cached
git submodule status --recursive
git submodule foreach --recursive 'git status --short --untracked-files=no'
```

顶层 tracked status、顶层 diff 和 staged diff 均无输出。递归 submodule 共 18
项，当前 HEAD 与 superproject gitlink 一致，未发现 tracked 修改或 gitlink 变化：

| 路径 | gitlink/HEAD |
|---|---|
| `subprojects/ddx` | `4d79e3d9caeae5e602683572a71cb550414f9b09` |
| `subprojects/dftd4` | `6e1f59c3f39d919a2dbef0601d2576727c8b30e8` |
| `subprojects/fmlip_relay` | `1f297071f28ae6725aa693cac93ff8b3c84f6020` |
| `subprojects/gfn0` | `d77fea885a890eae98939037e1e618e768608bc4` |
| `subprojects/gfnff` | `272ed91b9ff71ad955f5996d3e08a7ee1b8b8c6d` |
| `subprojects/gfnff/subprojects/test-drive` | `e8b7ca492c647ed384c9845d2caed04192af7d02` |
| `subprojects/lwoniom` | `9430975e59d759879e157dd1cb9b83468f57fd36` |
| `subprojects/lwoniom/subprojects/test-drive` | `e8b7ca492c647ed384c9845d2caed04192af7d02` |
| `subprojects/lwoniom/subprojects/toml-f` | `28f4601fe0992ed17a6b97e230a61289f56bcd8e` |
| `subprojects/mctc-lib` | `e9de066d89f250d1cfb6de3a33f0c27c0e2f855d` |
| `subprojects/mstore` | `663245d739be0123da61c917e55116b0c3db4c74` |
| `subprojects/multicharge` | `6a5d63f9e9e29dcf13cc47cc27f33bf9015681bf` |
| `subprojects/pvol` | `010bddaa8766a03e023a977aeebaa6454629c947` |
| `subprojects/pvol/subprojects/test-drive` | `e8b7ca492c647ed384c9845d2caed04192af7d02` |
| `subprojects/s-dftd3` | `6f0b06fbfa8653a23ca55c453772ce3af4420702` |
| `subprojects/tblite` | `b244a0f2f9f254781f09711d05573f3225df4eb2` |
| `subprojects/test-drive` | `c506771aefd594e7e372240a8027b3fd06d61264` |
| `subprojects/toml-f` | `28f4601fe0992ed17a6b97e230a61289f56bcd8e` |

`.meson-subproject-wrap-hash.txt` 仅通过 submodule 本地 `.git/info/exclude` 忽略，
未修改 tracked `.gitignore`。

## 验证环境

- GCC/GFortran `14.2.0`；系统默认 `/usr/bin/cc/gfortran` 为 GCC `8.5`，因此
  CMake route 显式固定 GCC 14.2 编译器。
- OpenBLAS `0.3.34`，主项目正确链接 `/share/software/openblas/0.3.34`。
- Meson `1.11.2`，Ninja `1.13.0`。
- CMake `/home/zbhu/.local/bin/cmake` `3.31.10`。
- Phase 1 QCG runtime candidate：xTB `6.7.0`；官方 xTB `6.7.1` 仅作为严格
  compatibility A/B 对照。
- 所有构建目录位于 `/home/zbhu/GloMinCluster/crest-build`，未写入仓库源码树。

## Phase 1-0A：Meson strict F2018

```text
Meson + config/gnu.ini + strict -std=f2018
Configure: PASS
Compile: FAIL
```

失败原因是固定 `subprojects/pvol` 源码的 declaration-order incompatibility：
`xhcff_engrad.f90:180` 和 `pv_engrad.f90:189` 在 strict F2018 下于声明前使用
`nno` 作为数组边界。该问题未修复；未修改 pvol 或其它源码。

## Phase 1-0B：Meson GNU-default dialect

```text
Meson GNU-default dialect
pvol compile: PASS
953 targets entered final link
link: FAIL
```

未使用 `config/gnu.ini`，生成文件不含 `-std=f2018`，因此 pvol 两个源文件编译
通过。Meson 未解析到真正 OpenBLAS，退回 generic `/usr/lib64/libblas.so`，同时
定义 `WITH_OPENBLAS`；最终在 `test/crest-tester` 和 `crest` 链接时出现：

```text
undefined reference to openblas_set_num_threads_
```

未添加 BLAS workaround，未修改源码或依赖 gitlink。

## Phase 1-0C：Meson Debug + OpenBLAS

配置为 GCC/GFortran `14.2.0`、OpenBLAS `0.3.34`、Meson GNU-default dialect 和
`-Dlapack=openblas`。`config/gnu.ini` 未使用，Fortran dialect 为 `none`。

结果：

```text
Configure: PASS
Debug build: 953/953 PASS
主 CREST link: /share/software/openblas/0.3.34
```

`crest` 和 `test/crest-tester` 的最终 link line 均包含
`/share/software/openblas/0.3.34/lib/libopenblas.so` 及对应 rpath，无 unresolved
symbol。ddx 子项目仍可能引用其默认 netlib BLAS/LAPACK；这不改变主 CREST 的
OpenBLAS link 结论。

完整 Meson Debug suite：

```text
183 total
OK 131
Expected Fail 9
Fail 2
Timeout 41
```

已保留的两个 Debug diagnostics：

- `metadynamics`：`SIGFPE`，`src/sorting/irmsd_module.f90:476`。
- `pbc_cregen`：`SIGFPE`，`src/sorting/pbc_fingerprint.f90:117`。

`molecular_dynamics` 在原始 Debug 测试中受 timeout/oversubscription 影响；在
`OMP_NUM_THREADS=1` 且 timeout multiplier=`5` 的后续复核中以 `81.26 s` PASS。
因此两个 SIGFPE 保留为 Debug diagnostics，原 MD timeout 归为 Debug 性能/线程
配置问题，不作为 CMake primary acceptance 的失败依据。

## Phase 1-0D-R：CMake RelWithDebInfo primary acceptance

采用 GCC/GFortran `14.2.0`、OpenBLAS `0.3.34`、CMake `3.31.10`、Ninja 和
`RelWithDebInfo`。由于集群默认 `/usr/bin/cc/gfortran` 为 GCC `8.5`，CMake
显式固定 GCC 14.2 编译器；未复用旧 CMake cache。

```text
Build: 1592/1592 PASS
upstream-equivalent crest-only CTest: 15/15 PASS, 0 FAIL
```

`metadynamics`、`pbc_cregen` 和 `molecular_dynamics` 均在该 CMake build 中
通过；MD 用时 `31.13 s`。这是当前 baseline 的 primary acceptance route。

binary identity：

```text
crest 3.1.0
commit (unknown-commit)
```

`ldd` 交叉检查结果：

- OpenBLAS 来自 `/share/software/openblas/0.3.34`；
- `libgfortran`、`libgomp`、`libgcc_s` 来自 GCC 14.2 runtime；
- `not found=none`。

`commit (unknown-commit)` 是当前已有 build metadata 状态，未在本轮修改源码；
后续 GMC capability metadata 阶段再处理。

## Runtime smoke

以下项目已使用 CMake primary acceptance binary 实际执行并 PASS：

| Smoke | 结果 |
|---|---|
| GFN2 single point | PASS；`--gfn2 --sp -T 1`，总能量 `-14.5574960501 Eh`，正常终止 |
| standalone `mdopt` | PASS；50/50 轨迹结构成功优化，正常终止 |
| NCI-iMTD | PASS；`--gfnff --imtdgc -nci -squick -T 1`，正常终止 |
| `--gfn2@gfnff` | PASS；27/27 末端重优化成功，正常终止 |
| `--gfn2//gfnff` | PASS；各阶段结构优化和单点评估成功，正常终止 |

每项均检查 exit status、预期输出和正常终止；未把 build success 当作 smoke
结果。

## QCG xTB compatibility

两版严格 A/B 固定相同 CREST binary、输入、参数、GCC/OpenBLAS 环境和
`OMP_NUM_THREADS=1`，仅切换 xTB runtime。CREST binary SHA256 为：

```text
4c854e912b40bd2f12aee35ddefcc95273b4da5f543630c65fef179f14286c1e
```

### xTB 6.7.0

```text
QCG: PASS
CREST exit: 0
best.xyz: 15 atoms / 17 lines, valid ASCII XYZ
xtb_dock.out: Successful; * finished run
```

因此：

```text
Phase 1 QCG runtime candidate = xTB 6.7.0
```

### official xTB 6.7.1

```text
QCG: FAIL
CREST exit: 1
best.xyz: empty/invalid
atom-count mismatch: Expected 15 got 5214
xtb docking: no normal finished marker
```

判定为：

```text
external xTB aISS version compatibility regression
```

这是外部 xTB compatibility 问题，不通过 CREST workaround 处理；不修改 CREST
源码或任何 submodule。

### xTB commit 902b313678b95d793122174df09d590365a669d7

该 commit 已独立完成 source/build/install 和 runtime 验证：

```text
Release build: 808/808 PASS
install: exit 0
runtime banner: 显示完整 commit
QCG: PASS
CREST exit: 0
best.xyz: 15 atoms / 17 lines, valid ASCII XYZ
xtb_dock.out: Successful; * finished run
```

这证明 CREST 3.1 源码中 `Tested with xtb version 6.7.1 (902b313)` 对应的是
该 post-release development commit。它只作为 compatibility evidence，不作为
默认 runtime pin：6.7.0 是稳定 release，严格 A/B 已通过，更易部署和复现。

## Post-baseline hardening：CREST MTD zero-RMSD

记录日期：2026-08-08。保留上面的 baseline 原始结果；本节记录后续的独立
zero-RMSD numerical hardening。修复位于 post-baseline hardening commit，未进入
GMC API 或其它 Phase 1 功能开发。

根因是 `src/sorting/irmsd_module.f90:rmsd_core` 在 `error == 0` 时仍计算
`(x-U^T y)/error`。当前 Gaussian RMSD bias 实际使用
`E = k*exp(-alpha*RMSD**2)` 和 `dEdr = -2*alpha*E*RMSD`，因此 exact zero
的 bias force 极限为零。由于这里的 `error` 非负，修复用 `error <= 0.0_wp` 识别
exact zero 并返回零梯度，其它值保留原梯度公式；不引入任意 near-zero 阈值，所以
正的 small/nonzero RMSD 仍走原路径，异常值也不会被 guard 静默吞掉。

修改文件：

- `src/sorting/irmsd_module.f90`：zero-RMSD gradient guard；
- `test/test_irmsd.F90`：public `rmsd(...,gradient=...)` 的 identical、translation、
  rotation、small-nonzero 和 finite-difference regression；
- `docs/development/CREST-3.1-baseline.md`：本节记录。

验证结果：

- GNU Debug + FPE traps：`crest/irmsd` 新增 5 项与原有项目共 9 项 PASS，
  `crest/metadynamics` 6/6 PASS；准确的 metadynamics test 已由 baseline 的
  `SIGFPE` 变为 PASS；
- GNU Debug CREST suite：14/15 PASS；唯一剩余失败是未修改的
  `src/sorting/pbc_fingerprint.f90:117` `pbc_cregen` DGESVD/SIGFPE diagnostic；
- CMake `RelWithDebInfo` + GCC/GFortran 14.2 + OpenBLAS 0.3.34：crest-only
  CTest `15/15 PASS`；
- NCI-iMTD runtime smoke：复用 water-trimer 输入，6 个 MTD 均正常完成，
  `144/144` 结构优化成功，`crest_dynamics.trj.xyz` 非空且未发现 NaN/Inf，
  最终 `CREST terminated normally`；
- 未进行科学 benchmark；本次结果属于 unit verified、debug regression verified
  和 runtime smoke verified。

## 未执行、限制与诊断边界

- 独立 CREST `CMAKE_BUILD_TYPE=Release`：`NOT YET VALIDATED`；本轮尚未执行，
  `RelWithDebInfo` 不等同于 `Release`。
- CREST `ninja install` 尚未执行，未覆盖生产 CREST。
- Meson Debug 完整 183 项 suite 的历史结果仍保留原始 timeout 诊断及
  `pbc_cregen` SIGFPE；不能写成全套 Meson tests PASS。
- 尚未开始 GMC API、energy raw/restraint/total、CREGEN
  raw ranking、constraint redesign 或 QCG final-vtight。
- 本轮未修改第三方 submodule、gitlink 或 tracked `.gitignore`。

## 证据保留

详细原始日志和 runtime 目录保留在 `crest-build` 及独立 xTB 工作目录，包含 0A、
0B、0C、0D-R 的 configure/build/test/identity 日志、QCG A/B 的 `best.xyz`、
`xtb_dock.out`、环境快照和 exit status，以及 902b313 的 source/build/install
日志。build tree、binary、log、raw runtime output 和独立 xTB source/build/install
tree 不提交到仓库。

主要证据根目录：

```text
/home/zbhu/GloMinCluster/crest-build/logs/
/home/zbhu/GloMinCluster/crest-build/qcg-xTB-ab-20260808-propanol-water-keeptmp/
/home/zbhu/GloMinCluster/crest-build/qcg-xTB-902b313-20260808-propanol-water-keeptmp-final/
/home/zbhu/GloMinCluster/xtb-902b313-src/
/home/zbhu/GloMinCluster/xtb-902b313-build/
/home/zbhu/GloMinCluster/xtb-902b313-install/
```

关键日志文件包括：

- `logs/preflight-0c-initial.log`、`logs/preflight-0c-final.log`；
- `logs/toolchain-baseline.log`、`logs/toolchain-gnu-default.log`、
  `logs/toolchain-openblas-0c.log`；
- `logs/meson-debug-setup.log`、`logs/ninja-debug-build.log`；
- `logs/meson-debug-gnu-default-setup.log`、
  `logs/ninja-debug-gnu-default-build.log`；
- `logs/meson-debug-openblas-setup.log`、
  `logs/meson-debug-openblas-audit.log`、
  `logs/ninja-debug-openblas-build.log`、
  `logs/meson-debug-openblas-test.log`；
- `logs/cmake-relwithdebinfo-openblas-setup-rerun.log`、
  `logs/ninja-cmake-relwithdebinfo-openblas-build.log`、
  `logs/ctest-cmake-relwithdebinfo-openblas-crest.log`、
  `logs/runtime-cmake-relwithdebinfo-openblas-identity.log`；
- `logs/runtime-cmake-relwithdebinfo-openblas-{basic-gfn2,mdopt,nci-imtd,gfn2-at-gfnff,gfn2-slash-gfnff}.log`；
- `logs/runtime-cmake-relwithdebinfo-openblas-qcg.log` 和
  `logs/runtime-cmake-relwithdebinfo-openblas-qcg-retry.log`；
- 独立 xTB 902b313 的 `reconfigure-from-source-local-deps.log`、
  `build-all-902b313-embedded-commit.log` 和
  `install-xtb-902b313-embedded-commit.log`。
