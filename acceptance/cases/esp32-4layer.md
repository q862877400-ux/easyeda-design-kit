# 验收用例：esp32-4layer

**用途**：已知需求基线用例。产品的「未见板」用例另见 `unseen-a.md` / `unseen-b.md`（由业主出题或批准）。

**状态**：此用例当前**未通过**——它存在的意义是把失败点顶出来，而不是展示成功。

## 需求原文（客户口径）

- **四层板**：2 层 GND + 1 层内电层 + 1 层 VCC 电源层
- **丝印**：必须有
- **供电**：板载 5V 接线端子；插 USB 也能供电（共用一路 5V）；降压模块 5V→3.3V 给主控
- **下载调试**：板载 CH340 USB 转串口；BOOT + RESET 两个按键
- **点灯**：一个 LED，附近丝印标 +/− 正负极
- **结构**：四角各一个 M3 螺丝孔
- **其他**：符合电气规范、良好信号完整性、考虑散热、必要接口连接器

## 通过判据（由 `acceptance/run.ps1` 判定，不由执行者声称）

| 阶段 | 判据 |
|---|---|
| kit-integrity | 7 份必需文档齐备 |
| tool-decision-table | ≥30 个情境，点名工具全部可解析 |
| environment | EDA 窗口在线 |
| schematic-gates | sch drc passed |
| pcb-layout | 0 短路 / 0 重叠 / 0 出框 |
| pcb-connectivity | Connection Error = 0 |
| pcb-dfm | DFM ERROR = 0 |
| delivery | Gerber / 钻孔 / 坐标 / BOM 均非空 |
| no-oneoff-scripts | 审计日志里临时脚本 = 0 |

## 已知当前缺口（写于 2026-10-31，供对照）

- 决策表、边界清单、阶段文档、playbook 索引**尚未编写** → kit-integrity 必然 FAIL
- 交付导出尚无可用路径 → delivery 将 FAIL/BLOCKED
- 板上仍有未连网络 → pcb-connectivity 将 FAIL

这份缺口的价值：它把「产品还差什么」变成一张可执行的清单，而不是我的叙述。
