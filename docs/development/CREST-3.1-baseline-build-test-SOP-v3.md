# CREST 3.1/GloMinCluster baseline build and test SOP v3

## 文档状态

本文件是当前有效的 CREST-GMC baseline 构建与测试 SOP，取代历史执行前方案
`SOP-v2`。本仓库中未发现 tracked 或工作树中的 SOP-v2；v2 不复制、不加入 Git，
也不与本文件并列作为当前 SOP。

本 SOP 基于已完成的 CREST 3.1 fork baseline 实际证据重构。它定义“从干净源码
重新固定并验收”的操作顺序，不把一次 build success 当作 runtime acceptance。

## 1. Scope

本 SOP 用于：

- 固定 CREST 3.1/GloMinCluster fork 的可复现 source、toolchain、submodule 和
  build baseline；
- 将 baseline acceptance 与 diagnostic testing 分开；
- 将日常开发 dynamic build 与未来 release/static distribution 分开；
- 在构建之后执行 binary identity 和 runtime smoke；
- 单独验证 QCG 所依赖的外部 xTB compatibility。

本 SOP 不授权修改 CREST 源码、第三方 submodule、gitlink、外部 xTB 或科学参数。
遇到源码、依赖、输入、输出或结构异常必须明确失败，不能静默跳过。

## 2. Pinned source

baseline source 必须固定为：

~~~text
Repository: hdlghzb/crest
Upstream: crest-lab/crest
Branch: glomincluster/crest-3.1-api-v1
HEAD: bd27e348ec001e27eab3177586843e8d86f66dc8
Tag: gmc-crest-3.1-base-bd27e34
~~~

进入源码目录后先执行，不得先更新 submodule：

~~~bash
git branch --show-current
git rev-parse HEAD
git describe --tags --exact-match HEAD 2>/dev/null || true
git status --short
git diff
git diff --cached
git submodule status --recursive
git submodule foreach --recursive 'git status --short --untracked-files=no'
~~~

期望的递归 submodule SHA 如下。输出有 `+`、`-` 或 `U` 前缀时必须停止并诊断，
不得自动 `git submodule update` 或改变 gitlink：

~~~text
subprojects/ddx                         4d79e3d9caeae5e602683572a71cb550414f9b09
subprojects/dftd4                       6e1f59c3f39d919a2dbef0601d2576727c8b30e8
subprojects/fmlip_relay                 1f297071f28ae6725aa693cac93ff8b3c84f6020
subprojects/gfn0                        d77fea885a890eae98939037e1e618e768608bc4
subprojects/gfnff                       272ed91b9ff71ad955f5996d3e08a7ee1b8b8c6d
subprojects/gfnff/subprojects/test-drive e8b7ca492c647ed384c9845d2caed04192af7d02
subprojects/lwoniom                    9430975e59d759879e157dd1cb9b83468f57fd36
subprojects/lwoniom/subprojects/test-drive e8b7ca492c647ed384c9845d2caed04192af7d02
subprojects/lwoniom/subprojects/toml-f  28f4601fe0992ed17a6b97e230a61289f56bcd8e
subprojects/mctc-lib                    e9de066d89f250d1cfb6de3a33f0c27c0e2f855d
subprojects/mstore                     663245d739be0123da61c917e55116b0c3db4c74
subprojects/multicharge                 6a5d63f9e9e29dcf13cc47cc27f33bf9015681bf
subprojects/pvol                       010bddaa8766a03e023a977aeebaa6454629c947
subprojects/pvol/subprojects/test-drive e8b7ca492c647ed384c9845d2caed04192af7d02
subprojects/s-dftd3                    6f0b06fbfa8653a23ca55c453772ce3af4420702
subprojects/tblite                     b244a0f2f9f254781f09711d05573f3225df4eb2
subprojects/test-drive                 c506771aefd594e7e372240a8027b3fd06d61264
subprojects/toml-f                     28f4601fe0992ed17a6b97e230a61289f56bcd8e
~~~

`.meson-subproject-wrap-hash.txt` 等本地生成文件可以在本地 exclude，但不得修改
tracked `.gitignore`。发现用户已有修改时保留并报告，不能覆盖、恢复或混入验收。

## 3. Toolchain

当前推荐 baseline toolchain：

~~~text
GCC/GFortran 14.2.0
OpenBLAS 0.3.34
CMake >= 3.21 (validated: 3.31.10)
Ninja
xTB 6.7.0 for Phase 1 QCG
~~~

要求：

