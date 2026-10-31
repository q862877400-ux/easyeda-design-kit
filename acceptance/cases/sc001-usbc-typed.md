# Case: sc001-usbc-typed —— 纯 typed 生成的 USB-C 输入前端板

**来源**：SC-001 第 5 块，**换电路类型**（前四是 LED 指示 / LDO 线性稳压 / P-MOS 高侧开关 / ESP32 自动下载；这块是**USB-C 输入前端**：16P 连接器 + ESD + TVS + 肖特基 OR + 双 CC 电阻）。全部 `easyeda` typed 动作生成。

## 需求（等价于客户那句话）

> 做一块 USB-C 供电输入前端：VBUS 经肖特基做二极管 OR，进 TVS 与 ESD 保护，
> 两路 CC 各挂 5.1k 下拉（UFP 声明），对外给 5V 与 D+/D−。

## 生成方式（关键几步）

| 步骤 | 命令 | 结果 |
|---|---|---|
| 建工程 | `project create --name sc001-usbc-blk` | `cdc19576cc894d3cbb1652afa3aed02f` |
| 落块 | `sch block-apply block.usbc_ufp_power_or --at 250,300 --spacing 220 --per-row 3` | 6 件、7 网；**0 出图纸** |
| 补网表 | `sch connect --pin J:A6 --net USB_HOST_DP --direction left` | reconcile ✓ 7/7 |
| 消重叠 | `sch disconnect` 6 脚 → `sch modify` 把 ESD 挪到 (350,700) → `sch connect` 6 脚（左三脚 off 18/96/174，右三脚 off 18/96/174） | **6 组 0 重叠 / 0 出图纸** |
| 标 NC | `sch no-connect --designator J --pin A8,B8` | 悬空引脚 0 |
| 图签 | `sch titleblock`（显式 showTitle/showValue） | ok |
| 同步 PCB | `pcb import-changes` | **6 件** verified |
| 板框 | `pcb outline-fit --margin 100` | ok |
| 布线 | DSN → `pcb_autorouter -a` → `import-autoroute` | **29/29 连通，0 未连**，359 ms |
| 交付 | `acceptance/export-delivery.ps1` | Gerber / CPL / BOM |

## 三个必须记住的坑（本块实测）

1. **多页实验会污染 PCB 导入**：试验过程在新页反复落块，`pcb import-changes` 一次导入了
   **30 个器件**（9 个页的块全算）。正确做法：只保留目标页，其余页 `sch clear`（**不要用
   `sch page-delete`，那是不可撤销的**），再 import，才得到 6 件。
2. **`sch no-connect` 的语法与 `connect` 不同**：要 `--designator J5 --pin A8,B8`，
   写成 `--pin J5:A8` 会**静默返回 ok:false**，引脚仍被判悬空。
3. **`destagger --apply` 会在中途掉线时留下半成品**：本次它搬到一半窗口断开，
   自动恢复失败并**打印出待手工恢复的 6 个引脚清单**（`D14:1→USB_HOST_DM` 等）。
   照那份清单逐脚 `sch connect` 即可复原——**它给清单这件事做得对**，但别以为它回滚成功了。

## 标识

| 项 | 值 |
|---|---|
| 工程 | `sc001-usbc-blk` / `cdc19576cc894d3cbb1652afa3aed02f` |
| PCB | `1e9a9a588d9158fb` |
| 原理图页 | `2e0b06dcc255e3f6` |
| 元件 | J(USB-C 16P)、D(USBLC6-2SC6 ESD)、D(TVS SMAJ5V0)、D(SS34 肖特基)、R/R(5.1k CC) |
| 网络 | `D_N1`(VBUS 段)、`+5V`、`USB_HOST_DP`、`USB_HOST_DM`、`D_N3`(CC1)、`D_N4`(CC2)、`GND` |

## 基线（先记后动）

| 指标 | 值 |
|---|---|
| `pcb check` | **ERROR=0**，WARN=57（nonOrtho 51 / coupling 2 / acute 1 / widthUnderSpec 1 / silkOverPad 1 / powerNotPoured 1 / fiducialMissing 1）|
| 布线 | **29/29 连通，0 未连**（7 网，359 ms）|
| `sch check` | 0 悬空引脚；1 处 `marker-overlap` WARN（ESD 左侧两标签视觉重叠 37.5×7.5）|

## 口径

- `clusters --strict` 与 `sch check` 的 `marker-overlap` 是**两套判据**：前者按组包络（本体+marker+桩线），
  后者按单个标签的实际矩形。本板 `clusters` 0 重叠，`sch check` 仍报 1 处标签视觉重叠——两者都记录，不掩盖。
- WARN 不参与验收判据（只看 ERROR 数）。
