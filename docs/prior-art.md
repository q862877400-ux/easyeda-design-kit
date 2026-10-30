# 生态先行者评估（prior art）

**结论先行**：我们的目标**已被多个开源项目部分实现**。经评估，本 Kit **直接采用**其中一项通用组件
（Design IR + Gate-1 校验器，MIT），**不采用**其控制通道与记忆结构；其余项目作为**交叉引用**，
不重复实现。

---

## 1. 现有项目对照

| 项目 | 做了什么 | 与本 Kit 的关系 | 我们的决策 |
|---|---|---|---|
| [does-iot/smart-hardware-engineer](https://github.com/does-iot/smart-hardware-engineer) | 自然语言 → 投板文件；**Design IR + 离线校验 + 确定性驱动**；自建 MCP 通道；分层记忆 L0–L2 + 蒸馏；能力自评；环境自愈 | **重合度最高**：IR、门禁、能力自评、记忆都对应我们的缺口 | **采用 IR 与校验器**；不采用其通道/记忆/自愈脚本 |
| [i1619khz/jlceda](https://github.com/i1619khz/jlceda) | 72 个 MCP 工具，AI 驱动 PCB 流水线 | 工具面与本机 CLI（169 动作）重叠 | 交叉引用；不引入 |
| [keiller9/AI-EDA](https://github.com/keiller9/AI-EDA) | 122 个 MCP 工具，Claude Code ↔ JLCEDA Pro 桥 | 同上 | 交叉引用；不引入 |
| [zhoushoujianwork/easyeda-agent](https://github.com/zhoushoujianwork/easyeda-agent) | 我们正在用的 CLI/Skill/MCP 三形态（169 动作，794★） | **本 Kit 的基础设施** | 已依赖 |
| [yufeiyufei888/electronic-design-skills-toolkit](https://github.com/yufeiyufei888/electronic-design-skills-toolkit) | EasyEDA API 文档技能包 | 文档参考 | 交叉引用 |

**为什么不能整体照搬任何一个**：它们都自带**控制通道**（MCP + 各自扩展，端口 8765/8787 等），
而本机已装的是 `easyeda` CLI + Connector（60832–60841）与 169 个类型化动作。
换通道 = 重装一轮环境，且会把「已能用的东西」换掉。**能搬的是纯数据与纯脚本**。

---

## 2. 已采用：Design IR + Gate-1 校验器

**位置**：`vendor/prior-art/smart-hardware-engineer/`（含 LICENSE，MIT）

| 文件 | 作用 |
|---|---|
| `ir/schema/design_ir.schema.json` | 设计 IR 的 JSON Schema |
| `ir/examples/blinky_usb_mcu.ir.json` | 通过校验的样例 |
| `scripts/ir_validate.py` | 离线校验：结构 / 连通性 / 电源树 / 去耦 / 命名 / 占位料号 |

**实测（本机，2026-10-31）**

```
python scripts/ir_validate.py ir/examples/blinky_usb_mcu.ir.json   → 结果: 通过（0 error）  exit 0
（删掉 meta 后再跑）                                                  → 结果: 未通过（1 error） exit 1
```

**本机适配**：Windows 控制台 GBK 下会在打印 `⚠️` 时崩（逻辑已完成）；必须设 `PYTHONUTF8=1`。
我们的 `design-ir` 阶段已强制设置。

**接入形态**：`acceptance/run.ps1` 新增阶段 `design-ir`（需 `-IR <file>`）：
无 IR → `BLOCKED`；IR 通过 → `PASS`；未通过 → `FAIL`（带校验器原话）。

**为什么这个缺口值得补**：本 Kit 原本从「需求」直接跳到「EDA 操作」，
导致（a）无法在落地前离线自检，（b）改一处要重画一遍。IR 把「设计是什么」与「怎么画」分开。

---

## 3. 明确未采用（附理由）

| 上游组件 | 理由 |
|---|---|
| `she-mcp`（Node MCP，8765/8787）| 与本机通道不同；换通道成本高于收益 |
| `jlceda-extension` | 同上，且需单独构建安装 |
| `eda_doctor.py` / `eda_recover.py` / `check_jlceda_bridge.py` / `cdp_eval.py` | 绑定其桥/CDP/copilot 端口，本机不适用 |
| `memory/L0–L2` | 本 Kit 用决策表 + 边界清单表达同类知识；引入会形成两套记忆 |
| `capabilities.yaml` | 本 Kit 用 `capability-boundary.md` + 门禁表达同一意图 |

---

## 4. 我们仍然独有的部分（价值所在）

| 能力 | 为什么仍然需要 |
|---|---|
| **情境→工具决策表（87 行，工具名可解析）** | 上游的 playbook 面向其自身通道；我们把「用哪个工具」变成**可机械校验**的表 |
| **双向门禁（P1–P7 正向 / N1–N9 负向）** | 上游有 gate 概念，但没有「防自己跑偏」的负向判据 |
| **历史错误矩阵（16 条）** | 把「我犯过的错」变成可回归的用例，上游没有 |
| **三态验收 + 交付证据判定** | `BLOCKED ≠ PASS`、交付按 `delivery-evidence.json` 判，不靠文件名猜 |
| **能力边界清单（13 条，含 triedTools）** | 强制"先试过现有工具"才能宣告做不到 |

---

## 5. 后续（已转为任务）

- **T050**（本轮完成）：采用 IR + 校验器并接入 `design-ir` 阶段。
- **T051**：用开源广场/开源仓库的**真实工程**做未见板用例（已下载一份 0.3 MB `.epro2` 验证格式）。
- **T052**：`.epro2` 导入为**一次性 GUI 操作**（无导入动作），导入后其余流程可全 CLI 驱动。
- **T053**：评估是否把上游 `references/` 的电路架构知识并入决策表（去重后引用，不整份复制）。
