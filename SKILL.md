---
name: easyeda-design-kit
description: >-
  在嘉立创 EDA / EasyEDA 专业版里把电路板落地成可打样文件、并按阶段自证时用（不负责从功能描述设计电路）——先查「情境→工具」决策表，
  再按原理图 S0–S6 与 PCB P0–P10 阶段推进，遇到"做不到"查能力边界，最后用验收脚本判定是否真的画完。
  触发：客户给了画板需求、要新建或修改 PCB、要布线/扇出/铺铜/DFM/导 Gerber、要复刻别人的板、
  或用户说「按规范画一块板」「别手搓，用现成工具」「这块板画不出来」。
  NOT for: 纯 EDA 资料问答、只看不改的电路学习、不涉及画板的通用编程。
---

# EasyEDA AI Design Kit

**这个技能做的事情**：把「画一块板」从**依赖执行者临场发挥**，变成**按文档执行 + 脚本判定**。

**产品定义、边界与纪律**见 `PRODUCT.md`；本文件只负责一件事：**告诉你按什么顺序读、按什么规则做**。

---

## 0. 使用前

| 需要 | 检查 |
|---|---|
| `easyeda` CLI（EDA Agent Connector 的命令面） | `easyeda daemon health` |
| EasyEDA Pro 打开工程并保持窗口在线 | `easyeda daemon health` 里 `windows` 非空 |

缺任何一个 → 报告 `BLOCKED`，**不要**在无窗口状态下继续（会读到中间态并得出错误结论）。

---

## 0.5 先看结论（30 秒）

**`docs/status.md`** 是一页纸结论：这套 kit **能做什么 / 不能做什么 / 为什么 / 需要谁**。
花 30 秒读完，再决定是否往下读——它比任何一份细节文档都更值得先看。

---

## 1. 阅读顺序（不要跳）

0. **`docs/status.md`** —— 一页纸结论；**`docs/README.md`** —— 按「5 分钟 / 半小时 / 要动手」分层的阅读路径。

1. **`docs/tool-decision-table.md`** —— 拿到"我要做 X"时先查这里：用哪个工具、什么参数、已知的坑。
2. **`docs/phases/schematic-s0-s6.md`** —— 原理图 7 个阶段，每阶段有进入条件与退出判据。
3. **`docs/phases/pcb-p0-p10.md`** —— PCB 11 个阶段，含每个阶段的首选扩展。
4. **`docs/capability-boundary.md`** —— 做不到什么、证据、替代路径。**卡住先查这里**。
5. **`docs/phases/pcb-connectivity-recovery.md`** —— 布完线仍有未连时的处置流程。

---

## 2. 三条硬规则

| 规则 | 违反后果（实测） |
|---|---|
| **优先用扩展中心既有能力**：PCB Auto Router / 内电层自动分划 / 嘉立创下单检查 / 生成丝印 / PCB Delivery Export | 手搓布线器与 DFM 曾耗掉数十轮，而扩展本就有 |
| **多步链路写成 playbook 或命令**，不写一次性脚本 | 一次性产物让能力随会话归零（26 个脚本 + 28 个 playbook） |
| **结论只认脚本**：PASS / FAIL / BLOCKED 三态，`BLOCKED` 不是通过 | 把"没验证"当"通过"是所有自欺的入口 |

---

## 3. 一次画板的完整流程

```
需求 →（S0–S6 原理图）→（P0–P10 PCB）→ 交付导出 → 验收
```

关键节点上的**工具与判据**都在上面第 1 节的四份文档里。每一步结束都要能回答：
「这一步的退出判据是什么？是命令还是数字？」——答不出来就不要进下一步。

---

## 4. 卡住时的处置顺序（固定）

1. 查 `docs/capability-boundary.md` 有没有对应 `GAP-*`
2. 查 `docs/tool-decision-table.md` 该情境该用哪个工具
3. 两处都没有 → **先加一条 GAP**（必须写试过哪些工具），再决定是否换路
4. 三组以上参数都失败 → 判「需布局/自动布线」，**停止盲试**

---

## 5. 验收（唯一判据）

```powershell
pwsh -NoProfile -File acceptance/run.ps1 -Case <case> `
  -Project <工程> -SchDoc <原理图uuid> -Doc <PCB uuid> `
  -DeliveryDir <交付目录> -RunLog <运行日志> -Executor "<模型>/<harness>"
```

退出码：`0` 全 PASS / `1` 有 FAIL / `2` 有 BLOCKED / `3` 用法错误。
**只有 0 才算画完。**

---

## 6. 这个技能自己怎么验证

```powershell
pwsh -NoProfile -File acceptance/selftest.ps1        # 门禁自测
pwsh -NoProfile -File acceptance/mistake-matrix.ps1  # 历史错误矩阵
```

两者都过，说明门禁本身是可信的；否则先修门禁，再谈画板。

