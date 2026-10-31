# 成功判据（SC）证据台账

**规则**：每条 SC 只认**可复跑的命令 + 数字**。没实测的一律写「未验证」，不许写「已支持」。

| 判据 | 状态 | 证据 | 复跑方式 |
|---|---|---|---|
| **SC-001** 两块未见板 2/2 | **未验证（0/2 已完成 1 块）** | 本会话完成的是 `agent-e2e-esp32s3-board31`（练习板，非"未见板"）；未见板素材需 GUI 导入开源 `.epro2`（T052） | 见 T052 |
| **SC-002** 四项同时成立 | **已验证** | `acceptance/run.ps1` 16 PASS / 0 FAIL / 0 BLOCKED：`schematic-gates` PASS + `pcb-connectivity` Connection Error 0 + `pcb-dfm` DFM ERROR 0 + `delivery` 三件齐备（Gerber 74,869 B / 坐标 13,358 B / BOM 8,379 B） | `pwsh -File acceptance/run.ps1 -Case esp32-4layer -Project … -SchDoc … -Doc … -DeliveryDir …` |
| **SC-003** 一次性脚本 = 0 | **已验证** | `no-oneoff-scripts` PASS（审计 `-RunLog`，无临时脚本调用） | 同上（带 `-RunLog`） |
| **SC-004** 换模型/换 harness 复跑通过 | **已验证（harness 维度）** | 两个全新会话、零上下文的子 agent 复跑：运行 C 得 **16 PASS / 0 FAIL / 0 BLOCKED（退出码 0）**，与运行 A **逐阶段 0 处不同**；selftest 30/30、matrix 16/16 亦一致。**模型维度未验证**（三次都是 deepseek-v4.1） | 见 `docs/executor-crosscheck.md`；换模型仍需业主入口 |
| **SC-005** 决策表可执行率 ≥90% | **已验证 98.9%** | 新门禁 `decision-actionability`：可执行 **93/94 = 98.9%**。可执行的机械定义：有工具名 + 参数 ≥10 字符 + 标「未装」时必须给替代。补齐前实测 77/94 = 81.9%（17 行是空话），逐行改写后达标 | `run.ps1` 的 `decision-actionability` 阶段 |
| **SC-006** 同需求两次执行结论一致 | **已验证** | 连续两次完整验收，各 15 个阶段，**0 处判定不一致**（两次均 15 PASS / 0 FAIL / 0 BLOCKED） | 连跑两次 `run.ps1` 比对阶段表 |

---

## SC-005 具体做了什么（不是改判据放宽）

1. 新增门禁 `decision-actionability`，机械定义"可执行"，阈值写死 90%。
2. 首跑 **77/94 = 81.9% FAIL** —— 暴露 17 行参数只有"导入 CSV""带网络""只服务 FPC"这类空话。
3. 逐行重写为可执行描述（含替代路径），**不删行、不降阈值**。
4. 复跑 **93/94 = 98.9% PASS**；剩余 1 行留作观察，仍高于阈值。
5. 自测新增两条断言（正例：kit 自身 ≥90%；反例：30 行全是"短"→ 必 FAIL）。

## SC-006 的注意事项

一次性看似的"两次一致"可能被环境骗过：第一次实测时 EDA 窗口中途掉线，两次都返回 BLOCKED —— 那不是"一致"，是**两次都失败**。
因此 SC-006 的比较必须建立在**两次都无 BLOCKED**的前提上，本次已满足（15 PASS 各两次）。

