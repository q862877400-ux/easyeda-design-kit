# Implementation Plan: EasyEDA AI Design Kit

**Branch**: `004-ai-pcb-design-kit` | **Date**: 2026-10-31 | **Spec**: [spec.md](./spec.md)

**Input**: Feature specification from `specs/004-ai-pcb-design-kit/spec.md`

## Summary

产品要交付的不是代码，而是**可安装、可验收的能力**：装上它，任何模型在任意 harness 上，
只凭一段需求文本就能把板子画到可打样。

技术路线据此定为**三层、零自有实现**：

1. **能力知识层**（Markdown + JSON）：情境→工具决策表、分阶段流程、设计规则、能力边界；
2. **接口层**（复用既有基础设施）：`easyeda` CLI、169 个类型化动作、扩展中心 75 个扩展；
3. **验收层**（PowerShell 脚本）：三态判定（PASS / FAIL / BLOCKED）+ 双向门禁
   （正向是否在长能力、负向是否再犯历史错误）+ 错误矩阵（16 条历史错误回放）。

Kit 仓库**不含任何 `src/` 实现代码**——这一条由门禁 P3 机械强制，因为过去 49 轮的教训是：
一旦允许"顺手写个实现"，就会退化成手搓，而不是复用扩展中心。

## Technical Context

**Language/Version**: PowerShell 7（门禁脚本） + Markdown / JSON（技能包内容）。无编译产物。

**Primary Dependencies**（均为**外部既有**，不在本仓库实现）：
- `easyeda` CLI（EDA Agent Connector 的 CLI 面；安装于 `%USERPROFILE%\.local\bin\easyeda.exe`）
- EDA Agent Connector 扩展（EasyEDA Pro 内，端口 60832–60841）
- EasyEDA Pro 4.1.78+ 与扩展中心（75 个已装扩展，见 `docs/extensions-index.md`）

**Storage**: Git 仓库；内容为 Markdown、JSON fixture、playbook。无数据库。

**Testing**:
- `acceptance/run.ps1` —— 9 个阶段的三态验收（静态阶段可在无 EDA 窗口时跑）
- `acceptance/selftest.ps1` —— 门禁自测，8 条断言（每个分支的正例+反例）
- `acceptance/mistake-matrix.ps1` —— 历史错误矩阵，16 条用例，要求 16/16 抓到

**Target Platform**: Windows（PowerShell 7）。跨平台移植不在首选范围，但脚本不依赖 Windows 专有 API。

**Project Type**: 能力包（文档 + 校验脚本） + 可安装扩展形态；**不是** application / library。

**Performance Goals**:
- 纯静态验收（无工程、无 EDA 窗口）**≤ 90 秒**（当前实测约 40–60 秒）
- 单块板的端到端执行**≤ 2 小时**（含求解与铺铜；该数字待 P4 用未见板校准）
- 决策表规模：当前 **84 行**，目标 **≥ 120 行**（覆盖八类流程的实际情境）

**Constraints**:
- **零一次性脚本**：所有对工程的写入必须来自具名命令或可回放 playbook（SC-003）
- **三态诚实**：缺前置条件报 BLOCKED，不得报 PASS；交付物查存在且非空
- **换模型仍成立**：至少一个不同模型复跑通过（SC-004）
- 一次验收只覆盖**单块板**；拼板/多板不在首选版
- 不改客户给定板框（禁止 `pcb outline-fit`）

**Scale/Scope**:
- 目标板：ESP32-S3 四层板（2 层 GND + 内电层 + VCC），板框由客户给定
- 验收用例：1 个已知基线（`esp32-4layer`） + **2 个未见板**（P4 阶段由业主出题或批准）
- 阶段文档：原理图 S0–S6、PCB P0–P10，共 17 个阶段

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

> **发现（必须先说）**：`.specify/memory/constitution.md` 仍是**未填的模板**（占位符 `[PRINCIPLE_1_NAME]` 等原样保留）。
> 也就是说本项目**没有正式批准的宪法**。不掩盖这一点：本计划改用**已达成的产品约定**作为临时门禁来源，
> 并在 tasks 中安排一次 `speckit-constitution` 把这五条正式写入宪法。

临时门禁（来源：`easyeda-design-kit/PRODUCT.md` + 本特性 spec 的 SC）：