- CMake 必须显式指定 GCC/GFortran 14.2 的 `CMAKE_C_COMPILER`、
  `CMAKE_CXX_COMPILER` 和 `CMAKE_Fortran_COMPILER`，不能依赖集群默认
  `/usr/bin/cc/gfortran`（当前为 GCC 8.5）。
- OpenBLAS 必须解析到 `/share/software/openblas/0.3.34`，不能只根据
  `WITH_OPENBLAS` 定义推断实际链接库。
- `OMP_NUM_THREADS` 不得硬编码到 modulefile；每次测试在命令或测试环境中显式
  记录。baseline CMake CTest 使用 `1,2,1` 的测试线程设定，专项复核可固定为 1。
- 构建放在源码树外的独立 build tree；不得复用旧 CMake cache。

## 4. OpenBLAS validation

加载 compiler 和 OpenBLAS module 后，保存以下输出：

~~~bash
pkg-config --modversion openblas
pkg-config --libs openblas
pkg-config --cflags openblas
pkg-config --variable=libdir openblas
~~~

必须确认版本为 `0.3.34`、libdir 为
`/share/software/openblas/0.3.34/lib`，并对解析出的 `libopenblas.so` 执行：

~~~bash
ldd /share/software/openblas/0.3.34/lib/libopenblas.so
nm -D /share/software/openblas/0.3.34/lib/libopenblas.so \
  | grep openblas_set_num_threads
~~~

validation gate：OpenMP 支持可用，`libgomp` 和 `libgfortran` 可解析，且所有
依赖检查均无 `not found`。最终还必须在 `crest` binary 上重复 `ldd` 检查；不能
仅凭 pkg-config PASS 宣称 CREST link/runtime PASS。

## 5. Primary acceptance build

当前 baseline 的 primary acceptance route 是 CMake `RelWithDebInfo`。Meson 用于
诊断，不替代该 gate；未来 `Release` 和 distribution/static build 另行验收。

在源码外建立全新的 build tree，例如：

~~~bash
SRC=/home/zbhu/GloMinCluster/crest
BUILD=/home/zbhu/GloMinCluster/crest-build/baseline-cmake-relwithdebinfo-openblas
CC_PATH=$(command -v gcc)
CXX_PATH=$(command -v g++)
FC_PATH=$(command -v gfortran)

cmake -S "$SRC" -B "$BUILD" -G Ninja \
  -DCMAKE_BUILD_TYPE=RelWithDebInfo \
  -DCMAKE_C_COMPILER="$CC_PATH" \
  -DCMAKE_CXX_COMPILER="$CXX_PATH" \
  -DCMAKE_Fortran_COMPILER="$FC_PATH" \
  -DBLA_VENDOR=OpenBLAS
~~~

配置前记录 `gcc --version`、`gfortran --version`、`cmake --version`、
`ninja --version` 和 OpenBLAS validation 输出。若 CMake cache 已存在，删除该
独立 build tree 后重新配置，不能用旧 cache 掩盖 compiler 或 BLAS 解析问题。

## 6. Build gate

完成配置后执行完整 Ninja build：

~~~bash
cmake --build "$BUILD" --parallel 2
~~~

build gate 只有在完整 build 成功后才为 `PASS`。同时保存并审计：

- `crest` final link line；
- `test/crest-tester` final link line；
- link line 中的 OpenBLAS 是否来自 `/share/software/openblas/0.3.34`；
- `openblas_set_num_threads_` 等符号是否已解析；
- 生成 binary 的 `ldd` 是否无 `not found`。

当前已验证基准为 `1592/1592 PASS`。仅 configure PASS 或部分 target 编译通过
不得标记为 build gate PASS。

## 7. Test gate

primary acceptance 采用 upstream-equivalent crest-only CTest，不把所有 bundled
subproject tests 作为主 gate：

~~~bash
OMP_NUM_THREADS='1,2,1' \
ctest --test-dir "$BUILD" \
  --output-on-failure \
  --parallel 2 \
  -R '^crest/'
~~~

当前基准为：

~~~text
15/15 PASS
0 FAIL
~~~

`metadynamics`、`pbc_cregen` 和 `molecular_dynamics` 必须包含在该 gate 中。
若 CTest 失败，保留完整输出、环境和 binary，不以其它子项目测试结果覆盖失败。

## 8. Binary/runtime identity

在与 build 相同的 compiler/OpenBLAS runtime 环境中执行：

~~~bash
"$BUILD/crest" --version
ldd "$BUILD/crest"
~~~

记录并核对：

- CREST version，应为 `3.1.0`；
- commit/build identity；当前 baseline binary 的 metadata 为
  `commit (unknown-commit)`，这是待后续 metadata 阶段改善的事实，不在本 SOP
  中修改源码；
