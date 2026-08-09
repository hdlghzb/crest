# GloMinCluster Phase 2A — CREST Fork 详细执行计划
## QCG Final Optimizer + Final-Only Structural Restraints

状态：**EXECUTION-READY**  
实际代码目标仓库：`hdlghzb/crest`  
实际目标分支：`glomincluster/crest-3.1-api-v1`

> 本文件是 Phase 2A 在 CREST fork 仓库内的权威执行计划。GloMinCluster 仓库只保留跨仓库索引与 Phase 2B/2C 文档，不再维护 Phase 2A 镜像，避免双份文档漂移。

## 1. 前置状态

CREST Phase 1 已 runtime smoke-tested：

```text
pinned upstream base
bd27e348ec001e27eab3177586843e8d86f66dc8

accepted source
44bfec711151474c85be827d9b95b47e812b5a81

Phase 1 docs closeout
ec5e8ab704df104dc9edc42790fa026f5e72e4c8
```

已完成：capability/provenance、raw/restraint/total、XYZ/extxyz persistence、hybrid propagation、CREGEN raw ranking、QCG+xTB6.7.0 smoke。

不得重复或重置 Phase 1 foundation。

## 2. 本阶段必须完成

1. QCG grow-final optimization 统一到 mdopt-equivalent calculator/optimizer implementation；
2. final convergence 支持 GMC 请求 `vtight`；
3. final optimizer 前释放 grow-only whole-solute protection；
4. final-only distance/angle/dihedral restraints；
5. restraint 不污染 QCG setup/grow/docking/aISS；
6. final artifact 带正确 energy components；
7. capability API 暴露新功能；
8. CMake/Meson/Release/runtime regression；
9. official xTB 6.7.0 QCG compatibility gate。

## 3. 不做

- 不修改 GloMinCluster Python；
- 不改变 QCG growth/aISS 科学算法；
- 不改变 xTB6.7.0 acceptance target；
- 不做 MTD final-tight skip；
- 不改变 NCI-iMTD scientific parameters；
- 不实现 iRMSD production clustering；
- 不把 g-xTB 设为默认；
- 不实现 GPR；
- 不把 FeCN6 联合科学验收算作 2A，FeCN6 属于 2C。

## 4. Preflight

在 CREST 工作目录：

```bash
git remote -v
git branch --show-current
git rev-parse HEAD
git log --oneline -12
git status --short
git diff
git diff --cached
git submodule status --recursive
```

先读：

```text
docs/development/CREST-GMC-FORK.md
docs/testing/CREST-GMC-Phase1-test-report.md
docs/development/GloMinCluster-CREST-fork-Phase1-detailed-execution-plan.md
docs/development/CREST-GMC-Phase2A-QCG-constraints-execution-plan.md
src/qcg/qcg_main.f90
src/qcg/qcg_misc.f90
src/qcg/qcg_coord_type.f90
src/calculator/calculator.F90
src/optimize/optimize_module.f90
src/confparse.f90
src/gmc_api.f90
```

保存用户修改，不 reset 到 upstream base。

## 5. Current QCG audit

修改前：

```bash
rg -n "opt_cluster|xtb_opt_qcg|final_gfn2_opt|cluster_optimized|fixsolute|constrain_solu" src/qcg src
rg -n "cinp|constraint|parse_constraint" src/confparse.f90 src
rg -n "optimize_geometry|optlev" src/qcg src/optimize
```

形成调用图，区分：

- grow-final no-wall optimization；
- setup/intermediate/CFF/其它 QCG optimize；
- grow freeze/protection state；
- generic `--cinp` 影响范围。

只改目标 final path，不机械替换所有 `opt_cluster`。

## 6. Scientific contract

```text
setup/grow/docking/aISS
→ existing grow-stage solute protection
→ no GMC key-coordinate final restraints

completed grow cluster
→ release grow-only whole-solute protection
→ full cluster optimizer
→ GFN2-xTB(vtight)
→ optional explicit solute internal-coordinate restraints
→ final geometry + energy components
```

constraint OFF：full cluster free。  
constraint ON：full cluster free + only explicit solute key restraints。

禁止 final whole-solute freeze、whole-solute pair restraints、rigid solvent、final-cinp 泄漏到 grow/aISS。

## 7. Mdopt-equivalent 定义

目标是统一 implementation core：

- same `optimize_geometry` / calculator path；
- same active method；
- same convergence-level semantics；
- same final reevaluation/component correctness；
- 不再让 QCG final 使用一套独立 external `xtb --opt` 行为。

不是要求 shell/CLI 形式完全相同。

## 8. Final-only opt-level API

推荐接口：

```text
--qcg-final-opt-level vtight
```

要求：

- 只控制 grow-final no-wall optimizer；
- 不提高 setup/grow/docking/aISS intermediate opt level；
- invalid value fail fast；
- options absent 时保持 upstream-compatible default；
- parser/unit tests。

