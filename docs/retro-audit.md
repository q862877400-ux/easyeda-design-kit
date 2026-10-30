# 用新门禁回测历史（retro-audit）

**目的**：用新门禁去审我**过去真实做过的事**，验证它能不能抓住当事人自己犯的错。
不是自评，是拿证据跑脚本。

**方法**

| 输入 | 来源 |
|---|---|
| 被审计工作区 | `easyeda-auto`（`.work/` 799 个文件；历史 playbooks；我写的实现代码） |
| 代码范围 | `-CodeScope 'src\easyeda-agent'`（只审自己写的，排除第三方与扩展工程） |
| 历史运行日志 | `acceptance/fixtures/runlog-historical.txt` —— 从台账内联代码块**机械抽取**（不是手写、不是重跑） |

复现命令：

```
pwsh -File acceptance/run.ps1 -Case esp32-4layer `
  -AuditRoot <path-to-easyeda-auto> -CodeScope 'src\easyeda-agent' `
  -RunLog acceptance/fixtures/runlog-historical.txt
```

---

## 1. 抓到了什么（实测，截至 2026-10-31）

| 判据 | 实测结果 | 对应我真实做过的事 |
|---|---|---|
| **N1 一次性产物** | **FAIL：184 个**（`autolayout-apply.json`、`pc-apply.json`、`pc-apply2.json`…） | 用一次性 playbook 反复画板——能力归零的直接机制 |
| **N5 旧快照求解** | **FAIL：求解 14 次 / 取快照 2 次** | 第 43、46 轮同一个错，Clearance 18→31 |
| **P6 编造命令** | **FAIL：`sch delete`（2 处）、`checkpoint`** | 历史 playbook 里写了 **CLI 根本不存在的命令**，当时无人能发现 |
| **N3 自建检查器** | **FAIL：4 个** — `cmd_pcb_module_check.go` 115KB、`pcb_check.go` 98KB、`pcb_check_connector.go` 29KB、`check-exam-examples.py` 30KB | 我自己写 DFM/规则检查，而扩展中心已有「嘉立创下单检查」（18 项） |
| **P3 功能重叠** | **FAIL：5 个** — 上榜含 `pcb_route_critical.go` 等 | 手搓布线能力，而扩展中心已有 PCB Auto Router |

**最有价值的是 P6**：它证明历史里那些「跑通了」的链路，至少有一整步是**凭想象写的命令**。
当时没有任何检查能发现——这就是"看起来在推进"的典型形态。

---

## 2. 回测顺带抓出的门禁自身缺陷（已修 / 已验证）

| 缺陷 | 症状 | 处置与验证 |
|---|---|---|
| **A 噪音放大** | 首次报「10041 个实现类源文件」（含 `node_modules`、扩展工程） | 加排除目录；实测 `-CodeScope` 范围内 814 个 `.go/.ts/.js`（748 个 `.go`）——**这是真实数字**，不是噪音 |
| **B `-CodeScope` 静默失效** | 以为限定了范围，其实扫了全盘 | 根因是 `-match` 用了未转义反斜杠（非法正则），失效方式与我犯错同源。改用 `Contains()`，并在运行头部**打印** `auditRoot`/`codeScope` 供核对 |
| **C 判据太糙** | P3/N3 只按"提到 clearance/drc/dfm"就算，把 `cmd_pcb.go`(225KB)、`dispatch.go` 等基础设施也算进来（52 个） | 改为**文件名签名 + 体积**：`(check|drc|dfm|autorout|shortroute|route_)` 且 >20KB 且非测试。结果收敛到 **5 个 P3 / 4 个 N3**，全部人工可核对 |
| **D 外部审计语义错误** | 拿"kit 里零实现代码"去审历史仓库，把连接器本身判成违规 | 引入 `-AuditRoot != RepoRoot` 判定：外部审计只判**与既有扩展功能重叠**的子集 |

**已验证**：修完后 `codeScope: [src\easyeda-agent]` 在运行头部可见；同一命令的两次结果从「10041 / 52」收敛到「5 / 4」。

---

## 3. 结论

1. **门禁抓得住我过去的错**：184 个一次性产物、14:2 的旧快照求解、2 个编造命令、4 个自建检查器、5 个功能重叠实现——这四类就是"跑偏"的全部形态。
2. **门禁自己也会静默失效**，而且失效方式与我犯错同源（以为检查在位，其实没生效）。因此门禁必须双向验证：既证明它会 FAIL，也证明它**在该生效的位置生效**、且**数字可核对**。
3. 修正后的判据是**可复核的**：每条都给出文件名与体积，人能一眼判断对错，不需要相信脚本的结论。
