# Case: sc001-ldo-typed —— 纯 typed 生成的 LDO 供电板

**来源**：与 `sc001-led-typed` 同一样板，但换**电源类**电路块（AMS1117-3.3），用于检验管线在不同块类型上的稳定性。SC-001 第 2 块。

## 需求（等价于客户那句话）

> 做一块把 5V 转成 3.3V 的供电小板：AMS1117-3.3 + 输入/输出去耦 + 旁路，两层板，能给下游主控供电。

## 生成方式（全部 CLI 动作）

| 步骤 | 命令 | 结果 |
|---|---|---|
| 建工程 | `project create --name sc001-ldo-blk` | `7d296b6f438f4e33b04419d205f211ec` |
| 落块 | `sch block-apply block.ams1117_ldo_3v3 --at 300,400` | U1 + C1/C2/C3，**10 条 autoconnect**，3 网 reconcile 通过 |
| 布局 | `sch clusters --strict` | **4 组 0 重叠 / 0 出图纸** |
| 图签 | `sch titleblock`（显式 showTitle/showValue） | ok |
| 同步 PCB | `pcb import-changes` | **4 件** imported/verified 均 true |
| 板框 | `pcb outline-fit --margin 100` | 1017×727 |
| 布线 | DSN → `pcb_autorouter -a` → `import-autoroute` | **7/7 连通，0 未连，3 网**，116 ms |
| 交付 | `acceptance/export-delivery.ps1` | Gerber 11,485 B / CPL 1,944 B / BOM 7,014 B |

## 标识

| 项 | 值 |
|---|---|
| 工程 | `sc001-ldo-blk` / `7d296b6f438f4e33b04419d205f211ec` |
| PCB | `8ca0da711b435e06` |
| 原理图页 | `8e69ff25c793edad`（schematic `71409b1fa7a1b144`） |
| 元件 | U1（ldo.ams1117_3v3）、C1（100nF 0402）、C2（10µF 0805）、C3（22µF 0805） |
| 网络 | `+5V`（U1.VIN + C2.1）、`+3V3`（U1.VOUT + C3.1 + C1.1）、`GND`（U1.GND + C1/C2/C3.2） |

## 基线（先记后动）

| 指标 | 值 |
|---|---|
| `pcb check` | **ERROR=0**，WARN=22（nonOrtho 14 / widthUnderSpec 2 / powerNotPoured 3 / decapTooFar 3，均建议项） |
| `pcb drc` | `Netlist Error 1`（与第 1 块同现象；`board rebind` 后仍在） |
| `pcb layout-lint` | **score 100/100**，0 short / 0 overlap / 0 off-board，0 signal nets（已全布） |
| `sch check` | 0 floating pin / 0 marker-overlap |

## 已知口径

- `Netlist Error 1` 属既有状态，照实报告（GAP-033），不为变绿改判据。
- 22 条 WARN 全是**建议类**（非正交走线、线宽下限、散热铜、去耦距离），不是 ERROR；
  验收判据看 `ERROR` 数，不看 WARN 数。
