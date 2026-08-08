# GloMinCluster / CREST Fork Phase 1 详细执行方案
## —— 在已验收 CREST 3.1 基线上建立 GMC API v1、分离 raw/restraint/total energy，并使 CREGEN 使用 raw energy

**用途：** 直接交给 Codex / Luna 执行的 Phase 1 当前有效实施文档
**日期：** 2026-08-08
**GloMinCluster 目标开发线：** `develop/0.2.0a2`
**CREST fork：** `hdlghzb/crest`
**CREST upstream：** `crest-lab/crest`
**CREST fork branch：** `glomincluster/crest-3.1-api-v1`
**固定 upstream base / PR #483 commit：** `bd27e348ec001e27eab3177586843e8d86f66dc8`
**固定 upstream base tag：** `gmc-crest-3.1-base-bd27e34`
**CREST version metadata：** `3.1.0`
**Phase 1 QCG runtime candidate：** **xTB 6.7.0**
**已验证兼容参考：** xTB `902b313678b95d793122174df09d590365a669d7` QCG PASS
**已知不兼容：** official tagged xTB 6.7.1 在固定 CREST 3.1 baseline 上 QCG/aISS FAIL
**Phase 1 状态：** Phase 1-0 baseline 已完成；zero-RMSD MTD hardening 已完成并 push；现在进入 GMC API / energy foundation 实施阶段

**当前基础证据文档：**

```text
docs/development/CREST-3.1-baseline.md
docs/development/CREST-3.1-baseline-build-test-SOP-v3.md
```

> 本文中的 `bd27e348...` 是**固定 upstream base**，不是当前开发分支必须保持的 HEAD。当前 branch HEAD 已包含 baseline 文档提交和 post-baseline hardening；执行任务时必须读取实际 `git rev-parse HEAD`，不得把 branch 重置回 upstream base。

---

# 0. Phase 1 的最终目标

本阶段只建立未来 GloMinCluster 使用 CREST fork 所需的**底层科学接口**。

完成后应得到：

```text
GloMinCluster-controlled CREST 3.1 fork
        │
        ├─ pinned upstream base SHA
        ├─ reproducible build identity
        ├─ GMC API v1 capability probe
        │
        ├─ energy_raw
        ├─ energy_restraint
        ├─ energy_total
        │
        ├─ optimizer / MD 使用 total
        └─ CREGEN / EWIN / scientific ordering 使用 raw
```

同时保持：

```text
QCG = single CREST orchestration
```

但：

```text
QCG grow / aISS
→ 仍由 CREST 内部调用 external xTB
→ Phase 1 已验证默认 runtime candidate = xTB 6.7.0
```

因此本阶段**不删除 xTB runtime dependency**。

兼容性边界固定为：

```text
xTB 6.7.0                         QCG PASS，Phase 1 默认 candidate
official tagged xTB 6.7.1        QCG FAIL，已验证 compatibility regression
xTB 902b313... development commit QCG PASS，仅作兼容性证据，不作为默认 pin
```

---

# 1. 本阶段明确包含与不包含的内容

## 1.1 本阶段必须完成

### 已完成前置基础

以下已经完成，不得在 Phase 1 功能实现时重复建立或重置：

1. GloMinCluster-controlled CREST fork 已建立；
2. `origin = hdlghzb/crest`，`upstream = crest-lab/crest`；
3. upstream PR #483 base 固定为 `bd27e348...`；
4. 开发 branch 为 `glomincluster/crest-3.1-api-v1`；
5. baseline = `PASS WITH DEBUG DIAGNOSTICS`；
6. primary acceptance 已验证为 GCC 14.2 + OpenBLAS 0.3.34 + CMake 3.31.10 + RelWithDebInfo；
7. crest-only CTest 已验证 `15/15 PASS`；
8. GFN2、mdopt、NCI-iMTD、`--gfn2@gfnff`、`--gfn2//gfnff` runtime smoke 已通过；
9. QCG strict A/B 已固定 Phase 1 runtime candidate 为 xTB 6.7.0；
10. zero-RMSD MTD divide-by-zero 已在 commit `ff93ba5` 修复并通过 Debug / CMake / NCI-iMTD regression。

### Phase 1 当前待完成：能量语义

11. 增加：
   ```text
   energy_raw
   energy_restraint
   energy_total
   ```
12. `coord%energy` 继续保持 legacy **total energy** 语义；
13. calculator 在 structural restraint 加入前保存 raw；
14. restraint contribution 单独累计；
15. total 保持 optimizer / dynamics 实际使用值；
16. energy components 能够跨普通 XYZ / extxyz ensemble 落盘和读回；
17. legacy 文件没有 component metadata 时安全 fallback。

### Phase 1 当前待完成：科学排序

18. 增加统一 `ranking/science energy` accessor；
19. CREGEN 的：
   - energy sorting；
   - EWIN；
   - energy-difference screening；
   - representative energy comparison；
   - lowest-energy reference；
   全部使用 raw energy；
20. constraint off 时行为与已验收 baseline 不变。

### Phase 1 当前待完成：API / provenance

21. `crest --gmc-capabilities`；
22. 输出：
   - CREST version；
   - fork commit / build identity；
   - pinned upstream base；
   - GMC API version；
   - energy component capability；
   - raw-energy ranking capability；
   - QCG single-CREST orchestration；
   - QCG external xTB requirement；
   - **QCG validated xTB runtime version = 6.7.0**。

---

## 1.2 本阶段禁止实施

以下全部留到后续 Phase：

```text
constraint YAML / GloMinCluster constraint parser
distance / angle / dihedral 用户约束配置
QCG final mdopt-equivalent vtight
QCG final-only restraint interface
MTD skip-final-tight
normal vs tight A/B
Round-level vtight Slurm stage
iRMSD 接入 GloMinCluster
descriptor clustering
GPR
GREEN/RED 删除
g-xTB 默认启用
sampling 参数修改
MTD 参数修改
QCG grow 算法修改
aISS 移植进 CREST
```

发现这些问题只记录，不在 Phase 1 顺手解决。

当前唯一已允许的 post-baseline hardening 是已经完成的 zero-RMSD 修复；不要以此为理由继续扩大 hardening 范围。`pbc_cregen` 的 Debug `DGESVD` SIGFPE 继续作为已知 diagnostic 保留，不属于本阶段功能 patch。

---

# 2. 已核对的 CREST 3.1 源码事实

执行前 Luna 必须重新核对，但不得在没有用户明确批准时自动换 upstream base。

当前核对的 SHA：

```text
bd27e348ec001e27eab3177586843e8d86f66dc8
```

## 2.1 Build

当前 3.1：

```text
project version = 3.1.0
```

同时支持：

```text
Meson
CMake
```

经过 Phase 1-0 实际 baseline 后，本项目的构建/测试职责已经固定：

### Primary acceptance path

```text
GCC/GFortran 14.2.0
OpenBLAS 0.3.34
CMake 3.31.10（要求 >= 3.21）
Ninja
CMAKE_BUILD_TYPE=RelWithDebInfo
```

并执行：

```text
crest-only CTest (-R '^crest/')
```

当前 baseline：

```text
build 1592/1592 PASS
CTest 15/15 PASS
```

> **Phase 1 的主 acceptance/build regression 路径使用 CMake RelWithDebInfo。**

### Numerical diagnostic path

Meson GNU Debug 继续保留，用于：

```text
-ffpe-trap=invalid,zero,overflow
-fcheck=all
-finit-real=snan
```

下的 numerical robustness 检查，但：

> **完整 Meson 183-test dependency suite 不是 Phase 1 primary acceptance gate。**

baseline 已知：

```text
pbc_cregen / DGESVD SIGFPE = known remaining diagnostic
historical dependency-suite timeouts = debug/oversubscription diagnostic
```

zero-RMSD metadynamics SIGFPE 已在 `ff93ba5` 修复，后续不得再作为已知允许失败项。

### Release

独立 CREST `CMAKE_BUILD_TYPE=Release` **尚未完成验证**。

状态必须写作：

```text
NOT YET VALIDATED
```

它是 Phase 1 最终收口/发布前的后续 gate，而不是 Phase 1-0 已完成事实。

---

## 2.2 QCG 与 xTB

当前 QCG 非 legacy 路径中：

```text
SP
→ CREST calculator / engrad

geometry optimization
→ optimize_geometry

MD / MTD
→ CREST internal dynamics
```

