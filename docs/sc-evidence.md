# 成功判据（SC）证据台账

**规则**：每条 SC 只认**可复跑的命令 + 数字**。没实测的一律写「未验证」，不许写「已支持」。

| 判据 | 状态 | 证据 | 复跑方式 |
|---|---|---|---|
| **SC-001** 未见板 5/5 | **5/5 端到端跑通**（现口径：每块 **18 PASS / 1 FAIL / 0 BLOCKED**，唯一 FAIL 是 `pcb-drc-clean`；五种电路类型：LED / LDO / P-MOS / 自动下载 / USB-C） | 第 1 块 `sc001-led-typed`：**由 typed 动作现场生成**（此会话第 7 轮才出现，此前不存在），`project.create` → `sch block-apply` → 布局收敛 → `pcb import-changes` → `outline-fit` → `route fill` → 导出交付，验收 **16 PASS / 0 FAIL / 0 BLOCKED**。**口径限制**：两块均由本会话构建与执行；"零上下文"那半个口径由 executor-crosscheck 方法另行覆盖（本会话已对 `sc001-ldo-typed` 派发零上下文复跑，结果见该文件） | `run.ps1 -Case sc001-led-typed -Project sc001-led-blk -SchDoc 8124aea12d407530 -Doc 1e56ec91cd0bad4b -DeliveryDir …`；第 2 块 `sc001-ldo-typed`（AMS1117 供电板，4 件/3 网/7 连接，DSN→`pcb_autorouter` 全自动布线 116ms）同样 **16 PASS / 0 FAIL / 0 BLOCKED**，Gerber 11,485 B / CPL 1,944 B / BOM 7,014 B |
| **SC-002** 四项同时成立 | **已验证** | `acceptance/run.ps1`（现 19 阶段）**18 PASS / 1 FAIL / 0 BLOCKED**，FAIL 仅 `pcb-drc-clean`；四项判据本身仍成立：`schematic-gates` PASS + `pcb-connectivity` Connection Error 0 + `pcb-dfm` DFM ERROR 0 + `delivery` 三件齐备（Gerber 74,869 B / 坐标 13,358 B / BOM 8,379 B） | `pwsh -File acceptance/run.ps1 -Case esp32-4layer -Project … -SchDoc … -Doc … -DeliveryDir …` |
| **SC-003** 一次性脚本 = 0 | **已验证** | `no-oneoff-scripts` PASS（审计 `-RunLog`，无临时脚本调用） | 同上（带 `-RunLog`） |
| **SC-004** 换模型/换 harness 复跑通过 | **已验证（harness 维度）** | 两个全新会话、零上下文的子 agent 复跑：运行 C 得 **16 PASS / 0 FAIL / 0 BLOCKED（退出码 0；当时口径 16 阶段，现为 19 阶段）**，与运行 A **逐阶段 0 处不同**；selftest 30/30、matrix 16/16 亦一致。**模型维度未验证**（三次都是 deepseek-v4.1） | 见 `docs/executor-crosscheck.md`；换模型仍需业主入口 |
| **SC-005** 决策表可执行率 ≥90% | **未达成（29.7%）** | 新门禁 `decision-actionability`：实测 **33/111 = 29.7%**（2026-11-01 收紧口径后）。旧值 110/111=99.1% 由"参数列 ≥10 字符"撑起——那样纯散文也能过（外部审计 A1）。现口径要求参数列含**具体物**：flag / 反引号命令 / 数值+单位 / 文件名 / JSON。可执行的机械定义：有工具名 + 参数 ≥10 字符 + 标「未装」时必须给替代。补齐前实测 77/94 = 81.9%（17 行是空话），逐行改写后达标 | `run.ps1` 的 `decision-actionability` 阶段 |
| **SC-006** 同需求两次执行结论一致 | **已验证** | 两次**完整**运行（19 阶段口径，比对排除 `run-consistency` 自身）**18 个可比阶段 0 处不一致**，两次均 0 BLOCKED；`run-consistency` 门禁实测输出：`18 个阶段结论一致 … 两次均 0 BLOCKED`。注：含 BLOCKED 的运行（窗口掉线）**不算**一致证据，也不算出证据 | 连跑两次 `run.ps1` 比对阶段表 |

---

## SC-005 具体做了什么（不是改判据放宽）

1. 新增门禁 `decision-actionability`，机械定义"可执行"，阈值写死 90%。
2. 首跑 **77/94 = 81.9% FAIL** —— 暴露 17 行参数只有"导入 CSV""带网络""只服务 FPC"这类空话。
3. 逐行重写为可执行描述（含替代路径），**不删行、不降阈值**。
4. 复跑 **93/94 = 98.9% PASS**；剩余 1 行留作观察，仍高于阈值。
5. 自测新增两条断言（正例：kit 自身 ≥90%；反例：30 行全是"短"→ 必 FAIL）。

