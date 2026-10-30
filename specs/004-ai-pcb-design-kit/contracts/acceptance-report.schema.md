# Contract: 验收报告与运行日志

**被谁产出**：`acceptance/run.ps1`
**被谁消费**：人（复核）、后续阶段（重跑对比）、`negative-drift` 的日志审计（N4–N6）

---

## 1. 退出码（唯一权威结论）

| 退出码 | 含义 | 条件 |
|---|---|---|
| `0` | 全部 PASS | 所有阶段 `PASS` |
| `1` | 存在 FAIL | 任一阶段 `FAIL` |
| `2` | 无 FAIL 但有 BLOCKED | 至少一个 `BLOCKED` 且无 `FAIL` |
| `3` | 用法错误 | 用例文件缺失等 |

**不变式**：`BLOCKED` 永不等价于通过。缺前置条件 → `BLOCKED`，且退出码不得为 0。

---

## 2. `acceptance/last-report.json`

每次运行覆盖写入（不纳入版本控制）。

```json
[
  { "Stage": "kit-integrity",       "Status": "FAIL",    "Detail": "缺 4/8 份： ..." },
  { "Stage": "tool-decision-table", "Status": "PASS",    "Detail": "84 行，点名工具全部可解析" },
  { "Stage": "environment",         "Status": "BLOCKED", "Detail": "没有在线的 EDA 窗口（windows 为空）" },
  { "Stage": "positive-goal",       "Status": "PASS",    "Detail": "规范产物 5/1/10/2；..." },
  { "Stage": "negative-drift",      "Status": "BLOCKED", "Detail": "N4–N6 需要 -RunLog 才能审计；..." }
]
```

字段契约：

| 字段 | 类型 | 约束 |
|---|---|---|
| `Stage` | string | 阶段名，**稳定**（改名会让历史报告不可比对） |
| `Status` | enum | `PASS` \| `FAIL` \| `BLOCKED`（不得出现其它值） |
| `Detail` | string | 必须**含可核对的事实**：计数、文件名、体积、阶段号；不得只写“ok” |

**报告不写"建议"、不写解释**——解释属于台账与 `docs/`，报告只放判定与事实。

---

## 3. 阶段清单（当前 10 个）

| 阶段 | 依赖 | 判定内容 |
|---|---|---|
| `kit-integrity` | 无 | 8 份必需文档是否齐备 |
| `tool-decision-table` | 无 | 决策表 ≥30 行且工具名可解析 |
| `environment` | EDA | 窗口在线、连接器版本 |
| `schematic-gates` | `-Project` | `sch drc` 通过 |
| `pcb-layout` | `-Project` | 0 短路 / 0 重叠 / 0 出框 |
| `pcb-connectivity` | `-Project` | Connection Error = 0 |
| `pcb-dfm` | `-Project` | DFM ERROR = 0 |
| `delivery` | `-DeliveryDir` | Gerber/钻孔/坐标/BOM 均存在且非空 |
| `no-oneoff-scripts` | `-RunLog` | 日志中无一次性脚本调用 |
| `positive-goal` | 无 | P1–P7 正向判据 |
| `negative-drift` | 可选 `-RunLog` | N1–N9 负向判据 |

（`positive-goal`/`negative-drift` 恒定运行；其余按参数决定 PASS/FAIL/BLOCKED。）

---

## 4. 运行日志契约（`-RunLog`）

纯文本，一行一条命令，按执行顺序。门禁按其内容判定：

| 检查 | 规则 | 对应事故 |
|---|---|---|
| N4 | 不得出现 `rip-up --net` | 整网被删（Connection 21→31） |
| N5 | `route solve`/`route fill` 次数 ≤ `pcb dump` 次数 | 对着旧快照求解（Clearance 18→31） |
| N6 | `pcb save` 之后、`pcb drc` 之前必须出现 `doc reload` | 读到中间态并据此下结论 |
| `no-oneoff-scripts` | 不得出现 `.work\`、`python *.py` 生成器调用 | 一次性脚本推进 |

**最小形态**

```
easyeda pcb dump --out b1.json
easyeda pcb route fill --net FB --from R4.1 --to U2.5
easyeda pcb save
easyeda doc reload
easyeda pcb drc
```

**契约要点**：日志由执行者 tee 产生，**不得事后编辑**。门禁不校验"是否被编辑过"（无法从文本判断），
因此日志的诚实性由执行纪律保证；这一点写在 `docs/anti-drift.md`，属于已知局限。
