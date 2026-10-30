# PCB 阶段 P0–P10

**用途**：把"画 PCB"拆成 11 个有进入/退出判据的阶段。`退出判据` 必须是命令或数字。

**通用纪律**

- 布线与铺铜**优先用已装工具**：`JsPCB自动布线`、`嘉立创下单检查`、命令层 `pcb route fill` / `pcb pour-fit`。**注意：`PCB Auto Router`、`内电层自动分划`、`自动生成铜皮`、`生成丝印` 本机未装**（见 `docs/extensions-index.md` 的已核实装机清单）。
- 顺序不可乱：**先结构 → 再规则 → 再布局 → 再布线 → 再铺铜 → 最后校验**。
  乱序的代价是重布线（历史实测：先铺铜后改布线，Clearance 假性恶化 18→26）。
- 任何落铜之后必须 `pcb pour-rebuild` 再读 DRC（`GAP-009`）。

---

## P0 板框与结构

| 项 | 内容 |
|---|---|
| **进入条件** | S6 PASS |
| **动作** | 客户给定板框直接采用 / `板框定位孔生成助手`（四角 M3）/ `智能尺寸`（若需精确标注） |
| **退出判据** | ① 板框四角坐标与需求一致；② 4 个 M3 孔在位且不与器件冲突；③ **未使用** `pcb outline-fit`（客户板框不可改） |
| **失败处置** | 孔位冲突 → 调布局，不改板框 |

---

## P1 叠层与设计规则

| 项 | 内容 |
|---|---|
| **进入条件** | P0 PASS |
| **动作** | `设计规则生成器`（含嘉立创 12 种阻抗模式、叠层库）/ `规则配置管理`（导出/迁移） |
| **退出判据** | ① 四层叠层（GND / 内电层 / VCC / 信号）定义完成；② 线宽阶梯与电流匹配（信号 9.84 / 电源 15.75 / 高电流 19.69 mil）；③ 规则**已激活**（生成器默认只另存不激活，需手动确认） |
| **失败处置** | 规则未激活 → 手动激活后再布局 |

---

## P2 导入变更与器件落位

| 项 | 内容 |
|---|---|
| **进入条件** | P1 PASS，原理图已导出 |
| **动作** | PCB 侧「导入变更」/ `pcb import-changes` |
| **退出判据** | ① 器件数与原理图一致；② 每个焊盘有网络（无 `netless`）；③ 无重叠、无出框（`pcb layout-lint` 报 0/0/0） |
| **失败处置** | 少器件 → 回 S6；无网络 → 回 S3 查连接 |

---

## P3 模块化布局

| 项 | 内容 |
|---|---|
| **进入条件** | P2 PASS |
| **动作** | `PCB自动化工具`（整版全自动模块化布局）/ `PCB器件分组器`（按图页分组）/ `pcb place-constrained`（约束布局） |
| **退出判据** | ① 每个功能块聚成一团且互不重叠；② 连接器在板边、朝向合理；③ `layout-lint` 0 重叠 0 出框；④ 飞线总长较导入时下降（`pcb layout-lint` 的 `ratsnest` 数字） |
| **失败处置** | 仍重叠 → 用 `-constrained` 逐块锁定后重排 |

---

## P4 关键器件约束布局

| 项 | 内容 |
|---|---|
| **进入条件** | P3 PASS |
| **动作** | 手工/命令微调：去耦电容贴近电源脚、`BGA 滤波电容放置`（若有 BGA）、晶振靠近主控 |
| **退出判据** | ① 去耦电容到电源脚距离小于工艺要求；② 晶振不跨分割；③ 关键网络飞线不再交叉（或已接受） |
| **失败处置** | 放不下 → 回 P3 重排该模块 |

---

## P5 扇出

