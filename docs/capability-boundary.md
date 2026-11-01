# 能力边界

**用途**：明确写出「这件事做不到 / 达不到理想」，附实测证据与替代路径，让执行者不必在失败里反复试。

**填表纪律**

- `triedTools` **必须**至少写 1 个真实工具名——没试过现有工具就断言"做不到"是无效应答。
- `evidence` 必须可核对：命令、数字、坐标、文件名。
- `status`：`open`（仍受限）/ `accepted`（接受次优）/ `resolved`（已获解决且有证据）。

---

## GAP-001 单层零过孔求解器解不了必须换层的跳

- **capability**：`pcb route solve` 在 `layers` 只有一项时，只搜单层、不产生过孔。
- **evidence**：ESP32-S3 板上 `Q2_B`（Q2.1↔R8.2）在 step 10/15/20、任何 `maxDetour` 下均返回
  `grid-limit`；同样请求加 `"layers":[1,2]` 后 `pass`，1904 mil / 4 过孔。
- **triedTools**：`pcb route solve`、`PCB Auto Router`、`FreeRouting`
- **alternative**：请求里给两个层号（双层内核 + 过孔）；或改用扩展 `PCB Auto Router` 全板布。
- **status**：`resolved`（双层内核已接线并实测落板）

---

## GAP-002 过孔判据必须按焊盘的渲染包络算，而非理想化形状

- **capability**：形状元组算出的间隙与 DRC 看到的不一致。
- **evidence**：某过孔在 (1650.5, 1414.8)，形状判据判为合法；改用 W/H 矩形包络算出 16.16 mil，
  低于 12+6=18 mil；DFM 报 4.2 mil（=16.16−12，过孔半径）。同一判据改字符串后搜索自动换到
  (1650.5, 1404.8)，间隙 25.14 mil。
- **triedTools**：`pcb drc`、`pcb check`（DFM）、`pcb route solve`
- **alternative**：过孔合法性按 `W/H` 矩形包络判定；最终路径再过一次判据（命令已内置收尾复检）。
- **status**：`resolved`

---

## GAP-003 `rip-up --net` 语义过粗，会删掉该网原有合法铜

- **capability**：没有"按网撤销但我只想去掉刚画的那段"的细粒度撤销。
- **evidence**：第 46 轮用 `pcb rip-up --net VIN/5V/3V3` 撤销刚落的路径，VIN 未连从 2 条变 **10** 条、
  3V3 从 4 变 **12** 条，Connection 21→31。
- **triedTools**：`pcb rip-up`、`pcb track-delete`、`pcb via-delete`
- **alternative**：撤销只删"这一次落的具体图元"——`pcb track-delete --ids` / `pcb via-delete --ids`；
  门禁 N4 会在日志里抓 `rip-up --net`。
- **status**：`accepted`（工具行为不改，改用精确删除并加门禁）

---

## GAP-004 整板 beautify 一次调用会超时

- **capability**：`pcb beautify` 对整板一次性调用不可靠。
- **evidence**：整板调用返回 `DISPATCH_FAILED: connector did not respond; context deadline exceeded`，
  并留下部分修改（130→134 走线、clearance 21→24），无回滚。
- **triedTools**：`熔化/优化/美化PCB`、`pcb beautify`
- **alternative**：按 `--net` 分批（实测 16/16 批成功，单批 0.1–11.9 s）。注意：beautify **不会**清
  `acute`/`nonOrtho`，别指望它修转角。
- **status**：`accepted`

---

## GAP-005 清除丝印属性文本需要显式 ids

- **capability**：`pcb silk.set` 没有 `--key` 过滤，不能按"属性文本"批量选。
- **evidence**：清属性丝印必须先从 `pcb check --json` 的 `silk-over-pad` 发现项里取 `primitives` ids，
  再用 `pcb silk-set --ids`；一次清 12 条。
- **triedTools**：`pcb silk-set`、`生成丝印`、`pcb check`
- **alternative**：按 ids 清；或改用扩展 `生成丝印` 从源头规范丝印。
- **status**：`accepted`

---

## GAP-006 没有 `silk-list` 这类 CLI 查询命令（**已更正：能力以类型化动作存在，见 GAP-065**）

- **capability**：CLI 侧缺丝印对象列表命令。
- **evidence**：`easyeda pcb --help` 无 `silk-list`；类型化动作里存在 `pcb.silk.list`。
- **triedTools**：`pcb.silk.list`、`pcb check`
- **alternative**：用类型化动作 `pcb.silk.list`；或 `pcb check --json` 间接取。
- **status**：`open`（需要时再补命令）

---

## GAP-007 Gerber 导出在旧栈缺失

- **capability**：早期连接器只实现 3 个制造导出方法（BOM/DSN/ExportDocument），无 Gerber。
  `eda.pcb_ManufactureData.*` 有 29 个方法，未逐个接线。
- **evidence**：`specs/003-pcb-design-authoring/spec.md` 记录的调研表：`getGerberFile` 未实现。
- **triedTools**：`PCB Delivery Export`、`多板生产文件一键导出`、`pcb drc`
- **alternative**：交付改用扩展 `PCB Delivery Export`（Gerber+BOM+CPL 一键），不走自研导出。
- **status**：`resolved`（走扩展）；如有缺口，按 E4 记录新条目

---

## GAP-008 电源/地未连多数卡在缝合过孔位不足

- **capability**：`power-planes` 在密集区找不到干净打孔位时会报 `unplaced`。
- **evidence**：某轮 `power-planes` 报 GND `unplaced 4`、3V3 `unplaced 2`；同时 DRC 里 GND 9 条、
  3V3 4 条未连。
- **triedTools**：`pcb power-planes`、`电源地就近打孔`、`pcb via-stitch`
- **alternative**：先改布局把它们挪出密集区（`PCB自动化工具` 重排），或用 `电源地就近打孔` 定点补；
  纯靠加孔会推高 `coupling`。
- **status**：`open`

---

## GAP-009 DRC 读数会被陈旧铺铜污染

- **capability**：新画铜（尤其新过孔）不会自动生成反弹片，DRC 会报假间隙。
- **evidence**：双层路径落板后 Clearance 18→26，`pour-rebuild` 后恢复 18；不是几何问题。
- **triedTools**：`pcb pour-rebuild`、`pcb.rebuildPour`、`自动生成铜皮`
- **alternative**：任何落铜之后**必须** `pour-rebuild` 再读 DRC；门禁 N6 同时要求 `save → doc reload → drc`。
- **status**：`resolved`

---

## GAP-010 自建检查器不得作为通过依据

- **capability**：自写 DFM/检查器会与自己一致，形成自我确认。
- **evidence**：曾自建 98KB `pcb_check.go` 当 DFM，并用它给自己开绿灯；扩展中心已有「嘉立创下单检查」（18 项）。
- **triedTools**：`嘉立创下单检查`、`设计规则生成器`、`pcb check`
- **alternative**：DFM 权威口径一律用 `嘉立创下单检查`；自建检查器只做早期诊断，且 kit 内禁止实现（门禁 N3/P3）。
- **status**：`resolved`

---

## 本文件怎么维护

1. 遇到"以为能做到但其实做不到"的事 → 加一条；
2. `triedTools` 至少 1 个真实工具名，否则该条无效；
3. 解决后改 `status: resolved` 并附证据；
4. 条目数只增不减（与决策表同源纪律）。

---

## GAP-011 扩展形态无法携带 CLI 依赖

- **capability**：把 Kit 完整能力（169 动作、193 命令、playbook、验收脚本）打包成 `.eext` 扩展。
- **evidence**：`.eext` 是标准 ZIP，只含 `extension.json` + 编译后的入口 bundle + 图标 + 文档
  （官方要求见 `docs/publish-extension.md`）。扩展运行在 EasyEDA Pro 内，**无法携带或调用
  `easyeda.exe`**，因此 `acceptance/*.ps1` 与 playbook 在扩展内不可运行。
- **triedTools**：`EDA Agent Connector`、`PCB Delivery Export`、`eda.pcb_Document`
- **alternative**：扩展形态定位为「入门 + 随身手册」（内置决策表与阶段文档、调用 `eda.*` 做单点动作）；
  完整能力走 CLI 形态安装。两种形态共用同一套文档（`docs/harness-install.md` 已写清）。
- **status**：`accepted`

---

## GAP-012 类型化动作 `schematic.export.bom` 返回 no file

- **capability**：通过动作导出 BOM（xlsx/csv）。
- **evidence**：`easyeda call schematic.export.bom --payload '{"fileType":"xlsx"}'`（未固定文档）返回
  `ok:false`「BOM export returned no file.」；改用 `--doc <原理图页 uuid>` 后 **`ok:true`**，
  产出 `20261031-011335-schematic_bom-e43f4f93.xlsx`（**8,378 B**）。csv 同样成功。
- **triedTools**：`schematic.export.bom`、`PCB Delivery Export`、`多板生产文件一键导出`
- **alternative**：调用时**必须** `--doc <原理图页 uuid>` 固定文档；否则动作找不到 BOM 上下文。
- **status**：`resolved`

---

## GAP-013 导出制品固定落盘到 `.easyeda\artifacts`，`fileName` 不控制路径

- **capability**：让导出直接写到指定交付目录。
- **evidence**：`pcb.export.gerber --payload '{"fileName":"D:/…/board-gerber.zip"}'` 返回
  `result.fileName` 为传入值，但实际 `artifactPath` 为
  `<repo>\.easyeda\artifacts\20261031-010915-pcb_gerber-7af89560.zip`（74,863 B）；
  `pcb.export.pick_place` 同理（13,358 B csv）。
- **triedTools**：`pcb.export.gerber`、`pcb.export.pick_place`、`schematic.export.bom`
- **alternative**：以 `artifactPath` 为准收集文件，再复制到交付目录；验收读
  `delivery-evidence.json`（记录 artifactPath/size/drilling），不靠文件名猜。
- **status**：`accepted`


---

## GAP-014 `sch drc` 不支持部分文档类型（doctype 3）

- **capability**：用 `sch drc` 做原理图门禁。
- **evidence**：`easyeda sch drc --project agent-e2e-esp32s3-board31 --doc b49d862ac5104b22` 返回
  `SCH_DrcUtil: doctype(3) not support check sch drc`（无 JSON）。改用 `sch check` 可给出
  `0 reported violation(s) — 0 fatal, 0 error, 0 warn, 0 info`。
- **triedTools**：`sch drc`、`sch check`、`schematic.runDrc`
- **alternative**：验收的 `schematic-gates` 阶段在检测到 `not support` 时回退 `sch check`；
  两者都不可用时报 `BLOCKED`（不报 PASS）。
- **status**：`accepted`

---

## GAP-015 CLI 会把「artifact saved」提示异步打进 stdout，污染 JSON

- **capability**：直接解析 CLI 的 JSON 输出。
- **evidence**：`easyeda call pcb.export.gerber ...` 的输出里，`📎 artifact saved: <path>` 一行
  会**夹在 JSON 的 `{` 与 `"id"` 之间**，导致 `ConvertFrom-Json` 报
  `Invalid property identifier character`。同一命令有时正常（提示走 stderr），呈竞态。
- **triedTools**：`pcb.export.gerber`、`pcb.export.pick_place`、`schematic.export.bom`
- **alternative**：解析前过滤含 `artifact saved:` 的行（`acceptance/run.ps1` 与
  `acceptance/export-delivery.ps1` 均已实现），并设 `[Console]::OutputEncoding = UTF8`。
- **status**：`accepted`

---

## GAP-016 导出动作按「当前活动文档」判定，PCB 导出也必须 `--doc`

- **capability**：不指定文档就导出 Gerber/坐标。
- **evidence**：先切到原理图导 BOM，再调 `pcb.export.gerber`（不带 `--doc`）→
  `Gerber export returned no file — the PCB may be empty or have no copper`；
  补 `--doc <pcb uuid>` 后正常（74,869 B）。
- **triedTools**：`pcb.export.gerber`、`pcb.export.pick_place`
- **alternative**：所有导出动作都固定 `--doc`：Gerber/坐标用 PCB uuid，BOM 用原理图 uuid。
  `acceptance/export-delivery.ps1` 已把 `-Doc`/`-SchDoc` 设为必填。