但 QCG grow / aISS 仍显式调用 external xTB。

CREST 3.1 source 文案为：

```text
aISS requires xtb 6.6.0 or newer
tested with xtb 6.7.1 (902b313)
```

实际兼容性验证已经证明这里的 `6.7.1` 必须按**具体 commit**理解，而不能等同于 official tagged 6.7.1：

```text
xTB 6.7.0
→ strict QCG A/B PASS
→ Phase 1 default runtime candidate

official tagged xTB 6.7.1
→ strict QCG A/B FAIL
→ best.xyz invalid/empty + atom-count mismatch
→ external aISS compatibility regression

xTB 902b313678b95d793122174df09d590365a669d7
→ independent Release build/install PASS
→ identical CREST/input QCG PASS
→ compatibility reference only
```

因此 Phase 1 固定：

```text
QCG validated runtime candidate = xTB 6.7.0
```

不要：

```text
把 official xTB 6.7.1 当作默认 runtime
把 902b313 development commit 强制要求给普通用户
为绕过 official 6.7.1 regression 修改 CREST QCG grow 算法
```

---

## 2.3 Calculator 当前能量流

当前 calculator 逻辑：

```text
potential calculations
→ calc%etmp / calc%grdtmp

weighted method energy
→ energy

calc_eprint(...)

constraints
→ efix
→ energy = energy + efix
→ gradient = gradient + constraint gradient

mol%energy = energy
```

因此：

> **raw method energy 在进入 restraint loop 之前天然存在。**

Phase 1 不需要重新调用一次 unconstrained SP 来恢复 raw energy。

---

## 2.4 当前 `coord` 数据模型

当前 `coord` 只有：

```text
real(wp) :: energy
```

没有：

```text
energy_raw
energy_restraint
energy_total
```

当前 `coord%energy` 最终被 calculator 设置为加入 restraint 后的 total。

---

## 2.5 当前 ensemble I/O

普通 XYZ：

```text
energy= ...
```

写入 comment。

读取时：

```text
grepenergy(comment)
→ structures(i)%energy
```

extxyz 当前同样只稳定处理：

```text
energy=
energy_units=
```

所以：

> **只修改 calculator 不够。**

如果 energy components 不进入 ensemble comment / extxyz metadata：

```text
calculator
→ raw exists
→ ensemble write
→ raw lost
→ ensemble read
→ only total remains
→ CREGEN again sees total
```

这是 Phase 1 必须防止的错误。

---

# 3. Git / Fork 当前状态与维护规则

## 3.1 已建立仓库关系

当前实际关系：

```text
origin   = hdlghzb/crest
upstream = crest-lab/crest
```

源码目录：

```text
/home/zbhu/GloMinCluster/crest
```

开发 branch：

```text
glomincluster/crest-3.1-api-v1
```

固定 upstream base：

```text
bd27e348ec001e27eab3177586843e8d86f66dc8
```

固定 tag：

```text
gmc-crest-3.1-base-bd27e34
```

执行任何 Phase 1 patch 前重新核对：

```bash
git remote -v
git branch --show-current
git rev-parse HEAD
git status --short
git diff
git submodule status --recursive
```

---

## 3.2 upstream base 与当前 HEAD 必须区分

`bd27e348...` 只定义：

```text
upstream scientific/source baseline
```

当前开发 branch HEAD 已经包含：

```text
baseline/SOP 文档提交
zero-RMSD hardening commit ff93ba5
```

因此：

```text
current HEAD != pinned upstream base
```

是正常且预期的。

禁止为了“匹配文档 SHA”执行：

```text
reset --hard bd27e348...
recreate branch from upstream base
force push
```

---

## 3.3 如果 PR #483 head 已变化

执行者必须：

1. 报告 current PR head；
2. 报告 pinned upstream base `bd27e348...`；
3. **不得自动更新 upstream base**；
4. 继续在当前 fork branch 上开发，除非用户明确启动 upstream rebase/cherry-pick 审计。

原因：

> Phase 1 追求可重现和可追溯，不追求自动跟随 upstream head。

---

# 4. 开发目录和 build 目录

当前实际布局：

```text
/home/zbhu/GloMinCluster/crest
/home/zbhu/GloMinCluster/crest-build
```

推荐继续把独立 build tree 放在 `crest-build/`：

```text
baseline-cmake-relwithdebinfo-openblas/
baseline-debug-openblas/
phase1-<feature>-cmake/
phase1-<feature>-debug/
```

不要把 build artifacts 混入 source tree。

原 baseline build tree / logs 是历史证据，不应为了 Phase 1 功能开发清理或覆盖。

---

# 5. Toolchain 冻结

当前已验证 toolchain：

```text
GCC/GFortran 14.2.0
OpenBLAS 0.3.34
CMake 3.31.10（CMake >=3.21）
Ninja 1.13.0
Meson 1.11.2（Debug diagnostic）
xTB 6.7.0（QCG Phase 1 candidate）
```

执行前记录：

```bash
which gcc
gcc --version
which gfortran
gfortran --version
which cmake
cmake --version
which ninja
ninja --version
which meson
meson --version
which xtb
xtb --version
pkg-config --modversion openblas
pkg-config --variable=libdir openblas
```

CMake 必须显式锁定：

```text
/share/software/gcc/14.2.0/bin/gcc
/share/software/gcc/14.2.0/bin/c++
/share/software/gcc/14.2.0/bin/gfortran
```

因为集群 `/usr/bin/cc` / `/usr/bin/gfortran` 曾解析到 GCC 8.5。

OpenBLAS 必须解析到：

```text
/share/software/openblas/0.3.34
```

QCG acceptance 使用：

```text
xTB 6.7.0
```

如果不是 6.7.0：

```text
不得把 QCG smoke 计入 Phase 1 acceptance
```

可额外测试 `902b313...`，但它不替代默认 candidate。

---

# 6. Phase 1-0：Baseline 与 pre-Phase-1 hardening 状态

Phase 1-0 已经完成。本节是**已验证事实**，不是待重复执行的 bootstrap 指令。

详细证据见：

```text
docs/development/CREST-3.1-baseline.md
docs/development/CREST-3.1-baseline-build-test-SOP-v3.md
```

## 6.1 Baseline 0A / 0B / 0C 诊断

已保留：

```text
0A strict -std=f2018
→ pvol declaration-order incompatibility

0B Meson GNU-default + generic BLAS fallback
→ WITH_OPENBLAS / generic BLAS mismatch
→ openblas_set_num_threads_ link failure

0C GCC 14.2 + real OpenBLAS 0.3.34 + Meson Debug
→ build 953/953 PASS
→ full 183-test diagnostic suite暴露 SIGFPE / timeout
```

这些是 baseline 诊断证据，不应在 Phase 1 反复“修”第三方 pvol 或 Meson BLAS detection。

## 6.2 Primary baseline acceptance

最终 acceptance：

```text
GCC/GFortran 14.2.0
OpenBLAS 0.3.34
CMake 3.31.10
RelWithDebInfo
Ninja build 1592/1592 PASS
crest-only CTest 15/15 PASS
```

binary identity / `ldd`：

```text
crest 3.1.0
OpenBLAS path correct
GCC runtime correct
not found = none
```

runtime smoke PASS：

```text
GFN2
mdopt
NCI-iMTD
--gfn2@gfnff
--gfn2//gfnff
```

## 6.3 QCG compatibility baseline

strict A/B：

```text
xTB 6.7.0          PASS
xTB official 6.7.1 FAIL
```

独立 compatibility reference：

```text
xTB 902b313... Release build 808/808
install exit 0
QCG PASS
```

因此：

```text
Phase 1 QCG runtime candidate = xTB 6.7.0
```

## 6.4 Zero-RMSD hardening 已完成

post-baseline hardening commit：

```text
ff93ba5 fix(mtd): handle zero-RMSD gradient safely
```

root cause：

```text
rmsd_core
error = 0
→ residual / RMSD
→ SIGFPE
```

修复语义：

```text
error <= 0（非负 RMSD 的 exact-zero 分支）
→ zero gradient

positive RMSD
→ 原公式完全保留
→ 无 near-zero artificial cutoff
```

MTD 实际公式：

```text
dEdr = -2 * alpha * E * RMSD
```

因此 zero-RMSD bias force 极限为 0。

已验证：

