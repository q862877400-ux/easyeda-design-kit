# 验收用例：open-source-esp32s3-usb（未见板，来自开源工程）

> **状态：已导入、已有基线、未验收（2026-11-01）。** 导入路径已跑通（工程 `ESP32S3_USB`，8 页原理图 + PCB2（**实测 2 层**，`pcb layers` 报 copperLayerCount=2），
> 见 GAP-032）。基线见文末「P4 基线」一节。**验收尚未跑**；本板当前**未布线**（ratsnest 9816 mil / 60 crossings），
> 因此 `pcb-connectivity` 与 `pcb-drc-clean` 会如实判 FAIL —— 那是这块板真实状态，不是 kit 失败。
> SC-001 的 5/5 仍全部来自五块自造板；本板用于**外部板**这条输入线。

**用途**：SC-001 要求的「此前没画过的板」用例。不用凭空出题——直接采用公开开源工程，
其需求意图、板框、器件与工艺约束都是真实存在的。

**来源与许可**

| 项 | 值 |
|---|---|
| 工程仓库 | https://github.com/11cookies11/esp32s3-usb-devboard |
| 源文件 | `design/ProPrj_ESP32S3_USB_2026-05-20.epro2` |
| 下载地址 | `https://github.com/11cookies11/esp32s3-usb-devboard/raw/main/design/ProPrj_ESP32S3_USB_2026-05-20.epro2` |
| 字节数 | **312,836** |
| SHA-256 | `9DE23C01329743C7EC527EE020A2D9C460773E1B87281BBCCB25B870D5F60DF9` |
| 实测格式 | 前 4 字节 `50 4B 03 04`（标准 ZIP）|
| 许可 | CERN Open Hardware Licence v2 – Strongly Reciprocal（仓库 LICENSE）|
| 用例性质 | **unseen**（本 Kit 未参与其设计）|
| 出题/批准 | 业主指示（2026-10-31）：可用开源广场/开源仓库的真实工程作为练习题 |

**下载与校验（可复现）**

```powershell
$url = "https://github.com/11cookies11/esp32s3-usb-devboard/raw/main/design/ProPrj_ESP32S3_USB_2026-05-20.epro2"
Invoke-WebRequest -Uri $url -OutFile esp32s3-usb.epro2 -Headers @{ 'User-Agent' = 'dsh-kit' }
(Get-FileHash esp32s3-usb.epro2 -Algorithm SHA256).Hash   # 应等于上表
```

---

## 需求（从工程与 README 的设计意图归纳，非臆造）

- **主控**：ESP32-S3（USB 直连，无需外部 USB-UART 桥）
- **供电**：USB-C 供电 + 板载稳压
- **调试下载**：USB 直连烧录；BOOT/RESET 按键
- **扩展**：GPIO 引出排针，便于原型
- **结构**：板框与安装孔按工程给定（**不得改动**）
- **工艺**：可制造（Gerber/BOM/CPL 齐备）

> 上述意图与仓库 `docs/`、`manufacturing/` 的产物一致；**未经逐条对照原理图核实**，
> 若与实际不符，以工程内原理图为准（本文件只作验收框架）。

---

## 通过判据（由 `acceptance/run.ps1` 判定）

| 阶段 | 判据 |
|---|---|
| `kit-integrity`…`capability-boundary` | 与本用例无关，按常规跑 |
| `design-ir` | 若提供 IR，必须通过（0 error）|
| `schematic-gates` | 需 `-SchDoc`；`sch drc` 不支持 doctype 时回退 `sch check` 不报错 |
| `pcb-layout` | 0 短路 / 0 重叠 / 0 出框 |
| `pcb-connectivity` | Connection Error = 0 |
| `pcb-dfm` | DFM ERROR = 0 |
| `delivery` | Gerber / 钻孔 / 坐标 / BOM 齐备且非空（按 `delivery-evidence.json`）|

---

## 当前状态：**BLOCKED（需一次 GUI 导入）**

`.epro2` 的导入**没有 CLI/动作入口**（动作目录只有 `project.export` / `export_source` /
`find` / `open`，无 `import`）。因此流程是：

1. **一次性 GUI 操作**：EasyEDA Pro → 项目管理 → 导入工程 → 选 `.epro2`；
2. 之后所有验证由 CLI 驱动（`project.find` 找到 uuid → `pcb drc` / `pcb check` / 导出动作）；
3. 用 `project.find` 拿到的 uuid 填进 `-Project` / `-Doc` / `-SchDoc` 再跑验收。

**为什么把它写成用例而不是等**：一旦导入完成，本文件就是完整的执行脚本；
未导入期间它的价值是**把"还差哪一步"钉在纸面上**，而不是含糊地说"还没开始"。

---

## 与基线用例的区别

| | `esp32-4layer` | `open-source-esp32s3-usb` |
|---|---|---|
| 来源 | 客户需求（本项目画过） | 公开开源工程（**未参与**）|
| 用途 | 回归基线（防退化） | **SC-001 未见板**（证明能力可迁移）|
| 板框 | 客户指定 | 上游工程指定（不可改） |
| 依赖 | 已有工程 | 需先导入（T052） |



---

## P4 基线（2026-11-01 实测，**先记后动**）

| 指标 | 值 | 说明 |
|---|---|---|
| 器件数 | **45**（bottom 12 / top 33） | `pcb layout-lint` |
| 信号网 | **29** | 同上 |
| ratsnest | **9816 mil** | 飞线总长 —— 说明**这块板未布线** |
| crossings | **60** | 同上 |
| `pcb drc` | **passed=False，1 条**（Netlist Error） | 未布线，故无间距违规 |
| `pcb check`（DFM） | **215 条**，含 `LIMIT`：1 个焊盘缺源形状/可读宽高 | 378 track / 90 via / 159 pad |
| `layout-lint` 得分 | **0/100（very-hard）** | 未布线 + 密集 |

**口径（GAP-033）**：外部板自带的历史问题如实记录，不改判据、不为好看调阈值。
"未布线"是基线事实，不是缺陷。

## 下一步

DSN → 外部布线器（`pcb_autorouter`）→ SES → `pcb import-autoroute`，看 45 器件 / 29 网能否跑通；
布线后复跑 `pcb drc` / `pcb check` / 验收，记录真实数字。