实际内部可用 enum/settings object，但 capability/CLI contract需稳定。

## 9. Final-only constraint API

推荐：

```text
--qcg-final-cinp constraints.inp
```

要求：

- 只在 final optimizer 初始化 calculator/constraints 时读取；
- setup/grow/aISS 不读取；
- missing/invalid fail fast；
- distance/angle/dihedral 复用现有 calculator restraint implementation；
- numeric target only；
- no `coord.ref`；
- no literal `auto`。

不要开发一套 GMC-specific restraint 数学实现。

## 10. Grow freeze release

必须有代码/targeted test 直接证明 final calculator 不继承 grow-only whole-solute freeze。

如果 grow protection 来自 `constrain_solu`、freezelist 或其他多条路径，final entry 必须显式清理/重建正确 state，不依赖偶然对象生命周期。

## 11. Final implementation

推荐最小改动：只迁移 target grow-final no-wall path。

概念：

```text
qcg cluster
→ coord molin
→ setup active GFN2 calculator
→ clear grow-only freeze
→ add optional final-only restraints
→ set final opt level
→ optimize_geometry(molin,molout)
→ final reevaluation/components
→ write/return molout
```

失败时不得把 pre-final `cluster.xyz` 冒充成功 final output。

## 12. Energy/output contract

Phase 1 保持：

```text
energy=total
energy_total=total
energy_raw=physical active-method energy
energy_restraint=structural restraint contribution
```

final metadata 必须对应最终 returned geometry。

优先继续使用 `cluster_optimized.xyz`，减少 GMC integration变化；如新增 machine artifact，必须保留已有兼容 output并文档化。

## 13. Capability

在 `--gmc-capabilities` 中增加稳定字段，概念：

```json
{
  "qcg_final_optimizer": true,
  "qcg_final_opt_level": true,
  "qcg_final_constraints": true,
  "qcg_final_constraint_types": ["distance", "angle", "dihedral"]
}
```

实际字段名实现时冻结。

要求：

- no geometry/xTB required；
- Phase 1 fields unchanged；
- 是否 bump GMC API version 必须按 backward compatibility 明确决定；
- GloMinCluster 通过 capability，不通过 `--help` grep。

## 14. Unit tests

新增/扩展独立 QCG-final suite：

1. final opt-level parser；
2. final cinp parser；
3. options absent compatibility；
4. final constraint OFF：no grow freeze / no restraint；
5. distance final-only；
6. angle final-only；
7. dihedral final-only；
8. final-cinp no leakage to grow；
9. vtight scope only final；
10. final output components correspond to final geometry。

## 15. Standalone equivalence

相同 small cluster/start geometry/method/charge/UHF/constraint/level：

```text
A QCG final optimizer
B standalone mdopt-equivalent optimize_geometry reference
```

比较 success、final energy、geometry、components、restrained coordinate，记录合理 tolerance。

## 16. Build/test gates

Primary：GCC/GFortran14.2 + OpenBLAS0.3.34 + CMake RelWithDebInfo。

至少：

```text
gmc_qcg_final
gmc_energy
gmc_cregen
gmc_hybrid
gmc_capabilities
optimization
```

再跑 crest-only 和 full CTest。

Meson Debug targeted 同步；已知 `pbc_cregen` Debug FPE diagnostic 不在本阶段修。

## 17. Runtime QCG smokes

official xTB6.7.0：

```text
A options absent baseline
B final vtight, no constraint
C final vtight + simple distance restraint
```

检查 single CREST entry、valid final artifact、components、successful/finished aISS markers。

因为 production optimizer changed，必须重跑 xTB6.7.0 QCG compatibility gate。

## 18. Clean Release acceptance

完成实现提交后重新 clean Release configure/build：

- build；
- crest-only；
- full CTest；
- capability/provenance；
- ldd；
- QCG xTB6.7.0 smoke。

accepted binary `fork_commit` 必须等于实际 committed implementation source short SHA。

## 19. Docs/report

在 CREST 仓库更新：

```text
docs/development/CREST-GMC-FORK.md
docs/testing/CREST-GMC-Phase2A-test-report.md
```

不覆盖 Phase 1 历史报告。

## 20. Commit建议

```text
A1 feat(qcg): add final-only optimizer controls
A2 feat(qcg): apply final-only structural restraints
A3 test/docs: close Phase 2A acceptance
```

可以按实际最小实现调整，但禁止混入 MTD/GPR/iRMSD/g-xTB default等后续任务。

## 21. 完成判定

可写：

> `CREST GMC Phase 2A QCG final-optimizer and final-only restraint implementation is runtime smoke-tested.`

只有在 final mdopt-equivalent、vtight scope、grow freeze release、distance/angle/dihedral、components、capability、CMake/Release、xTB6.7.0 QCG smoke、commit/push 全部完成后。

不得写：GloMinCluster integration PASS、FeCN6 scientific acceptance PASS、MTD final-tight skip PASS 或 formal release ready。