```text
GNU Debug RMSD regression 9/9 PASS
GNU Debug metadynamics 6/6 PASS
CMake crest-only 15/15 PASS
NCI-iMTD runtime smoke PASS
no NaN / Inf
```

剩余 Debug diagnostic：

```text
pbc_cregen / pbc_fingerprint.f90:117 / DGESVD SIGFPE
```

它当前不是 Phase 1 blocker，不得顺手扩大修复范围。

## 6.5 Phase 1 开发的 baseline 回归原则

从现在开始，每个 Phase 1 功能 commit 应比较：

```text
current fork before feature patch
vs
current fork after feature patch
```

而不是把整个 branch 重置回 `bd27e348...`。

同时，涉及 constraint-off 科学行为时仍可使用 pinned upstream base binary 作为第二层 reference。

---

# 7. 推荐的 Phase 1 commit 拆分

已完成前置提交：

```text
baseline / SOP documentation         已完成
ff93ba5 zero-RMSD MTD hardening      已完成并 push
```

Phase 1 功能实现继续保持小提交：

```text
Commit 1
feat(gmc): add fork capability metadata

Commit 2
feat(energy): preserve calculator energy components

Commit 3
fix(cregen): rank constrained ensembles by raw energy

Commit 4
test(gmc): cover energy persistence and raw ranking
```

每个 commit 单独执行：

```text
build / targeted tests
git diff --check
scientific behavior audit
```

最终 Phase 1 收口后再执行：

```text
CMake crest-only full regression
Meson Debug targeted numerical regression
clean Release validation
runtime smoke including QCG + xTB 6.7.0
```

不要把 API、energy model、CREGEN ranking 和无关 hardening 混进同一个 commit。

---

# 8. Commit 1：GMC Fork capability / provenance

## 8.1 目标

增加：

```bash
crest --gmc-capabilities
```

输出建议为 JSON：

```json
{
  "gmc_api_version": 1,
  "crest_version": "3.1.0",
  "fork_commit": "<git-short-sha>",
  "upstream_base": "bd27e348ec001e27eab3177586843e8d86f66dc8",
  "energy_components": false,
  "raw_energy_ranking": false,
  "qcg_single_crest_orchestration": true,
  "qcg_aiss_external_xtb": true,
  "qcg_aiss_xtb_validated_version": "6.7.0"
}
```

`qcg_aiss_xtb_validated_version` 表示**本项目已经实测通过的默认 QCG runtime compatibility target**，不是声明 CREST 只支持该版本，也不是当前运行环境动态探测值。official tagged 6.7.1 的已知 regression 和 `902b313...` 的兼容性证据记录在 provenance 文档，不需要把复杂版本黑名单塞进 API v1 JSON。

Phase 1 初期在 Commit 1 时：

```text
energy_components
raw_energy_ranking
```

可以先输出：

```text
false
```

Commit 2/3 完成后改成：

```text
true
```

不要提前宣称 capability 已实现。

---

## 8.2 实现建议

新增独立小模块：

```text
src/gmc_api.f90
```

内容只负责：

```text
GMC API constants
upstream base SHA
capability print
```

例如概念：

```fortran
integer, parameter :: GMC_API_VERSION = 1
character(len=*), parameter :: GMC_UPSTREAM_BASE = &
  "bd27e348ec001e27eab3177586843e8d86f66dc8"
```

不要把这些常量散落在多个源文件。

---

## 8.3 Build identity

baseline 已确认当前 CMake `RelWithDebInfo` binary 的 `--version` 显示：

```text
commit (unknown-commit)
```

因此 Phase 1 Commit 1 不能假定现有 build metadata 已经提供可用 fork SHA。

要求：

1. 优先审计并复用 CREST 已有 metadata 生成机制（包括 `crest_metadata.fh` 或实际当前对应文件）；
2. 在 Git checkout 中构建时，`fork_commit` 必须在**build time**嵌入实际 source commit；
3. installed binary 运行时不得调用 `git rev-parse`；
4. 从无 `.git` 的 source archive 构建时，允许通过明确的 build-time provenance override 提供 fork commit；
5. 如果无法可靠确定 commit，必须输出明确的 `unknown`/invalid provenance，不能伪造 SHA；
6. Phase 1 acceptance build 必须证明 `--gmc-capabilities` 中 `fork_commit` 与实际被构建 source HEAD 一致。

`upstream_base` 与 `fork_commit` 是两个不同概念：

```text
upstream_base = bd27e348...       # 固定科学/源码基线
fork_commit   = actual build HEAD # 当前 fork 实现版本
```

不要把 upstream base SHA 冒充 fork build commit。

---

## 8.4 CLI 接口

当前 `src/confparse.f90` 已在最前面处理：

```text
--version
```

建议同一层增加：

```text
--gmc-capabilities
```

要求：

- 不需要 geometry input；
- 不启动 calculator；
- 不检查 xTB；
- 输出后正常 `stop`；
- stdout 机器可解析；
- 不混入正常 CREST banner。

如果正常 parser 架构不适合 JSON-only，可单独在早期 flag pass 中处理。

---

## 8.5 Build files

若新增：

```text
src/gmc_api.f90
```

同步修改：

```text
src/meson.build
src/CMakeLists.txt
```

或当前对应 source list。

Meson/CMake 必须都能构建。

---

## 8.6 Tests

至少：

```text
crest --gmc-capabilities
```

返回 code 0。

JSON：

```python
json.loads(stdout)
```

成功。

检查：

```text
gmc_api_version == 1
upstream_base == pinned SHA
qcg_aiss_xtb_validated_version == "6.7.0"
```

---

# 9. Commit 2：Energy Component 数据模型

## 9.1 核心原则

内存中：

```text
coord%energy
=
energy_total
```

保持 legacy 兼容。

新增：

```text
coord%energy_raw
coord%energy_restraint
coord%energy_total
coord%energy_components_valid
```

---

## 9.2 `coord` 类型修改

主要文件：

```text
src/molecule/type.f90
```

建议字段：

```fortran
real(wp) :: energy = 0.0_wp

real(wp) :: energy_raw = 0.0_wp
real(wp) :: energy_restraint = 0.0_wp
real(wp) :: energy_total = 0.0_wp

logical :: energy_components_valid = .false.
```

不要删除旧：

```text
energy
```

---

## 9.3 `coord_copy`

必须复制：

```text
energy
energy_raw
energy_restraint
energy_total
energy_components_valid
```

否则：

```text
structure copy
→ energy metadata lost
```

---

## 9.4 deallocate / initialization

确保新字段不会携带旧 molecule 的 stale value。

当 `coord` 被重新打开或重新分配时：

```text
energy_raw = 0
energy_restraint = 0
energy_total = 0
energy_components_valid = false
```

---

# 10. Calculator 修改

主要文件：

```text
src/calculator/calculator.F90
```

---

## 10.1 raw capture point

必须在：

```text
method / weighted energy construction
```

完成后，

但在：

```text
constraint loop
```

之前保存：

```text
raw_energy = energy
```

不能从：

```text
calc%etmp(1)
```

直接等同 raw。

原因：

CREST 支持：

```text
multiple calculation levels
weights
ONIOM
selected calc id
```

正确 raw 定义应该是：

> **进入 additive constraint loop 之前，calculator 已经组装完成的那个实际 method energy。**

---

## 10.2 restraint accumulation

constraint loop 开始前：

```fortran
restraint_energy = 0.0_wp
```

每次：

```fortran
efix
```

实际加入 total 时：

```fortran
restraint_energy = restraint_energy + efix
energy = energy + efix
```

---

## 10.3 component assignment

constraint 完成后：

```text
mol%energy_raw = raw_energy
mol%energy_restraint = restraint_energy
mol%energy_total = energy
mol%energy = energy
mol%energy_components_valid = true
```

---

## 10.4 `energy_restraint` 的 Phase 1 语义

在 GMC 正常 structural-restraint workflow 中：

```text
energy_restraint
=
structural restraint contribution
```

当前 CREST calculator 的 constraint list 还可能包含其它 non-adiabatic constraint。

Phase 1 不扩展数据模型解决所有 CREST 特殊模式。

因此 API v1 说明：

> `energy_restraint` 表示 raw method energy 之后由 calculator constraint stage 累加的 energy contribution；GloMinCluster Phase 2 只使用 structural restraint，因此在 GloMinCluster domain 中它就是 structural restraint energy。

不要为了罕见模式把 Phase 1 扩成通用 bias decomposition 框架。

---

## 10.5 Frozen atoms