- **status**：`resolved`

---

## GAP-017 `route-short` 对长跳与电源网无效，Connection 不降

- **capability**：用 `pcb route-short` 一次性把剩余未连网络降到 0。
- **evidence**：`pcb route-short --corner 45 --max-len 3000` 在 Connection=37 的板上跑完后，
  `pcb drc` 仍报 **Connection Error (37)**，Clearance 18 未变；说明它既没连上这些跳，也没制造新问题。
  原因：这些跳多为电源/地（GND 9、3V3 4、5V_IN 4、VIN 2、5V 2）或长距离信号，超出其阈值。
- **triedTools**：`pcb route-short`、`PCB自动化工具`、`PCB Auto Router`
- **alternative**：逐跳用 `pcb route fill`（内部自带取快照，`layers:[1,2]`）。
  **实测有效**：VIN（27 段，1378 mil）、5V（40 段 + 2 孔，1679 mil）、5V_IN（10 段 + 2 孔，452 mil）
  三跳落板后 Connection **37 → 33**，Clearance 保持 18、DFM ERROR 保持 0。
  电源/地仍优先靠 `pcb power-planes` 与铺铜承担；`power-planes` 报 `GND: 4 pads / 3V3: 2 pads
  had no clearance-clean via spot`，说明剩余多为**布局挤死**（GAP-008），不是布线能解。
- **status**：`open`


---

## GAP-018 DRC 标的「未连过孔」不等于孤儿，删掉会更糟

- **capability**：把 DRC 列为 Connection Error 的过孔当垃圾清掉。
- **evidence**：对 4 个该类过孔执行 `pcb via-delete --ids`（GND/3V3/5V_IN×2）后，
  Connection **33 → 38**（+5），Clearance 不变。按原坐标用 `pcb via` 重建后，**恢复为 33**。
  **第二次独立验证（第 14 轮）**：删掉 (1040,1530) 与 (1470,1394.4) 两个被判「未连」的过孔后，
  Connection **14 → 16**；按原坐标 `pcb via` 重建（16/8 与 24/12 孔径）后恢复到 **14**。
  规律稳定：**DRC 的「未连」过孔一律不要删**。
  结论：DRC 的「未连」表示"未接入全网"，这些过孔仍在承载层间连接。
- **triedTools**：`pcb via-delete`、`pcb via`、`pcb drc`
- **alternative**：清理前必须先确认该图元是否真的孤立（看 `pcb via-list` 两端是否无铜）；
  否则不要删。撤销用原坐标 `pcb via --x --y --net` 重建（实测可恢复）。
- **status**：`accepted`

---

## GAP-019 U0TXD（U1.37 ↔ U3.3）在多种参数下均不可解

- **capability**：把 U0TXD 这一跳连通。
- **evidence**：`pcb route fill --net U0TXD --from U1.37 --to U3.3 --layers 1,2 --width 10`
  在 **step 20 / detour 1500**、**step 15 / detour 2000**、**step 25 / detour 2500** 三组参数下
  全部返回 `status=incomplete`（`segs` 空）。同板另 6 条信号跳（IO0/LED_GPIO/Q2_B/RTS/U0RXD/USB_DP）
  同参数下均 `found`，因此不是工具坏了，而是这跳被硬阻。
- **triedTools**：`pcb route fill`、`pcb route solve`、`PCB Auto Router`
- **alternative**：绕行需从更远处走（U1.36/U1.37 相邻，U0RXD 已占用邻近通道）；可先连 U0RXD 的另一侧
  通道，或调整 U1 与 U3 之间器件的位置腾出走廊。**未验证**：`PCB Auto Router` 扩展能否自动解。
- **status**：`open`

---

## GAP-020 `pcb via-stitch` 不做间距校验，盲铺可能产生 Clearance Error

- **capability**：用 `via-stitch` 一键补缝合孔而不用担心间距。
- **evidence**：`--help` 只有几何参数（`--rect` / `--pitch` / `--margin` / `--diameter` / `--hole`），
  无任何"跳过与既有铜冲突点"的开关；`--dry-run` 只输出网格坐标（实测 16 点，全部按 pitch 均布），
  **不报告与走线/焊盘的冲突**。
- **triedTools**：`pcb via-stitch`、`pcb power-planes`、`电源地就近打孔`
- **alternative**（已实测有效）：**矩形必须落在焊盘铜内**，并以焊盘中心为基准（例：EPAD 中心
  mil (474,619) → `--rect "458,603,492,637" --pitch 30`，落 4 孔）。落完立即
  `pour-rebuild` + `save` + `doc reload` + `pcb drc` 复测。
  **实测**：U1_41 两个 EPAD 各 4 孔后 GND 未连 9→7；U3_1 EPAD 4 孔后 7→5。
  若某个角落孔引入 Clearance（U3_1 的 (1646,1478) 距 U0RXD 仅 5.1mil < 6），
  **只删那一个孔**（`pcb via-delete --ids`），其余保留——实测删后 DFM ERROR 回到 0 且连通性不回退。
- **反例（我自己的错）**：把 `pcb drc` 的**嵌套输出（mm）**坐标当成扁平 `--json`（mil）坐标用，
  把孔打到 (1846,2400) 的空白处，Connection 19→22，被迫回滚。
- **status**：`accepted`


---

## GAP-021 3V3 的 U3_4 焊盘被 DTR 走线封死，无法打散热孔

- **capability**：在 U3_4（3V3，中心 1780.7,1462.7 mil）打散热孔接到内层 3V3。
- **evidence**：`pcb via-stitch --net 3V3 --rect "1765,1447,1796,1478"` 用默认 24/12 孔径时
  **4 孔全部失败**（`placed:0, failed:4`）；改用 16/8 孔径可落 4 孔，但随即产生
  **4 条 Clearance ERROR**：每个孔距 DTR 走线仅 **1.3–2.7 mil**（要求 6 mil），
  坐标 (1765/1795, 1447/1477)。删除这 4 孔后 DFM ERROR 回到 0。
- **triedTools**：`pcb via-stitch`、`pcb via-delete`、`pcb power-planes`
- **alternative**：该点须先改走线（把 DTR 让开）或改布局；仅靠加孔不可行。
  同一轮里 **J2_9**（GND，中心 1025.4,1545.7）用 16/8 孔径 4 孔**成功**：GND 未连 5→4，
  说明方法本身有效，卡的是该点的空间。
- **status**：`open`

---

## GAP-022 5V_IN 的 D2_5 与 GND 的 J2_11 都打不了有效孔

- **capability**：在 D2_5（5V_IN，中心 1740,1360.2）与 J2_11（GND，中心 1025.4,1710.3）打散热孔。
- **evidence**：两者用 16/8 孔径均**成功落 4 孔**（`placed:4, failed:0`），但结果不同：
  - **D2_5**：随即产生 **4 条 Clearance ERROR**——每孔距 D2.6（USB_DP）/D2.4（USB_DM）焊盘仅
    **4.0 mil**（要求 6）；**且连通性无改善**（5V_IN 仍 4）。删孔后 ERROR 回 0。
  - **J2_11**：**无 ERROR**，但**连通性无变化**（GND 仍 4，总数仍 14）——孔落在了已有铜上，
    没改变 DRC 判定。
- **triedTools**：`pcb via-stitch`、`pcb via-delete`、`pcb pour-fit`、`pcb pour-rebuild`
- **alternative**：这两点不值得继续加孔。D2_5 需改走线/布局；J2_11 的未连判定来自别的路径，
  应先查 `pcb net-path <net> <pad>` 弄清它到底缺哪一段铜，再决定动作。**未验证**：net-path 诊断。
- **status**：`open`

---

## GAP-023 `pcb net-path` 不覆盖铺铜/填充/PLANE，对内层供电网会误报 FAIL

- **capability**：用 `net-path` 判断某个电源/地焊盘"到底缺哪段铜"。
- **evidence**：`pcb net-path --net GND --from J2.11 --to J2.9` 输出
  `FAIL: no continuous listed-copper path`，并在 `scope:` 行自陈
  **"copper pours, fills, and PLANE connectivity excluded"**。
  也就是说它只证明"已列出的走线/过孔/焊盘"之间的连续路径；本板 GND/3V3 由**内层平面**供电，
  该命令结构上无法证明——它的 FAIL 对本场景是**预期行为**，不是缺陷证据。
- **triedTools**：`pcb net-path`、`pcb drc`
- **alternative**：内层供电网的连通性只认 `pcb drc` 的 Connection Error；
  若要诊断"为什么没接到平面"，看 `power-planes` 的 `unplaced` 报告与 `pcb via-list` 是否在焊盘内，
  而不是 net-path。
- **status**：`accepted`

---

## GAP-024 焊盘内打过孔仍不连通，原因是铺铜避让隔离（不是平面缺覆盖）（**更正：未试专用工具 `pcb via-bond`，见 GAP-066**）

- **capability**：给 J2_11（GND，中心 1025.4,1710.3）在焊盘内打孔以接入内层地。
- **evidence**：三种尝试均不改善（Connection 保持 14、GND 保持 4）：
  1. `--rect "1010,1695,1041,1726" --pitch 30 --diameter 16 --hole 8` → 落 4 孔，DRC 不变；
  2. 同矩形 `--pitch 20`（仅 1 孔，落点在焊盘内）→ DRC 仍不变；
  3. 上述尝试期间 DFM 始终保持 ERROR 0（没有新违规）。
  同板 J2_9 用同样手法**成功**（GND 5→4），说明差别不在"平面覆盖"，而在该点周围铜的密度。
  **补充实测**：`pcb pour-fit --help` 明确其行为是"pour a net-bound plane sized to the board,
  inset from the edge"——矩形按板框 bbox 生成，所以平面覆盖全板；重跑 `power-planes` 后
  GND `unplaced` 由 4 降到 3，但 Connection 仍 14，进一步否证"扩平面即可"的设想。
- **triedTools**：`pcb via-stitch`、`pcb pour-rebuild`、`pcb net-path`、`pcb power-planes`
- **alternative**：**假设已被推翻**——`pour-fit` 铺的是"整板 bbox 矩形"（`--inset` 只改内缩），
  因此 GND 平面**本来就覆盖全板**，不是"没覆盖到 J2_11"。
  真正原因是该焊盘被**铺铜避让（anti-pad）**与邻网铜隔离：周围没有 thermal spoke 通道。
  可行路径只剩改布局/改走线让开空间，或换到信号层绕行。**未验证**：改布局后的效果。
- **status**：`open`

---

## GAP-025 剩余未连只剩两个"孤岛"，都卡在没有过孔空间

- **capability**：把 Connection Error 从 6 降到 0。
- **evidence**（第 16 轮实测，DRC 扁平输出）：
  - **5V_IN 孤岛**：`Track (1704.2,1354.8)` + `SMD Pad D2_5 (1740,1360.2)` + `Via (1321.9,1479.7)`
    + `Via (1535,1305.6)`。D2_5 是**顶层 SMD 焊盘**，要接入的那簇铜在 **L2**，
    因此必须打孔；但同网走线离它最近的点在 (1705,1365.6)，而该处打孔实测距 D2.4/D2.6 仅 **4.0 mil**
    （要求 6，见 GAP-022），`route fill` 从 D2.5 出发的两次尝试（→J1.1、→C8.1）均 `incomplete`。
  - **U0TXD 孤岛**：`U1_37 (70.5,464.8)` 与 `U3_3 (1730.7,1462.7)`，六种参数组合全部 `incomplete`（GAP-019）。
- **triedTools**：`pcb route fill`、`pcb via-stitch`、`pcb via-hop`、`pcb power-planes`
- **alternative**：两者都需**布局级**改动（挪 D2 或挪 U1/U3 之间的器件腾出过孔位/走廊），
  或改用扩展 `PCB Auto Router` 全板重布。**未验证**：挪动后的收敛性。
- **status**：`open`

---

## GAP-026 「75 个扩展已装」是错的：GUI 实测只有 22 个

