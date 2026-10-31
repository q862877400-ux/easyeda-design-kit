# 跨执行者复跑记录（SC-004）

> **口径更正（2026-10-31，外部审计后）。** 本文件里 2026-10-31 之前出现的「16 PASS / 0 FAIL / 0 BLOCKED」
> 是**旧 16 阶段口径**的结果——那套判据只验 `Connection Error`，不验 DRC 其他分类。
> 加入第 17 阶段 `pcb-drc-clean` 后，**五块板实测均为 16 PASS / 1 FAIL**（DRC 非 0）。
> 历史记录保留原样（它们在当时的口径下是真的），当前真相见 `docs/sc-evidence.md` 的「状态更正」一节
> 与 `acceptance/runs/` 下入库的 per-board 报告。


**判据原文**：「至少**一个不同模型**（或不同 harness）复跑其中一块板并通过，证明结果不依赖特定执行者。」

## 结论

**SC-004 已满足（走"不同 harness"这一支）**：全新会话、零上下文的执行者，用同一条命令得到**逐阶段完全一致**的结果。

**但它只能证明"不依赖特定会话上下文"，不能证明"不依赖特定模型"** —— 两次运行都是 deepseek-v4.1。
这一句必须留着，否则就是把结论说过头了。

---

## 口径（先写清楚，避免事后凑解释）

| 变更项 | 是否满足 | 说明 |
|---|---|---|
| 不同 **harness**（会话上下文） | ✅ 运行 C | 全新子 agent，零先前上下文，只给命令与回报格式 |
| 不同 **模型** | ❌ | 仍是 deepseek-v4.1 |
| 不同 **机器/工作目录** | ❌ | 同机同工程 |

---

## 三次运行

### 运行 A：Lead（本会话）

| 项 | 结果 |
|---|---|
| selftest | 30 PASS / 0 FAIL |
| mistake-matrix | 16/16 |
| acceptance | **16 PASS / 0 FAIL / 0 BLOCKED**，退出码 0 |

### 运行 B：全新会话 #1（**参数不同**：漏 `-IR`、交付目录未预建）

| 项 | 结果 |
|---|---|
| selftest | 28 PASS / 0 FAIL（当时断言数 28） |
| acceptance | **14 PASS / 1 FAIL / 1 BLOCKED**，退出码 1 |
| 差异 | `design-ir` BLOCKED（无 `-IR`）、`delivery` FAIL（目录不存在） |

**判读**：差异来自**调用参数**，不是执行者。但这轮**暴露了两个真缺陷**（见下节），价值高于一致性本身。

### 运行 C：全新会话 #2（参数与运行 A 完全一致）

| 项 | 结果 |
|---|---|
| selftest | **30 PASS / 0 FAIL** |
| mistake-matrix | **16/16** |
| acceptance | **16 PASS / 0 FAIL / 0 BLOCKED**，退出码 0 |
| BLOCKED | 无 |
| 前置 | `ensure_eda_window.py` 成功（窗口活跃） |

**逐阶段比对（A vs C）**：16 个阶段，**0 处不同**。

| 阶段 | A | C |
|---|---|---|
| kit-integrity / kit-portability / tool-decision-table / installed-claims / decision-actionability / capability-boundary | PASS | PASS |
| environment / schematic-gates / design-ir | PASS | PASS |
| pcb-layout / pcb-connectivity / pcb-dfm / delivery | PASS | PASS |
| no-oneoff-scripts / positive-goal / negative-drift | PASS | PASS |

---

## 运行 B 暴露的两个真缺陷（已修，附反例）

1. **`delivery` 把"目录不存在"判 FAIL**。什么都没导出，就报"交付坏了" = 误指控。
   三态诚实：未做 → `BLOCKED` 并给出下一步命令。已改。
2. **`delivery` 缺件记账 bug**：未命中的键不写入 `$found`，`$missing` 永远为空 → **任何缺件都 PASS（假绿）**。
   由已有的两条 fixture（`缺钻孔 FAIL`、`零字节文件 FAIL`）同时变红暴露——两条旧断言一起翻才说明是代码 bug。
   另修：**同一文件不得同时充当两个键**（一个 `cpl.csv` 曾同时满足"坐标"与"BOM"）。