freeze 只修改 gradient：

```text
不产生 energy_restraint
```

保持现有行为。

---

# 11. Energy component invariant

每次 valid 时必须满足：

```text
energy_total
≈
energy_raw + energy_restraint
```

推荐内部 tolerance：

```text
1e-10 ~ 1e-8 Eh
```

具体测试 tolerance 根据浮点路径确定。

不要在 production 每个 engrad call 都昂贵 assert。

可在 debug/test helper 中验证。

---

# 12. 普通 XYZ 持久化

这是 Phase 1 很容易漏掉的部分。

当前 ensemble 很多路径仍用普通 XYZ。

因此必须让普通 XYZ comment 在 component valid 时包含：

```text
energy=<legacy total>
energy_raw=<raw>
energy_restraint=<restraint>
energy_total=<total>
energy_units=Hartree
```

例如：

```text
energy=-100.0000000000 energy_raw=-100.0020000000 energy_restraint=0.0020000000 energy_total=-100.0000000000 energy_units=Hartree
```

---

## 12.1 为什么 `energy=` 继续写 total

为了减少 upstream compatibility break：

```text
energy=
```

保持原来：

```text
coord%energy = total
```

新的科学消费者必须读取：

```text
energy_raw
```

后续 GloMinCluster 若需要喂给 legacy isostat 的 raw-energy XYZ：

```text
由 GloMinCluster 派生生成
```

不要在 Phase 1 改全 CREST `energy=` 的传统语义。

---

## 12.2 修改位置

重点检查：

```text
coord%write
coord%append
wrensemble_coord_name
wrensemble_coord_channel
CREGEN output writer
```

不要只改某一个最终文件。

---

# 13. 普通 XYZ 读取

当前 `rdensemble_coord_type()` 已经保存：

```text
comments(i)
```

因此增加 helper：

```text
parse_gmc_energy_components(comment, ...)
```

如果同时找到：

```text
energy_raw
energy_restraint
energy_total
```

则：

```text
structures(i)%energy_raw = ...
structures(i)%energy_restraint = ...
structures(i)%energy_total = ...
structures(i)%energy = energy_total
structures(i)%energy_components_valid = true
```

否则：

```text
structures(i)%energy = legacy parsed energy
structures(i)%energy_components_valid = false
```

---

## 13.1 Legacy fallback

旧 XYZ：

```text
-123.456
```

或：

```text
energy=-123.456
```

必须继续可读。

不允许：

```text
没有 energy_raw
→ error
```

Phase 1 的兼容规则：

```text
legacy input
→ valid=false
→ ranking_energy falls back to energy
```

---

# 14. Single regular XYZ 读取

`coord%open()` 对普通 XYZ 也必须考虑 component metadata。

Luna 应检查当前 `rdcoord()` 是否保留 comment。

如果不保留：

增加最小 helper：

```text
read_xyz_comment_energy_components(fname,...)
```

只读取：

```text
nat line
comment line
```

然后解析 component keys。

不要为此重写整个 XYZ parser。

---

# 15. extxyz 持久化

当前 extxyz 已经有：

```text
energy=
energy_units=
```

扩展为：

```text
energy=
energy_raw=
energy_restraint=
energy_total=
energy_units=Hartree
```

---

## 15.1 Reader

扩展：

```fortran
read_extxyz_frame(...)
```

增加**optional** output：

```text
energy_raw
energy_restraint
energy_total
energy_components_found
```

必须是 optional，避免破坏所有已有 caller。

---

## 15.2 Unit conversion

全部 component 使用同一个：

```text
energy_units
```

Phase 1 canonical GMC output 推荐：

```text
Hartree
```

如果 extxyz 读到：

```text
eV
```

则：

```text
raw
restraint
total
```

都做相同转换。

---

# 16. Ranking Energy Accessor

不要在 CREGEN 到处写：

```fortran
if (components_valid) then ...
```

建议在 `coord` 中增加统一函数：

```text
ranking_energy()
```

语义：

```text
if energy_components_valid:
    return energy_raw
else:
    return energy
```

名称也可以：

```text
science_energy()
```

二选一。

推荐：

```text
ranking_energy
```

因为 Phase 1 最明确的用途是排序/筛选。

---

# 17. Commit 3：CREGEN 使用 raw energy

主要文件：

```text
src/sorting/cregen.f90
```

以及所有 CREGEN helper 所在 sorting 文件。

Luna 必须先执行：

```bash
rg -n '%energy|energy' src/sorting
```

建立一个 audit list。

不要全局替换。

---

# 18. 必须改为 ranking_energy 的科学决策

以下凡是基于 ensemble energy 做：

```text
order
cut
keep/drop
group representative
energy difference eligibility
lowest structure
```

都必须使用：

```text
ranking_energy()
```

---

## 18.1 `cregen_esort`

必须：

```text
排序依据 = raw
EWIN = raw relative energy
```

这是最核心测试。

---

## 18.2 ETHR / duplicate comparison

如果 duplicate/classification 中有：

```text
abs(E_i - E_j) < ETHR
```

必须使用 raw。

否则 restraint penalty 会改变 duplicate eligibility。

---

## 18.3 Representative selection

如果一组 rotamer/conformer 中：

```text
energy minimum member
```

决定代表结构：

```text
必须按 raw
```

---

## 18.4 `env%elowest`

如果从 CREGEN sorted structure 更新：

```text
env%elowest
```

必须使用：

```text
ranking_energy(first)
```

而不是 total。

---

## 18.5 Boltzmann / thermochemistry

Phase 1 的原则：

如果该量在当前 workflow 中被解释为：

```text
conformer physical low-level energy
```

则应基于 raw。

但如果某特殊 CREST mode 明确需要 constrained Hamiltonian total：

```text
不要擅自修改
```

Luna 必须：

1. 列出相关调用；
2. 判断用途；
3. 只修改当前 conformer/CREGEN science decision path；
4. 不进行无关 thermochemistry 重构。

---

# 19. 重要兼容原则

## constraint off

calculator 给出：

```text
restraint = 0
raw = total
```

因此：

```text
ranking_energy = raw = old energy
```

必须保证 upstream normal workflows 行为不变。

---

## legacy ensemble

没有 component metadata：

```text
ranking_energy = legacy energy
```

保持兼容。

---

# 20. Capability 状态更新

Commit 2 完成：

```json
"energy_components": true
```

Commit 3 完成并测试：

```json
"raw_energy_ranking": true
```

禁止测试未通过就把 capability 标成 true。

---

# 21. Unit Test 设计

建议新增：

```text
test/test_gmc_energy.F90
```

并加入：

```text
test/CMakeLists.txt
test/meson.build
test/main.f90
```

根据现有 test-drive 风格实施。

如果为了最小改动并入：

```text
test/test_optimization.F90
```

也可以。

但推荐独立：

```text
gmc_energy
```

便于以后长期 regression。

---

# 22. Test U1：No-restraint identity

同一简单 molecule：

```text
calculator
no restraint
```

检查：

```text
energy_components_valid = true
energy_restraint = 0
energy_raw = energy_total
energy = energy_total
```

---

# 23. Test U2：Single restraint decomposition

程序化增加一个 structural restraint。

选择一个几何故意偏离 target，使：

```text
energy_restraint > 0
```

检查：

```text
total = raw + restraint
```

---

# 24. Test U3：Raw equals unconstrained SP at same geometry

对**同一 geometry**：

```text
A. no restraint engrad
B. restraint engrad
```

检查：

```text
E_A
≈
B.energy_raw
```

不要比较优化后 geometry，因为 geometry 会变化。

这是最直接证明：

```text
energy_raw
```

没有被 restraint contamination。

---

# 25. Test U4：Multiple restraint accumulation

至少两个 restraint：

```text
restraint_total
=
efix1 + efix2
```

并检查：

```text
total = raw + restraint_total
```

---

# 26. Test U5：coord copy

创建带 components 的 coord：

```text
copy
```

检查全部字段和 valid flag 完整。

---

# 27. Test U6：Plain XYZ roundtrip

```text
coord with valid components
→ write .xyz
→ read .xyz
```

检查：

```text
raw
restraint
total
valid
```

完整恢复。

---

# 28. Test U7：extxyz roundtrip

同上：

```text
write .extxyz
→ read
```

同时测试：

```text
Hartree
```

如现有测试基础允许，再加 eV conversion。

---

