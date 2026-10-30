# 把 Kit 装进任意 harness

**目标**：让一个和你无关的 harness（以及运行在其中的任意模型）拿到本 Kit 的**全部知识与流程**，
不用读本仓库历史、不用问原作者。

**当前状态**：技能包形态（skill 目录）**已验证**（本机 `easyeda-tool-router` 就是这种形态且能被加载）；
扩展包形态（嘉立创扩展中心 `.eext`）**未验证**——见 `docs/capability-boundary.md` 与
`specs/004-ai-pcb-design-kit/research.md` 的 U1。

---

## 1. 前置：三个外部依赖

| 依赖 | 作用 | 检查命令 |
|---|---|---|
| `easyeda` CLI | 所有具名命令（布线/DRC/导出/playbook） | `easyeda daemon health` |
| EDA Agent Connector 扩展 | 让 CLI 能驱动 EasyEDA Pro | 编辑器内看扩展是否启用 |
| EasyEDA Pro + 扩展中心 | 画板本体 + 75 个扩展 | 打开编辑器确认扩展列表 |

**Kit 不包含**这三样，也不重新实现它们（见宪法 I「复用优先」）。

---

## 2. 装法 A：技能包（推荐，已验证）

### 2.1 目录形态

```
<harness 的 skills 目录>/easyeda-design-kit/
├── SKILL.md                      # 见 2.2
├── PRODUCT.md
├── docs/
│   ├── tool-decision-table.md
│   ├── capability-boundary.md
│   ├── anti-drift.md
│   ├── design-rules.md
│   ├── extensions-index.md
│   └── phases/
│       ├── schematic-s0-s6.md
│       └── pcb-p0-p10.md
├── playbooks/
│   ├── README.md
│   ├── pcb-rebuild-routed.playbook.json
│   └── sch-to-pcb-import-and-place.playbook.json
└── acceptance/                   # 可选：只有想让 harness 自证时才装
```

### 2.2 `SKILL.md` 的 frontmatter

harness 只看得到 `name` 与 `description`（模型据此决定要不要加载）。`description` 必须写成
**触发条件**，而不是功能列表：

```markdown
---
name: easyeda-design-kit
description: >-
  在嘉立创 EDA / EasyEDA 专业版里把电路板从需求画到可打样时用——先查「情境→工具」决策表，
  再按 S0–S6 / P0–P10 阶段推进，最后用验收脚本判定是否真的画完。
  触发：客户给了画板需求、要新建/修改 PCB、要布线路由/铺铜/DFM/导出 Gerber、
  或用户说「按规范画一块板」「别手搓，用现成工具」。
  NOT for: 纯 EDA 资料问答、只看不改的电路学习、不涉及画板的通用编程。
---
```

正文第一段 MUST 写清**从哪读起**（顺序：决策表 → 阶段文档 → 边界清单），否则模型会随机翻。

### 2.3 安装后自检

让模型回答三个问题，全部答对才算装好：

1. 「要把去耦电容挪到芯片旁边，先查哪张表？」→ 应指向 `docs/tool-decision-table.md`
2. 「布线阶段首选什么？」→ 应指向 `PCB Auto Router`（扩展），而不是自建脚本
3. 「什么情况必须停下来问人？」→ 应提到 `capability-boundary.md` 的 GAP 与 BLOCKED 三态

---

## 3. 装法 B：EasyEDA 扩展（未验证）

目标形态：在嘉立创扩展中心安装一个 AI 扩展，内含同一套流程文档与工具入口，使 EasyEDA 用户
不用碰命令行。

**已确认的约束**：扩展运行在 EasyEDA Pro 内，能调用 `eda.*` 与类型化动作，但**不能**假设存在
`easyeda` 可执行文件；因此扩展形态需要把流程文档内置为提示词/指令，把动作走扩展自身的 API。

**未完成项**：`.eext` 打包格式、manifest 字段、安装后如何注册 AI 指令——本机无样例，
需在 P5 实测后补进本文件（`research.md` U1）。

**在此之前**，扩展形态的临时替代：用扩展中心的「ai助手（deepseek-harness）」+ 本 Kit 的
`PRODUCT.md` 与 `docs/` 作为上下文。

---

## 4. 装法 C：只借文档（最低成本）

若目标 harness 只支持"给一段系统提示"，把下面三份按顺序拼进去即可：

1. `PRODUCT.md`（是什么/不是什么/三态/复用优先）
2. `docs/tool-decision-table.md`（情境→工具）
3. `docs/phases/pcb-p0-p10.md` + `docs/phases/schematic-s0-s6.md`（流程与判据）

**不要拼**
`docs/design-rules.md`（47KB 规范手册）——太大且需要按需检索；改成"需要时再读"的引用。

---

## 5. 安装后 MUST 做的事

| 项 | 原因 |
|---|---|
| 让执行者先读 `docs/anti-drift.md` | 否则会退化成"用一次性脚本把这块板画出来" |
| 约定运行日志落盘方式 | 验收的 N4–N6 依赖日志；没有日志 → `BLOCKED` |
| 明确"未验证"标记规则 | 未实测的结论不得当作完成 |

---

## 6. 已知不完美（如实写）

- 扩展形态未验证（U1）。
- 「换模型一致」未验证（SC-004）；当前只能用"全新会话零上下文"作弱化验证。
- 75 个扩展的装机口径以 `easyeda actions` 为准；`docs/extensions-index.md` 里的数字是**人读说明**，
  可能与实际安装数不符（历史出现过 75/69/52 三个口径）。
