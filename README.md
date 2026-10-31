# EasyEDA AI Design Kit

> **装上它，任何模型都能把一块电路板从需求画到可打样。**

本仓库是产品的**唯一来源（canonical）**。它不是又一个 EDA 工具，而是把「画出板子」这件事
从**执行者的临场发挥**，变成**按文档执行 + 脚本验收**。

- 产品定义：[PRODUCT.md](PRODUCT.md)
- 需求规格：[specs/004-ai-pcb-design-kit/spec.md](specs/004-ai-pcb-design-kit/spec.md)
- 当前状态：**验收未通过**（见下）

---

## 1. 产品由三件套组成

| 件 | 内容 | 目录 |
|---|---|---|
| 能力知识包 | 情境→工具决策表、分阶段流程、设计规则、能力边界 | `docs/` |
| 可回放链路 | 多步操作固化为 playbook，禁止临时脚本 | `playbooks/` |
| 验收 | 一条命令判定「这块板画完没有」 | `acceptance/` |

**复用优先是硬规则**：默认零自有代码。先查扩展中心（`docs/extensions-index.md`），
再查命令层与类型化动作，都覆盖不了才补工具，并在 `docs/capability-boundary.md` 记录缺口证据。

---

## 2. 前置条件（安装一次）

1. **EasyEDA Pro**（含扩展中心可访问）。
2. **能力基础设施**：`easyeda` CLI 与 EDA Agent Connector 扩展（由既有项目提供，独立安装升级）。
3. 需要时在扩展中心安装流程文档点名的扩展（安装步骤写在文档里，不在每次执行时做）。

本仓库**不重新实现**上述基础设施。

---

## 3. 一条命令验收

```powershell
pwsh -NoProfile -File acceptance/run.ps1 -Case esp32-4layer
```

有工程时再加：

```powershell
pwsh -NoProfile -File acceptance/run.ps1 -Case esp32-4layer `
  -Project agent-e2e-esp32s3-board31 -Doc e8c8b7cb5507b5e2 `
  -DeliveryDir <制造文件目录> -RunLog <本次执行日志>
```

三态语义：**PASS / FAIL / BLOCKED**。退出码 `0`=全通过，`1`=有 FAIL，`2`=有 BLOCKED，`3`=用法错误。
BLOCKED 表示缺前置条件（没有工程、没有窗口、未提供审计日志），**不是通过**。

---

## 4. 当前状态（诚实记录）

`acceptance/run.ps1` 现在的结果是 **8 PASS / 0 FAIL / 10 BLOCKED**（BLOCKED = 需要在线板子的阶段），失败点已由脚本点名：

```
[FAIL] kit-integrity      缺 5/7 份：
       docs/tool-decision-table.md, docs/capability-boundary.md,
       docs/phases/schematic-s0-s6.md, docs/phases/pcb-p0-p10.md,
       playbooks/README.md
```

这就是本项目的**任务清单**：把这 5 份补出来，再把 8 个 BLOCKED 逐个变成 PASS。
未通过之前，任何「板子画好了」的说法都不算数。

---

## 5. 目录约定

```
docs/                能力知识包（决策表、阶段流程、规则、边界）
  extensions-index.md    扩展中心 75 项索引（已装/未装边界）
  design-rules.md        设计规范手册（线宽/间距/过孔/铺铜/DRC 清单）
playbooks/           可回放链路（具名、带说明、被索引）
acceptance/          验收脚本与用例
specs/               需求规格与质量清单
```

## 6. 验收立不住的情况（视为产品不成立）

- 只有某一个模型能通过；
- 通过依赖任何一次性脚本；
- 交付文件缺失却报 PASS；
- 把「数字变好」当成通过。
---

## 7. 反目标偷换（每轮的常驻门禁）

产品最大的失效模式不是「做不出来」，而是**把目标偷换**成「用一堆一次性脚本把眼前这块板画出来」。
它不会自我暴露，只会看起来一直在推进（实测：一次性脚本 26 个、一次性 playbook 28 个）。