| # | 门禁 | 来源 | 当前状态 |
|---|---|---|---|
| G1 | **复用优先**：扩展中心 → 命令层 → 才轮到自有代码，且自有代码必须带缺口证据 | PRODUCT §4 / FR-010 | PASS（kit 内零实现代码，P3 在跑） |
| G2 | **机械可验证**：结论必须来自脚本退出码，不来自叙述 | spec SC-001/003 | PASS（run.ps1 + selftest + matrix） |
| G3 | **三态诚实**：PASS/FAIL/BLOCKED 不混淆 | spec FR-009 | PASS |
| G4 | **零一次性脚本** | spec SC-003 | PASS（N1 强制） |
| G5 | **模型无关**：换模型仍通过 | spec SC-004 | **未验证**（P4 才可能证明） |

G5 未验证是**已知且允许的**当前状态：它只能在 P4 用未见板 + 换模型时被证伪或证实。

## Project Structure

### Documentation (this feature)

```text
specs/004-ai-pcb-design-kit/
├── plan.md              # 本文件
├── research.md          # Phase 0：待定项的决策与理由
├── data-model.md        # Phase 1：实体与校验规则
├── quickstart.md        # Phase 1：可跑的验证场景
├── contracts/           # Phase 1：决策表行 / playbook / 验收报告 的契约
│   ├── decision-row.schema.md
│   └── acceptance-report.schema.md
└── tasks.md             # Phase 2（由 /speckit-tasks 生成）
```

### Source Code (repository root)

**本特性不产生应用源码。** 交付物仓库为 `easyeda-design-kit/`，结构如下（`src/` 刻意不存在）：

```text
easyeda-design-kit/
├── README.md
├── PRODUCT.md
├── docs/
│   ├── anti-drift.md            # 反目标偷换的纪律与判据
│   ├── retro-audit.md           # 用门禁回测历史的记录
│   ├── tool-decision-table.md   # 84 行「情境 → 工具 → 坑」
│   ├── capability-boundary.md   # 待建（P1）
│   ├── design-rules.md          # 设计规范手册
│   ├── extensions-index.md      # 75 扩展索引
│   └── phases/                  # 待建（P1）
│       ├── schematic-s0-s6.md
│       └── pcb-p0-p10.md
├── playbooks/                   # 可回放链路 + README（待建）
├── acceptance/                  # 门禁与测试（已建）
│   ├── run.ps1                  # 9 阶段三态验收
│   ├── stages-gates.ps1         # 双向门禁
│   ├── selftest.ps1             # 门禁自测（8 条）
│   ├── mistake-matrix.ps1       # 历史错误矩阵（16 条）
│   ├── baseline.json            # 棘轮基线
│   ├── cases/                   # 验收用例
│   └── fixtures/                # 运行日志 fixture
└── specs/                       # 本规格副本
```

**Structure Decision**:
选择「文档 + 校验脚本」单仓结构，**明确放弃 `src/`**。理由：

1. 产品价值在**决策层与验收层**，实现层由扩展中心与 CLI 提供；
2. 允许自有源码会直接诱发过去 49 轮的失败模式（手搓布线器/DFM 而非复用 PCB Auto Router、嘉立创下单检查）；
3. 该约束可机械检查（P3 扫描 `*.go/*.ts/*.js`），因此不依赖自觉。

如果将来出现**扩展确实覆盖不了**的缺口，处理方式是：在 `docs/capability-boundary.md` 记录缺口证据
（试过哪些扩展、为何不足），再**在该文件对应的独立仓库**中实现，而不是让 kit 长出 `src/`。

## Complexity Tracking

| 项 | 为何需要 | 为什么不选更简单的做法 |
|---|---|---|
| 三套测试脚本（run / selftest / matrix） | 门禁本身曾两次静默失效（非法正则、判据只看关键词），只测被测物不测尺子会重犯 | 只保留 run.ps1 会让门禁的失效无人发现；实测中矩阵三次抓出我写错的 fixture |
| 双向门禁（正向 + 负向） | 只抓错则"不犯错"时永远绿灯，缺乏正向要求 | 只做负向无法阻止"用整理/精简掩盖能力退化" |
| JSON fixture 而非真实历史 | 历史无法在 CI 里重放；乱真会产生误判 | 直接用真实日志不可复现，且涉及外部工程状态 |
| 无 `src/` | 见上 | 有 src 就会手搓，这是已验证的行为模式 |
