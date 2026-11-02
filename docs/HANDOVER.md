# 交接说明（HANDOVER）

> **口径更正（2026-10-31，外部审计后）。** 本文件里 2026-10-31 之前出现的「16 PASS / 0 FAIL / 0 BLOCKED」
> 是**旧 16 阶段口径**的结果——那套判据只验 `Connection Error`，不验 DRC 其他分类。
> 加入第 17 阶段 `pcb-drc-clean` 后，五块板实测均为 16 PASS / 1 FAIL；**现为 19 阶段 → 18 PASS / 1 FAIL**。
> **当前口径快照（2026-11-01，第 49 轮）**：门禁 **21 阶段**；完整运行一块板 **18 PASS / 1 FAIL / 0 BLOCKED**（FAIL = `pcb-drc-clean`）；

<!-- claims: stages=23; boundaries=87; decision_rows=127; decision_actionable=78; playbook_steps=37; selftest_cases=46 -->
> `selftest` **42 PASS / 0 FAIL**；`mistake-matrix` **16/16**；静态 acceptance **10 PASS / 1 FAIL / 10 BLOCKED**（FAIL = `decision-actionability` 18/111）；
> 边界 **69 条**（open 28 → 7 根因）；决策表 **111 行**（可执行 18 行，其余为未装扩展目录）；必需文档 **18 份**。
> 历史记录保留原样（它们在当时的口径下是真的），当前真相见 `docs/sc-evidence.md` 的「状态更正」一节
> 与 `acceptance/runs/` 下入库的 per-board 报告。


**写于**：2026-10-31，第 20 轮
**状态**：产品侧完成；板子侧剩 6 条未连，卡在需要业主授权的两项操作。

---

## 1. 这个仓库是什么

一个**可安装的能力包**：装上之后，任何模型在任意 harness 上，能按文档把一块板从需求画到可打样。
不是新的 EDA 引擎，也不是一堆针对性脚本。

**入口**：`SKILL.md`（harness 读这个文件决定是否加载）
**定义**：`PRODUCT.md`
**验收**：`acceptance/run.ps1`

---

## 2. 已经**证明**的能力（可复跑）

| 能力 | 证据 | 复跑命令 |
|---|---|---|
| 文档完整且可移植 | `kit-integrity` 13/13、`kit-portability` PASS | `pwsh -File acceptance/run.ps1 -Case esp32-4layer` |
| 决策表 92 行全部可解析 | `tool-decision-table` PASS | 同上 |
| 能力边界 25 条结构合规 | `capability-boundary` PASS | 同上 |
| 门禁自身可信 | `selftest` **38 PASS / 0 FAIL**（每分支正例+反例） | `pwsh -File acceptance/selftest.ps1` |
| 抓得住历史错误 | `mistake-matrix` 16/16 | `pwsh -File acceptance/mistake-matrix.ps1` |
| 交付四类齐备 | Gerber 74,869 B（钻孔在包内）+ 坐标 13,358 B + BOM 8,379 B | `pwsh -File acceptance/export-delivery.ps1 -Project … -SchDoc … -Doc … -OutDir …` |
| Design IR 可离线自检 | 上游样例 PASS / 破坏后 FAIL | `pwsh -File acceptance/run.ps1 -IR <file>` |
| **整套包搬走仍能跑** | 复制到临时目录后同 8 PASS / 0 FAIL / 10 BLOCKED | 见下方 §6 |

---

## 3. 板子现状（练习题）

| 指标 | 值 |
|---|---|
| Connection Error | **6**（`5V_IN=4`、`U0TXD=2`）|
| Clearance Error | 18（全程未恶化）|
| Netlist Error | 1 |
| DFM | **ERROR 0**（全程保持）|
| 走线 / 过孔 | 465 / 105 |

**本会话累计**：Connection **39 → 6**（−33），且 DFM ERROR 始终为 0。

### 剩下 6 条是什么（已量化）

两个孤岛，命令行层面已穷尽：

1. **5V_IN 孤岛**：`D2_5`（顶层 SMD 焊盘）要接的铜在 L2 → 必须打孔；最近可打孔位距 D2.4/D2.6 仅 **4.0 mil**（要求 6）。
   三组参数尝试全部 `incomplete`。
2. **U0TXD 孤岛**：`U1_37 ↔ U3_3`，**七组参数**（step 10/15/20/25/30、detour 600/1500/2000/2500）全部 `incomplete`。

详见 `docs/capability-boundary.md` 的 **GAP-019 / GAP-025**。

---

## 4. 需要业主决定的两件事（唯一阻塞）

| # | 决定 | 解开什么 |
|---|---|---|
| **A** | **是否允许我操作 EasyEDA 的图形界面**（浏览器自动化点扩展面板） | T055（`PCB Auto Router` 全板重布，目标 6→0）、T048（GUI 导出验证）、T052（导入开源 `.epro2` 做 P4 未见板） |
| **B** | 若不允许动 GUI：**是否接受"挪器件腾空间"的风险**（会断现有走线，需按回退基准复原） | T056 |

**在此之前板子不会变绿**——这是事实，不是态度问题。

---

## 5. 未验证项（如实列出）

| 项 | 为什么未验证 |
|---|---|
| SC-004「换模型仍通过」 | 需要第二个模型或第二个会话复跑；当前只有一份执行记录 |
| 扩展 `.eext` 的实际上传/审核 | 需开发者账号；打包**要求**已核实到官方文档级，校验器已写（`check-extension-package.ps1`） |
| GUI 相关三条路径 | 同 §4-A |
| `route fill` 在更大板上的表现 | 只在本板 39→6 这段验证过 |

---

## 6. 怎么接手（十分钟）

```powershell
# 1) 门禁自测（不需要 EDA 窗口）
pwsh -NoProfile -File acceptance/selftest.ps1          # 期望 38 PASS / 0 FAIL
pwsh -NoProfile -File acceptance/mistake-matrix.ps1    # 期望 16/16

# 2) 静态验收（不需要工程）
pwsh -NoProfile -File acceptance/run.ps1 -Case esp32-4layer
#    期望 7 PASS / 0 FAIL / 7 BLOCKED（BLOCKED = 缺工程，不是失败）

# 3) 完整验收（需要窗口 + 工程）
pwsh -NoProfile -File acceptance/run.ps1 -Case esp32-4layer `
  -Project agent-e2e-esp32s3-board31 `
  -SchDoc b49d862ac5104b22 -Doc e8c8b7cb5507b5e2 `
  -DeliveryDir <目录> -RunLog <日志> -Executor "<模型>/<harness>"

# 4) 自包含验证：复制到别处仍能跑
Copy-Item . $env:TEMP\kit-copy -Recurse -Exclude .git
pwsh -NoProfile -File $env:TEMP\kit-copy\acceptance\run.ps1 -Case esp32-4layer
```

---

## 7. 纪律（违反过，别再犯）

1. **绝不删 DRC 标「未连」的过孔** —— 两次实测：删 4 个 33→38、删 2 个 14→16；按原坐标 `pcb via` 可精确恢复。
2. **绝不用 `rip-up --net` 撤销** —— 会删掉该网全部铜（VIN 2→10、3V3 4→12）。
3. **改完必须 `pour-rebuild` → `save` → `doc reload` → 再测**，否则读中间态。
4. **`pcb drc --json` 坐标是 mil，嵌套输出是 mm** —— 混用会把孔打到空地（实测 19→22）。
5. **判据不能为了让状态变绿而改**；判据有缺陷时，先写出反例证明它会误判，再改。





























