# 29. Test U8：Legacy XYZ fallback

输入：

```text
只有传统 energy comment
```

检查：

```text
components_valid = false
ranking_energy() = energy
```

---

# 30. CREGEN Regression Tests

这是 Phase 1 最重要的一组。

---

## 30.1 Test C1：Raw/total ranking inversion

人工构造两个结构：

```text
A:
raw   = -10.000
total = -9.990

B:
raw   = -9.995
total = -9.999
```

则：

```text
raw ranking:
A < B

total ranking:
B < A
```

CREGEN 必须输出：

```text
A first
```

---

## 30.2 Test C2：EWIN uses raw

构造：

```text
raw difference < EWIN
total difference > EWIN
```

结构必须：

```text
保留
```

反向再构造：

```text
raw difference > EWIN
total difference < EWIN
```

结构必须：

```text
删除
```

---

## 30.3 Test C3：ETHR uses raw

构造 near-identical geometry：

```text
raw ΔE
total ΔE
```

跨过 ETHR 的反转案例。

验证 duplicate eligibility 看 raw。

---

## 30.4 Test C4：Representative uses raw

同一 duplicate group：

```text
raw minimum member ≠ total minimum member
```

最终 representative：

```text
必须是 raw minimum
```

---

## 30.5 Test C5：constraint-off baseline

components valid：

```text
raw == total
```

CREGEN output：

```text
与 legacy energy path 完全一致
```

---

# 31. Phase 1 Regression Gate

完成 Phase 1 功能 patch 后，primary regression 使用 CMake crest-only gate。

推荐建立新的独立 validation tree，或在能够明确追溯 source HEAD 的现有 CMake tree 增量 rebuild。

执行：

```bash
OMP_NUM_THREADS='1,2,1' \
ctest \
  --output-on-failure \
  --parallel 2 \
  -R '^crest/'
```

要求：

```text
全部 crest tests PASS
0 new FAIL
0 new TIMEOUT
```

当前 baseline 是：

```text
15/15 PASS
```

如果 Phase 1 新增 crest test，最终数量可以增加，但必须全部 PASS。

同时使用 Meson GNU Debug 跑与本次修改直接相关的 targeted tests，特别是：

```text
metadynamics
irmsd
calculator / optimization
CREGEN / GMC energy tests
```

完整 Meson 183-test dependency suite 可以作为 diagnostic 再跑，但**不是 primary acceptance gate**。如果仍出现 baseline 已知的 `pbc_cregen` DGESVD FPE-trap diagnostic 或依赖 timeout，必须与 baseline 对照；只要没有新增 regression，不得把历史 diagnostic误写成 Phase 1 新失败。

如果出现 baseline 中没有的新 failure：

```text
Phase 1 BLOCKED
```

不得简单标记为 unrelated。

---

# 32. Release Build

状态：

```text
NOT YET VALIDATED
```

Phase 1 功能和 RelWithDebInfo regression 稳定后，必须创建独立 clean Release tree：

```bash
cmake \
  -S /home/zbhu/GloMinCluster/crest \
  -B /home/zbhu/GloMinCluster/crest-build/phase1-release-openblas \
  -GNinja \
  -DCMAKE_BUILD_TYPE=Release \
  -DCMAKE_C_COMPILER=/share/software/gcc/14.2.0/bin/gcc \
  -DCMAKE_CXX_COMPILER=/share/software/gcc/14.2.0/bin/c++ \
  -DCMAKE_Fortran_COMPILER=/share/software/gcc/14.2.0/bin/gfortran \
  -DBLA_VENDOR=OpenBLAS

ninja -C /home/zbhu/GloMinCluster/crest-build/phase1-release-openblas
```

Release build 后重新执行：

```text
crest-only CTest
--version / --gmc-capabilities
ldd
关键 runtime smoke
QCG + xTB 6.7.0
```

不要把 RelWithDebInfo PASS 等同于 Release PASS。

---

# 33. Runtime Smoke S1：Version / capability

执行：

```bash
<crest-gmc> --version
<crest-gmc> --gmc-capabilities
```

保存 stdout。

检查：

```text
version = 3.1.0
fork/build commit = actual built source identity
upstream_base = bd27e348...
GMC API = 1
qcg_aiss_xtb_validated_version = 6.7.0
```

`--gmc-capabilities` 必须：

```text
不需要 geometry
不启动 calculator
不检查 external xTB 是否当前可用
JSON-only / machine parseable
exit 0
```

---

# 34. Runtime Smoke S2：QCG xTB runtime identity

默认 acceptance：

```text
xTB 6.7.0
```

执行并保存：

```bash
which xtb
xtb --version
```

必须确认实际 binary/module 是已验证的 6.7.0 candidate。

已知边界：

```text
official tagged xTB 6.7.1 = known QCG/aISS regression
902b313... = compatibility PASS, optional reference only
```

不得用 902b313 PASS 替代默认 xTB 6.7.0 acceptance。

---

# 35. Runtime Smoke S3：Unconstrained SP / mdopt regression

选择一个小普通体系。

参考：

```text
A = pinned upstream base / accepted baseline binary
B = current modified fork binary
```

相同：

```text
geometry
method
charge
uhf
threads
```

比较：

```text
final energy
final geometry
success
```

目标：

```text
constraint-off scientific result 不变
```

建议 tolerance：

```text
energy <= 1e-8 ~ 1e-6 Eh
geometry <= 1e-6 ~ 1e-4 Å
```

按实际 optimizer deterministic/numerical behavior调整并记录。

---

# 36. Runtime Smoke S4：Constrained single-geometry decomposition

此阶段不测试 GloMinCluster 新 constraint schema。

只用 CREST 当前支持的一个最简单 structural restraint，对**同一 geometry**检查：

```text
energy_raw
energy_restraint
energy_total
```

并执行独立 unconstrained SP：

```text
independent SP ≈ energy_raw
energy_total ≈ energy_raw + energy_restraint
```

这一 smoke 只证明 energy contract 正确，不代表 Phase 2 的用户约束 schema 已验收。

---

# 37. Runtime Smoke S5：Small QCG single-CREST orchestration

目标不是验证 QCG 科学正确性，而是验证：

```text
one CREST process entry
+
external xTB 6.7.0 aISS
```

在 Phase 1 fork 修改后仍能协作。

选择已用于 strict A/B 的简单普通体系或等价小体系，不用 FeCN6 作为 Phase 1 pass/fail gate。

检查：

```text
one crest process entry
which xtb / xtb --version = validated 6.7.0
QCG grow runs
CREST exit 0
best.xyz atom count / line count / XYZ validity
xtb_dock.out contains Successful and finished run
expected QCG output exists
no fork regression
```

---

# 38. Phase 1 不做的真实测试

以下不要在 Phase 1 强行完成：

```text
FeCN6 QCG final vtight acceptance
FeCN6 constraint scientific A/B
MTD normal vs tight
NCI-iMTD skip-final-tight
100k clustering
GPR
```

这些属于后续 Phase。

---

# 39. Build/Runtime provenance 文档

Phase 1 应新增/维护：

```text
docs/development/CREST-GMC-FORK.md
```

至少包含：

```text
Upstream repository
Pinned upstream base SHA
Fork repository / branch
Current validated fork commit
GMC API version
Primary build/acceptance route
Compiler / OpenBLAS
QCG validated xTB runtime = 6.7.0
official xTB 6.7.1 compatibility regression
902b313 compatibility reference
Energy component semantics
Known out-of-scope issues
```

已有 baseline 事实继续引用：

```text
docs/development/CREST-3.1-baseline.md
docs/development/CREST-3.1-baseline-build-test-SOP-v3.md
```

不要复制大段 raw logs 到 Git。

---

# 40. 测试报告

Phase 1 测试报告建议：

```text
docs/testing/CREST-GMC-Phase1-test-report.md
```

至少写：

```text
pinned upstream base
feature fork commit(s)
compiler / OpenBLAS / build system
CMake crest-only regression
targeted Meson Debug tests
unit tests
unconstrained regression
energy decomposition smoke
plain XYZ / extxyz roundtrip
CREGEN raw ranking tests
hybrid tests
QCG + xTB 6.7.0 smoke
Release status
known diagnostics
not-yet-validated items
```

必须明确区分：

```text
unit verified
debug regression verified
runtime smoke verified
not scientifically benchmarked
```

---

# 41. GloMinCluster 主仓库在 Phase 1 的处理

