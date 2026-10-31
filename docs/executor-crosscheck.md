# 跨执行者复跑记录（SC-004）

**判据原文**：「至少**一个不同模型**（或不同 harness）复跑其中一块板并通过，证明结果不依赖特定执行者。」

**本文件的口径**（先写清楚，避免事后凑解释）：

| 变更项 | 本记录是否满足 | 说明 |
|---|---|---|
| 不同 **harness**（会话上下文） | ✅ | 全新子 agent 会话，**零先前上下文**，只给命令与回报格式 |
| 不同 **模型** | ❌ | 仍是 deepseek-v4.1；同一模型家族 |
| 不同 **工作目录/机器** | ❌ | 同一台机、同一工程 |

**因此本记录只能支撑「不依赖特定会话上下文」，不能支撑「不依赖特定模型」。**
SC-004 按原文的两种满足方式里，本记录走的是"不同 harness"这一支；要覆盖"不同模型"必须由业主另给模型入口。

---

## 复跑方式（可重复）

给一个**全新会话**的执行者三条命令，不提供任何工程背景，只看它能否得出同样的结论：

```powershell
# 1 门禁自测
pwsh -NoProfile -File easyeda-design-kit\acceptance\selftest.ps1

# 2 错误矩阵
pwsh -NoProfile -File easyeda-design-kit\acceptance\mistake-matrix.ps1

# 3 完整验收（须 EasyEDA 窗口在线；掉线会如实返回 BLOCKED）
pwsh -NoProfile -File easyeda-design-kit\acceptance\run.ps1 `
  -Case esp32-4layer -Cli "$env:USERPROFILE\.local\bin\easyeda.exe" `
  -Project agent-e2e-esp32s3-board31 -SchDoc b49d862ac5104b22 -Doc e8c8b7cb5507b5e2 `
  -DeliveryDir "$env:TEMP\kit-delivery-sc4" `
  -RunLog easyeda-auto\.work\round16.log `
  -Executor "subagent/fresh-session/deepseek-v4.1"
```

**判读规则**：只有两次运行的**逐阶段结论一致**才算复跑通过；若新会话出现大面积 BLOCKED，那是环境问题（窗口掉线），须先恢复窗口重跑，**不得**把"环境缺失"算作"结果不同"。

---

## 结果

| 项 | Lead（本会话） | 新会话子 agent | 是否一致 |
|---|---|---|---|
| selftest | 28 PASS / 0 FAIL | 待填 | 待判 |
| mistake-matrix | 16/16 | 待填 | 待判 |
| acceptance 阶段表 | 16 PASS / 0 FAIL / 0 BLOCKED | 待填 | 待判 |

> 待子 agent 回报后填写。**在填完之前，本文件不构成 SC-004 的证据。**
