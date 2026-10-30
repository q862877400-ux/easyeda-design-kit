# 进度账本（产品视角）

**规则**：每轮追加一行，只记**能力**变化与门禁证据；板子细节属于练习题，不在此表。

| 轮次 | 本轮长出的能力 | 门禁证据 | 提交 |
|---|---|---|---|
| 0 | 仓库与三件套骨架（文档 + playbook + 验收） | kit-integrity FAIL（缺 5 份）| `51af5b8` |
| 0 | 反目标偷换门禁（N1/N2/N3 + 双向） | drift-guard 双向验证 | `f6c6f43` |
| 0 | 门禁自测 8 条 + 历史错误矩阵 16 条 | selftest 8/8、matrix 16/16 | `3dd591a`→`1502018` |
| 1 | 决策表 84 行（工具名可解析） | tool-decision-table PASS | `47d7f86` |
| 1 | 边界清单 10 条 + 阶段文档 S0–S6 / P0–P10 + playbook 索引 | kit-integrity 8/8 PASS | `e029c30` |
| 1 | 宪法 v1.0.0 + 执行者比对 + 安装文档 + 新 playbook | selftest 8/8、matrix 16/16 | `70f6504` |
| 2 | 边界结构校验阶段 + 抽样脚本 + 未见板剧本 | capability-boundary PASS、sample 5/5、selftest 10/10 | `bc4efda` |
| 2 | 执行者无关性章节 + 复跑章节 + README 导航 + delivery 多命名 + 证据格式 | delivery 三态实测（齐备/缺项/零字节）、selftest 13 条 | 本轮 |

## 当前状态（以门禁为准）

| 阶段 | 状态 |
|---|---|
| kit-integrity | PASS（9 份必需文档）|
| tool-decision-table | PASS（84 行）|
| capability-boundary | PASS（10 条）|
| positive-goal | PASS |
| negative-drift | BLOCKED（需要运行日志）|
| environment / schematic-gates / pcb-* / delivery / no-oneoff-scripts | BLOCKED（无工程/无窗口/无日志）|

**结论**：产品骨架与自证体系已成型；**尚未在任何真板上端到端跑通**（P4 未开始，缺未见板题目）。
| 2 | 扩展口径对账（169 动作 / 27 命令组为权威）+ 全量回归 | selftest 13/13、matrix 16/16、sample 5/5、run 4 PASS 0 FAIL | 本轮 |
| 3 | `.eext` 打包要求核实到官方文档 + 本地打包校验器（三态实测）| kit-integrity 10/10、selftest 15/15、capability-boundary 11 条 | 本轮 |
| 3 | 交付链路打通（类型化动作面）+ 交付按证据判定 | Gerber 74,863 B zip（钻孔在包内）、坐标 13,358 B CSV；BOM 动作返回 no file（GAP-012）| 本轮 |
| 3 | **交付阶段首次在真板 PASS**（四类齐备）| Gerber 74,863 B + 坐标 13,358 B + BOM 8,378 B；钻孔在 Gerber 包内；`delivery` PASS | 本轮 |
| 4 | 采用上游 Design IR + Gate-1 校验器（MIT），新增 `design-ir` 阶段 | design-ir 正例 PASS / 反例 FAIL；selftest 19/19；全量 6 PASS 0 FAIL | 本轮 |
| 5 | 开源板成为正式验收用例（含哈希/许可/下载命令）+ 上游知识按引用映射 | kit-integrity 11/11、用例可识别 | 本轮 |
| 5 | `export-delivery.ps1`：一条命令完成三类导出并生成证据；用例与上游映射落盘 | delivery PASS（74,869/13,358/8,379 B）；selftest 19/19；全量 7 PASS 0 FAIL | 本轮 |
| 6 | 修 `sch drc` 未传 `--json` 的判据缺陷；用运行日志解掉 2 个 BLOCKED | **12 PASS / 1 FAIL / 0 BLOCKED**；仅剩 pcb-connectivity 37 条 | 本轮 |
| 7 | 逐跳 `route fill` 打通电源三网（VIN/5V/5V_IN）；修 N5 误报判据 | Connection **37→33**，Clearance 18、DFM ERROR 0；selftest 20/20 | 本轮 |
| 8 | 5 个信号网 + USB_DP 两跳落板；记录「删未连过孔会更糟」的教训 | Connection **33→21**（累计 −16），Clearance 18、DFM ERROR 0 | 本轮 |