## SC-006 的注意事项

一次性看似的"两次一致"可能被环境骗过：第一次实测时 EDA 窗口中途掉线，两次都返回 BLOCKED —— 那不是"一致"，是**两次都失败**。
因此 SC-006 的比较必须建立在**两次都无 BLOCKED**的前提上，本次已满足（16 PASS 各两次）。










---

## 跨板回归（2026-10-31，同一轮内顺序实测）

| # | 板 | 类型 | 验收 |
|---|---|---|---|
> 口径：下表为**现 19 阶段**结果（含 `pcb-drc-clean`），每块唯一的 FAIL 都是 DRC 非 0；此前 16 阶段口径下的 16/0/0 已作废。
| 1 | `agent-e2e-esp32s3-board31` | 客户给定练习板（4 层） | **18 PASS / 1 FAIL / 0 BLOCKED** |
| 2 | `sc001-led-typed` | LED 指示（2 件/1 网） | **18 PASS / 1 FAIL / 0 BLOCKED** |
| 3 | `sc001-ldo-typed` | AMS1117 线性稳压（4 件/3 网） | **18 PASS / 1 FAIL / 0 BLOCKED** |
| 4 | `sc001-buck-blk` | P-MOS 高侧负载开关（6 件/7 网） | **18 PASS / 1 FAIL / 0 BLOCKED** |
| 5 | `sc001-usbc-blk` | USB-C 输入前端（6 件/7 网、29/29 布通） | **18 PASS / 1 FAIL / 0 BLOCKED** |

五块板**同一次顺序运行**内跑完（2026-10-31 第 19 轮复验），无一块退化。这条替代了此前"靠记忆认为没退化"的说法——
每次改动后必须重跑，才能说"没退化"。






---

## 状态更正（2026-10-31，外部审计后，**必须读**）

此前本文件多处写「五块板 16 PASS / 0 FAIL / 0 BLOCKED」。加入第 17 阶段 `pcb-drc-clean` 后，**真实结果是每块 16 PASS / 1 FAIL**：

| 板 | `pcb drc` 实测 | 结论 |
|---|---|---|
| `agent-e2e-esp32s3-board31`（练习板） | passed=False，**27 条**（Clearance 26 + Netlist 1） | 不满足 SC-A 的「DRC 0」 |
| `sc001-usbc-blk` | passed=False，**3 条**（Clearance 2 + Netlist 1） | 同上 |

**旧口径只验 `Connection Error`（都是 0），所以显示全绿**——那是窄口径，不等于 DRC 干净。
SC-A 如实标注：**未达成**，待办 = 把板子的 DRC 违规清零（netlist 与 clearance）。
其余判据（SC-001 五块板端到端跑通、SC-002/003/004/005/006）不受影响。

---

## SC-006 状态更正（2026-10-31，接入 `run-consistency` 后）

此前本文件写 SC-006「两次执行 16 阶段 0 处不同」。把比对接成门禁第 19 阶段 `run-consistency` 后，
用**同一块板、同一命令连跑两次**实测：

| 次 | 结果 |
|---|---|
| 第 1 次 | 17 PASS / 1 FAIL / 1 BLOCKED |
| 第 2 次 | 17 PASS / 2 FAIL / 0 BLOCKED |
| 比对 | **10 处阶段结论不一致**（多数为 BLOCKED → PASS）|

根因：**EDA 窗口在运行中途掉线**（GAP-055）。同样的板、同样的命令，差异全部来自"那一刻窗口在不在"。

**修正后的结论（同轮实测）**：把比对规则收紧为「只挑**完整运行**（除 `run-consistency` 自身外 0 BLOCKED）」后，
两次完整运行的结论是**一致的**——门禁给出
`[PASS] run-consistency 18 个阶段结论一致；两次均 0 BLOCKED，pass=17/fail=1`
（两份报告：`20261101-000634-…` 与 `20261101-000647-…`）。

即：**SC-006 成立的前提是两次都跑完整**。掉线的那次不能被当成"不一致"的证据，也不能被当成"一致"的证据
——它根本不是一次完整运行。这条限制已写进阶段三态（两次阶段集不同 → BLOCKED；含 BLOCKED → BLOCKED）。
`run-consistency` 已实现三态：两次阶段集不同 → BLOCKED（跨版本不可比）；两次都含 BLOCKED → BLOCKED
（不完整的两次不算一致证据）；逐阶段不同 → FAIL。






