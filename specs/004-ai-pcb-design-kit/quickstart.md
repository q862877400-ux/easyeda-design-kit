# Quickstart — 怎么验证这个 kit 真的能工作

**目标读者**：第一次接触本项目的人（或另一个模型）。照着做完，你就知道当前产品处于什么状态。

---

## 0. 前置条件

| 项 | 要求 | 检查方式 |
|---|---|---|
| PowerShell | 7.x | `pwsh -NoProfile -Command $PSVersionTable.PSVersion` |
| `easyeda` CLI | 已安装 | `easyeda daemon health` |
| EasyEDA Pro | 已装、扩展中心可访问 | 打开编辑器，确认扩展列表 |
| 工程 | 验收需要时再准备 | 见第 3 节 |

**注意**：第 1、2 节的验证**不需要** EasyEDA 窗口；第 3 节才需要。

---

## 1. 门禁自测（30 秒，最先跑这个）

```powershell
cd easyeda-design-kit
pwsh -NoProfile -File acceptance/selftest.ps1
```

**期望输出**

```
[PASS] kit 自身 → positive-goal PASS
[PASS] kit 自身 → negative-drift PASS
[PASS] 反例日志 → negative-drift FAIL
[PASS] N3 关键词提及(1KB) → 不判失败
[PASS] N3 实质实现(>20KB) → FAIL 并报体积
[PASS] P3 外部审计 → FAIL 并点名文件
[PASS] -CodeScope 生效（不存在范围 → 无 P3 重叠）
[PASS] 历史回测 → 抓到 N1/N5

===== 8 PASS / 0 FAIL =====
```

**若失败**：先查门禁脚本是否被你改坏（P7 会报语法错误）；不要改判据让它变绿。

---

## 2. 历史错误矩阵（约 2 分钟）

```powershell
pwsh -NoProfile -File acceptance/mistake-matrix.ps1
```

**期望**：`===== 16/16 抓到，0 漏网 =====`，退出码 `0`。

它逐条植入"我曾经犯过的错"的复现物，验证门禁抓不抓得住。任一条 `[漏了]` 都是真缺口，
**必须补门禁**，不许改用例迁就。

---

## 3. 完整验收（有工程时）

```powershell
pwsh -NoProfile -File acceptance/run.ps1 -Case esp32-4layer `
  -Project agent-e2e-esp32s3-board31 `
  -Doc e8c8b7cb5507b5e2 `
  -DeliveryDir <制造文件输出目录> `
  -RunLog <本次执行日志>
```

**先看退出码，再看明细**：

| 退出码 | 含义 | 你要做的 |
|---|---|---|
| 0 | 全 PASS | 这块板到此可交付 |
| 1 | 有 FAIL | 按 FAIL 的阶段名去修；**不许绕过** |
| 2 | 有 BLOCKED | 补前置条件（工程/窗口/日志），不是通过 |
| 3 | 用法错误 | 检查 `-Case` 指向的文件是否存在 |

**当前状态（2026-11-01）**：不带 `-Project` 的静态跑为 `10 PASS / 1 FAIL / 1 BLOCKED`
（`-Static` 模式；唯一 FAIL 是 `decision-actionability` 18/111，已记为未达成）。
带 `-Project` 的完整跑还需 EDA 窗口在线，否则 9 项板级检查报 BLOCKED——那**不是失败**。
精确数字以 `pwsh -NoProfile -File acceptance/run.ps1 -Case sc001-usbc-typed -Static` 的实跑为准。

---

## 4. 我要加一个工具经验，怎么做

1. 在 `docs/tool-decision-table.md` 对应章节加一行：`| 情境 | 工具名 | 参数/坑 |`；
2. 工具名**逐字照抄**（扩展名 / 命令 / 动作），不要写子功能说明（写进第 4 列）；
3. 跑一次 `acceptance/run.ps1`，确认 `tool-decision-table` 仍 PASS（它会逐行核对能不能解析）；
4. 更新 `acceptance/baseline.json` 的 `decision_rows`（只许调高）。

---

## 5. 我发现一个现有工具做不到的事，怎么做

1. 在 `docs/capability-boundary.md` 加一条 `GAP-xxx`；
2. **必须**在 `triedTools` 写出试过哪些现有工具（至少 1 个，否则该条无效）；
3. 写明替代路径（次优但可用）；
4. 只有在"扩展中心确实覆盖不了"时，才考虑自有实现，且实现要放在**独立仓库**，
   kit 里保持零 `src/`（P3 会拦）。

---

## 6. 常见误解（读到这里能少踩坑）

| 误解 | 事实 |
|---|---|
| "命令返回 ok 就算成功" | 不算。交付物要查**存在且非空**；板子要查 DRC/DFM 数字 |
| "BLOCKED 就是差不多通过" | 不是。BLOCKED 是"没验证"，退出码不为 0 |
| "数字变好就是进步" | 不是。`positive-goal` 会问这轮有没有长出规范产物 |
| "写个脚本先跑通再说" | 会被 N1 抓；要落成 playbook 或具名命令 |
| "kit 里加点实现更方便" | 会被 P3 抓；实现属于独立仓库 |
## 7. 第二执行者复跑（SC-004）

单次通过只证明"这次能做"，不证明"产品能做"。复跑步骤：

```powershell
# A 执行者
pwsh -NoProfile -File acceptance/run.ps1 -Case esp32-4layer -Executor "A/<harness>/<session>" `
  -Project <p> -Doc <d> -DeliveryDir <dir> -RunLog <log-a>
Copy-Item acceptance/last-report.json runs\a.json
Copy-Item acceptance/last-run-meta.json runs\a-meta.json

# B 执行者：换模型，或至少换全新会话（零上下文）
pwsh -NoProfile -File acceptance/run.ps1 -Case esp32-4layer -Executor "B/<harness>/<session>" `
  -Project <p> -Doc <d> -DeliveryDir <dir> -RunLog <log-b>
Copy-Item acceptance/last-report.json runs\b.json
Copy-Item acceptance/last-run-meta.json runs\b-meta.json

# 比对
pwsh -NoProfile -File acceptance/compare-runs.ps1 -A runs\a.json -B runs\b.json `
  -MetaA runs\a-meta.json -MetaB runs\b-meta.json
```

**判定**

| 结果 | 含义 |
|---|---|
| 退出码 0（CONSISTENT） | 阶段结论一致，SC-004 在该强度下成立 |
| 退出码 1（INCONSISTENT） | 列出差异阶段；差异若在"必须一致"清单里 → 产品不成立，必须修 |

**弱化验证的写法（重要）**：若无法切换模型，只能用"全新会话零上下文"，报告里 MUST 写

```
弱化验证：未换模型，仅用全新会话（零上下文）。SC-004 视为未完全验证。
```

不得写成"已满足 SC-004"。