| 项 | 内容 |
|---|---|
| **进入条件** | P4 PASS |
| **动作** | `PCB自动化工具`（管脚扇出打孔 / 模块自动扇出打孔）/ `焊盘扇出`（8 方向、盲埋孔）/ `电源地就近打孔` |
| **退出判据** | ① 密集封装（QFN/BGA）引脚均可出线；② 扇出过孔不压焊盘、不压丝印；③ `pcb check` 的 `viaInPad` 为 0（EPAD 散热孔除外，需单列说明） |
| **失败处置** | 出不来 → 换方向/换孔径；仍不行 → 回 P4 微调位置 |

---

## P6 布线

| 项 | 内容 |
|---|---|
| **进入条件** | P5 PASS |
| **动作** | 已装可用：`JsPCB自动布线`（全板）；命令行 `pcb route fill`（逐跳，实测主力）/ `pcb route-short`（短线）/ `pcb route solve` + playbook（难线）。**未装**：`PCB Auto Router`、`FreeRouting`、`PCB自动化工具`（需现装） |
| **退出判据** | ① `pcb drc` 的 Connection Error = 0；② Clearance Error 不高于布局阶段基线；③ 无 `dangling` 悬空端 |
| **失败处置** | 有未连 → 先查是否 `GAP-001`（需换层）；再查 `GAP-008`（缝合位不足）；**禁止**用 `rip-up --net` 撤销（`GAP-003`） |

**顺序要点**：一条一条网落线时，**每次落线前重新取快照**（否则互相看不见，Clearance 18→31 实测两次）。

---

## P7 等长与阻抗

| 项 | 内容 |
|---|---|
| **进入条件** | P6 PASS（相关网络已通） |
| **动作** | `一键等长`（蛇形/大折返）/ `走线等距` / `熔化/优化/美化PCB`（拐角圆弧、线宽平滑） |
| **退出判据** | ① 差分/总线组内长度差在设计要求内；② 阻抗线宽与 P1 的规则一致；③ `pcb check` 的 `acute`/`nonOrtho` 为 0 |
| **失败处置** | beautify 超时 → 按 `--net` 分批（`GAP-004`）；它**不会**修 acute/nonOrtho，别指望 |

---

## P8 铺铜与内电层

| 项 | 内容 |
|---|---|
| **进入条件** | P6/P7 PASS |
| **动作** | `内电层自动分划`（内电层按网络优先级分划）/ `自动生成铜皮` / `平衡铜工具` / `pcb pour-fit` + `pcb pour-rebuild` |
| **退出判据** | ① 每条电源轨有独立铜区；② `pcb.listPours` 的 `filled` 状态**明确为已填充**（`filled` 未知不算完成）；③ 无孤岛铜（`floatingIsland` = 0） |
| **失败处置** | 未填充 → `pour-rebuild`；孤岛 → 调间距或删岛 |

---

## P9 缝合与跨平面检查

| 项 | 内容 |
|---|---|
| **进入条件** | P8 PASS |
| **动作** | `pcb power-planes`（共享过孔缝合）/ `电源地就近打孔` / `跨平面检查` |
| **退出判据** | ① 缝合过孔间距均匀且 `gridAligned`（非自由角度，避免 acute/nonOrtho）；② `跨平面检查` 报告 0 条跨缝/无参考；③ GND/3V3 的 `unplaced` 为 0 |
| **失败处置** | `unplaced` > 0 → 改布局腾位（`GAP-008`），不要硬加孔 |

---

## P10 校验与交付

| 项 | 内容 |
|---|---|
| **进入条件** | P9 PASS |
| **动作** | `pcb drc`（Clearance/Connection/Netlist）→ `嘉立创下单检查`（18 项 DFM）→ `PCB Delivery Export`（Gerber+BOM+CPL）→ `装配图导出` |
| **退出判据** | ① DRC Connection = 0；② DFM **ERROR = 0**；③ Gerber/钻孔/坐标/BOM **存在且非空**；④ 版本落盘（save + reload 后复读一致） |
| **失败处置** | DFM ERROR → 按项修；交付缺项 → 报缺失，**不得**报通过 |

**权威口径**：DFM 只认 `嘉立创下单检查`；自建检查器不得作为通过依据（`GAP-010`）。

