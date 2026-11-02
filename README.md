# EasyEDA Design Kit

> 一套**给 AI 用**的嘉立创 EDA（EasyEDA 专业版）画板工具包：把「画一块板」变成**可执行的步骤 + 可机器验证的验收**。
> 它让 AI 能把板子画出来，并且**不能靠嘴说自己画完了**——每一步都要过门禁。

**当前状态：能用，但只在一个窄带里。** 下面第 3 节是实测数字，第 6 节是它做不到什么。

---

## 1. 它解决的具体问题

让 AI 画板，失败通常不是"不会画"，而是三件事：

| 问题 | 具体表现 |
|---|---|
| **不知道调哪个工具** | 装着上百个扩展、几百条命令，仍然靠试错 |
| **没法判断"画完没有"** | 「器件落下去了」被当成「板子做好了」；DRC 没跑就说完成 |
| **能力留不下来** | 每次会话从零开始，上一轮怎么解决的没人知道 |

这套包对应三件东西：**情境→工具决策表**（`docs/tool-decision-table.md`）、**三态验收门禁**（`acceptance/`）、**能力边界清单**（`docs/capability-boundary.md`，93 条，每条五要素：能力 / 证据 / 试过的工具 / 替代方案 / 状态）。

---

## 2. 它是什么 / 不是什么

**是**：

- 一份可装进任意 harness 的 **skill 目录**（`SKILL.md` + `docs/` + `playbooks/`）
- 一套 **CLI 驱动脚本**：`acceptance/*.ps1`（只调用现成工具，不自己实现画板能力）
- 一套 **验收判据**：23 个阶段、三态结论（PASS / FAIL / BLOCKED），`BLOCKED` 永不算通过

**不是**：

- 不是 EDA 软件，也不重新实现布线器——它**驱动**已有的嘉立创 EDA 及其扩展
- 不是"输入一句话就出板"的魔法：**需求→电路这一步目前不可靠**（见第 6 节）
- 不是产品级认证：作者是 AI 代理，不是硬件工程师

---

## 3. 当前实测状态（2026-11-02）

```
自测         46 PASS / 0 FAIL / 0 SKIP       acceptance/selftest.ps1
错误矩阵     16/16 历史事故全部能被拦住       acceptance/mistake-matrix.ps1
静态验收     12 PASS / 1 FAIL / 0 BLOCKED    acceptance/run.ps1 -Static
完整跑一块板 21 PASS / 2 FAIL / 0 BLOCKED
```

唯一 FAIL 是 `decision-actionability`：**78/127 = 61.4%**（决策表里"参数具体到可执行"的行占比）。剩下的行多为未安装扩展的目录信息，没有 CLI 等价物。

**五块自造板的 DRC 明细一致**：间距/清晰度类违规 **0 条**；每块剩 1 条 `Netlist Error`，原因是 **PCB 只实现了整份原理图的一部分**（实测某板 PCB 6 器件 vs 原理图 43 器件）——属设计范围问题，不是几何不合格。

---

## 4. 怎么自己验（三分钟，不需要 EDA 在线）

```powershell
# 1) 自测：46 条断言，验证"判据本身"是否可信
pwsh -NoProfile -File acceptance/selftest.ps1

# 2) 错误矩阵：16 类历史真实事故，确认都能被拦住
pwsh -NoProfile -File acceptance/mistake-matrix.ps1

# 3) 静态验收：12 项（文档一致性、声明与实测一致、边界五要素、判据自身合理）
pwsh -NoProfile -File acceptance/run.ps1 -Case sc001-usbc-typed -Static
```

跑一块真实板子需要 EasyEDA 在线（浏览器 + 连接器扩展 + daemon），见 `docs/README.md`。

---

## 5. 目录

```
SKILL.md                 技能入口（给模型看的第一层）
PRODUCT.md               产品定义（含已知不能做的部分）
docs/                    知识包：状态页、决策表、能力边界、阅读路径、可行性实验
playbooks/               4 个可执行配方（37 步），覆盖四类小电路
acceptance/              验收：run.ps1（23 阶段）、selftest.ps1、mistake-matrix.ps1、
                         export-delivery.ps1、epru-audit.ps1、prune-runs.ps1、cases/、runs/
specs/004-ai-pcb-design-kit/   规格、计划、任务、数据模型
.githooks/pre-commit     提交前强制跑三件套，绕过会失败
```

**复用优先是硬规则**：默认零自有代码。先查扩展中心（`docs/extensions-index.md`），再查命令层与类型化动作，都覆盖不了才补工具，并在 `docs/capability-boundary.md` 记录缺口证据。

---

## 6. 已知局限（实测得出，不是推测）

| # | 局限 | 证据 |
|---|---|---|
| 1 | **需求→电路不可靠，会漏功能项** | 对开源项目做实验：第一版漏掉 I²C 电平转换（**电气错误**）；第二版补上，**又漏"没有 MCU 也能用"的档位配置** |
| 2 | **选型不可靠** | 实验中把"四联电阻排（8 脚）"当单只电阻用，被 `sch check` 的"6 引脚悬空"抓住 |
| 3 | **"DRC 全绿"在子板设计下不可达** | 结构性 `Netlist Error`，除非把 PCB 做成整机 |
| 4 | **大板受 A4 限制** | 六件块实测 672 mil vs 可用 627 mil；且没有改图纸尺寸的 API |
| 5 | **无电路仿真** | 本机未装 SPICE，电源完整性只能靠规则检查 |

完整实验记录（含命令、报错、对比数字）：`docs/feasibility-001-ch224a.md`。

---

## 7. 这套东西最适合怎么用

**推荐**：你给出**明确的电路与器件清单**，它负责画对、画完、自证（DRC / DFM / 交付物 / 阶段门禁）。

**不推荐**：让它从一句模糊的功能描述独立设计电路——第 6 节第 1、2 条讲的就是这件事。

---

## 8. 前置条件（安装一次）

1. **EasyEDA Pro**（含扩展中心可访问）
2. **能力基础设施**：`easyeda` CLI 与 EDA Agent Connector 扩展（由既有项目提供，独立安装升级）
3. 需要时在扩展中心安装流程文档点名的扩展

本仓库**不重新实现**上述基础设施。

---

## 9. 许可

MIT，见 [LICENSE](LICENSE)。

作者是 AI 代理（DeepSeek Harness 上的 lead agent），并非硬件工程师。板级结论请以你自己的复核为准。
