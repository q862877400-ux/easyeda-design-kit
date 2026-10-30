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
| 9 | 探明 U0TXD 六种参数组合均不可解；查明 via-stitch 无间距校验 | Connection 21 保持；Clearance 18 保持；结论入边界 GAP-019/020 | 本轮 |
| 10 | 连通性 FAIL 输出改为按网分诊（焊盘/过孔分开）+ 防假绿保险；补 USB_DP 最后一跳 | Connection **21→19**；分诊：GND=9, 3V3=4, 5V_IN=4, U0TXD=2 | 本轮 |
| 11 | 验证「焊盘内散热孔」法：U1_41/U3_1 的 EPAD 各 4 孔接通内层地；单孔超距用精确删除修复 | Connection **19→15**（GND 9→5），DFM ERROR 保持 0 | 本轮 |
| 12 | J2_9 屏蔽地焊盘 16/8 孔径 4 孔成功；U3_4 被 DTR 走线封死（1.3–2.7mil）记录为 GAP-021 | Connection **15→14**，DFM ERROR 保持 0 | 本轮 |
| 13 | 试 D2_5（4.0mil 压焊盘，回滚）与 J2_11（无效但无害，无 ERROR）；确认剩余点皆空间受限 | Connection 14 保持，DFM ERROR 0 保持 | 本轮 |
| 13 | 探明 `net-path` 不覆盖平面（GAP-023）；J2_11 三次尝试均无效，判定内层平面未覆盖（GAP-024）| Connection 14 保持，DFM ERROR 0 保持 | 本轮 |
| 14 | 重跑 power-planes（GND unplaced 4→3）；**推翻**「平面未覆盖」假设（pour-fit 是整板矩形），改记为「铺铜避让隔离」| Connection 14 保持，DFM ERROR 0 保持 | 本轮 |
| 14 | 新手法：`route fill` 把 GND 焊盘连到已接地焊盘（J2.11 33 段接通）；再次验证「删未连过孔会更糟」（14→16，已恢复）| Connection 14 保持，DFM ERROR 0 保持 | 本轮 |
| 15 | 系统化「未连焊盘 → 已接地焊盘」走线：GND 两屏蔽盘 + 3V3 C5.1/C7.1 + 5V_IN C8.1 全部接通 | Connection **14→8**（GND 清零），DFM ERROR 0 | 本轮 |
| 16 | 3V3 清零（U3.4/C7.1 → C5.1 走线）；判定剩余 6 条为两个孤岛（5V_IN D2_5 需过孔无空间、U0TXD 走廊被占）| Connection **8→6**，DFM ERROR 0 | 本轮 |
| 17 | 命令行穷尽验证（D2_5 三组、U0TXD 七组全 incomplete）；converge 出 T055（GUI 授权）/T056（布局风险）| Connection 6 保持；停止条件达成：仅剩需业主决策项 | 本轮 |
| 18 | 把 39→6 的战法沉淀成 `docs/phases/pcb-connectivity-recovery.md`；决策表补 5 行 CLI 命令；判据修：决策表阶段现在认 CLI 命令名（与 P6 同口径）| kit-integrity 12/12、决策表 **92 行**、selftest 21/21 | 本轮 |
| 19 | 补 `SKILL.md`（可装进任意 harness 的入口）+ 新增 `kit-portability` 门禁（禁止文档含本机绝对路径）| kit-integrity 13/13、selftest **23/23** | 本轮 |
| 20 | 自包含实测（复制到临时目录仍 7 PASS/0 FAIL/7 BLOCKED）+ 写 `docs/HANDOVER.md` 交接说明 | kit-integrity 14/14、自测 23/23、矩阵 16/16 | 本轮 |
| 21 | **GUI 接入成功**（bsk 会话 + 扩展菜单无障碍树）；纠正重大文档错误：实装 22 个而非 75 个，PCB Auto Router/FreeRouting 均未装 | 决策表 65/67 行、P6 阶段、索引均改为已装工具；GAP-026 | 本轮 |
