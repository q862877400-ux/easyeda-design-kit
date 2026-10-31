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
| 21 | 新增 `installed-claims` 门禁（决策表里标「首选/已装」的扩展必须在装机清单，否则 FAIL）+ `docs/installed-extensions.json`（22 项权威清单）| 自测 **25/25**，含反例（把 PCB Auto Router 写成首选必 FAIL）| 本轮 |
| 22 | GUI 进扩展广场（ext.lceda.cn 实测可达）：确认 PCB Auto Router v1.48.7 在列并下载 .eext（288 KB）；查明它**依赖单独主程序**（127.0.0.1）；发现扩展菜单懒渲染 → 「22 个已装」降级为某次读取结果 | GAP-027/028；装机清单加 caveat | 本轮 |
| 23 | 装 PCB Auto Router 主程序（v1.4807，`/S` 静默）；发现其**自带无头 CLI**；DSN 导出成功（131 KB，keepout 2 处）；被免费额度挡住（游客 2 层），查明**注册会员免费档 100 网/600 焊盘/4 层足够**，只差登录 | GAP-029；决策表 93 行；自测 26/26；新增 `docs/external-tools.json` | 本轮 |
| 24 | **登录后用 PCB Auto Router 无头 CLI 打通 DSN→SES**：335/335 连通，Connection **6→0**；查明导入前必须先 `rip-up`（否则叠铜 182 条）；剩 3 条 5.4–5.8mil 微差；发现 `pcb drc` 与 `pcb check` 读数不一致 | DFM ERROR 3；GAP-030 | 本轮 |
| 25 | 最后 3 条微差用「过孔 24→20mil 原位缩小」清零 | **验收 15 PASS / 0 FAIL / 0 BLOCKED —— 全绿** | 本轮 |
| 26 | 新增 `decision-actionability` 门禁（SC-005）；两次执行比对（SC-006）；建立 `docs/sc-evidence.md` 台账 | 首跑 77/94=81.9% FAIL → 改写后 **93/94=98.9% PASS**；验收 **16 PASS / 0 FAIL / 0 BLOCKED**；自测 28/28 | 本轮 |
| 27 | T048：GUI 实测扩展 `PCB 交付 → 一键导出` —— **网页版必然失败**（`非客户端环境无法调用本接口`，saveFileToFileSystem 仅桌面客户端可用）；对话框能力已记录 | GAP-031；决策表 95 行；可执行 94/95 | 本轮 |
| 28 | T052 查明受阻（无 import 动作/命令；网页版导入需原生文件框，工具无 file-input）；新增「接外部板」流程文档 + GAP-032/033；任务收敛出 T295–T298 | kit-integrity 15/15、决策表 97 行 | 本轮 |
| 29 | SC-004 方法学落地：写清「不同 harness ≠ 不同模型」的口径，并向全新会话子 agent 派发复跑（零上下文）；新增 `docs/executor-crosscheck.md` 并纳入必需清单 | kit-integrity 16/16；结果栏待子 agent 回报后填写 | 本轮 |
| 30 | 新会话复跑暴露并修复 **delivery 两个缺陷**：①缺目录误判 FAIL→改 BLOCKED；②缺件记账 bug 导致**任何缺件都 PASS（假绿）**；自测 28→30 | 验收 16 PASS / 0 FAIL / 0 BLOCKED；自测 **30/30**；矩阵 16/16 | 本轮 |
| 31 | 运行 C（第二新会话，同参数）回报：**16 PASS / 0 FAIL / 0 BLOCKED，退出码 0，与运行 A 逐阶段 0 处不同** | SC-004 **harness 维度已验证**（模型维度仍缺）；验收 16/0/0 | 本轮 |
| 32 | 探路「纯 typed 建板」：project.create + block-apply 成功落 2 件并网表一致；但 clusters --strict 判重叠、destagger 假进展 | GAP-034/035；未见板构建 **进行中**（未完成，未计入 SC-001） | 本轮 |
| 33 | 纯 typed 建板打通到 PCB：新工程 + block-apply + 布局收敛 + 图签 + import-changes（PCB 2 件，imported/verified 均 true）；记录「假失败定律」实测 3 例与 3 处可用性硬约束 | GAP-036/037；sch check 0 悬空、clusters 0 重叠 | 本轮 |
| 34 | **SC-001 第 1 块全绿**：`sc001-led-typed` 纯 typed 生成（建工程→落块→收敛布局→图签→import-changes→板框→布线→交付），验收 **16/0/0**；同时修 `pcb-dfm` 对零违规输出形态的误判 | 自测 33/33；GAP-038 记录判据修复 | 本轮 |
| 35 | **SC-001 第 2 块全绿**：AMS1117 LDO 板（4 件/3 网），typed 生成 + PCB Auto Router 全自动布线 7/7（116ms）| 验收 **16/0/0**；SC-001 **2/2** | 本轮 |
| 36 | 修两个审计判据缺陷：日志必须匹配工程（GAP-039）、一次性脚本只认脚本文件而非 `.work` 中间件（GAP-040）；两块自造板各补本工程运行日志后复跑 | 两板均 **16/0/0**；自测 **36/36**；零上下文复跑板 #2 亦 16/0/0 | 本轮 |
| 37 | 把已跑通的纯 typed 建板管线固化成 `playbooks/typed-board-build.playbook.json`（12 步、全部可 CLI 重放）；SC-006 在新板上复验；原始板回归 | 三块板验收均 **16/0/0**；SC-006 两次 16 阶段 0 差异；自测 36/36 | 本轮 |
| 38 | 鲁棒性对照：USB-C 六件块实测放不进 A4（`block-apply` 正确拒绝并给 919×672 vs 456×615 的实测），自动下载四件块 6 网对齐但留 3 处微重叠；`destagger` 再证不收敛 | GAP-041；两块既有板仍 16/0/0 | 本轮 |
| 39 | 量化 A4 硬约束：可用 1170×627（图签 hard keepout 468×198），六件块 919×672 差 45mil；4 种排布全被拒绝；确认无改纸张 API | GAP-042；既有三块板 16/0/0 未变 | 本轮 |
| 40 | 查明"放不下"判定**按页缓存**（clear 无效、换页重置）；六件块在新页可落但 4 组纵向越界（限 813，实测到 1352）；改原点被拒 | GAP-043/044；既有三块板 16/0/0 未变 | 本轮 |
| 41 | SC-001 第 3 块（P-MOS 高侧开关）全绿：6 件/7 网、`--spacing 220 --per-row 3` 下 0 重叠、15/15 布通、DFM 0；更正"六件块放不进 A4"的旧结论 | 三块板均 **16/0/0**；SC-001 = 3/3；GAP-045 记录反例 | 本轮 |
| 42 | 回测 USB-C 六件块：`220/3` 能进 A4（0 出图框，仅 2 处小重叠），`260/3` 网表对齐但右沿超 12mil；发现"放不下"判定非单调（240/250 拒、220/260 收） | GAP-046；三块板仍 16/0/0 | 本轮 |
| 43 | USB-C 六件块实测存在三方权衡：220/3 进框但网表不对齐；245–260/3 网表对齐但超宽 14–58mil；解组+整页重排会扯脱 26 支 marker（破连通性，已列负结果） | 三块板仍 16/0/0；GAP-047 记录 8 组参数矩阵 | 本轮 |
| 44 | 同一轮内四块板顺序回归（练习板 + LED + LDO + P-MOS），并修正 SC-006 里的过期阶段数（15→16） | 四板均 **16/0/0**；证据文档数字与门禁一致 | 本轮 |
| 45 | SC-001 第 4 块（ESP32 自动下载电路）全绿：模板重叠用「挪件+重连」消掉，6/6 布通、DFM 0；记录两个新坑（connect 方向 = 引脚外朝；export-dsn 假称无网络） | 四块板均 **16/0/0**；SC-001 = 4/4 | 本轮 |
| 46 | SC-001 第 5 块（USB-C 输入前端）全绿：220/3 进框 + 补 A6 网 + 挪 ESD + 桩长错开 + NC 标 SBU；29/29 布通、DFM 0；GAP-047 结案，记 3 个新坑 | 五块板均 **16/0/0**；SC-001 = 5/5 | 本轮 |
| 47 | 把大块配方固化成 `big-block-fit` playbook（14 步）；五块板同一次顺序回归全绿 | 4 个 playbook（+README）/37 步全解析；五板均 **16/0/0** | 本轮 |
| 48 | 决策表补 10 条本会话学到的可执行结论（大块适配/缓存重置/对账/悬空揭穿/NC 语法/重连方向/多页污染/DSN 假错） | 决策表 **107 行全解析**、可执行率 **99.1%**；五板仍 16/0/0 | 本轮 |
| 49 | 修 M12 测试缺陷：`DecisionBaseline` 硬编码 99，表长到 107 后 M12 假通过（矩阵 16/16→15/16）；改为按当前表行数动态取基线 | 矩阵回 **16/16**、自测 **36/36**；反例（基线调 200）确认门禁仍能抓缩水 | 本轮 |
| 50 | 改测试后的完整复验：三件套 + 五板顺序回归 + 反例（基线调 200 应触发 N8） | 自测 36/36、矩阵 16/16、静态 7/0/9 BLOCKED、五板均 16/0/0 | 本轮 |

| 51 | 自查：数字对账（阶段 16/边界 49/决策表 107/playbook **4 个** 37 步/case 7 个）；修我此前"5 个 playbook"的措辞错误；门禁消息加标签消除歧义；给未跑过的外部板用例标注「未验证」 | 静态门禁仍 8 PASS / 0 FAIL / 8 BLOCKED；自测 36/36；矩阵 16/16 | 本轮 |
| 52 | 外部审计整改：修 6 类真缺陷（钻孔自证/前缀豁免/回退判据/status 死代码/自测假 36/可移植性漏检）；新增 `pcb-drc-clean` 阶段暴露真相——所有板 DRC 均非 0（练习板 27 条、USB-C 3 条）| 阶段 16→**17**；练习板与 USB-C 板实测 **16 PASS / 1 FAIL**；SC-A 标为未达成 | 本轮 |
| 53 | T318 首次尝试清 DRC：同步网表 + 改原理图桩长均**无效**（3 条违规原样）；查明两条间距属 PCB 走线几何、Netlist Error 是真差异 | 无进展但结论明确（GAP-052）；自测 36/36、矩阵 16/16 | 本轮 |
