# 未见板执行剧本

**用途**：拿到一块**此前没画过**的板的需求，按本文件一步步做完并自证。这是 SC-001 的可操作形态。
**对象**：任何执行者（包括零上下文的新会话、另一个模型）。

---

## 0. 开始前（防作弊与防自欺）

| 动作 | 命令 / 做法 |
|---|---|
| 冻结题目 | `Get-FileHash acceptance\cases\<case>.md -Algorithm SHA256`，把哈希记进报告 |
| 开日志 | `$log = "runs\$(Get-Date -Format yyyyMMdd-HHmmss).log"`；**每条命令都追加一行**（见第 2 节） |
| 明确执行者 | 报告里写 `-Executor "<模型>/<harness>/<会话>"` |
| 读三份文档 | `docs/tool-decision-table.md` → `docs/phases/schematic-s0-s6.md` → `docs/phases/pcb-p0-p10.md`（顺序不要变） |

**禁止**：改用例文件、事后补日志、把"没验证"写成"通过"。

---

## 1. 需求 → 约束清单

把需求文本拆成可检查的约束，每条形如「层数=4」「板框=客户给定」「四角 M3 孔」「载 5V 端子 + USB 供电」。
**约束必须能被某个阶段的退出判据检查到**；检查不到的约束要么删掉，要么补判据。

---

## 2. 运行日志（N4–N6 的输入）

不写新脚本，用 `Tee-Object`：

```powershell
$log = "runs\$(Get-Date -Format yyyyMMdd-HHmmss).log"
function Log-Run { param([string]$Cmd) ; $Cmd | Tee-Object $log -Append ; Invoke-Expression $Cmd }
```

之后每条命令都走 `Log-Run "easyeda pcb dump --out b1.json"` 这种形式：
**命令与日志同步产生，事后不补**。

---

## 3. 原理图 S0–S6

按 `docs/phases/schematic-s0-s6.md` 逐阶段做。每阶段结束记录：

| 记录项 | 例 |
|---|---|
| 阶段 | S5 |
| 用的工具 | `schematic.runDrc` |
| 判据结果 | `passed: true` |
| 失败与处置 | 无 / 修了什么 |

**卡住时**：先查 `docs/capability-boundary.md` 有没有对应 GAP（如 GAP-006 无 silk-list）；
有 → 走它的替代路径；没有 → 记一条新 GAP（含 triedTools）再决定。

---

## 4. PCB P0–P10

按 `docs/phases/pcb-p0-p10.md` 做。三个高频坑（都有实测）：

1. **落铜后不重铺就读 DRC** → Clearance 假性恶化（18→26）。必须 `pour-rebuild`（GAP-009）。
2. **对着旧快照求解多对** → 互相不避让（18→31）。每落一跳重新 `pcb dump`。
3. **用 `rip-up --net` 撤销** → 删掉该网全部铜（VIN 2→10 未连）。用 `track-delete`/`via-delete` 按 id。

布线阶段**首选** `PCB Auto Router`；它不可用时才走 `pcb route solve` + playbook（见 GAP-001）。

---

## 5. 交付

1. `嘉立创下单检查` → 要求 **ERROR = 0**（权威 DFM 口径，GAP-010）。
2. `PCB Delivery Export` → 导出 Gerber / 钻孔 / 坐标 / BOM 到指定目录。
3. 核对每类文件**存在且非空**（不是看命令返回 ok）。

---

## 6. 验收（唯一判据）

```powershell
pwsh -NoProfile -File acceptance/run.ps1 -Case <case> `
  -Project <工程> -Doc <PCB 文档 id> `
  -DeliveryDir <交付目录> -RunLog $log `
  -Executor "<模型>/<harness>/<会话>"
```

| 退出码 | 含义 | 下一步 |
|---|---|---|
| 0 | 全 PASS | 记录报告，交付 |
| 1 | 有 FAIL | 按阶段名修，**不许改判据** |
| 2 | 有 BLOCKED | 补前置（工程/窗口/日志）——不是通过 |
| 3 | 用法错误 | 检查 `-Case` 文件是否存在 |

---

## 7. 报告模板（贴进台账）

```text
用例：<case>   哈希：<sha256>   执行者：<model/harness/session>
阶段：S0..S6 / P0..P10 逐条 PASS/FAIL/BLOCKED
关键数字：DRC Connection=<n> Clearance=<n>；DFM ERROR=<n>；走线/过孔=<n>/<n>
交付：Gerber/BOM/CPL 路径与体积
退出码：<0|1|2|3>
未验证项：<逐条列出，或写"无">
```

---

## 8. 这张剧本本身怎么被检验

跑一遍脚本化检查：

```powershell
pwsh -NoProfile -File acceptance/run.ps1 -Case <case> -AuditRoot . -RunLog $log
```

若 `negative-drift` 报 N4/N5/N6，说明执行过程本身有问题——**先修过程，再谈板子**。