- **capability**：按文档"已装扩展"直接选用工具（例如把 `PCB Auto Router` 当作布线首选）。
- **evidence**：打开编辑器「更多/扩展」菜单并取无障碍树快照，实际列出 **22 个**扩展：
  Gerber工具、PartLab元器件管理、AI 指令引擎、嘉立创下单检查、BGA 滤波电容放置、EDA Agent、
  装配图导出、盗铜工具、平衡铜工具、EE Workbench、轮廓工具、🧰 PCB 工具箱、FPC 速成引擎、
  电热膜线路生成器、PCB 交付、API Gateway、批量导出、一键等长、线段等距、**JsPCB自动布线**、
  AI 知识库、导出设计。
  **没有** `PCB Auto Router`、`FreeRouting`、`PCB自动化工具`、`内电层自动分划`、`生成丝印`、
  `焊盘扇出`、`电源地就近打孔`、`设计规则生成器` 等——而它们在索引/决策表/阶段文档里曾被写成"首选"或"已装"。
- **triedTools**：`JsPCB自动布线`（已装，实际可用的自动布线器）、`嘉立创下单检查`、`PCB 交付`
- **alternative**：索引已补「已核实装机清单」（22 个，附件式逐字列举），决策表与 P6 阶段文档已把
  "未装"显式标注，布线首选改为 `JsPCB自动布线` 或命令行 `pcb route fill`。**未验证**：JsPCB 全板重布的效果。
- **status**：`resolved`（文档已纠正）；`JsPCB自动布线` 的实跑效果仍 `open`

---

## GAP-027 扩展广场可装，但 PCB Auto Router 不是"装上就能用"

- **capability**：在编辑器里用 `PCB Auto Router` 一键全板重布。
- **evidence**（2026-10-31 实测，GUI + 官方详情页）：
  1. 扩展广场 **https://ext.lceda.cn/** 可访问（浏览器已有登录态），列表里确有 `PCB Auto Router v1.48.7`
     （发布者 mini-coco / PcbAutoRouter，414 次安装，UUID `6478ce6707ac4293a6c1827ad510f621`，
     适用 EDA 版本 `^3.2.140`）。
  2. 下载得到 `.eext` **288 KB**（`pcb-auto-router_v1.48.7.eext`）。
  3. 官方安装路径：**高级 → 扩展管理器 → 搜索安装 / 导入 .eext**。
  4. **关键限制**（详情页「注意事项」原文）：该插件**不是独立布线器**，"需要先安装主程序"，
     插件通过 **127.0.0.1** 与本机主程序通信；主程序在 **https://www.pcbautorouter.top/** 单独下载，
     且安装后须在扩展管理器里为它开启**外部交互**权限；超出免费额度还需登录/升级 Pro。
- **triedTools**：`bsk_inspect`（读扩展菜单 DOM）、`pcb autoroute`（直接调用未登录引擎）、`daemon health`（确认窗口与连接器）
- **alternative**：本机已装的 `JsPCB自动布线` 是**纯编辑器内**的自动布线器（无外部主程序依赖），
  应作为首选；`PCB Auto Router` 只在愿意装主程序时才用。**未验证**：主程序装好后是否能把 6 条降到 0。
- **status**：`open`（已下载 `.eext`，未导入；未装主程序）

## GAP-028 扩展菜单是懒渲染，读 DOM 得到的"已装清单"不可信

- **capability**：通过读编辑器扩展菜单来确知"本机装了哪些扩展"。
- **evidence**：两次读取同一菜单得到**不同**结果：一次 22 项（含 嘉立创下单检查 / PCB 交付 / JsPCB自动布线），
  一次 14 项（含 狼黑工具 / 规则配置 / 工程文档导出，但**不含**上述三个）。菜单带滚动与懒加载，
  DOM 只反映当前可见区域。**因此第 21 轮写的"22 个已装"不是权威结论，已降级为"某次读取结果"。**
- **triedTools**：`bsk_inspect snapshot/observe`、CLI `actions`（无扩展列表动作）、`easyeda --help`（无扩展命令）
- **alternative**：权威来源只有 **高级 → 扩展管理器 → 已安装** 页；或读本地扩展目录/IndexedDB（**未验证**）。
  决策表判据 `installed-claims` 的清单须来自该页，而不是菜单快照。
- **status**：`open`

---

## GAP-029 PCB Auto Router 主程序：已装 + 免费额度够，但需登录（原生 GUI 无法自动化）

