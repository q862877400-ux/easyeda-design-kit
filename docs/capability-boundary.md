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
  `ok:false`，`code=EDA_CALL_FAILED`，`message="BOM export returned no file."`；
  同时 `schematic.export.netlist` 等动作存在。切到原理图窗口后仍如此。
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