因此 `acceptance/run.ps1` 里有一条常驻阶段 `drift-guard`，判据只看仓库事实：

1. 仓库内**不许存在**一次性产物（`.work/`、`*gen*.py`、`*apply*.json`、acceptance 之外调用 easyeda 的脚本）；
2. **最近一次提交必须动到** `docs/`、`playbooks/`、`acceptance/`、`specs/` 之一；
3. 规范产物数量**只能增不能减**（棘轮，基线 `acceptance/baseline.json`）。

门禁是**双向**的：`positive-goal` 查「是不是在长产品能力」（规范产物棘轮、playbook 必须可执行、kit 内禁实现代码、SC 判据 ≥3），`negative-drift` 查「有没有再犯历史错误」（一次性产物、只改板子的提交、自建检查器、rip-up 撤网、旧快照求解、未重载就读 DRC）。\n\n**两者都必须 PASS，这一轮才算数**——无论板子看起来多好。详见 [docs/anti-drift.md](docs/anti-drift.md)。
---

## 8. 门禁自测（门禁也要被门禁检查）

门禁自己会静默失效——本项目已发生两次：`-match` 用非法正则导致范围过滤没生效；
判据只看关键词导致数字不可核对。所以门禁配了自测：

```powershell
pwsh -NoProfile -File acceptance/selftest.ps1
```

它逐条验证**每个分支的正例与反例**：kit 自身必须 PASS；反例日志必须 FAIL；
`N3` 对"仅提及关键词"不判死、对"实质实现（>20KB）"必判死并报体积；
`-CodeScope` 必须真的缩小范围；历史回测必须抓到 N1/N5。当前 **36 PASS / 0 FAIL**（`acceptance/selftest.ps1`）。
---

## 9. 历史错误矩阵（把每个犯过的错都试一遍）

```powershell
pwsh -NoProfile -File acceptance/mistake-matrix.ps1
```

把我在这个项目里**真实犯过**的错逐条列成用例，植入复现物后看门禁是否给出预期判定。
当前 **16/16 抓到**：一次性脚本、一次性 playbook、说明冒充 playbook、编造 CLI 命令、
自建 DFM/布线器/丝印工具、rip-up 撤网、旧快照求解、未 reload 就读 DRC、决策表缩水、
跑旧二进制、门禁脚本自身损坏，外加两条「干净状态不得误判」的对照。

**这个矩阵本身也抓过我的错**：它三次抓出我写的复现物不合格（1KB 够不到 20KB 阈值、
`-Cli` 重复传参、断言匹配了不会出现的字样）——说明它在真检查，不是橡皮章。


---

## 10. 从这里开始读（导航）

| 你想做什么 | 读这个 |
|---|---|
| 了解产品是什么、不是什么 | [PRODUCT.md](PRODUCT.md) |
| 判断某件事该调哪个工具 | [docs/tool-decision-table.md](docs/tool-decision-table.md) |
| 画原理图 | [docs/phases/schematic-s0-s6.md](docs/phases/schematic-s0-s6.md) |
| 画 PCB（布局/布线/铺铜/交付） | [docs/phases/pcb-p0-p10.md](docs/phases/pcb-p0-p10.md) |
| 处理"做不到"的情况 | [docs/capability-boundary.md](docs/capability-boundary.md) |
| 跑一块没画过的板 | [docs/playbook-unseen-board.md](docs/playbook-unseen-board.md) |
| 装到别的 harness | [docs/harness-install.md](docs/harness-install.md) |
| 验证它真的能工作 | [specs/004-ai-pcb-design-kit/quickstart.md](specs/004-ai-pcb-design-kit/quickstart.md) |
| 看还有哪些没做完 | [specs/004-ai-pcb-design-kit/tasks.md](specs/004-ai-pcb-design-kit/tasks.md) |
| 理解为什么有这些门禁 | [docs/anti-drift.md](docs/anti-drift.md) · [docs/retro-audit.md](docs/retro-audit.md) |