- **capability**：用 `PCB Auto Router` 打通 DSN→SES 自动布线。
- **evidence**（2026-10-31 全程实测）：
  1. **下载**：官网 `https://www.pcbautorouter.top/zh/` 的真实安装包为
     `https://download.pcbautorouter.top/releases/PCBAutoRouter-1.4807-setup.exe`（7.4 MB，**无代码签名**）；
     `.eext` 为 `.../jlceda-plugin-1.48.7.eext`。注意网页按钮会被「迅雷/AIX 下载器」截获，
     直接 `Invoke-WebRequest` 取直链才可靠。
  2. **安装**：`PCBAutoRouter-1.4807-setup.exe /S` → 退出码 0，装到 `C:\Program Files\PCBAutoRouter\`。
  3. **主程序自带无头 CLI**（关键发现，不需要 GUI 也不需要插件）：
     `pcb_autorouter.exe -i <board.dsn> -a -o <board.ses> [--threads 0|4|8|16] [--auto-rules]`
  4. **DSN 导出可行**：`easyeda pcb export-dsn --project <p> --doc <pcb>` → 131.1 KB，
     `keepout` 段落存在（2 处），pins=279。
  5. **免费版额度**：游客 网络50/焊盘200/2层；**注册会员（免费）网络100/焊盘600/4层/板框100mm**；
     专业版 ¥129/月、¥999/年、¥1999 永久。
     本板 21 网 / 279 焊盘 / 4 层 / 70×45mm → **注册会员免费档即可，无需付费**。
  6. **实际报错**：`Error: design exceeds free version limits (pins=279 nets=21 layers=4), please upgrade to Pro`
     —— 因为当时是**未登录游客**（2 层上限）。登录后应落回 4 层档。
- **triedTools**：`pcb_autorouter.exe --help/-a/-u`、`easyeda pcb export-dsn`、官网定价页
- **alternative**：登录有两种，但都需人工一步——
  (a) 打开 GUI（`pcb_autorouter.exe -u`）用邮箱注册/登录；
  (b) 提供账号凭据。
  **本工具的边界**：这是**原生 GLFW 窗口**，不在浏览器自动化范围内，且当前模型不支持读图，
  因此登录动作**无法由我代做**。
  未登录时的替代路径：已装的扩展 `JsPCB自动布线`（编辑器内、无外部依赖、无额度限制）。
- **status**：`open`（已装好主程序；缺一次登录）

---

## GAP-030 PCB Auto Router 实测：335/335 连通达成，但会留 3 条微米级间距误差

- **capability**：用 `PCB Auto Router` 主程序（DSN→SES）一次把整板连通性清零。
- **evidence**（2026-10-31 全流程实测，登录后）：
  1. `pcb_autorouter.exe -i board.dsn -a -o board.ses --threads 8` →
     **`connections: 335/335, unconnected: 0`**，耗时 2.5s；
     导回后 `Connection Error` **6 → 0**（本会话从 39 起算，累计 −39）。
  2. **必须先清空旧铜再导入**：直接 `import-autoroute` 是在原走线上**叠加**一层
     （实测同网 0mil 违规 182 条）；正确顺序是
     `pcb rip-up`（不带 --net = 全部）→ `pcb import-autoroute <ses>` → `pcb pour-rebuild`。
  3. 剩下 **3 条 Clearance**（6mil 规则，实测 5.4 / 5.5 / 5.8mil）：
     - (1735,1403) 5V_IN 走线 vs USB_DM 过孔（2 条）
     - (1675,1396) U0TXD 走线 vs 5V_IN 过孔（1 条）
     把 DSN 每层 `(clearance 5)` 提到 6.5 甚至 8 后**三条数值一模一样**，说明这是布线器
     **对"过孔↔异网走线"不检查**的固定产物，不是规则没给够。
  4. **`pcb drc --json` 与 `pcb check` 读数不一致**：同一时刻前者报 `Clearance Error 0`，
     后者 `ERROR=3 clearance=3`。门禁以 `pcb check` 为准（`pcb-dfm` 阶段）。
- **triedTools**：`pcb_autorouter.exe -a`、`pcb export-dsn`、`pcb import-autoroute`、`pcb rip-up`、
  `pcb check`、`pcb drc`
- **alternative**：这 3 条需**局部微调**（挪过孔 3mil 或删除该段重走）；或用
  `pcb drc-rules-set` 提高该类间距让布线器重跑（**未验证**）。
- **status**：`open`（连通性已达标；间距差 3 条）

---

## GAP-031 扩展 `PCB 交付` 的导出只能在桌面客户端跑，网页版会失败

- **capability**：在**网页版**编辑器里用扩展 `PCB 交付 → 一键导出` 直接产出 Gerber/BOM/CPL 到本地目录。
- **evidence**（2026-10-31 GUI 实测，完整可复现）：
  1. 菜单路径：顶部「更多」→ `PCB 交付` → `一键导出`，弹出真实对话框
     「PCB Delivery Export — 导出设置」。
  2. 对话框内容（可用于判断能力边界）：**必选** Gerber · BOM · CPL；
     可选 原理图 PDF / STEP 3D / 交互式 BOM(HTML) / 工程源 V3(.epro2) / V2(.epro) / 导出前跑 DRC；
     制造要求（板厚 1.6、阻焊、字符 White、表面处理、阻抗控制）；输出目录可填或「浏览」。
  3. 填 `…\.work\gui-delivery` 后点「开始导出 / Export」→ 失败，原文：
     `ExportStepError: 无法写入输出目录：…\gui-delivery`
     `最后一次尝试的目录：…\gui-delivery\Board1_20261031`
     `原始信息：Error: 错误：非客户端环境无法调用本接口！`
     `at g_.saveFileToFileSystem (https://modules.lceda.cn/pro-api/0.3.53.…/api.js)`
  4. 先手动建好该目录后重试，同样失败——**不是权限/路径问题**，是 API 在网页环境不可用。
- **triedTools**：扩展 `PCB 交付`（GUI）、`pcb.export.gerber`（类型化动作）、CLI `pcb.export.gerber` / `pcb.export.pick_place` /
  `schematic.export.bom`（**这三条 CLI 路径可用**，实测 74,869 B / 13,358 B / 8,379 B）
- **alternative**：网页版走 CLI 类型化动作 + `acceptance/export-delivery.ps1`；
  需要扩展的富交付（STEP/交互 BOM/工程源）时，改用 **EasyEDA 桌面客户端**打开同一工程再导出。
- **status**：`resolved`（结论明确：网页版不可用，路径已给出）

---

## GAP-032 网页版无法自动化导入 `.epro2`：缺 file-input 能力，连接器也无 import 动作

- **capability**：把本机 `.epro2` 工程文件导入 EasyEDA 网页版，作为「未见板」素材。
- **evidence**（2026-10-31 实测）：
  1. 动作目录里与工程相关的只有 `project.create`（**只建空容器**，原文："This creates only the project
     container — create schematic/Board/PCB documents separately"）、`project.open`（按 uuid 打开已存在的）、
     `project.export_source`（导出）、`project.find`。**没有任何 import/upload 动作**。
  2. CLI `easyeda project` 的子命令同样只有 create / doc / export / export-source / find / info / open。
  3. 网页版的导入入口是原生**文件选择框**，而当前自动化工具（bsk_*）提供 click / hover / wheel /
     scroll-to / focus / blur / fill / select / press，**没有设置 file input 的能力**
     （chrome-devtools MCP 的 upload_file 在本机不可用：它指向不存在的 Edge 路径）。
- **triedTools**：`project.create`、`project.open`、`easyeda project --help`、`easyeda actions`、bsk GUI
- **alternative**：① **人工一次性导入**（点一次文件框，成本最低）；② 用 `project.create` 建空容器 +
  逐页 API 重建（**未验证**，且对开源板等于重新画一遍）；③ 改用 **EasyEDA 桌面客户端**（其 API 可用，
  但本机未装）。
- **status**：`open`（拦在工具能力，不是判断；需要人工一步或补 file-input 能力）

---

## GAP-033 外部板自带违规时，验收会「如实 FAIL」——这不是套件失败

- **capability**：拿别人的开源板跑我们的验收，并解释结果。
- **evidence**：本会话全部判据都是**绝对阈值**（Connection Error=0、DFM ERROR=0、交付三件非空），
  不含"相对改善"口径。因此一块**本来就带违规**的外部板，跑完验收必定 FAIL，即使套件工作完全正常。
- **triedTools**：`pcb layout-lint`、`pcb drc`、`pcb check`（2026-11-01 已在导入的 `ESP32S3_USB` 上实跑记基线：45 器件 / 29 网 / ratsnest 9816 mil / DRC 1 条 / DFM 215 条）
- **alternative**：接外部板时必须**先记基线**（`pcb drc` / `pcb check` 的原始计数），把"基线"与"本次改动后"
  分开报告；套件只对**本次需求相关的项**负责。已在 `docs/playbook-unseen-external-board.md` 写成流程。
- **status**：`accepted`（口径已固化）

---

## GAP-034 纯 typed 建板：块能落、能连线，但默认模板布局过不了 clusters 门禁，且 destagger 是「假进展」

- **capability**：不用 GUI，用 `project.create` + `sch block-apply` 从内嵌电路块库生成一块新板（SC-001 的"未见板"素材）。
- **evidence**（2026-10-31 全程实测）：
  1. `easyeda blocks ls --ready` → **19 个 ready 块**（LDO/buck/USB-C/RS485/microSD/LED 等）。
  2. `easyeda project create --name sc001-led-blk --open` → uuid `337b5613358540d69ee8efdb4d24a5df`，
     自带 `Schematic1/P1`（page `8124aea12d407530`）。
  3. `sch block-apply block.led_indicator_gpio --at 200,450` **成功**：落 2 件（R1@200,450 / LED1@320,450）、
     自动连线 4 条、`reconcile ✓ 3 net(s) match the live netlist`。
  4. **但 `sch clusters --strict` 判 FAIL**：`R1 ↔ LED1 重叠 38×11`
     （R1 体积 x=[64,330]，LED1 x=[260,450]——两组的 netport marker/桩线互压）。
  5. **`sch destagger --apply` 连跑 3 轮**：每轮自报"已搬迁 N 个 marker"，
     但 `clusters` 读到的几何**三次完全相同**（R1 x=[64,330] / LED1 x=[260,450]）；
     工具自身 verdict 也写"未收敛：还剩 2 处 marker 重叠"。→ **报告的进展与测量到的几何不一致**。
- **triedTools**：`blocks ls/show`、`project create`、`sch block-apply`（dry-run + live）、`sch destagger`、
  `sch clusters --strict`
- **alternative**：需先把两件拉开（block 模板间距 120mil，而 marker 伸出约 110mil）：
  ①`sch group-move --ids <primitiveId…>` 平移整组；②或换 `sch autolayout --spec` 按模块布局；
  ③或把块落到更大的纸面/多页。**未验证**：以上任一能否让 clusters 归零。
- **status**：`open`

---

## GAP-035 `sch group-move --ids` 只认 primitiveId，传位号会 ok:false（**已更正：designator→id 可从 `pcb.components.list` / `schematic.designators.list` 取，见 GAP-065**）

- **capability**：把「器件 + 它的桩线/旗标」整体平移，腾出空间解决布局重叠。
- **evidence**：`sch group-move --ids LED1 --dx 200 --dy 0` → `ok:false`，返回体带
  `degraded: {consecutiveFailures:1, degraded:true}` 提示；`--help` 写明 `--ids <primitiveId,...>`
  与 `--group g1`（持久组，自动展开成员+桩+旗）。用位号不是合法输入。
- **triedTools**：`sch group-move`、`sch list`（本轮 `--json` 未取到可解析的 components 数组）
- **alternative**：先建持久组（`sch group create`）再用 `--group`；或从 `sch list --include-*` 的
  完整输出里取 primitiveId。**未验证**。
- **status**：`open`

---

## GAP-036 写操作返回 ok:false 但**实际已落地**——必须以只读复核为准（实测三次）

- **capability**：判断 `sch disconnect / modify / connect` 这类写操作到底成没成。
- **evidence**（2026-10-31，sc001-led-blk 实测）：
  1. `sch disconnect --pin LED1:+`、`--pin LED1:-` 均回 **not-ok**，
     但随后 `sch check` 显示两脚变悬空 → **断开确实生效了**。
  2. `sch modify --id 076db22e194dbb7a --x 560` 回 `"ok": false`，
     但 `save + reload` 后重读 LED1 坐标 = **560** → **移动确实生效了**。
  3. `sch connect --pin LED1:2 …` 当时无任何输出，随后 `sch check` 的
     `floating pin(s)` 由 1 归 0 → **连接确实生效了**。
  工具自身也提示过 "connector looks DEGRADED under load … this write may have LANDED despite the failure（假失败定律）"。
- **triedTools**：`sch disconnect`、`sch modify`、`sch connect`、`sch check`、`schematic.save` + `doc reload`
- **alternative**：**判据只能是只读复核**——`sch check` 的 `floating pin(s)`、`sch list` 的坐标、
  `sch clusters` 的几何。失败即重发会重复写入（例如重复 flag）。本轮的判定顺序：
  **写 → save → reload → 只读复核 → 才决定是否重试**。
- **status**：`accepted`（已写入流程纪律）

---

## GAP-037 建板路径上的三处「可用性硬约束」（都曾卡住，现已知道怎么过）

- **capability**：纯 typed 从 0 造一块板并让它过门禁。
- **evidence**（同上，sc001-led-blk）：
  1. **`sch titleblock` 拒绝从 null 推断显隐**：只给 `{"Name":{"value":"…"}}` 会被拒，
     原文要求补 `Name.showTitle / Name.showValue / Description.showTitle / Description.showValue`，
     且"不能从 null、缺失或非布尔值推断宿主默认状态"。补齐后 `ok:true`，`missing-titleblock` 归零。
  2. **`sch group-move --group` 对"整块一起建的组"无效**：`g1` 同时含 R1 与 LED1，
     整体平移后两者**相对重叠不变**（实测几何同步 +200，重叠仍 38×11）。
     要解决的是**组内相对间距**，不是整组位置。
  3. **`sch connect --direction down` 会静默不生效**：`down` 方向连接后仍报 1 个 floating pin；
     换回 `left` 立即归零。**方向要按引脚朝向选**，选错不会报错、只会不连。
- **triedTools**：`sch titleblock`、`sch group-move`、`sch connect`（4 个方向）、`sch clusters`、`sch check`
- **alternative**：建板顺序已跑通为：
  `project.create` →（自带 Schematic1/P1 与 Board1/PCB1，**无需 board.create**）→
  `sch block-apply` → `sch clusters --strict` / `layout-lint` 收敛布局 →
  `sch titleblock`（显式显隐）→ `pcb import-changes` → PCB 布局/布线 → 验收。
- **status**：`accepted`

---

## GAP-038 `pcb check` 零违规时输出形态不同，旧判据会把干净板判 FAIL

- **capability**：用 `pcb-dfm` 阶段判断 PCB 有没有 DFM 错误。
- **evidence**：实测两种输出形态——
  - 有违规：`ERROR=3 WARN=245  | dangling=2 …`（含 `ERROR=` 计数行）
  - **零违规**：`PCB check (DFM): 7 track(s), 0 via(s), 4 pad(s) — 0 issue(s)` + `✓ no DFM issues found`
    （**不含** `ERROR=`）
  旧判据只 `[regex]::Match($out,'ERROR=(\d+)')`，于是 `sc001-led-typed`（7 走线 / 4 焊盘 / 0 违规）
  被判「未给出 ERROR 计数」→ **假 FAIL**。反例成立：板子是干净的，判据却报失败。
- **triedTools**：`pcb check`、`pcb drc --json`
- **alternative**：把解析抽成 `acceptance/dfm-parse.ps1` 的 `Parse-DfmErrorCount`，同时认两种形态；
  无法判定时返回 **-1（报 FAIL，不当 0）**。已配 3 条自测断言（零违规形态→0、`ERROR=3`→3、垃圾→-1）。
- **status**：`resolved`

---

## GAP-039 审计日志必须与工程匹配，否则等于审别人的日志（假保证）

- **capability**：用 `-RunLog` 审计「有没有一次性脚本 / 有没有对着旧快照求解」。
- **evidence**：2026-10-31，零上下文执行者复跑 `sc001-ldo-blk` 后主动指出：
  我给它的 `-RunLog` 指向的 `round16.log` 里**只有旧工程 `agent-e2e-esp32s3-board31` 的命令**，
  没有任何本工程记录；而 `no-oneoff-scripts` / `negative-drift` 当时仍判 **PASS**。
  即：审计阶段读了一份**与本次运行无关**的日志并给绿。
- **triedTools**：`no-oneoff-scripts`、`negative-drift`、`run.ps1`（带 -RunLog 参数）
- **alternative**：已加守卫——指定 `-Project` 时，日志里必须出现该工程名，否则判 **BLOCKED**
  （既不是 PASS 也不是 FAIL）。两块自造板随后各补了一份**按实际执行命令整理**的运行日志
  （文件头明确标注"事后整理，非实时 tee"），复跑后审计才是真的。
- **status**：`resolved`

---

## GAP-040 一次性脚本判据把 `.work` 中间件误判成脚本

- **capability**：`no-oneoff-scripts` 判断日志里有没有"手搓脚本"。
- **evidence**：旧规则任一行命中 `\.work\` 即判可疑。于是**文档化的 DSN→SES 管线**
  （中间件写 `easyeda-auto\.work\ldo.dsn` / `.ses`）被判「2 处疑似一次性脚本」→ **假 FAIL**。
  `.work` 恰恰是 kit 规定的中间件/日志目录，不是脚本目录。
- **triedTools**：`no-oneoff-scripts`
- **alternative**：判据改为**只看脚本文件**（`.ps1/.py/.sh/.js/.mjs/.bat/.cmd`），
  并放行 kit 自带的 `acceptance\*.ps1` 与 `tools\ensure_eda_window.py`；
  另修一个显示 bug（单条命中时 `$suspects[0]` 取到首字符，已用 `@()` 包住）。
  三条自测钉住：错日志→BLOCKED、`.work` 中间件→PASS、`.work` 脚本→FAIL。
- **status**：`resolved`

---

## GAP-041 六件以上的块可能**放不进 A4**：工具会拒绝，而 `destagger` 仍不收敛

- **capability**：把更大的内嵌块（USB-C 输入前端 / 自动下载电路）直接放进新建工程的一页并过布局门禁。
- **evidence**（2026-10-31 实测，三个块）：
  1. `block.usbc_ufp_power_or`（6 件：USB-C 16P + ESD + TVS + 双 CC 电阻 + 肖特基）
     - 默认 grid 布局：28 条 autoconnect，但 **reconcile 失败 2 项**（`USB_HOST_DP: missing J1.A6`、
       `GND: missing J1.B1A12`），且有 **4 处组重叠**（33×11 / 66×11 / 38×11 / 31×11）。
     - 改 `--spacing 300 --per-row 2` 后 **7 网全部对齐**（reconcile ✓），但器件**跑出 A4 图框**。
     - 再收紧到 `--spacing 200 --per-row 3` 时，工具**主动拒绝落块**并给出实测依据：
       `usbc_ufp_power_or 实测 919×672`，而图签把可用区切成 L 形（宽 ≤456 / 高 ≤615），
       两条都不满足，并明确写"这不是摆放问题：再挪、再压 --per-row、再调 margin/gutter 都不会让它变小"。
  2. `block.esp32_autodownload`（4 件：双三极管 + 双 4k7）：10 条 autoconnect、**6 网 reconcile ✓**，
     但仍有 **3 处极小重叠**（6×1 / 1×6 / 6×1）。
  3. 对上述重叠跑 `sch destagger --apply --max-rounds 2`：**无输出、几何未变**，与 GAP-034 同现象。
- **triedTools**：`sch block-apply`（三种 spacing/per-row 组合）、`sch clusters --strict`、
  `sch destagger --apply`
- **alternative**：按工具自陈的三条出路——
  ①换更大的图纸/独占整页（A4 之外，需确认宿主是否支持改纸张）；②分页承载；
  ③**改 marker 朝向把组收小**（`sch disconnect` + `sch connect --direction left|right`，
  竖排标签能把组高从 134 压到 58）。**未验证**：③ 对本块是否足以把 919×672 压进 456×615。
- **status**：`open`

---

## GAP-042 A4 是硬约束：可用高度 627 vs 六件块 672，差 45 mil；且没有改图纸尺寸的 API

- **capability**：让六件以上的块（如 `usbc_ufp_power_or`）在一页 A4 上落块并通过布局门禁。
- **evidence**（2026-10-31 实测，逐项数量化）：
  1. `sch sheet-geometry` 给出图纸真相：
     `template "a-series-landscape", bbox [0,0 → 1170,825]`，
     `titleBlock (visible) bbox [468,0 → 1170,198]`，且为 **hard keepout**。
     → **可用区是 L 形**：整幅上方（y>198）为 **1170×627**；左侧（x<468）为 **468×825**。
  2. USB-C 六件块实测尺寸 **919×672**：宽 919 > 468（左侧放不下），高 672 > 627（上方放不下）→ 两路都不行。
     差距只有 **45 mil**（672 − 627）。
  3. 四种排布全部试过：
     `--per-row 2 --spacing 300` → 落块成功但 4 个组出图框（out-of-sheet）；
     `--spacing 300/per-row 2` 之外的 `260/3`、`260/2`、`200/3` → **工具直接拒绝落块**（预测放不下）。
  4. **改图纸尺寸的入口不存在**：`easyeda` 全局与 `sch` 子命令里都没有 paper/sheet-size 相关命令；
     动作目录里 `schematic.page.*` 只有 open/create/rename/delete/clear，**没有改纸张**。
     A4 是宿主模板给的硬边界。
- **triedTools**：`sch sheet-geometry`、`sch block-apply`（4 组 spacing/per-row）、`sch clusters`、
  `easyeda --help` / `sch --help` / 动作目录检索
- **alternative**：只剩两条——
  ①**缩短 marker**（`sch disconnect` + `sch connect --direction left|right` 让标签横排）把块高压到 ≤615；
    **未验证**能否省下 45 mil；
  ②分页承载（把一个块拆成两页不现实，但可换成更小的块组合）。
- **status**：`open`

---

## GAP-043 「这一块在本页放不下」的判定**按页缓存**，`sch clear` 清不掉，换新页才重置

- **capability**：在被判过"放不下"的页面上重试落块（哪怕已经清空该页）。
- **evidence**（2026-10-31 实测，同一命令对照）：
  1. 首次在新页 P1 上 `sch block-apply usbc_ufp_power_or --at 300,700 --spacing 300 --per-row 2`
     → **落块成功**（28 autoconnect、7 网对齐），但 4 组出图框。
  2. 之后在同一页反复 `sch clear` + 用**完全相同**的参数重试 → **一律拒绝**，
     理由是"上一轮已**实测**量过这一块在本页放不下（919×672 …）"。
  3. 对同一工程**新建页 P2**（`sch page-new --schematic <uuid>`）后，**同样参数立即落块成功**
     （网表 7/7 对齐）——说明拒绝结论是**按页缓存**的，不是每次现算。
  4. 把原点下移到 `--at 300,180`（想避出图框）→ 拒绝；即换了原点也仍按页判定。
- **triedTools**：`sch block-apply`（多组参数）、`sch clear`、`sch page-new`、`sch clusters`
- **alternative**：需要重置该判定时**换新页**（已验证可行）；否则视为该页对该块已封板。
- **status**：`resolved`（机制已查明，绕过方式已验证）

---

## GAP-044 六件块在 A4 上的最终实测：可落但必出图框；四组越界位置已量化

- **capability**：让 `usbc_ufp_power_or` 在 A4 一页内完成布局门禁。
- **evidence**（新页 P2、`--at 300,700 --spacing 300 --per-row 2`、网表 7/7 对齐）：
  `clusters --strict` 报 **4 处 out-of-sheet**：
  `J1 左沿 -50 < 12、上沿 1142 > 813`；`R2 上沿 1352`；`D3 上沿 1352`；`R1 上沿 1032`（限 813）。
  它们全部是**纵向越界**，因为 3 行 × 300 间距把最上一行推到 y≈1340，而图签把可用高度压到 627。
  把原点下移到 180 想整体下压 → 工具拒绝（预测撞图签 keepout）。
- **triedTools**：`sch block-apply`、`sch clusters`、`sch sheet-geometry`
- **alternative**：只剩"缩短 marker"这条路（`disconnect` + `connect --direction left|right`），
  目标是在**行距不变**的前提下把每组纵向包络压到能塞进 627。**本轮未做，未验证**。
- **status**：`open`

---

## GAP-045 更正 GAP-042/044：「六件块放不进 A4」是**块相关**，不是普遍结论

- **capability**：把六件块放进一页 A4 并通过布局门禁。
- **evidence**（2026-10-31 实测，反例推翻旧结论）：
  `block.pmos_highside_softstart`（6 件：100nF + S8050 + SI2301 + 10k/100k/10k）
  在默认 grid 下确有 **3 处重叠**（31×11 / 21×11 / 17×11）；
  但改用 **`--spacing 220 --per-row 3`** 后：`sch clusters --strict` → **6 组 0 重叠 / 0 出图纸**，
  网表 `reconcile ✓`，随后 `pcb import-changes` 6 件 verified、DSN→`pcb_autorouter` **15/15 连通**、
  DFM **ERROR=0**、验收 **16 PASS / 0 FAIL / 0 BLOCKED**。
  → 同样是 6 件，USB-C 块（含 12 marker 的 16P 连接器）放不下，而全小封装的块放得下。
  **因此 GAP-042 的「919×672 vs 1170×627 差 45 mil」只能代表 `usbc_ufp_power_or` 这一种块**；
  并且当时多次重试被拒还叠加了 GAP-043（按页缓存的"放不下"判定）。
- **triedTools**：`sch block-apply`（带 `--spacing/--per-row`）、`sch clusters --strict`、
  `pcb import-changes`、`pcb_autorouter`、`pcb check`
- **alternative**：六件块先试默认 grid；有重叠就**加大 `--spacing` 并调 `--per-row`**（本块 220/3 即通过），
  而不是直接判定放不下。只有带大连接器（marker 极多）的块才需要缩短 marker 或分页。
- **status**：`resolved`

---

## GAP-046 「放不下」的预测**非单调**，且 `220/3` 就能让 USB-C 六件块进 A4

- **capability**：把带 16P 连接器的六件块（`usbc_ufp_power_or`）放进一页 A4。
- **evidence**（2026-10-31，全部在新页 P4 上实测，每轮先 `sch clear`）：

  | 配置 | 落块 | 结果 |
  |---|---|---|
  | `--at 250,300 --spacing 220 --per-row 3` | **成功** | **0 出图框**，仅 2 处重叠（D5↔D4 `24×1`、D5↔J2 `96×11`），网表未对齐 |
  | `--at 250,300 --spacing 260 --per-row 3` | **成功** | 网表 `reconcile ✓`，但 J2 右沿 **1170 > 1158**（差 12 mil）+ 2 处重叠 |
  | `--at 200,350 --spacing 220 --per-row 2` | **拒绝** | 预测宽度放不下 |
  | `--at 210,300 --spacing 250 --per-row 3` | **拒绝** | — |
  | `--at 160,300 --spacing 240 --per-row 3` | **拒绝** | — |

  → 判定**非单调**：250 与 240 被拒，反而 220 与 260 被接受。所以"放不下"不能当结论用，
  只能当"这一组参数被拒"，必须换参数重试（换页还会重置缓存，见 GAP-043）。
- **triedTools**：`sch block-apply`（5 组参数）、`sch clusters --strict`、`sch page-new`、`sch clear`
- **alternative**：先试 `220/3`（能进框）再用 **单个器件微移** 消重叠；
  或 `260/3`（网表对齐）后整组左移 ~20 mil 收掉右侧 12 mil 越界。
  两条都还没实跑完，**未验证**能否一次做到 0 重叠 0 出图。
- **status**：`open`

---

## GAP-047 六件 USBC 块的**三方权衡**：进框 / 网表对齐 / 无重叠，A4 上未能同时满足

- **capability**：让 `usbc_ufp_power_or`（含 16P 连接器 13 marker、USBLC6 ESD 6 marker）在一页 A4 内
  同时满足：0 出图纸、0 组重叠、网表 `reconcile ✓`。
- **evidence**（2026-10-31，逐页实测，每轮新建页 + `sch clear`）：

  | 配置 | 落块 | 网表 | clusters |
  |---|---|---|---|
  | `220/3` | 成功 | **✗ 未对齐** | 0 出图框，**2 处重叠**（24×1、96×11）|
  | `245/3` | 成功 | ✗ | 左沿 **-10 < 12**，2 处重叠 |
  | `255/3` | 成功 | ✗ | 左沿 **0 < 12**，2 处重叠 |
  | `260/3` | 成功 | **✓** | 右沿 **1200 > 1158**（超 42），2 处重叠 |
  | `220/2`、`240/3`、`250/3` | **拒绝** | — | — |

  块在 245–260 间距下总宽约 **1160–1204**，而 A4 可用宽度只有 **1146**（x 12→1158）：
  够宽就对齐不了网表，对齐了网表就超宽 ~14–58 mil。
- **another dead end（负结果）**：`sch group ungroup` + `sch autoplace-free --all --apply` 虽然消掉了重叠，
  但把 **26 支 marker 从导线上扯脱**（`sch clusters` 报"既不沾任何导线、离谁都远"），
  J4 仍出界 10 mil。**结论：对已连线的块不要用"解组后整页重排"**，会静默破坏连通性。
- **triedTools**：`sch block-apply`（8 组参数）、`sch clusters --strict`、`sch group-move`、
  `sch group ungroup`、`sch autoplace-free --all --apply`、`sch page-new`
- **alternative**：只剩**按引脚缩短 marker**：对 USBLC6 的 6 个引脚
  `sch autoconnect --pin D:<pin> --net <net> --replace --offset-min 18 --offset-max 30`，
  把每个标签的桩长压到最小，理论上能把宽度收进 1146。**未验证**。
- **status**：`open`

---

## GAP-048 `connect` 的方向必须等于引脚外朝方向；`export-dsn` 的 stale 报错会冒充"板是空的"

- **capability**：给已挪位的器件重新接线；在改动过的 PCB 上导出布线用的 DSN。
- **evidence**（2026-10-31，`sc001-autodl-blk` 实测）：
  1. **connect 方向**：R1 的 1 脚在器件**左侧**（外朝 180°）。用
     `sch connect --pin R1:1 --net USB_DTR --kind netport --direction right` 时被几何守卫拒：
     `wire segment 0 (290,680)→(320,680) enters component body` +
     `pin 1 outward rotation 180° requires its first wire segment to leave outward`。
     四条连接改成「左脚走 `left`、右脚走 `right`」后**一次全过**，`sch check` 从
     **4 个悬空引脚**归零。
     更要注意：**先 `disconnect` 后若 `connect` 失败，引脚是悬空的**，而 `clusters` 只会显示
     `marker 0 / 桩线 0`（看起来"更干净"）——必须用 `sch check` 的 floating-pin 计数复核。
  2. **export-dsn 的 stale 守卫**：PCB 被 `pcb.component.attrs_backfill` 改过后直接导出，返回
     `DSN export returned no file — the PCB may be empty or have no nets (run pcb.import_changes first)`。
     实际板上 **4 个器件、4 条信号网俱在**（`layout-lint` 96/100 可证），报错**与事实相反**。
     正确顺序：`pcb save` → `doc reload` → 等窗口重连（本机实测要 8–12 s）→ `export-dsn`，
     之后 DSN 正常导出 3 KB。
- **triedTools**：`sch connect`、`sch disconnect`、`sch modify`、`sch check`、`pcb export-dsn`、
  `pcb save`、`doc reload`、`pcb layout-lint`
- **alternative**：接线一律按引脚朝向给 `--direction`；导出前一律 save+reload+重连窗口，
  不把 "no nets" 当结论（先用 `layout-lint` 核实器件与网络数）。
- **status**：`resolved`

---

## GAP-049 GAP-047 已解：USB-C 六件块**能**在 A4 上全绿；解在多页污染、NC 语法与 destagger 半途失败

- **capability**：把 `usbc_ufp_power_or`（16P 连接器 + ESD + TVS + 肖特基 + 双 CC）做成一块过验收的板。
- **evidence**（2026-10-31，`sc001-usbc-typed` 实测，验收 **16 PASS / 0 FAIL / 0 BLOCKED**）：
  最终配方 = `--spacing 220 --per-row 3`（能进框）+ 补 `J:A6 → USB_HOST_DP`（reconcile 7/7 才成立）
  + 把 ESD 挪到 (350,700) 并给同侧三个标签不同桩长（18/96/174）
  + `sch no-connect --designator J --pin A8,B8`（SBU 两脚按设计悬空，需显式 NC）。
  结果：`clusters --strict` **6 组 0 重叠 / 0 出图纸**、0 悬空引脚、布线 **29/29**、DFM **ERROR=0**、
  交付 Gerber 22,154 B / CPL 2,760 B / BOM 7,124 B。
  并实测确认：`sch check` 的 `marker-overlap` 是 **WARN**，`schematic-gates` 在仅有 WARN 时 **PASS**
  （此前 GAP-047 记的三方权衡，缺的正是"补网表 + 挪单件 + 错开桩长"这三步）。
- **evidence-2（多页污染，代价 30 个器件）**：试验期在 9 个页上反复落块，`pcb import-changes` 一次导入
  **30 个器件**。正确做法：只留目标页，其余页 `sch clear`（**不要 `sch page-delete`，不可撤销**），
  再导入 → 6 件。
- **evidence-3（NC 语法与 connect 不同）**：`sch no-connect --pin J5:A8` **静默 ok:false**；
  必须 `--designator J5 --pin A8,B8`。
- **evidence-4（destagger 半途失败的恢复）**：`sch destagger --apply` 搬到一半窗口断开，
  自动恢复失败，但**打印出待手工恢复的引脚清单**（`D14:1→USB_HOST_DM` …），照单逐脚 `connect` 即复原。
- **triedTools**：`sch block-apply`、`sch connect`、`sch disconnect`、`sch modify`、`sch no-connect`、
  `sch destagger`、`sch clusters`、`sch reconcile`、`sch clear`、`pcb import-changes`、`pcb export-dsn`、
  `pcb_autorouter`、`pcb check`
- **alternative**：六件块的通用配方见上；大连接器块**不是不能做**，是要"进框优先、再补网表、再挪单件"。
- **status**：`resolved`

---

## GAP-050 「PCB 全绿」不等于「DRC 0」：旧口径只认 Connection Error，实测所有板都有其他 DRC 违规

- **capability**：宣称一块板「验收全绿」时，读者会理解为「DRC 干净」。
- **evidence**（2026-10-31，外部审计 S6 触发，实测）：
  - 练习板 `agent-e2e-esp32s3-board31`：`pcb drc` → **passed=False，27 条**（Clearance Error **26** + Netlist Error **1**）。
  - `sc001-usbc-blk`（第 5 块）：**passed=False，3 条**（Clearance Error 2 + Netlist Error 1）。
  - 而 `pcb-connectivity` 阶段只看 `Connection Error`，两者都是 **0** → 旧口径一律 PASS。
  - `PRODUCT.md` 的 SC-A 写的是「**DRC 0**」——**旧实现根本没验这条**。
- **triedTools**：`pcb drc --json`（读 passed/total/counts）、`pcb check`（DFM，只覆盖可制造性）
- **alternative**：新增第 17 阶段 `pcb-drc-clean`，判据 = `passed=true` 且所有分类计数为 0；
  解析不到 `passed` 判 BLOCKED（不是 PASS）。**加入后实测：练习板 16 PASS / 1 FAIL，
  USB-C 板 16 PASS / 1 FAIL** —— 这是真实状态。
- **status**：`open`（板要真正做到 DRC 0 才算满足 SC-A）

---

## GAP-051 外部审计（零上下文）一次挑出 10 类问题，其中 6 类是真缺陷

- **capability**：门禁自称"自证有效"。
- **evidence**（2026-10-31 审计报告 + 我逐条复核）：

  | 编号 | 问题 | 复核结果 | 处理 |
  |---|---|---|---|
  | S3 | `delivery` 的钻孔证据是**硬编码 true**，从不打开 Gerber 包 | **属实**（export-delivery.ps1 原第 56 行）| 已改为真开 zip、按成员名判定；假 zip 判失败 |
  | S4 | 空日志 PASS；`acceptance\*.ps1` 前缀可绕过 | 空日志被上轮守卫部分挡住；**前缀绕过属实** | 已加 ≥3 条实质行门槛；豁免改为精确文件名白名单 |
  | S5 | `schematic-gates` 回退分支 = “没出现 failed 字样就 PASS” | **属实** | 已改为 `sch check --strict` + 解析 floating pin 计数 |
  | S6 | `pcb-connectivity` 只认 Connection Error，DRC 其他类不看 | **属实** | 已新增 `pcb-drc-clean` 阶段（见 GAP-050）|
  | S7 | `capability-boundary` 的 status 校验是死代码（字符类 `[::]`）| **属实** | 已改 `[:：]` |
  | S8 | 自测跳过 2 条仍记 36/36 | **属实**（本机有 easyeda-auto 才 36；安装形态 35+1 SKIP）| 已让汇总如实报 SKIP |
  | S10 | `sample-boundaries.ps1` 未接入门禁，且当前 3/5 不合格 | **属实**（实测 3 通过 / 2 不合格）| **未修**（待办）|
  | S1/S2 | 证据层级：五块板是 2–6 件小模块；per-board 报告被 gitignore | **部分属实**（板规模确实小；报告确实未入库）| 已标注；报告入库**待办** |

  审计同时确认**没缺陷**的部分：错误矩阵 16/16 真实、CLI 子命令无编造、DFM 三形态解析正确、
  退出码三态正确、49 条 GAP 无重号无悬空。
- **triedTools**：`run.ps1` / `stages-gates.ps1` / `export-delivery.ps1` / `selftest.ps1` 逐行核对 + 反例探针
- **alternative**：每条修复都配反例（假 zip、空日志、前缀脚本、非法 status、无 historyRepo 形态）。
- **status**：`resolved`（6 类已修，S10/S1/S2 记 open）

---

## GAP-052 DRC 清零实测受阻：两条间距差 0.1/0.9 mil，Netlist Error 同步+重载后仍在

- **capability**：把 `sc001-usbc-blk` 的 `pcb drc` 从 passed=False 清到 passed=True（SC-A 的前置）。
- **evidence**（2026-10-31 实测，全部有命令与返回）：
  1. 初始：`passed=False total=3` —— `Clearance Error`(Slot Region to Track, `D13_N4`, **11.7 / 11.8 mil`)
     + `Clearance Error`(SMD Pad to Track, `USB_HOST_DM` 走线距 `J5_A6` 焊盘 **5.1 / 6 mil**) + `Netlist Error`。
  2. 试 **同步网表**：`pcb import-changes` → `componentsAfter=6, imported=true, verified=true`；
     `pcb save` → `doc reload` → 等窗口重连 → 重查：**三条原样不动**。
  3. 试 **改原理图桩长**：把 `J5:A6` 的 netport 桩从 offset 174 改到 30（`sch check` 仍 0 悬空），
     再 `import-changes` + save + reload + 重查：**`USB_HOST_DM` 那条仍 5.1 mil 不变**。
     → 结论：这两条**不是原理图桩的问题，是 PCB 里已布好的走线几何**（DLR 读的是铜皮距离，不随原理图桩变）。
  4. `Netlist Error` 在 import-changes（verified=true）+ save + reload **之后仍然存在**，
     说明它不是"没同步"，而是**确实存在差异**（PCB 与原理图在某个网络/焊盘上不一致），
     需要更细的 diff（`Import Changes` 的差异面板在 GUI 里，CLI 侧暂无对应命令）。
