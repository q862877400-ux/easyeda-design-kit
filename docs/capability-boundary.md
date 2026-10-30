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

## GAP-006 没有 `silk-list` 这类 CLI 查询命令

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
- **triedTools**：`pcb.export.gerber`、`pcb.export.pick_place`、`pcb.export.bom`
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
