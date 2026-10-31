# Case: sc001-led-typed —— 纯 typed 生成的最小指示板

**来源**：不是别人画的板，也不是手画的板；由 `easyeda` typed 动作现场生成（SC-001 的"未见板"素材）。

## 需求（等价于客户那句话）

> 做一块最小的 LED 指示板：一个 GPIO 输入经限流电阻驱动一颗黄色 0805 LED 到地，两层板即可。

## 生成方式（全部 CLI 动作，无 GUI、无粘贴）

| 步骤 | 命令 | 结果 |
|---|---|---|
| 建工程 | `project create --name sc001-led-blk --open` | 自带 `Schematic1/P1` + `Board1/PCB1` |
| 落块 | `sch block-apply block.led_indicator_gpio --at 200,450` | R1 + LED1，3 网自动连线 |
| 布局收敛 | `sch clusters --strict` / `sch layout-lint` | 0 重叠 / 0 出框 |
| 图签 | `sch titleblock --data …`（须显式 showTitle/showValue） | 缺图签项归零 |
| 同步 PCB | `pcb import-changes` | imported=true verified=true，2 件 |
| 板框 | `pcb outline-fit --margin 100` | 476×291，已锁定 |
| 布线 | `pcb route fill --net LED1_N2 --from R1.2 --to LED1.1` | found，7 段 |
| 交付 | `acceptance/export-delivery.ps1` | Gerber 10,150 B / CPL 1,040 B / BOM 6,815 B |

## 标识

| 项 | 值 |
|---|---|
| 工程 | `sc001-led-blk` / `337b5613358540d69ee8efdb4d24a5df` |
| PCB | `1e56ec91cd0bad4b` |
| 原理图页 | `8124aea12d407530` |
| 元件 | R1（res.1k_0402）、LED1（led.yellow_0805） |
| 网络 | `LED_CTRL`（R1.1，外部）、`LED1_N2`（R1.2–LED1.+，板内）、`GND`（LED1.−，外部） |

## 基线（接手时状态，先记后动）

| 指标 | 基线值 |
|---|---|
| `pcb check` | **0 issue(s)**（7 track / 4 pad，零违规形态，无 `ERROR=` 计数行） |
| `pcb drc` | `Netlist Error 1`（`board rebind` 后仍为 1） |
| `pcb layout-lint` | **score 100/100**，0 short / 0 overlap / 0 off-board / 1 signal net / 0 crossings |
| `sch check` | 0 floating pin / 2 marker-overlap(WARN) / 0 missing-deliverable |
| `sch drc` | 0 fatal / 0 error / 3 warn |

## 已知口径

- 这块板只有 **1 条板内信号网**（`LED1_N2`）；`LED_CTRL` 与 `GND` 是原理图外部端口，PCB 上没有对接焊盘，
  因此不会产生 Connection Error，也不该为了让指标好看而硬拉走线。
- `Netlist Error 1` 属**既有状态**（见基线），按 GAP-033 的口径照实报告，不靠改判据消除。