- **triedTools**：`pcb drc --json`、`pcb import-changes`、`pcb save`、`doc reload`、`sch connect`（改桩长）
- **alternative**（下一步，均**未验证**）：
  ① 对 `USB_HOST_DM` 走 `pcb rip-up --net` 后按显式层/宽度重布（有打断连通性的风险，须先备份）；
  ② 用 `pcb autoroute` 带更高间距规则重跑整板（会把现有 29/29 连通重算）；
  ③ Netlist 差异需要从 GUI 的 Import Changes 面板读出具体条目，或找 CLI 侧的等价诊断命令。
- **status**：`open`

---

## GAP-053 修 DRC 几何问题缺两件工具：PCB 备份导出在本项目上失败、无走线级编辑命令

- **capability**：把 PCB 上「走线离焊盘 5.1 mil」这类几何违规**定点修掉**，而不重排整板。
- **evidence**（2026-10-31，`sc001-usbc-blk` 实测）：
  1. **备份失败**：`project export-source --project … --payload {"uuid":…}` 与
     `project export --project … --out …` **都返回空结果、不产出 `.epro2` 文件**
     （`easyeda-auto\.work\usbc-backup.epro2` 不存在）。→ **没有回滚手段**。
  2. **无走线级编辑**：`pcb --help` 里没有 track 级 move/modify 命令；与走线有关的只有
     `route`（一次落一跳）、`rip-up`（按网撕）、`import-autoroute`、`bezier`/`beautify`。
     因此「把这条线挪开 1 mil」没有对应动作，只能**撕掉整条网重布**或**重跑整板 autoroute**。
  3. 焊盘级网表差异也读不到：`pcb nets` 只给网名与长度，`pcb list` 只给器件属性，**无焊盘→网络** 的查询；
     Netlist Error 的具体差异条目只在 GUI 的 `Import Changes` 面板里。
