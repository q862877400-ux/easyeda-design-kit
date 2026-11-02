# docs 阅读路径

> 这个目录有 20+ 份文档、100 KB 的边界清单、和一份 24 KB 的决策表。
> **不要从头读。** 按你手上的时间选一条路。
>
> **只想知道结论？** 直接看 [status.md](status.md) —— 一页纸：能做什么 / 不能做什么 / 为什么 / 需要你做什么。

## 只有 5 分钟：这套东西是什么、现在能用吗

- [easibility-001-ch224a.md](feasibility-001-ch224a.md) —— 可行性实验：从功能反推电路板，与开源项目对比（含我方两处功能缺失）。

1. [`../PRODUCT.md`](../PRODUCT.md) —— 产品声明：产物是什么、给谁、不做什么。
2. [`sc-evidence.md`](sc-evidence.md) —— **六条判据的当前状态**（达成 / 未达成 / 阻塞），每条都带门禁命令与数字。
   这是唯一"现在能不能用"的答案，不要读别处的结论。
3. 自己验一次（不需要 EDA 窗口，约 30 秒）：

   ```powershell
   pwsh -NoProfile -File acceptance/run.ps1 -Case sc001-usbc-typed -Static
   ```

   期望：`10 PASS / 1 FAIL / 1 BLOCKED（本模式不含 10 项板级检查，未计入 BLOCKED）`。
   唯一的 FAIL 是 `decision-actionability`（决策表可执行率 18/111），已如实记为**未达成**。

## 有半小时：它是怎么搭起来的、哪里会崩

- [easibility-001-ch224a.md](feasibility-001-ch224a.md) —— 可行性实验：从功能反推电路板，与开源项目对比（含我方两处功能缺失）。

4. [`HANDOVER.md`](HANDOVER.md) —— 交接：目录结构、命令、现状快照、**当前卡点**。顶部有一行机器核对的 `claims`。
5. [`boundary-root-causes.md`](boundary-root-causes.md) —— **75 条边界 → 7 个根因**。
   想知道"为什么 R1/R2/R3/R5 共 20 条都卡在同一件能力上"，读这份，不要读 100 KB 的原始清单。
6. [`tool-decision-table.md`](tool-decision-table.md) —— 情境 → 用哪个工具。
   **只有 18 行是当前机器上真正可执行的**（含 flag 与取值），其余标注了 `未装`——那是目录，不是手册。
7. [`phases/`](phases/) —— 分阶段流程：`schematic-s0-s6.md`、`pcb-p0-p10.md`、`pcb-connectivity-recovery.md`。

## 要动手：照着做

- [easibility-001-ch224a.md](feasibility-001-ch224a.md) —— 可行性实验：从功能反推电路板，与开源项目对比（含我方两处功能缺失）。

8. [`../playbooks/README.md`](../playbooks/README.md) —— 4 个可执行 playbook（37 步，每步的 flag 与取值都经门禁校验）。
   - `typed-board-build`：从零建一块小板上全绿
   - `big-block-fit`：把 6 件以上的大块塞进 A4（含非单调判定与参数配方）
   - `pcb-rebuild-routed`：重铺并重布
   - `sch-to-pcb-import-and-place`：原理图 → PCB
9. [`playbook-unseen-board.md`](playbook-unseen-board.md) / [`playbook-unseen-external-board.md`](playbook-unseen-external-board.md)
   —— 拿到一块**没见过的板**（自造 / 别人开源）时的流程。外部板那份强调"**先记基线再动手**"。

## 要查具体条目

- [easibility-001-ch224a.md](feasibility-001-ch224a.md) —— 可行性实验：从功能反推电路板，与开源项目对比（含我方两处功能缺失）。

10. [`boundary-index.md`](boundary-index.md) —— 75 条边界的**索引**（按 open / resolved / accepted 分组，一屏看完待办）。
11. [decision-gaps.md](decision-gaps.md) —— 决策表剩余行的可替代性分类（含 SC-005 能达到的上限）。
11b. [`capability-boundary.md`](capability-boundary.md) —— 75 条完整条目（100 KB）。
    **每条固定五字段**：capability / evidence / triedTools / alternative / status。用索引定位后再跳进来读。

## 想知道"这些结论可靠吗"

- [easibility-001-ch224a.md](feasibility-001-ch224a.md) —— 可行性实验：从功能反推电路板，与开源项目对比（含我方两处功能缺失）。

12. [`executor-crosscheck.md`](executor-crosscheck.md) —— 谁跑过、跑了几次、**逐阶段是否一致**。
13. [`progress-log.md`](progress-log.md) —— 每轮做了什么、数字怎么变、**犯过什么错**（不重写历史，更正在新增行里）。
14. [`anti-drift.md`](anti-drift.md) —— 反自欺条款：为什么"命令返回 ok"不算通过。
15. [`retro-audit.md`](retro-audit.md) —— 外部零上下文审计发现的 10 类问题及处置。

## 参考与历史（按需）

- [easibility-001-ch224a.md](feasibility-001-ch224a.md) —— 可行性实验：从功能反推电路板，与开源项目对比（含我方两处功能缺失）。

| 文件 | 什么时候读 |
|---|---|
| [`design-rules.md`](design-rules.md) | 要查具体设计规则（47 KB） |
| [`extensions-index.md`](extensions-index.md) | 要查 75 个扩展各自的命令面 |
| [`installed-extensions.json`](installed-extensions.json) / [`external-tools.json`](external-tools.json) | 要确认"本机到底装了什么" |
| [`prior-art.md`](prior-art.md) / [`prior-art-map.md`](prior-art-map.md) | 想知道别人怎么做的、我们借鉴了什么 |
| [`publish-extension.md`](publish-extension.md) | 要把 kit 做成扩展发布 |
| [`harness-install.md`](harness-install.md) | 要装 DSH / 排环境问题 |
| [`vendor-claims-easyeda-v4-ai.md`](vendor-claims-easyeda-v4-ai.md) | 要核对嘉立创官方对 V4 AI 的说法与实测差异 |

## 三条阅读纪律

- [easibility-001-ch224a.md](feasibility-001-ch224a.md) —— 可行性实验：从功能反推电路板，与开源项目对比（含我方两处功能缺失）。

1. **数字只信门禁输出**，不要信文档里的数字。文档里的数字由 `evidence-freshness` 与 `claims-match` 两个阶段核对，
   但它们只保证"与实测一致"，不保证"结论正确"。
2. **看到"未验证"就当它没做过**。本 kit 刻意保留这个词，用来区分"我试过"和"我以为"。
3. **`未达成` 不是失败，是记录**。`SC-005`（决策表可执行率）与 `SC-A`（DRC 0）都标未达成，
   理由和出路都写在 `sc-evidence.md` 与 `boundary-root-causes.md`。





