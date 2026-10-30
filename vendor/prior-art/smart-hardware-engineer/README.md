# 采用的上游组件：smart-hardware-engineer（Design IR + Gate-1 校验器）

**来源**：https://github.com/does-iot/smart-hardware-engineer（MIT，见同级 LICENSE）
**引入理由**：本 Kit 缺少「设计的中间表示」——直接从需求跳到 EDA 操作，导致（a）无法离线自检，
（b）改一次要重画一次。该项目的 Design IR 正是这个缺口的通用解法，且**不依赖它的控制通道**。

## 采用了什么

| 文件 | 作用 |
|---|---|
| `ir/schema/design_ir.schema.json` | 设计 IR 的 JSON Schema（draft 2020-12）|
| `ir/examples/blinky_usb_mcu.ir.json` | 通过校验的样例（USB-C 点灯板）|
| `scripts/ir_validate.py` | Gate-1 离线校验器（结构/连通/电源树/去耦/命名/占位料号）|
| `ir/README.md` | 上游对 IR 生命周期的说明（原样保留）|

## **没有**采用什么（重要）

| 上游组件 | 为什么不采用 |
|---|---|
| `she-mcp`（Node MCP，8765）| 与本机控制通道不同（我们用 `easyeda` CLI + Connector，端口 60832-60841）|
| `jlceda-extension` | 同上；且需要单独构建安装 |
| `scripts/eda_doctor.py` / `eda_recover.py` / `check_jlceda_bridge.py` / `cdp_eval.py` | 绑定其桥/CDP/copilot 端口，本机不适用 |
| `memory/L0-L2` | 我们有自己决策表与边界清单；**内容可交叉引用**，但不引入其目录结构 |
| `capabilities.yaml` | 我们用 `capability-boundary.md` + `capability-boundary` 门禁表达同一意图 |

## 本机适配注意

- 该校验器在 **Windows 控制台 GBK** 下会因打印 `⚠️` 崩在输出阶段（逻辑已完成）。
  运行前设 `PYTHONUTF8=1`（我们的 `design-ir` 阶段已强制设置）。
- 用法：`python scripts/ir_validate.py <design.ir.json>`；exit 0 = 无 error。
- **未验证**：上游其它脚本与本 Kit 的协同；IR → 本机 CLI 的确定性驱动仅做了门禁集成，未做自动落图。