- **triedTools**：`project export-source`、`project export`、`pcb nets`、`pcb list`、`pcb net-path`（未跑）、
  `pcb --help` 全量检索
- **alternative**：① 用 GUI 的 `Import Changes` 面板读出网表差异再决定改哪边；② 在**有备份**的前提下
  `rip-up --net` + `route` 重布；③ `drc-rules-set` 提高设计规则后**重跑 autoroute**（属于"整板重算"，非定点修复）。
  三条都**未验证**。
- **status**：`open`



---

## GAP-054 辅助阶段抛异常会**打断整条验收**：数组没有 `.Trim()`，矩阵当场抓到

- **capability**：新增一个门禁阶段（第 18 阶段 `capability-sample`）而不影响其它阶段。
- **evidence**（2026-10-31 本轮自查，我自己造成的）：
  1. 新阶段里写了 `(($out -split "`n" | … | Select-Object -Last 1) -replace "=", "").Trim()`。
     当 `-replace` 作用在**数组**上时返回数组，数组没有 `.Trim()` → 抛
     `方法调用失败，因为 [System.Object[]] 不包含名为 'Trim' 的方法`。
  2. 因为 `run.ps1` 是 `$ErrorActionPreference = "Stop"`，这个异常**中止了整个验收流程**：
     在矩阵的裸探针（`-AuditRoot <空目录>`）里，banner 之后一个阶段都不输出。
  3. **错误矩阵当场抓到**：`16/16` → **2/16**（大量 `实际 MISSING`），自测 `36/36` → `33/36`。
     即"门禁自身失效"这件事被另一层门禁发现了——这正是矩阵存在的意义。
  4. 修法：取最后一行先转 `[string]` 再 `Trim`，并给整个阶段包 `try/catch`——**辅助脚本出错只能让本阶段
     BLOCKED，不许打断流程**。修后 36/36、16/16 恢复。
- **triedTools**：`mistake-matrix.ps1`（2/16 报警）、`selftest.ps1`（33/36 报警）、`git show HEAD~1:…` 对照法
- **alternative**：任何新增阶段的两条硬规矩——① 阶段内的解析/转换要防数组；② 阶段整体 `try/catch` 兜底，
  异常一律降级为 BLOCKED。
