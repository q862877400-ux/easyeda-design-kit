# 跨执行者复跑记录（SC-004）

**判据原文**：「至少**一个不同模型**（或不同 harness）复跑其中一块板并通过，证明结果不依赖特定执行者。」

**本文件的口径**（先写清楚，避免事后凑解释）：

| 变更项 | 本记录是否满足 | 说明 |
|---|---|---|
| 不同 **harness**（会话上下文） | ✅ | 全新子 agent 会话，零先前上下文，只给命令与回报格式 |
| 不同 **模型** | ❌ | 仍是 deepseek-v4.1；同一模型家族 |
| 不同 **机器/工作目录** | ❌ | 同一台机、同一工程 |

**因此本记录只能支撑「不依赖特定会话上下文」，不能支撑「不依赖特定模型」。**

---

## 复跑方式（可重复）

给一个全新会话的执行者三条命令，不提供任何工程背景：`selftest.ps1` → `mistake-matrix.ps1` → `run.ps1`（参数见下）。

```powershell
pwsh -NoProfile -File easyeda-design-kit\acceptance\run.ps1 `
  -Case esp32-4layer -Cli "$env:USERPROFILE\.local\bin\easyeda.exe" `
  -Project agent-e2e-esp32s3-board31 -SchDoc b49d862ac5104b22 -Doc e8c8b7cb5507b5e2 `
  -DeliveryDir "$env:TEMP\kit-delivery-auto5" `
  -IR "…\easyeda-design-kit\vendor\prior-art\smart-hardware-engineer\ir\examples\blinky_usb_mcu.ir.json" `
  -RunLog "…\easyeda-auto\.work\round16.log" `
  -Executor "subagent/fresh-session-N/deepseek-v4.1"
```

**判读规则**：只有两次运行的**逐阶段结论一致**才算通过；新会话若出现大面积 BLOCKED，属窗口掉线（环境问题），须先 `ensure_eda_window.py` 恢复再重跑，**不得**把环境缺失算成"结果不同"。

---

## 运行 A：Lead（本会话，全参数）

| 项 | 结果 |
|---|---|
| selftest | **30 PASS / 0 FAIL**（本轮修复后） |
| mistake-matrix | **16/16** |
| acceptance | **16 PASS / 0 FAIL / 0 BLOCKED**，退出码 0 |

## 运行 B：全新会话子 agent #1（我给的命令漏了 `-IR`，交付目录也未预建）

| 项 | 结果 |
|---|---|
| selftest | 28 PASS / 0 FAIL（当时断言数 28） |
| mistake-matrix | 16/16 |
| acceptance | **14 PASS / 1 FAIL / 1 BLOCKED**，退出码 1 |
| 差异项 | `design-ir` BLOCKED（未指定 `-IR`）；`delivery` FAIL（交付目录不存在） |

**判读**：两处差异**都不是执行者差异**，是**调用参数差异**——它拿到的命令里没有 `-IR`，也没人替它先导出交付物。

**但它因此暴露了两个真缺陷（这是本记录最有价值的部分）**：

1. **`delivery` 把"目录不存在"判成 FAIL**。读到的是"这板交付坏了"，实际是**前置未做**。三态诚实要求：未做 → `BLOCKED` 并给出下一步命令。已改。
2. **`delivery` 的缺件记账有 bug**：未命中的键根本不会被写进 `$found`，导致 `$missing` 永远为空 —— **任何缺件都判 PASS（假绿）**。是本轮新增的 fixture 断言把它拦下来的（`缺钻孔` 与 `零字节` 两条旧断言同时变红，才暴露出这是代码 bug 而不是断言错）。已改。

两条修复都配了自测断言（自测从 28 → **30 条**）：
- `delivery → 目录不存在判 BLOCKED（不是 FAIL）`
- `delivery → 目录有文件但缺 BOM 判 FAIL`

## 运行 C：全新会话子 agent #2（参数与运行 A 完全一致）

结果：**待回报**。回报后填此表，并与运行 A 逐阶段比对。
在填完之前，本文件**不构成 SC-004 证据**。

---

## 结论（待填）

- 若运行 C 与运行 A 逐阶段一致 → SC-004 的 **harness 维度**成立，「结果不依赖特定会话上下文」有证据。
- 模型维度仍缺，需业主另给模型入口。