自测因此从 28 → **30 条**，双向钉住：
- `delivery → 目录不存在判 BLOCKED（不是 FAIL）`
- `delivery → 目录有文件但缺 BOM 判 FAIL`

---

## 复跑方法（可重复）

```powershell
# 0 先保证窗口在线（否则整片 BLOCKED 属环境问题）
cd easyeda-auto
python tools/ensure_eda_window.py --url "https://pro.lceda.cn/editor#id=<工程uuid>,tab=*<pcb>@<工程uuid>" --project <工程> --timeout 90

# 1 门禁自测 / 2 错误矩阵 / 3 完整验收
pwsh -NoProfile -File easyeda-design-kit\acceptance\selftest.ps1
pwsh -NoProfile -File easyeda-design-kit\acceptance\mistake-matrix.ps1
pwsh -NoProfile -File easyeda-design-kit\acceptance\run.ps1 `
  -Case esp32-4layer -Cli "$env:USERPROFILE\.local\bin\easyeda.exe" `
  -Project agent-e2e-esp32s3-board31 -SchDoc b49d862ac5104b22 -Doc e8c8b7cb5507b5e2 `
  -DeliveryDir "$env:TEMP\kit-delivery-auto5" `
  -IR "…\vendor\prior-art\smart-hardware-engineer\ir\examples\blinky_usb_mcu.ir.json" `
  -RunLog "…\easyeda-auto\.work\round16.log" `
  -Executor "subagent/fresh-session-N/deepseek-v4.1"
```

**判读规则**：逐阶段一致才算通过；大面积 BLOCKED 属窗口掉线，先恢复再重跑，**不得**算作"结果不同"。

## 尚未覆盖

- **不同模型**：需业主提供第二个模型入口。
- **另一块板**（SC-001 的第二块）：需导入开源 `.epro2`（T295）。

---

## 运行 D：零上下文子 agent 复跑**新生成的第 2 块板**（2026-10-31）

与运行 C 的区别：这块板（`sc001-ldo-typed`）在放行前**从未被任何会话验收过**，执行者也从未见过它。

| 项 | 结果 |
|---|---|
| acceptance | **16 PASS / 0 FAIL / 0 BLOCKED**，退出码 0 |
| BLOCKED | 无 |
| 与 Lead 比对 | 16 阶段**逐项一致** |
| 它额外指出的问题 | 我给它的 `-RunLog` 属于**旧工程**，审计等于审别人的日志 → 据此新增 GAP-039 守卫 |

**判读**：这块板的结论不依赖"我知道它是怎么造出来的"。它同时证明了一件事：
让执行者**挑错**比让它**复述结论**更有价值——运行 D 的最大产出不是那 16 个 PASS，而是它发现了日志错配。

---

## 运行 E：改过门禁脚本后的五板复验（2026-10-31，第 21 轮）

**背景**：上一轮修了 `mistake-matrix` 的 M12（原硬编码 `DecisionBaseline = 99`，表长到 107 行后假通过）。
改的是**门禁脚本本身**，所以必须复验"改动没有连带影响"。

| 项 | 结果 |
|---|---|
| `selftest.ps1` | **36 PASS / 0 FAIL** |
| `mistake-matrix.ps1` | **16/16 抓到，0 漏网**（M12 重新被抓到） |
| 静态 acceptance | **8 PASS / 0 FAIL / 9 BLOCKED**（BLOCKED = 需在线板子的阶段） |
| 五块板（同一次顺序运行） | 每块 **16 PASS / 0 FAIL / 0 BLOCKED** |
| 反例验证 | 把 `baseline.json` 的 `decision_rows` 临时改成 200 → `negative-drift` 报 `N8 决策表行数从 200 降到 107`（门禁确实会抓缩水，不是被改绿）|

**判读**：门禁脚本的改动不会影响板子验收——这是**测出来的**，不是推断的。以后每次动 `acceptance/` 下的判据，
都应照这条跑一遍：三件套 + 五板复验 + 一条反例。