- **status**：`resolved`

---

## GAP-056 「能力计数」把运行产出物也算进去：清理垃圾反被判成退化

- **capability**：`positive-goal` 用 `docs/playbooks/acceptance/specs` 四个计数做「能力只增不减」的棘轮。
- **evidence**（2026-11-01 自查）：
  1. 上一轮加"per-run 报告入库"时，**静态跑也会写报告**（未限定 `-Project`）→ 一夜之间
     `acceptance/` 从 ~27 个文件涨到 **274** 个，其中 225 份是无板子静态跑的产物。
  2. 我修掉"只给真实运行写报告"并清理那 225 份后，`positive-goal` 立刻报
     **`acceptance 从 274 降到 58（能力退化）`**，连带矩阵的 M14/M16 对照用例由 PASS 变 FAIL
     （14/16）、自测 35/36。
  3. 即：**这个口径把"运行产物"当成"能力"**，于是"清理垃圾"被判成退化、而"堆积垃圾"被当成增长。
- **triedTools**：`positive-goal`（计数）、`mistake-matrix`（M14/M16 对照）、`selftest`（kit 自身断言）
- **alternative**：计数排除 `acceptance/runs/`（运行产物不算能力），基线按新口径重设；并用
  "只给带 `-Project` 的真实运行写报告"从源头止住增长。修后 36/36、16/16、静态 9 PASS / 0 FAIL / 10 BLOCKED。
- **status**：`resolved`

---

## GAP-057 DRC 清零的第二条路（重建）同样被环境打断：新工程建好了，但接线时窗口反复掉线

- **capability**：绕开"旧板无备份、无走线级编辑"（GAP-053），改为**从头重建一块同样的板**并在布线前把间距条件放宽，从而得到 DRC 干净的板。
- **evidence**（2026-10-31 本轮实测）：
  1. 新工程 `sc001-usbc-clean`（`cf8079c6b8654423b8e580868e5f085d`）已建；`260/3` 落块 → 网表 ✓ 但 3 处报错
     （2 重叠 + J1 右沿 1170 > 1158）。
  2. 同页改用 `220/3` → **被拒**（GAP-043 的按页缓存第三次复现）；**新建页 P2** 后 `220/3` → 落块成功，
     6 件（D1 SS34 / D2 USBLC6 / J1 USB3.1-16P / R1 R2 5.1k / D3 SMAJ5.0A）。
  3. 接着执行已知配方时 **EDA 窗口掉线**：`sch connect --pin J1:A6` 失败、`sch connectivity` 返回非 JSON。
     因此"补 A6 → 挪 ESD → 标 NC"这一步**没能跑完**，新板停在"块已落、网表未补"的中间态。
- **triedTools**：`project create`、`sch page-new`、`sch block-apply`（220/3 与 260/3）、`sch connect`、`sch connectivity`
- **alternative**：窗口稳定时按 GAP-049 的配方继续（补 A6 → 挪 ESD 并给同侧标签错开桩长 18/96/174 → 标 NC ✕
   → 导入 PCB → 板框 margin 放大到 200 → autoroute → DRC）。**未验证**能否做到 DRC 0。
- **status**：`open`

---

## GAP-058 DRC 0 在当前工具链下**不可达**：两次独立重建得到**逐条相同**的 3 条违规

- **capability**：满足 PRODUCT.md 的 SC-A「DRC 0」。
- **evidence**（2026-10-31/11-01，**两次独立构建**对照，这是关键）：

  | 项 | 旧板 `sc001-usbc-blk` | 新板 `sc001-usbc-clean`（重建） |
  |---|---|---|
  | 布局 | `220/3` + 挪 ESD | `220/3` + 挪 ESD（同配方）|
  | 布线 | autoroute 29/29 | autoroute **29/29** |
  | `pcb drc` | passed=False，**3 条** | passed=False，**3 条** |
  | 违规 1 | `Slot Region to Track` 11.7 / 11.8（net `D13_N4`）| **同一条**：`Slot Region to Track` 11.7 / 11.8（net `D1_N4`）|
  | 违规 2 | `SMD Pad to Track` 5.1 / 6（`USB_HOST_DM` 对 `J5_A6`）| **同一条**：`USB_HOST_DM` 对 `J1_A6` 5.1 / 6 |
  | 违规 3 | `Netlist Error` | **同一条** |

  → 两块板、两个工程、两次独立布线，违规**逐条对应**。这说明它们不是"这次没摆好"，而是：
  - 违规 1、2 是 **autorouter 的间距模型与 EasyEDA DRC 的判定口径不一致**（布线器认为合规，DRC 认为差 0.1–0.9 mil）；
  - 违规 3 是 **网表记账差异**，在 `import-changes`(verified=true) + save + reload 之后依然存在。
- **triedTools**：`pcb drc`、`pcb import-changes`、`pcb outline-fit`（margin 200）、`pcb export-dsn`、`pcb_autorouter -a`、
  `sch connect`/`no-connect`（两次构建都做了）
- **alternative**：要让 DRC 0，需要三者之一——① 布线器侧支持 **slot/pad 级 clearance**（当前无参数）；
  ② CLI 侧的**走线级编辑**（GAP-053：无此命令）；③ GUI 手工改线（**原生/网页 GUI 均不可自动化**）。
  三条都**不可得**，因此**结论是"当前工具链不可达"，不是"再试几次"**。
- **status**：`open`（已判定为工具能力边界，不再作为可执行任务重试）

---

## GAP-032 结案：外部 `.epro2` **可以**导入，代价是"两次确认 + 一次原生文件框"

- **capability**：把别人画的 `.epro2` 工程导进本机编辑器，作为「未见板」素材。
- **evidence**（2026-11-01 实测成功）：
  1. 起点：开始页「快速开始 → **导入专业版**」打开的是**页面内模态框**（不是原生框）：
     含「文件类型 / **文件名** / `···` 选择按钮 / 导入文档·提取库文件·两者」。
  2. 点 `···` 才弹出 **Windows 原生「打开」对话框**（类名 `#32770`）。**必须先在框里进到目标目录**
     （直接往文件名框塞完整路径不行），再填文件名回车——这一步用户帮我点了一次「导入」。
  3. 随后出现**第二次确认框**「导入文档」：可选「新建工程 / 保存至已有工程」，填工程名与简介
     （本次默认 `ESP32S3_USB` / "一个ESP32FN8 S3芯片的开发板"），点「导入」后落库。
  4. 结果：CLI 立即可见 `ESP32S3_USB` 工程——**8 张原理图页**
     （Power_In & Regulation / ESP32S3_Core / Boot_Reset / Clock / RF_WiFi_Antenna / HMI_Keys_LED /
     Pin_Config / PSRAM）+ **1 块 PCB2**（`87d68529660f4a39`）。
  5. 自动化程度：`···` 打开的原生框可用 SendKeys/UIA 驱动（我做到了定位与填名），
     但**最终两次「导入」按钮点击**需要人确认（本次由业主点了一次，第二次我点 `@e63` 完成）。
- **triedTools**：bsk 会话点击「导入专业版」、`SetForegroundWindow`+`SendKeys`、UI Automation 枚举、
  `easyeda sch pages --project ESP32S3_USB`、`easyeda board list --project ESP32S3_USB`
- **alternative**：要全自动，需要给 bsk 加 `upload_file`/`setInputFiles` 能力（chrome-devtools MCP 有
  `upload_file`，但本机 MCP 的 `--executablePath=C:\Program Files(x86)\...` 少一个空格，浏览器起不来；
  该参数在启动时固化，改文件需重启宿主）。
- **status**：`resolved`（导入可行；**验收尚未跑**，见 T331）

---

## GAP-059 外部板 `ESP32S3_USB` 的 DSN 导出持续失败：报"没有网络"，但板上有 45 器件 / 29 网

- **capability**：对**导入的外部板**走 DSN → 外部布线器这条线（自造板上一直正常）。
- **evidence**（2026-11-01 实测）：
  1. 板子事实：`layout-lint` → **45 器件**（bottom 12 / top 33）、**29 信号网**、ratsnest **9816 mil**、60 crossings（未布线）。
  2. `pcb export-dsn` 连续两次返回
     `DSN export returned no file — the PCB may be empty or have no nets (run pcb.import_changes first)`。
  3. 已按 GAP-048 的严格序列重试：`pcb save` → `doc reload` → 等 15 s → `ensure_eda_window` → 等 12 s → 再导出，
     **仍然失败**。所以这一次不是 stale 守卫。
  4. **首要嫌疑（未验证）**：该板 DFM 报 `LIMIT 1 pad(s) lack both source shape and readable width/height;
     only center coincidence can anchor them` —— 可能是这个畸形焊盘让 DSN 生成器放弃输出。
     次嫌疑：导入板的 PCB 文档在导出时不是前台文档（本例板名 `PCB2`）。
- **triedTools**：`pcb export-dsn`（两次、不同状态）、`pcb save`、`doc reload`、`ensure_eda_window`、
  `pcb layout-lint`、`pcb check`
- **alternative**：① 定位并修复那个畸形焊盘（需焊盘级查询，CLI 目前没有——同 GAP-053）；② 在 GUI 里手动
  「PCB → 导出 DSN」绕过 CLI（未验证）；③ 改用 `pcb autoroute` 的一体化路径（同样依赖 DSN 导出，未验证）。
- **status**：`open`


---

## GAP-060 「窗口反复掉线」的根因：**bsk 会话空闲约 5 分钟自动关闭，EDA 窗口随之消失**

- **capability**：让一条长时间验收/布线流程稳定跑完，不被"窗口消失"打断。
- **evidence**（2026-11-01，本轮实证）：
  1. 之前多轮出现"跑到一半窗口没了"（GAP-055 记录的连跑两次 10 处不一致、GAP-057 的重建中断），
     当时只归因为"窗口不稳定"。
  2. 本轮复现出一条明确因果：先前 bsk 会话（`hffp`）在导入完成后约 5 分钟未使用即失效，返回
     `session not registered or already stopped (hint: start a new session; run the daemon with a larger --session-idle (default 5m) …)`，
     **它打开的 Agent Window 与其中标签一并关闭**——EDA 页面随之消失，`daemon health` 里窗口数归零。
  3. 即：**掉线不是 EDA 或连接器的问题，是自动化会话的空闲回收**。
- **triedTools**：`bsk_session start`（新会话恢复窗口）、`bsk_tabs list`（暴露 session 已停止）、
  `easyeda daemon health`（窗口数 0/2 但上下文为空）
- **alternative**：① 长流程前先开 bsk 会话并**在流程中周期性使用它**（保持不空闲）；
  ② 给 bsk daemon 加 `--session-idle` 更大值（需改启动参数，**未验证**）；
  ③ 用 `ensure_eda_window` 在每步前重连（已实现，但会话被回收时也会失败）。
- **status**：`resolved`（机制已查明）

---

## GAP-061 导入板 `ESP32S3_USB` 的连接器绑不上：窗口在、上下文为空

- **capability**：对导入工程执行任何 `--project ESP32S3_USB` 的 CLI 动作。
- **evidence**（2026-11-01 本轮）：
  1. 新建 bsk 会话打开 `pro.lceda.cn/editor`，点击工程列表里的 `ESP32S3_USB` 后，
     `daemon health` 报 **窗口数 2，但两个窗口的 `project/projectUuid/doc` 全为空**；
  2. 于是 `easyeda board list --project ESP32S3_USB` 返回
     `no connected window for project "ESP32S3_USB"`，`pcb autoroute` 同样被 `--doc guard` 拒绝。
  3. 后果：这条外部板的 DSN/布线链路（T332）**在当前窗口状态下不可执行**。
- **triedTools**：`bsk_session start`、`bsk_interact click`（工程链接）、`easyeda daemon health`、
  `easyeda board list`、`easyeda pcb autoroute`
- **alternative**：① 直接在浏览器地址栏打开
  `https://pro.lceda.cn/editor#id=<projectUuid>,tab=<docUuid>@<projectUuid>`（需要 projectUuid——
  本轮未取到，因为工程打开后上下文仍为空）；② 在 GUI 里先打开**编辑器内的 PCB 文档**再让连接器绑定；
  ③ 用 bsk 观察页面确认工程是否真的进入编辑器（本轮未见）。**三条都未验证。**