---

## 阶段依赖

```text
P0 → P1 → P2 → P3 → P4 → P5 → P6 → P7 → P8 → P9 → P10
                                   ↓         ↓
                               (落铜后必须 pour-rebuild 再读 DRC)
```

## 首选扩展速查（本阶段真正的主力）

| 阶段 | 首选扩展 |
|---|---|
| P3 布局 | `PCB自动化工具` |
| P5 扇出 | `PCB自动化工具` / `焊盘扇出` |
| P6 布线 | `JsPCB自动布线`（已装）/ `pcb route fill` |
| P7 等长 | `一键等长` |
| P8 内层 | `内电层自动分划` |
| P10 DFM | `嘉立创下单检查` |
| P10 交付 | `PCB Delivery Export` |

---

## 执行者无关性（SC-004 的依据）

同一块板由**不同执行者**（另一个模型 / 另一个全新会话）跑，下面这些**必须一致**，其余允许不同。

### 必须一致（不一致 = 产品不可信）

| 项 | 为什么不许有差异 |
|---|---|
| 各阶段的 PASS / FAIL / BLOCKED 结论 | 这是验收的唯一判据；结论不同说明流程不可复现 |
| DRC 的 Connection Error 数 | 连不上就是连不上，与执行者无关 |
| DFM ERROR 数 | 权威口径是 `嘉立创下单检查`，数字应一致 |
| 交付文件类别（Gerber/钻孔/坐标/BOM）齐备性 | 缺项是事实，不是风格 |

### 允许不同（不算不一致）

| 项 | 原因 |
|---|---|
| 布线路径的具体几何 | 求解器/自动布线器的搜索顺序可不同；只要 DRC 数字达标即等价 |
| 走线/过孔总数 | 同上，是路径差异的结果而非缺陷 |
| 阶段内耗时、命令条数 | 执行效率差异 |
| 中间过程的临时文件命名 | 不影响结果 |
| `coupling` / `acute` 等 WARN 级指标 ±少量 | WARN 不是通过判据；但**若跨越 ELIGIBLE 阈值导致 ERROR，则必须一致** |

### 怎么验证

```powershell
# 执行者 A
pwsh -NoProfile -File acceptance/run.ps1 -Case <case> -Executor "modelA/harnessA" ...
Copy-Item acceptance/last-report.json runs\a.json

# 执行者 B（另一个模型或全新会话）
pwsh -NoProfile -File acceptance/run.ps1 -Case <case> -Executor "modelB/harnessB" ...
Copy-Item acceptance/last-report.json runs\b.json

# 比对
pwsh -NoProfile -File acceptance/compare-runs.ps1 -A runs\a.json -B runs\b.json
# 退出码 0 = 阶段结论一致；1 = 有差异（会列出具体阶段）
```

**无法切换模型时**：用"全新会话 + 零上下文"代替，并在报告里显式标注
`弱化验证：未换模型`——不得把它写成已满足 SC-004。


### P6 补充：DSN→SES 用 PCB Auto Router 主程序（无头 CLI，实测）

```powershell
# 1) 导出 DSN（注意：CLI 输出里的 📎 行会破坏 JSON 解析，用正则抓 .dsn 路径）
easyeda pcb export-dsn --project <工程> --doc <PCB uuid>
#    实测产物 131 KB，含 keepout 段落（否则布线器会从天线下方走线）

# 2) 无头布线（主程序在 C:\Program Files\PCBAutoRouter\pcb_autorouter.exe）
& "C:\Program Files\PCBAutoRouter\pcb_autorouter.exe" -i board.dsn -a -o board.ses --threads 8 --auto-rules

# 3) 导回 SES
easyeda pcb import-autoroute board.ses --project <工程> --doc <PCB uuid>
```

**额度**：注册会员（免费）网络 100 / 焊盘 600 / 4 层；本板 21 / 279 / 4 层在限额内。
**前置**：主程序必须已登录（原生 GUI 登录一次即可），否则报 `design exceeds free version limits`。