- OpenBLAS 是否来自 `/share/software/openblas/0.3.34`；
- `libgfortran`、`libgomp`、`libgcc_s` 是否来自 GCC 14.2 runtime；
- `not found=none`。

identity 失败时，build 和 CTest 不能合并报告为完整 acceptance PASS。

## 9. Runtime smoke

Runtime smoke 必须使用已通过 build/test/identity gate 的 `crest` binary。至少执行
并记录以下场景：

| 场景 | 必须检查 |
|---|---|
| GFN2 single point | exit status、能量输出、正常终止 |
| standalone `mdopt` | 轨迹结构数、每个结构处理结果、正常终止 |
| NCI-iMTD | 预期目录/轨迹、正常终止 |
| `--gfn2@gfnff` | 末端重优化结构数、正常终止 |
| `--gfn2//gfnff` | 各阶段结构和 single-point 输出、正常终止 |
| QCG | 按下一节的 xTB-specific gate 检查 |

当前已验证的非 QCG smoke 为：GFN2 single point、standalone mdopt、NCI-iMTD、
`--gfn2@gfnff` 和 `--gfn2//gfnff` 均 PASS。不得仅凭 binary 可执行或 exit 0
而跳过预期输出、结构数和正常终止检查。

## 10. QCG-specific runtime

Phase 1 默认 QCG runtime 固定为稳定 release xTB `6.7.0`。每次 QCG 验证先保存：

~~~bash
which xtb
xtb --version
~~~

并保留 `best.xyz`、`xtb_dock.out`、QCG full log、exit status 和运行环境快照。
QCG gate 至少检查：

- CREST exit status 为 0，且出现正常终止标记；
- `best.xyz` 是可读的 ASCII XYZ，首行原子数和实际坐标行数一致；
- 对 1-propanol/water 固定输入，`best.xyz` 为 15 atoms / 17 lines；
- `xtb_dock.out` 含 `Successful` 和 `* finished run`；
- docking、结构数和后续 QCG 阶段均正常完成。

必须执行并保存与固定 binary、输入、参数、GCC/OpenBLAS、
`OMP_NUM_THREADS=1` 一致的 A/B 结果。不能因另一版本成功而掩盖当前版本失败。

> **Compatibility warning.** Official tagged xTB `6.7.1` has a verified QCG/aISS
> compatibility regression with the pinned CREST 3.1 baseline and SHALL NOT be used
> as the default Phase 1 QCG runtime.

官方 xTB `6.7.1` 的失败应归类为 `external xTB aISS version compatibility
regression`，不得通过修改 CREST workaround。其已观察到 `best.xyz` invalid/empty、
atom-count mismatch 和 docking 未正常完成。

CREST 源码注明的
`902b313678b95d793122174df09d590365a669d7` 也可作为 compatibility evidence：
该独立 source/build/install 的 `Release` build 为 `808/808 PASS`，QCG runtime
为 PASS，runtime banner 显示完整 commit，`best.xyz` 和 `xtb_dock.out` 正常。
但它是 post-release development commit，不是默认 runtime pin；Phase 1 仍固定
xTB `6.7.0`。

## 11. Debug diagnostics

Meson Debug route 用于 numerical robustness 和依赖配置诊断，**NOT the primary
acceptance gate**。如需复现诊断，使用源码外独立目录，并保存 configure、build、
link、test 和环境日志。

当前 baseline 诊断边界：

- `config/gnu.ini` + strict `-std=f2018`：configure PASS、compile FAIL；固定
  pvol 存在 declaration-order incompatibility，不在 baseline 验证中修复。
- GNU-default Meson：pvol compile PASS、953 targets 进入 link，但由于 generic
  `/usr/lib64/libblas.so` 与 `WITH_OPENBLAS` 组合导致
  `openblas_set_num_threads_` unresolved；不添加 workaround。
- Meson Debug + 正确 OpenBLAS：953/953 build PASS，但完整 183 项测试仍记录
  `OK 131`、`Expected Fail 9`、`Fail 2`、`Timeout 41`。
- 已知 numerical diagnostics：zero-RMSD `metadynamics` SIGFPE
  (`irmsd_module.f90:476`)；`pbc_cregen` 在 FPE trap 下触发 DGESVD 相关
  SIGFPE (`pbc_fingerprint.f90:117`)。
- full dependency test 的 timeout/oversubscription 也必须保留为诊断信息；不能把
  线程/超时复核结果写成完整 Meson suite PASS。