- **status**：`open`




---

## GAP-061 续：绑定失效的解法 = **必须通过 UI 点工程名**，CLI 无法自举

- **capability**：在没有已绑定窗口的情况下，找到并打开一个已存在的工程。
- **evidence**（2026-11-01 本轮实测成功）：
  1. `easyeda project find --name ESP32S3_USB` 返回 `enumeration.complete=false / reason=empty_uuid_list / matches=[]`
     —— **没有已绑定窗口就枚举不出工程 uuid**（鸡生蛋）。
  2. 用 bsk 在开始页点列表里的 `ESP32S3_USB`（按钮 `@e78`）后，标签 URL 变为
     `https://pro.lceda.cn/editor#id=8b44c9657a31444ebde70b635c3899ba` —— **工程 uuid 只在 URL 里才拿得到**。
  3. 随后 `daemon health` 显示 `project=ESP32S3_USB / uuid=8b44c9657a31444ebde70b635c3899ba`，
     `board list` 正常返回 `PCB2 / 87d68529660f4a39`。**绑定恢复。**
- **triedTools**：`project find`、`project open`、bsk 点击工程名、`daemon health`、`board list`
- **alternative**：外部工程的第一跳只能走 UI（点工程名或在地址栏填 `#id=<projectUuid>`）；
  `project open --project-uuid` 需要先有 uuid，而 uuid 又要先绑定——除非 uuid 从别处已知。
- **status**：`resolved`

---

## GAP-063 绑定恢复后 `pcb export-dsn` 在该外部板上**仍失败**：文档未激活（`doc=` 为空）

- **capability**：对导入的外部板执行 DSN 导出，供外部布线器使用。
- **evidence**（2026-11-01）：
  1. 绑定恢复后按 `#id=<proj>,tab=*<pcb>@<proj>` 打开 PCB 文档，`daemon health` 仍是
     `project=ESP32S3_USB` 但 **`documentType= / documentUuid=` 全为空** —— 连接器没有"当前文档"。
  2. 此时 `pcb export-dsn --doc 87d68529660f4a39` 仍返回
     `DSN export returned no file — the PCB may be empty or have no nets`。
  3. 对照：五块自造板在同样流程下（同样的 URL 形式）`doc` 有值且 DSN 正常导出
     ⇒ 差异在**该外部板的文档激活状态**，不在 URL 形式。
- **triedTools**：`ensure_eda_window`（带 `tab=*<pcb>@<proj>`）、`daemon health`、`pcb export-dsn`
- **alternative**：① 在 EDA 界面里手动双击打开 PCB2 使其成为活动文档（bsk 可点）；② 用 `doc ls`/`project info`
  确认当前文档；③ 直接在 GUI 里「PCB → 导出 DSN」验证板本身是否可导出（**均未验证**）。
- **status**：`open`（T332 仍未解）

### 续：已排除"文档未激活"这一假设
2026-11-01 补测：在工程树里**双击 PCB2** 后，`daemon health` 变为
`project=ESP32S3_USB / documentType=pcb / documentUuid=87d68529660f4a39`（正是该板），
**文档已激活**；此时 `pcb export-dsn` 与一体化的 `pcb autoroute` **仍报同一条**
`DSN export returned no file — the PCB may be empty or have no nets`。
⇒ 原因不在文档激活，而在**这块外部板自身的数据**（首要嫌疑仍是 DFM 报的那个缺源形状/宽高的焊盘）。
**可复用的操作知识**：工程树里**单击只选中、双击才打开**成活动文档（`docType` 才会变成 `pcb`）。



### GAP-060 续：窗口来自「bsk 会话 + 守护进程」两者同时在线，缺一即 0

- **capability**：让 CLI 能对某块板执行动作（`--project/--doc` 路由）。
- **evidence**（2026-11-01 本轮实测，两个必要条件）：
  1. **守护进程**：`easyeda daemon start` 是**前台常驻**命令（本轮它在 600 s 后被移到后台任务才继续），
     未启动时任何动作直接报 `no easyeda-agent daemon found on 127.0.0.1:60832-60841`。
  2. **浏览器窗口**：守护进程在线、但 bsk 会话因空闲被回收后，`daemon health` 报
     `守护: found  窗口数: 0` —— 此时所有 `--project … --doc …` 动作仍不可用。
  3. 即：**可用性 = 守护进程在线 ∧ bsk 会话在线（窗口未随会话回收）**。此前我只把它们当成一件事。
- **triedTools**：`daemon start`、`daemon health`、`pcb export-dsn`、`easyeda call pcb.export.dsn`
- **alternative**：① 长流程期间保持 bsk 会话活跃（周期性 `bsk_inspect`）；② 给 bsk daemon 调大
  `--session-idle`（**未验证**如何改，需查插件配置）；③ 每个动作前用 `ensure_eda_window` + `daemon health` 双检。
- **status**：`resolved`（依赖关系已查明）

---

## GAP-064 网页版 GUI 自动化的三条**前置条件**（缺任一，GUI 路线不可用）

- **capability**：用 bsk（浏览器自动化）驱动嘉立创 EDA 网页版做导入/打开文档/手工导出等 GUI 操作。
- **evidence**（2026-11-01 逐条实测）：
  1. **浏览器必须连着扩展**：本轮 `bsk_session start` 直接失败 —
     `no browser is currently connected (hint: open the browser-skill extension in your browser and wait for the popup to show "connected")`。
     即"打开浏览器"本身是**人的动作**，不是自动化能做的。
  2. **会话必须保活**：bsk 会话空闲约 5 分钟自动回收，连带关闭它打开的 Agent Window 与 EDA 标签
     （GAP-060）。因此长流程里**每隔 ≤4 分钟要发一次 bsk 调用**（哪怕只是 `bsk_tabs list`）才不会被回收。
  3. **守护进程必须在线**：`easyeda daemon start` 是前台常驻命令；没有它任何 `--project/--doc` 动作报
     `no easyeda-agent daemon found`。
  ⇒ **可用性 = 浏览器+扩展已连 ∧ 会话保活 ∧ 守护进程在线**，三者缺一即不可用。
- **triedTools**：`bsk_session start`、`bsk_tabs list`、`easyeda daemon start`、`easyeda daemon health`
- **alternative**：① 需要 GUI 的回合，先请业主确认浏览器与扩展处于 connected 状态；
  ② 把 idle 调大（扩展侧设置，**未验证**具体入口）；③ 纯 CLI 路径（不需要浏览器窗口，但仍需守护进程）。
- **status**：`resolved`（前置条件已查明；能否执行取决于这三条是否在线）


---

## GAP-065 「CLI 没有这个子命令」≠「这个能力不存在」：169 个类型化动作里已有 silk / designator / 焊盘级查询

- **capability**：只读查询丝印文本、位号→图元 id 映射、以及**焊盘级**信息。
- **evidence**（2026-11-01 实测，`easyeda actions` 目录 + `easyeda call` 通道）：
  1. **`pcb.silk.list`** 存在：`mutates=false`，输出 `texts[].primitiveId/kind/text/layer/mirror/fontSize/componentId/componentLayer/x/y` + `count`。
     → GAP-006 说"没有 `silk-list` 这类查询"**是错的**：缺的是 CLI 子命令，不是能力。
  2. **`pcb.components.list`** 支持 `includePads`：输出 `components[].primitiveId/designator/layer/x/y/rotation/bbox/pads`。
     → 这可能是 R2/R5 里"缺焊盘级诊断"的替代路径（**未验证**：本轮无窗口，未取到真实 pads 内容）。
  3. **`schematic.designators.list`** 输出 `designators[] {id,parentId,key,value,visible,bbox,source}`。
     → GAP-035「传位号会 ok:false」的绕法：先用它或 `pcb.components.list` 拿到 primitiveId，再传给 `--ids`。
  4. **`easyeda call <action> --payload {...}` 通道有效**：未知动作返回 `code=UNKNOWN_ACTION`（负例验证过），
     真实动作在无窗口时报 `--doc guard: no connected window`（即"通道通、窗口缺"）。
- **triedTools**：`actions`（169 条目录）、`call pcb.silk.list`、`call pcb.components.list`、`call pcb.no.such.action`（负例）、`daemon health`
- **alternative**：**以后判断"工具能不能做某事"时，先查 `easyeda actions` 的 169 条动作，再查 `--help` 子命令**——
  两者不是一回事；把 `call` 当通用入口用。仍**未验证**的是：这些动作在真实板子上返回的数据是否够用于诊断。
- **status**：`resolved`


---

## GAP-066 「这个做不到」之前必须先扫 169 条动作目录：`pcb via-bond` 从未被试过

- **capability**：给焊盘内（EPAD 散热孔等）的无网过孔赋上该焊盘的网络，使"打过孔仍不连通"变为连通。
- **evidence**（2026-11-01 清扫动作目录时发现）：
  1. `pcb via-bond` 存在且**正是为这件事设计的**：帮助原文 = assign netless footprint-embedded vias the net of
     the pad they sit in；带 `--dry-run` 可先看计划、`--component U1` 可限定器件。
  2. 而 `capability-boundary.md` 里 **`via-bond` 出现 0 次**——`GAP-024`（焊盘内打过孔仍不连通）是**没有试过这个专用命令**
     就下了"原因是铺铜避让隔离"的结论。这条结论目前只能算**未验证**。
  3. 该命令自身还标了一条平台限制（live-verified，#118）：**赋值不能跨 `doc reload` 存活** ——
     所以 GAP-024 的结论**可能仍然成立**，但理由需要用这个工具实测后重写，而不是靠排除法。
  4. 同一轮核对中：`pcb route fill`（含跳孔布线）与 `pcb power-planes` 在 GAP-008/019/021/022/025 里**都试过**，
     那 4 条不改判；**只有 GAP-024 这一条属于"没试专用工具"**。
- **triedTools**：`actions`（169 条目录）、`pcb route --help`、`pcb via-bond --help`、历史 `pcb route fill` / `pcb power-planes` 记录比对
- **alternative**：**规矩**——下"做不到"结论前，先在 `easyeda actions` 里按语义搜一遍（`silk`/`via`/`pad`/`designator`/`drc`/`dsn`），
  确认没有专用动作再用排除法。这条已写进 `docs/boundary-root-causes.md` 的"这张图怎么用"。
- **status**：`open`（GAP-024 需用 `pcb via-bond --dry-run` → 实跑 → `pcb net-path` 复核后重写）

---

## GAP-067 playbook 门禁只查命令名、不查 flag：`--no-such-flag-xyz` 也能过

- **capability**：保证 playbook 里写的每一步**真能执行**（不只是命令存在）。
- **evidence**（2026-11-01 实测）：
  1. 造反例 playbook：`{"steps":[{"run":"pcb route fill --net A --from U1.1 --to U2.2 --no-such-flag-xyz"}]}`，
     其中 `--no-such-flag-xyz` 是**编造的**。旧门禁输出 `playbook 1 步全部命中现作命令` → **PASS（误判）**。
  2. 原因：P6 只比对 `<group> --help` 里是否有该子命令名，完全不看 flag。
  3. 修后：按**完整命令路径**取帮助（`pcb route fill --help`，而不是 `pcb fill --help`——第一版就是这么错的，
     导致把所有 flag 都判成缺失），逐 flag 比对。反例现在报
     `步骤 run='… --no-such-flag-xyz' 的 flag 不存在： --no-such-flag-xyz`（**只报那一个**）。
  4. 真 kit：`playbook 37 步全部命中现有命令；**27 个 flag 全部存在**`。
  5. 自测加断言「playbook 里编造 flag 判 FAIL」（37/37 通过）。
- **triedTools**：`pcb route fill --help`、`sch block-apply --help`、`daemon start --help`、`run.ps1 -AuditRoot`（探针 kit）、`selftest.ps1`
- **alternative**：**规矩**——"命令存在"只是第一层；凡引用工具的地方（playbook / 决策表 / 边界），
  都要能对上 flag。下一次同类风险：参数**取值**（如 `--layers 1,2` 的合法域）仍未校验，**未验证**。
- **status**：`resolved`