Phase 1 原则上：

> **不修改 GloMinCluster production runtime behavior。**

GloMinCluster 当前目标开发线仍为：

```text
develop/0.2.0a2
```

完成 fork 后，在 GloMinCluster 状态/设计文档记录：

```text
CREST fork repository
pinned upstream base
validated fork commit
GMC API version
QCG validated xTB runtime = 6.7.0
Phase 1 validation status
```

真正让 GloMinCluster：

```text
probe --gmc-capabilities
require compatible fork
parse energy_raw
```

可在后续 constraint integration phase 正式接入。

如果为了自动化测试必须提前增加 read-only probe helper，也不得改变 production workflow。

---

# 42. Luna 执行时的源码审计清单

开始编码前必须运行：

```bash
git status --short
git branch --show-current
git rev-parse HEAD
git diff --stat
```

然后：

```bash
rg -n 'mol%energy|%energy' src/calculator src/molecule src/sorting
rg -n 'efix|calc_constraint|nconstraints' src/calculator
rg -n 'cregen_esort|ethr|ewin|elowest' src/sorting
rg -n 'writeextxyz|appendcoord|rdensemble_coord_type|read_extxyz_frame' src/molecule
rg -n '\-\-version|confscript_head' src
```

形成一个简短 audit note：

```text
修改文件
修改原因
scientific impact
```

再开始 patch。

---

# 43. 预计主要修改文件

大概率包括：

```text
src/calculator/calculator.F90

src/molecule/type.f90
src/molecule/io.f90
src/molecule/type_ensemble.f90

src/sorting/cregen.f90
src/sorting/<CREGEN helper files actually using energy>

src/confparse.f90
src/gmc_api.f90

src/meson.build
src/CMakeLists.txt

test/test_gmc_energy.F90
test/main.f90
test/meson.build
test/CMakeLists.txt

docs/development/CREST-GMC-FORK.md
docs/testing/CREST-GMC-Phase1-test-report.md
```

最终以源码实际调用链为准。

禁止为了让列表“看起来一致”而修改没有需要的文件。

---

# 44. 特别禁止的错误实现

## 错误 1

```text
优化完以后
再额外跑 unconstrained xTB SP
恢复 raw
```

Phase 1 不允许作为正常路径。

正确：

```text
calculator 在加入 efix 前直接保存 raw。
```

---

## 错误 2

只在 stdout 打印 raw：

```text
没有结构级持久化
```

不接受。

---

## 错误 3

只改 extxyz：

```text
普通 ensemble XYZ 落盘后 raw 丢失
```

不接受。

---

## 错误 4

把：

```text
coord%energy
```

全局改成 raw。

会破坏 optimizer / MD 传统语义。

不接受。

---

## 错误 5

全仓库机械替换：

```text
%energy → %energy_raw
```

不接受。

必须区分：

```text
optimization total
vs
scientific ranking raw
```

---

## 错误 6

CREGEN EWIN 改了 raw，但：

```text
ETHR / representative / elowest
```

仍用 total。

属于不完整修复。

---

## 错误 7

没有 metadata 时默认：

```text
raw = 0
```

会错误排序。

正确 fallback：

```text
ranking = legacy energy
```

---

## 错误 8

`--gmc-capabilities` 需要输入结构或启动 xTB。

不接受。

---

## 错误 9

把：

```text
xTB runtime dependency
```

从 QCG 删除。

Phase 1 不做 aISS 重写。

---

## 错误 10

顺便改：

```text
QCG final optimizer
MTD final tight
iRMSD
g-xTB
```

不接受。

---

# 45. Commit 前检查

每个 commit：

```bash
git status --short
git diff --check
git diff --stat
git diff
```

检查：

- 无 build dir；
- 无 binary；
- 无 large output；
- 无 test scratch；
- 无账号/路径敏感信息；
- 无无关格式化。

---

# 46. 建议 commit message

```text
feat(gmc): add fork capability metadata

feat(energy): preserve calculator energy components

fix(cregen): rank constrained ensembles by raw energy

test(gmc): cover energy persistence and raw ranking
```

---

# 47. Push

每个逻辑阶段完成必要验证后 commit，并 push 当前 branch：

```bash
git push origin glomincluster/crest-3.1-api-v1
```

不要直接 merge upstream/master/main。

push 前必须确认：

```text
no build tree
no binary
no raw logs
no xTB source/build/install artifact
no unrelated user changes
no submodule/gitlink changes
```

---

# 48. Phase 1 完成条件

必须全部满足：

## Fork / provenance

- [x] origin/upstream 关系已建立；
- [x] pinned upstream base = `bd27e348...`；
- [x] fork branch = `glomincluster/crest-3.1-api-v1`；
- [x] baseline / SOP 已建立；
- [x] zero-RMSD hardening `ff93ba5` 已验证并 push；
- [ ] GMC capability fork commit 可追踪并已 push。

## Build / regression

- [x] CMake RelWithDebInfo baseline build/CTest 已验证；
- [ ] Phase 1 modified fork CMake crest-only regression 全 PASS；
- [ ] Phase 1 targeted Meson Debug tests PASS；
- [ ] clean CREST Release build/test/runtime validation；
- [ ] compiler/build metadata 已记录。

完整 Meson 183-test dependency suite 不作为 primary completion checkbox；必须记录是否运行以及与 baseline diagnostics 的差异。

## Runtime dependency

- [x] QCG default candidate = xTB 6.7.0；
- [x] official xTB 6.7.1 regression 已记录；
- [x] 902b313 compatibility reference 已通过；
- [ ] modified Phase 1 fork + xTB 6.7.0 QCG smoke PASS。

## Energy model

- [ ] `energy_raw`；
- [ ] `energy_restraint`；
- [ ] `energy_total`；
- [ ] `coord%energy = total`；
- [ ] identity invariant 通过。

## Persistence

- [ ] regular XYZ roundtrip；
- [ ] extxyz roundtrip；
- [ ] legacy fallback；
- [ ] hybrid stage metadata persistence / invalidation 正确。

## CREGEN

- [ ] sort uses raw；
- [ ] EWIN uses raw；
- [ ] ETHR energy check uses raw；
- [ ] representative uses raw；
- [ ] elowest uses raw；
- [ ] constraint-off regression。

## API

- [ ] `--gmc-capabilities`；
- [ ] JSON parseable；
- [ ] fork/build identity；
- [ ] upstream SHA；
- [ ] GMC API version；
- [ ] `qcg_aiss_external_xtb=true`；
- [ ] `qcg_aiss_xtb_validated_version="6.7.0"`；
- [ ] 未实现 capability 不提前标 true。

## Evidence

- [ ] `docs/development/CREST-GMC-FORK.md`；
- [ ] `docs/testing/CREST-GMC-Phase1-test-report.md`；
- [ ] commits pushed；
- [ ] no build/log/binary/raw output committed。

---

# 49. Phase 1 允许的最终表述

如果只有代码级 unit / regression 完成：

> **CREST GMC fork Phase 1 code-level implementation and regression tests passed.**

如果同时完成实际 executable runtime smoke（包括 QCG + xTB 6.7.0）：

> **CREST GMC fork Phase 1 is runtime smoke-tested with validated xTB 6.7.0 for QCG/aISS.**

如果 clean Release 尚未执行：

```text
不得写 Release validated
```

无论 Phase 1 是否通过，仍不能说：

```text
constraint scientifically validated
QCG FeCN6 final optimizer fixed
MTD A/B workflow validated
formal release ready
```

这些属于后续 Phase / real cluster acceptance。

---

# 50. Phase 1 完成后立即进入的下一阶段

下一阶段：

```text
Phase 2
结构约束 + QCG final optimizer
```

此时再实施：

```text
distance / angle / dihedral
auto target
canonical constraints.inp
QCG grow fixed solute
QCG final mdopt-equivalent vtight
QCG final-only restraint
FeCN6 real acceptance
```

Phase 2 必须直接建立在：

```text
Phase 1 validated fork commit
```

上。

不要在 Phase 1 尚未稳定时并行大改 QCG。

---

# 51. 建议给 Codex/Luna 的执行指令

可以直接将以下要求附在 Phase 1 功能任务开头：

