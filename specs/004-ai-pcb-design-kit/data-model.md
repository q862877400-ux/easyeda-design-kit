# Phase 1 Data Model — EasyEDA AI Design Kit

产品不含数据库。这里的"数据"是**仓库内的结构化文档与报告**，它们的字段决定了门禁能否机械校验。

---

## E1 Requirement（验收用例）

代表一块要被画出来的板子的需求。

| 字段 | 类型 | 说明 |
|---|---|---|
| `id` | string | 用例标识，如 `esp32-4layer`、`unseen-a` |
| `title` | string | 一句话标题 |
| `text` | markdown | 客户口径的需求原文（不加工） |
| `constraints` | list | 硬约束：层数、板框、接口、工艺 |
| `sha256` | string | 用例文件内容哈希，**跑前冻结** |
| `unseen` | bool | 是否为"此前没画过"的板（SC-001 只认 true 的用例） |
| `approvedBy` | string | 出题/批准人；未见板必须由业主出题或批准 |

**校验规则**
- `unseen: true` 的用例，`approvedBy` 不得为空，且 `sha256` 必须与文件当前内容一致（防事后改题）。
- `constraints` 里的每一项都必须能被至少一个阶段文档的判据检查到，否则视为无效约束。

---

## E2 Phase（阶段）

流程的最小可验收单元。原理图 S0–S6（7 个）、PCB P0–P10（11 个），共 18 个。

| 字段 | 类型 | 说明 |
|---|---|---|
| `id` | string | `S0`…`S6` / `P0`…`P10` |
| `name` | string | 阶段名 |
| `entry` | list | 进入条件（前置阶段已 PASS + 必要输入） |
| `actions` | list | 该阶段要调用的**具名工具/命令/playbook**（不得写"写个脚本"） |
| `exit` | list | 退出判据，必须可被脚本或明确命令判定 |
| `onFail` | string | 失败处置：修 / 换工具 / 报 BLOCKED（不得静默跳过） |

**校验规则**
- `actions` 中每一项必须是**可解析的工具名**（与 E3 同一解析规则）。
- `exit` 判据不得是形容词（"布局合理"无效）；必须是命令或数字阈值。

---

## E3 ToolEntry（决策表行）

「情境 → 工具 → 参数/坑」的一行。

| 字段 | 类型 | 说明 |
|---|---|---|
| `situation` | string | 触发情境（第三人称，具体到任务） |
| `tool` | string | **真实工具名**：扩展名 / 命令 / 类型化动作 |
| `params` | string | 关键参数与已知坑；只写实测，未实测标「未验证」 |
| `source` | enum | `extension` \| `command` \| `action`（由解析结果推断） |
| `verified` | bool | 是否本人实测过（false 时不得用于关键路径） |

**校验规则**
- `tool` 必须能在 `easyeda actions` 输出或 `docs/extensions-index.md` 中被找到（`tool-decision-table` 阶段逐行核对）。
- 行数**只增不减**（N8 对照 `baseline.json` 的 `decision_rows`）。
- 若 `verified: false`，该行不得单独作为某阶段的唯一 `action`。

---

## E4 BoundaryEntry（能力边界）

「这件事做不到 / 达不到理想，证据是什么，替代路径是什么」。

| 字段 | 类型 | 说明 |
|---|---|---|
| `id` | string | `GAP-001` |
| `capability` | string | 做不到的能力（具体到动作） |
| `evidence` | string | 实测证据：试了什么、结果如何（含数字/坐标/命令） |
| `triedTools` | list | **试过的现有工具**（至少 1 个，否则不算"覆盖不了"） |
| `alternative` | string | 替代路径（次优但可用） |
| `status` | enum | `open` \| `accepted` \| `resolved` |

**校验规则**
- `triedTools` 为空 → 该条无效（违反"先查现有工具"）。
- `status: resolved` 必须附解决方式（哪个工具有了新版本/新增了什么能力）。

---

## E5 Playbook（可回放链路）

| 字段 | 类型 | 说明 |
|---|---|---|
| `name` | string | 唯一名 |
| `version` | int | 结构版本（当前 1） |
| `meta.project` / `meta.doc` | string | 目标工程与文档 |
| `meta.description` | string | 为什么是这个顺序（顺序本身是知识） |
| `steps[]` | list | 每步 `run`（命令） + `flags` + 可选 `assert` |

**校验规则**
- 每个 step 的 `run` 必须解析到真实命令（P6）。
- `steps` 非空（P2）。
- 带破坏性的步骤（删除、覆盖）必须有 `assert` 或人工确认位。

---

## E6 AcceptanceRun（一次验收）

| 字段 | 类型 | 说明 |
|---|---|---|
| `case` | string | 对应 E1 |
| `model` / `harness` | string | 执行者标识（SC-004 用） |
| `startedAt` | string | ISO 时间 |
| `stages[]` | list | 每项 `{ stage, status, detail }`，status ∈ PASS/FAIL/BLOCKED |
| `exitCode` | int | 0 全 PASS / 1 有 FAIL / 2 有 BLOCKED / 3 用法错误 |
| `runLog` | string | 运行日志路径（N4–N6 的输入） |

**校验规则（状态机）**
- `exitCode = 0` 当且仅当所有阶段 PASS（BLOCKED 不算通过）。
- 任一阶段 `MISSING` 视为执行异常，整体判失败。
- 同一 `case` 连续两次运行，阶段结论必须一致（SC-006），允许耗时差异。

---

## E7 GateCheck（门禁条目）

| 字段 | 类型 | 说明 |
|---|---|---|
| `id` | string | 正向 `P1`…`P7`；负向 `N1`…`N9` |
| `intent` | string | 它防的是什么（对应哪次真实事故） |
| `criteria` | string | 机械判据 |
| `lastResult` | enum | PASS/FAIL/BLOCKED |

**校验规则**
- 每个 GateCheck 必须在 `acceptance/selftest.ps1` 或 `mistake-matrix.ps1` 里至少有一条正例与一条反例。
- 新增门禁而未加测试 → 视为未完成（写进 tasks）。

---

## 关系

```text
Requirement 1 ──< AcceptanceRun >── n GateCheck
Phase 1 ──< actions >── n ToolEntry
BoundaryEntry n ──< triedTools >── n ToolEntry
Playbook 1 ──< steps >── n ToolEntry(命令类)
```

要点：**Phase 的 actions、BoundaryEntry 的 triedTools、Playbook 的 steps 都指向 E3**。
这条关系是产品的骨架——它保证"该调什么"只有**一个**知识源，不会三处各写一套。
