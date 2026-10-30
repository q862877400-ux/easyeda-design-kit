# 上游知识索引（按引用，不复制）

**原则**：上游 `smart-hardware-engineer` 的 `references/` 有 24 篇电路/流程知识，质量高。
**整份复制会形成第二套知识源**，与我们的决策表冲突。因此这里只做**映射与引用**：
「我们的哪一步，去读上游哪一篇」，正文不搬。

**上游地址**：https://github.com/does-iot/smart-hardware-engineer/tree/main/references
**许可**：MIT（见 `vendor/prior-art/smart-hardware-engineer/LICENSE`）

---

## 1. 阶段映射

| 我们的阶段 / 文档 | 上游参考 | 读它的理由 |
|---|---|---|
| `docs/phases/schematic-s0-s6.md` S0 需求解析 | `02-requirements-elicitation.md` | 澄清问题清单与"什么算需求明确" |
| S0 器件选型 | `06-component-selection.md` | 选型判据与替代料处理 |
| S2–S3 分页与连接 | `05-schematic-design.md` | 分页/网格/命名约定 |
| S4 电源与去耦 | `04-circuit-architecture.md` | 电源树与去耦策略 |
| S5 DRC | `10-verification-gates.md` | 门禁定义与豁免记录方式 |
| `docs/phases/pcb-p0-p10.md` P1 叠层 | `07-pcb-planning.md` | 叠层/层数规划 |
| P3–P4 布局 | `08-placement.md` | 分区与关键器件摆放 |
| P5–P7 布线/等长 | `09-routing.md` | 布线顺序与约束 |
| P10 交付 | `11-manufacturing-export.md` | 制造文件清单与检查项 |
| `docs/design-rules.md` | `04` / `09` / `10` | 与我们的规范手册互补（不替代）|
| `docs/anti-drift.md` | `16-controlled-experimentation.md` | 受控实验：先小范围试，再全量 |
| `docs/harness-install.md` | `19-eda-recovery.md` | 环境自愈思路（**脚本不采用**，通道不同）|
| `acceptance/run.ps1` 的 `design-ir` | 上游 `ir/README.md` + `scripts/ir_validate.py` | **已采用**（见 `vendor/prior-art`）|
| 板框/异形轮廓 | `07-pcb-planning.md` | 板框与定位孔策略 |
| 器件库建库 | `06-component-selection.md` | 以数据手册为证据的建库判据 |

## 2. 明确**不引用**的部分

| 上游内容 | 原因 |
|---|---|
| `13-jlceda-control.md` / `21-self-built-mcp.md` / `23-menu-control-and-logging.md` | 讲的是它们的 MCP/菜单控制通道；本机用 CLI + 动作面 |
| `14-memory-system.md` | 我们用自己的决策表 + 边界清单 |
| `15-capability-self-extension.md` | 我们用 `capability-boundary` 门禁表达 |
| `12-firmware.md` | 超出本 Kit 范围（交付板与制造文件） |
| `17-pdf-schematic-import.md` / `18-brd-board-import.md` | 我们暂不导入这两类来源；如需再评估 |

## 3. 怎么用这张表

1. 走到某阶段卡住 → 先查本表，再查 `docs/tool-decision-table.md`；
2. 引用时**写链接 + 一句话结论**，不整段抄；
3. 若上游说法与我们的实测冲突，**以实测为准**，并在 `docs/capability-boundary.md` 记一条
   （注明上游说法、我们的数据、结论差异）。

## 4. 后续

- **T053 已完成**：本文件即映射结果。
- 若将来引用量变大，再考虑把最常用的 3–5 篇做成 `docs/upstream-digest.md`（**摘要**，非全文）。
- **未验证**：上游 `references/` 内容未逐篇复核；本表只声明「值得读」，不背书其正确性。