- `molecular_dynamics` 的 timeout/oversubscription 可在
  `OMP_NUM_THREADS=1`、timeout multiplier=`5` 下专项复核；一次已验证复核为
  `81.26 s PASS`，这不删除其它诊断。

zero-RMSD MTD 必须列为后续独立 hardening task，不能在 SOP-v3 中以忽略测试、
修改 FPE 行为或静默重分类的方式“修复”。

## 12. Release build

CREST 独立 `CMAKE_BUILD_TYPE=Release` 在当前 baseline 中为：

~~~text
NOT YET VALIDATED
~~~

未来必须使用新的独立 build tree 显式设置 `CMAKE_BUILD_TYPE=Release`，并重新
完成完整 build、crest-only tests、全部 runtime smoke、QCG gate 和 `ldd` identity。
`RelWithDebInfo` 通过不能替代 Release acceptance；xTB 902b313 的独立 Release
build 也不能替代 CREST Release build。

## 13. Distribution/static build

正式发布阶段还必须单独验证 Linux x86_64 self-contained static
`crest-gmc` binary，参考 upstream CREST GNU static-release model。distribution
acceptance 应重新记录：

- static configure 选项、compiler、BLAS/LAPACK provider 和完整 build；
- binary 是否能在目标用户环境中运行；
- crest-only tests、runtime smoke、QCG compatibility 和 `ldd`/静态依赖审计；
- release artifact、SHA256、安装说明和回归报告。

目标是普通 GloMinCluster 用户不必提供 GCC、OpenBLAS、Meson、Ninja 或 CMake。
当前 QCG 仍需要外部兼容 xTB runtime，因此 static CREST binary 不等于 QCG
runtime 自包含。

本节是 **release/distribution acceptance requirement**，不是当前 baseline 已完成
项目。

## 14. Evidence retention

每次 baseline 验证必须保留到阶段收口：

- source preflight、submodule status、compiler/module/version snapshot；
- OpenBLAS pkg-config、`ldd`、symbol audit；
- CMake configure、完整 build、CTest 和 binary identity 输出；
- 每个 runtime smoke 的输入、命令、exit status、预期输出和正常终止证据；
- QCG 的 `which xtb`、`xtb --version`、`best.xyz`、`xtb_dock.out`、full log、
  atom-count/line-count 检查和环境快照；
- diagnostic、timeout、SIGFPE 和失败版本的原始日志。

不提交以下内容：

~~~text
build tree
binary
*.log
raw runtime output
独立 xTB source/build/install tree
temporary files
~~~

这些证据应保留在开发/验收机器的受控目录，并在报告中记录绝对路径。若证据
丢失，状态只能写为 `NOT TESTED` 或 `MOCK-ONLY`，不能追溯性地写成 PASS。

## 15. Acceptance status vocabulary

统一使用以下状态：

| 状态 | 含义 |
|---|---|
| `PASS` | 已实际执行，输出和验收条件均满足 |
| `PASS WITH DEBUG DIAGNOSTICS` | 核心 acceptance 满足，但诊断测试保留已知问题 |
| `BLOCKED` | 因明确外部依赖或前置条件无法继续，证据已保留 |
| `FAIL` | 已执行且验收条件未满足 |
| `NOT TESTED` | 尚未实际执行 |
| `MOCK-ONLY` | 只有 mock/code-level 证据，没有真实 runtime 证据 |

以下项目不能单独写成 real runtime `PASS`：code inspection、configure success、
compile success、部分 target success 或 mock test。QCG 也不能以 CREST binary
可执行替代外部 xTB compatibility verification。

## 16. Baseline closure audit

文档和验收收口前执行：

~~~bash
git status --short
git diff -- docs/development/
git diff --check
git diff --name-only
git diff --cached --name-only
git submodule status --recursive
git submodule foreach --recursive 'git status --short --untracked-files=no'
~~~

确认：

- CREST source 无 tracked 修改；
- submodule 无 tracked 修改；
- gitlink 无变化；
- `.gitignore` 无无关修改；
- build tree、binary、log、raw runtime output 和 xTB source/build/install tree 未
  进入提交；
- 报告中明确列出未执行的 CREST Release、install 和 distribution/static 项目；
- 当前有效 SOP 只有本文件，历史 SOP-v2 不作为执行入口。

如只提交文档，使用显式路径，禁止 `git add -A` 或 `git add .`：

~~~bash
git add docs/development/CREST-3.1-baseline.md \
  docs/development/CREST-3.1-baseline-build-test-SOP-v3.md
git diff --cached --check
git diff --cached --name-only
~~~

建议提交信息：

~~~text
docs(dev): finalize CREST 3.1 baseline and SOP
~~~
