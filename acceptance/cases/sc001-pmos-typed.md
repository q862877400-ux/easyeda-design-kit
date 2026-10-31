# Case: sc001-pmos-typed —— 纯 typed 生成的 P-MOS 高侧负载开关板

**来源**：SC-001 第 3 块，**换电路类型**（前两块是 LED 指示、LDO 线性稳压；这块是**MOS 高侧开关 + 软启动**）。全部由 `easyeda` typed 动作生成，无 GUI、无坐标粘贴。

## 需求（等价于客户那句话）

> 做一块用 GPIO 控制的高侧负载开关小模块：P-MOS 门控 3.3V 输出，带栅极电容与 RC 软启动，防止上电冲击主轨。

## 生成方式（全部 CLI 动作）

| 步骤 | 命令 | 结果 |
|---|---|---|
| 建工程 | `project create --name sc001-buck-blk` | `dcedf18d0cae4227900811e5ad625f5e` |
| 落块 | `sch block-apply block.pmos_highside_softstart --at 250,350 --spacing 220 --per-row 3` | 6 件、7 网 reconcile ✓ |
| 布局门禁 | `sch clusters --strict` | **6 组 0 重叠 / 0 出图纸** |
| 图签 | `sch titleblock`（显式 showTitle/showValue） | ok |
| 同步 PCB | `pcb import-changes` | 6 件 imported/verified ✓ |
| 板框 | `pcb outline-fit --margin 100` | 高 391 |
| 布线 | DSN → `pcb_autorouter -a` → `import-autoroute` | **15/15 连通，0 未连，7 网**，135 ms |
| 交付 | `acceptance/export-delivery.ps1` | Gerber 16,151 B / CPL 2,882 B / BOM 7,111 B |

## 关键参数发现（写回 GAP-042）

块落不下时**不要只试 `--at`**：这块 6 件在默认 grid 下报 3 处重叠（31×11 / 21×11 / 17×11），
改用 **`--spacing 220 --per-row 3`** 后 **0 重叠 0 出图**且网表对齐。
即：6 件块**能在 A4 内放下**，之前"差 45 mil 放不下"的结论至少对块类型敏感，不能一概而论。

## 标识

| 项 | 值 |
|---|---|
| 工程 | `sc001-buck-blk` / `dcedf18d0cae4227900811e5ad625f5e` |
| PCB | `175915bd60bfa38e` |
| 原理图页 | `745035b90b6cc586` |
| 元件 | C1(100nF) Q1(S8050) Q2(SI2301) R1(10k) R2(100k) R3(10k) |
| 网络 | `+3V3`(Q2.S/R2.1/C1.1)、`C1_N2`(Q2.G/R2.2/C1.2/R3.1)、`C1_N3`(R3.2/Q1.C)、`C1_N4`(Q1.B/R1.1)、`PWR_EN`、`GND`、`+3V3_SW` |

## 基线（先记后动）

| 指标 | 值 |
|---|---|
| `pcb check` | **ERROR=0**，WARN=29（nonOrtho 26 / silkOverPad 2 / powerNotPoured 1） |
| `pcb layout-lint` | 88/100，0 short / 0 overlap / 0 off-board |
| `sch check` | 0 floating pin / 0 marker-overlap；1 WARN `missing-partition`（未画分区框，建议项） |

## 已知口径

- 29 条 WARN 全是建议项（非正交走线为主），验收判据只看 ERROR 数。
- `missing-partition` 是**建议**不是错误：本板只有一个功能模块，未画分区框不影响可制造性。
- 与另两块板一样保留既有 `Netlist Error`（若有），不为变绿改判据。