```text
请严格按当前 Phase 1 文档执行，不进入 Phase 2。

当前事实：
1. repo = /home/zbhu/GloMinCluster/crest；
2. branch = glomincluster/crest-3.1-api-v1；
3. bd27e348... 是 pinned upstream base，不是当前 branch HEAD；
4. baseline = PASS WITH DEBUG DIAGNOSTICS；
5. zero-RMSD hardening ff93ba5 已完成；
6. primary acceptance = GCC14.2 + OpenBLAS0.3.34 + CMake RelWithDebInfo + crest-only CTest；
7. Meson GNU Debug = targeted numerical diagnostic；
8. QCG runtime candidate = xTB 6.7.0；official xTB 6.7.1 是 known regression。

开始前：
1. 核对 worktree、branch、actual HEAD、remote、diff、recursive submodule；
2. 读取 docs/development/CREST-3.1-baseline.md 和 SOP-v3；
3. 不重置到 pinned upstream base；
4. 保留所有用户现有修改。

实施要求：
1. 最小修改；
2. coord%energy 保持 total；
3. raw 在 calculator 加 restraint 前直接捕获；
4. energy components 必须能跨普通 XYZ 和 extxyz roundtrip；
5. CREGEN 所有影响排序/筛选/代表选择的 energy decision 使用 raw；
6. legacy 文件无 metadata 时 fallback 到原 energy；
7. hybrid/multilevel stage 必须正确刷新/失效 component metadata；
8. 不修改 QCG final optimizer；
9. 不修改 MTD final tight；
10. 不接入 iRMSD/GPR/g-xTB；
11. 不改变 sampling/resource 参数；
12. 不修 pbc_cregen DGESVD diagnostic。

验证：
1. targeted tests；
2. CMake crest-only full regression；
3. targeted Meson GNU Debug regression；
4. unconstrained baseline regression；
5. raw/restraint/total identity；
6. CREGEN raw/total inversion tests；
7. regular XYZ/extxyz roundtrip；
8. hybrid regression；
9. QCG + xTB 6.7.0 smoke；
10. Phase 1 最终收口前完成 clean Release validation。

完成后：
1. 更新 docs/development/CREST-GMC-FORK.md；
2. 更新 docs/testing/CREST-GMC-Phase1-test-report.md；
3. 检查 git diff / sensitive / large files；
4. 分逻辑 commit；
5. push glomincluster/crest-3.1-api-v1；
6. 明确区分 unit / debug regression / runtime smoke / scientific acceptance。
```

---

# 52. 预期 Phase 1 交付物

```text
CREST fork repository
└─ glomincluster/crest-3.1-api-v1
   ├─ GMC API v1
   ├─ raw/restraint/total energy
   ├─ raw-energy CREGEN
   ├─ normal XYZ component persistence
   ├─ extxyz component persistence
   ├─ hybrid/multilevel component synchronization
   ├─ tests
   ├─ docs/development/CREST-GMC-FORK.md
   └─ docs/testing/CREST-GMC-Phase1-test-report.md
```

以及最终实施报告：

```text
Pinned upstream SHA
Validated fork commit
Changed files
Behavior changes
CMake regression
Debug targeted regression
Release status
Runtime smoke
QCG xTB compatibility
Known limitations
Phase 2 prerequisites
```

---

# 53. 最终一句话定义

> **Phase 1 的任务不是改变 CREST 的采样算法，而是在已验收的 CREST 3.1 fork 基础上建立可追溯的 GMC API 与稳定能量契约：优化/动力学使用 total、科学排序使用 raw、restraint 单独记录；QCG 仍由单个 CREST job 编排并依赖 external xTB，其中 Phase 1 默认验证 runtime 固定为 xTB 6.7.0。**

---

# 54. Hybrid / Multilevel Method 兼容性契约

## 54.1 必须保留 CREST 3.1 原生两级方法语义

Phase 1 的 energy-component patch 不得破坏 CREST 3.1 已有 hybrid/multilevel method 机制。

当前 3.1 明确定义：

```text
A@B
  B = workhorse / sampling method
  A = quality method
  search 使用 B
  search 完成后用 A 对 conformer ensemble 做 post-search geometry optimization

A//B
  B = workhorse / sampling method
  A = quality method
  search 使用 B
  A 对候选执行 inline single-point re-ranking

A/sp/B
  与 A//B 等价的显式写法

A/opt/B
  B = workhorse / sampling method
  A = quality method
  A 执行 inline geometry refinement
```

因此未来 GloMinCluster 若采用：

```text
--gfn2@gfnff
```

应保持：

```text
GFN-FF sampling
→ final conformer ensemble
→ GFN2-xTB geometry re-optimization
```

而：

```text
--gfn2//gfnff
```

在 CREST 3.1 中的正式语义是：

```text
GFN-FF sampling
→ GFN2-xTB single-point re-ranking
```

不得把 `//` 重新解释成 geometry optimization。

---

# 55. `energy_raw` 在 hybrid workflow 中的正式定义

Phase 1 不允许将：

```text
energy_raw
```

硬编码为：

```text
GFN2 energy
calc%etmp(1)
workhorse energy
quality energy
```

统一定义必须是：

> **当前 active calculator/refinement stage 已完成实际方法能量组装之后、加入 structural restraint 之前的物理方法能量。**

因此：

## 普通单级 GFN2

```text
energy_raw
=
E_GFN2
```

## `gfn2@gfnff` sampling 阶段

```text
active stage = workhorse GFN-FF

energy_raw
=
E_GFNFF
```

## `gfn2@gfnff` post-search quality optimization 阶段

```text
active stage = quality GFN2

energy_raw
=
E_GFN2
```

## `gfn2//gfnff` sampling 阶段

```text
energy_raw
=
E_GFNFF
```

## `gfn2//gfnff` quality SP re-ranking 后

最终 reranked ensemble 的：

```text
energy_raw
=
E_GFN2(single-point)
```

这样 raw-energy contract 与 method 选择完全正交。

---

# 56. 为什么 raw capture 必须位于 calculator “组装完成后、restraint 前”

当前 calculator 支持：

```text
single active calculation
multiple calculation levels
weighted calculations
selected calc id
refine_stage
ONIOM
```

因此错误做法：

```text
energy_raw = calc%etmp(1)
```

可能在 hybrid/refinement workflow 中取得错误层级。

正确：

```text
active method calculations
        ↓
calculator energy construction
        ↓
energy = 当前 active stage 的完整 physical method energy
        ↓
【在这里 capture energy_raw】
        ↓
structural restraint / efix
        ↓
energy_total
```

这也是 Phase 1 原方案中“raw 在 restraint loop 前截获”的正式原因之一。

---

# 57. Hybrid stage 切换必须刷新 energy components

这是 Phase 1 新增的关键 regression contract。

禁止：

```text
sampling stage:
raw = E_GFNFF

quality refinement:
legacy energy 已变为 E_GFN2
但 energy_raw 仍残留 E_GFNFF
```

每一次成功：

```text
engrad
single-point refinement
geometry refinement
post-search optimization
```

都必须将目标 `coord` 的：

```text
energy_raw
energy_restraint
energy_total
energy
energy_components_valid
```

作为一个整体原子性更新。

---

# 58. `crest_sploop()` 必须同步 component metadata

当前 `crest_sploop()` 的 thread-local 路径为：

```text
structures(zcopy)
→ copy to mols(job)
→ engrad(mols(job), ...)
→ structures(zcopy)%energy = energy
```

Phase 1 修改后：

```text
engrad()
```

会在：

```text
mols(job)
```

中产生：

```text
energy_raw
energy_restraint
energy_total
valid
```

因此成功路径必须同步：

```text
structures(zcopy)%energy_raw
structures(zcopy)%energy_restraint
structures(zcopy)%energy_total
structures(zcopy)%energy
structures(zcopy)%energy_components_valid
```

推荐新增统一 helper，例如：

```text
copy_energy_components_from()
```

或：

```text
sync_energy_components(dst, src)
```

不要在多个 loop 中手工复制 5 个字段，降低以后漏字段风险。

failure path：

```text
energy_components_valid = false
```

不得保留输入 structure 的旧 component metadata。

---

# 59. `crest_oloop()` 必须同步 component metadata

当前 geometry optimization loop 成功后主要同步：

```text
structures(zcopy)%xyz
structures(zcopy)%energy
```

新增字段后同样必须同步 optimization 最终 geometry 对应的完整：

```text
raw/restraint/total/valid
```

特别要求：

> component metadata 必须对应 **优化后的最终 geometry**，不能对应最后一次 accepted step 之外的旧 geometry。

因此 Luna 必须核对：

