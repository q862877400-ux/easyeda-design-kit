# Case: sc001-autodl-typed —— 纯 typed 生成的 ESP32 自动下载电路板

**来源**：SC-001 第 4 块，**换电路类型**（前三是 LED 指示 / AMS1117 线性稳压 / P-MOS 高侧开关；这块是**三极管电平转换的自动下载电路**，对应 ESP32 的 DTR/RTS → EN/IO0）。全部 `easyeda` typed 动作生成。

## 需求（等价于客户那句话）

> 做一块 ESP32 自动下载小模块：USB 串口的 DTR/RTS 经双三极管交叉逻辑驱动 EN 与 IO0，
> 板内四件（两个 MMBT3904 + 两个 4k7），要能直接插到排针上。

## 生成方式（全部 CLI 动作）

| 步骤 | 命令 | 结果 |
|---|---|---|
| 建工程 | `project create --name sc001-autodl-blk` | `625ab5c851244ab7aae674a65d333e34` |
| 落块 | `sch block-apply block.esp32_autodownload --at 200,450 --spacing 240 --per-row 4` | 4 件、6 网 `reconcile ✓` |
| 布局修正 | 该块模板把两个电阻夹在两个三极管中间（`6×1`/`1×6`/`6×1` 三处细缝重叠）→ `disconnect` 两电阻各 2 脚 → `sch modify` 移到 y=680/760 → `sch connect` 复原 | **0 重叠 / 0 出图纸**，0 悬空引脚 |
| 图签 | `sch titleblock`（显式 showTitle/showValue） | ok |
| 同步 PCB | `pcb import-changes` | 4 件 imported/verified |
| 板框 | `pcb outline-fit --margin 100` | 568.5 × 456.1 |
| 布线 | DSN → `pcb_autorouter -a` → `import-autoroute` | **6/6 连通，0 未连**，1788 ms |
| 交付 | `acceptance/export-delivery.ps1` | Gerber / CPL / BOM |

## 两个必须记住的坑（本块实测）

1. **`connect` 的方向必须是引脚外朝方向**：把 1 脚（左侧，外朝 180°）接成 `--direction right`
   会被几何守卫拒：`wire segment 0 (290,680)→(320,680) enters component body`。
   左脚走 left、右脚走 right，四条一次全过。
2. **`export-dsn` 会被 stale 守卫拦**：`PCB was mutated by pcb.component.attrs_backfill since the last reload`
   → 必须 `pcb save` → `doc reload` → 等窗口重新连上 → 再 `export-dsn`，否则返回
   `DSN export returned no file — the PCB may be empty or have no nets`（**误导性错误**：其实有 4 个器件）。

## 标识

| 项 | 值 |
|---|---|
| 工程 | `sc001-autodl-blk` / `625ab5c851244ab7aae674a65d333e34` |
| PCB | `999ee3ea905c1e58` |
| 原理图页 | `c3e8dde3ca77f1d8` |
| 元件 | Q1/Q2 (MMBT3904)、R1/R2 (4k7) |
| 网络 | `USB_DTR`(Q1.E/R1.1)、`USB_RTS`(Q2.E/R2.1)、`Q1_N3`(Q1.B/R2.2)、`Q1_N4`(Q2.B/R1.2)、`IO0`(Q1.C)、`EN`(Q2.C) |

## 基线（先记后动）

| 指标 | 值 |
|---|---|
| `pcb check` | **ERROR=0**，WARN=11（nonOrtho 10 / silkOverPad 1）|
| 布线 | 6/6 连通，0 未连 |
| `sch check` | 0 悬空引脚；仅 `missing-partition` 类建议项 |

## 口径

- WARN 不参与验收判据（判据只看 ERROR 数）。
- 本板 4 个器件、6 个网里 2 个是单端网络（IO0/EN 只有器件脚），属设计意图（对外接排针），不是缺失。