```text
optimize_geometry()
```

最终能量评估到底写入：

```text
mols(job)
还是
molsnew(job)
```

然后从实际 final object 同步。

不能猜测。

---

# 60. `crest_refine()` 必须审计

当前 `crest_refine()` 支持：

```text
refine%singlepoint
refine%geoopt
refine%correction
refine%deltaG
```

并在结束时再次：

```text
structures(j)%energy = eread(j)
```

Phase 1 至少要保证 GloMinCluster 未来使用的：

```text
singlepoint
geoopt
post-search opt
```

不会把 component metadata 覆盖成 stale state。

建议：

### singlepoint

`crest_sploop()` 已更新 structure components 后：

```text
不要仅靠 eread 重写 legacy energy 而破坏 component consistency
```

### geoopt

`crest_oloop()` 已更新 geometry + components 后：

```text
保持完整 metadata
```

### correction / deltaG

Phase 1 不需要建立通用的：

```text
raw
+ thermochemical correction
+ restraint
+ bias
```

多分量框架。

对于这些特殊 refinement：

1. 保持 upstream 行为；
2. 若无法严格定义当前 GMC raw-energy contract：
   ```text
   energy_components_valid = false
   ```
   或限制 GMC capability；
3. 不允许错误地把 correction 当 structural restraint。

GloMinCluster 0.2.0a2 当前不依赖这些模式，因此不要扩大 Phase 1 范围。

---

# 61. Hybrid method provenance

Phase 1 至少必须保证：

```text
raw energy 的 active method/stage 可以由运行配置和 CREST calculator provenance 明确解释
```

建议 machine-readable metadata 最终增加：

```text
energy_stage
```

例如：

```text
workhorse
quality_sp
quality_opt
post_opt
```

以及可选：

```text
energy_method
```

例如：

```text
gfnff
gfn2
gxtb
```

但是否把字符串直接存进 `coord`，由 Luna 在最小改动原则下评估。

### 最低强制要求

即使 Phase 1 不新增 per-structure method string：

- calculation configuration 必须可追踪；
- refine stage 必须可追踪；
- extxyz/XYZ component 不能在不同 stage 间 stale；
- GloMinCluster 后续可通过 resolved config + stage provenance 确定该 raw energy 属于哪个方法。

---

# 62. Phase 1 新增 Hybrid Unit Tests

## Test H1：Parser regression

直接测试：

```text
gfn2@gfnff
```

必须解析为：

```text
quality = gfn2
workhorse = gfnff
mode = at
```

测试：

```text
gfn2//gfnff
```

必须：

```text
quality = gfn2
workhorse = gfnff
mode = sp
```

测试：

```text
gfn2/opt/gfnff
```

必须：

```text
mode = opt
```

Phase 1 不修改 parser，但必须把这些测试作为防回归检查。

---

## Test H2：Workhorse raw-energy semantics

建立：

```text
quality = GFN2
workhorse = GFN-FF
refine_stage = 0
```

在同一 geometry 上计算。

必须：

```text
energy_raw
≈ independent GFN-FF energy
```

不是：

```text
GFN2 energy
```

---

## Test H3：Quality SP raw-energy semantics

切换：

```text
refine_stage = singlepoint
```

对相同 geometry：

```text
energy_raw
≈ independent GFN2 energy
```

并确认：

```text
不是旧 GFN-FF raw
```

---

## Test H4：Workhorse constrained decomposition

在 workhorse stage 加一个 structural restraint：

```text
raw = GFN-FF physical energy
restraint > 0
total = raw + restraint
```

---

## Test H5：Quality constrained decomposition

切换 quality GFN2 stage：

```text
raw = GFN2 physical energy
restraint > 0
total = raw + restraint
```

证明 restraint decomposition 与 active method 无关。

---

# 63. Hybrid Integration Tests

## Test HI1：`--gfn2@gfnff`

选一个小分子/小团簇，运行最小可行 hybrid workflow。

验证日志/计算设置明确：

```text
sampling/workhorse = GFN-FF
post-search quality = GFN2
```

最终 refined conformer：

```text
geometry = GFN2 post-opt geometry
energy_raw = GFN2 energy at final geometry
energy_total = raw + restraint（若约束开启）
```

若无 restraint：

```text
raw == total
```

---

## Test HI2：`--gfn2//gfnff`

验证：

```text
geometry 不因 quality SP 改变
```

但最终 reranking energy：

```text
energy_raw = GFN2 SP
```

不得仍是 GFN-FF。

---

## Test HI3：Hybrid + XYZ roundtrip

对 quality-refined ensemble：

```text
write XYZ
→ read XYZ
```

确认：

```text
raw/restraint/total
```

不丢失，不回退到 sampling workhorse energy。

---

## Test HI4：Hybrid + extxyz roundtrip

同上。

---

## Test HI5：Hybrid + CREGEN

构造/运行一个 quality-refined ensemble：

```text
CREGEN ranking
```

必须使用：

```text
当前 refined ensemble 的 raw energy
```

例如：

```text
gfn2//gfnff
```

最终 CREGEN 应使用：

```text
GFN2 SP raw energies
```

而不是之前 GFN-FF sampling energies。

---

# 64. Phase 1 修改文件列表补充

除原计划文件外，Luna 必须审计：

```text
src/parsing/parse_hybrid.f90
src/algos/refine.f90
src/algos/parallel.f90
```

注意：

```text
parse_hybrid.f90
```

原则上只测试、不修改，除非实际发现 upstream bug。

`parallel.f90` 很可能必须修改，因为：

```text
crest_sploop
crest_oloop
```

目前只同步 legacy energy。

`refine.f90` 必须审计并按最小必要范围修复 component synchronization。

---

# 65. Phase 1 源码审计命令补充

Luna 开始修改前增加：

```bash
rg -n 'parse_hybrid|setup_hybrid_calc|refine_stage|refine_queue' src
rg -n 'crest_sploop|crest_oloop' src
rg -n 'structures\(.*\)%energy|%energy = eread' src/algos
rg -n 'refine%singlepoint|refine%geoopt|refine%post_opt' src
```

重点寻找：

> 哪些代码路径会在 calculator 已生成新 component 后，只回写旧 `energy` 而丢失 component metadata。

---

# 66. Hybrid 兼容性的完成条件

Phase 1 完成检查表新增：

- [ ] `A@B` parser semantics unchanged；
- [ ] `A//B` parser semantics unchanged；
- [ ] `A/opt/B` semantics unchanged；
- [ ] workhorse stage raw = B；
- [ ] quality SP stage raw = A；
- [ ] quality OPT/post-OPT stage raw = A；
- [ ] restraint decomposition independent of workhorse/quality method；
- [ ] `crest_sploop` 不丢 component metadata；
- [ ] `crest_oloop` 不丢 component metadata；
- [ ] `crest_refine` 不产生 stale raw energy；
- [ ] hybrid XYZ roundtrip；
- [ ] hybrid extxyz roundtrip；
- [ ] hybrid CREGEN 使用当前 refined raw energy；
- [ ] single-level upstream behavior unchanged。

---

# 67. 对未来 GloMinCluster 的意义

Phase 1 这样实现后，后续 GloMinCluster 可以安全扩展：

```yaml
mtd:
  method:
    sampling: gfnff
    refinement: gfn2
```

最终映射到：

```text
--gfn2@gfnff
```

或更一般的：

```text
A@B
```

同时 GPR / MF 可以明确区分：

```text
sampling workhorse energy
canonical/refined low-level energy
DFT energy
```

例如未来：

```text
MTD sampling:
GFN-FF

Round canonical geometry:
GFN2-xTB(vtight)

DFT:
r2SCAN-3c
```

则 surrogate 的低层 prior 应使用：

```text
canonical GFN2 raw energy
```

而不是：

```text
GFN-FF sampling energy
```

sampling energy 仍可作为额外 feature/provenance，但不能与 canonical refinement energy 混淆。

---

# 68. Hybrid 兼容性的一句话原则

> **Phase 1 的 raw/restraint/total 改造必须对 CREST 的 active calculation stage 透明：谁是当前 workhorse/refinement method，`energy_raw` 就记录谁在该 geometry 上、加入 restraint 前的物理能量；任何 stage transition 都必须原子性刷新全部 energy-component metadata，从而完整保留 `A@B`、`A//B` 和 `A/opt/B` 等 CREST 3.1 原生混合方法能力。**
