# Playbooks（可回放链路）

**用途**：把多步操作固化成**具名、可回放、可校验**的序列，替代一次性脚本。
门禁 N1 会抓 `.work/` 下的一次性生成器；门禁 P2/P6 会抓"冒充成 playbook 的说明文字"和"编造的命令"。

---

## 1. 现有链路

| 名称 | 文件 | 用途 | 前置 | 影响面 |
|---|---|---|---|---|
| `pcb-rebuild-routed` | `pcb-rebuild-routed.playbook.json` | 把 PCB 重建到"已布线 + 已铺铜"的一致状态：撕铜 → 短线布线 → 电源面 → 两个铺铜 → 保存 | 已有原理图转 PCB；窗口在线 | 破坏性（会 `rip-up` 全部走线），只在需要重建时用 |
| `typed-board-build` | `typed-board-build.playbook.json` | 从零造一块板并交付：建工程 → 落电路块 → 布局门禁 → 图签 → 同步 PCB → 板框 → 布线 → DFM → 落盘（全部可 CLI 重放，无 GUI/无坐标粘贴） | 空工程即可；需先在 `blocks ls --ready` 选块 | 12 步，两块实证板 16 PASS / 0 FAIL / 0 BLOCKED |

**顺序本身就是知识**（`meta.description` 里也写了）：

```
pcb rip-up → route-short（45°，max-len 3000）→ power-planes
          → pour-fit GND@15 → pour-fit 3V3@16 → pcb save
```

理由：先撕掉旧铜才能保证布线可复现；先布线再铺铜，避免新过孔缺反弹片导致 DRC 假性恶化
（见 `docs/capability-boundary.md` GAP-009）。

---

## 2. 契约（写新 playbook 必须满足）

| 字段 | 要求 |
|---|---|
| `version` | 当前 `1` |
| `meta.name` | 唯一名 |
| `meta.project` / `meta.doc` | 目标工程与文档 |
| `meta.description` | **为什么是这个顺序**（不是"做什么"） |
| `steps[].run` | 必须是 CLI 里**真实存在**的命令（门禁 P6 逐条核对 `--help`） |
| `steps[].flags` | 参数；破坏性步骤必须显式（如 `confirm: true`） |
| `steps[]` | **非空**（门禁 P2） |

**解析规则**：`run` 取第一个词为命令组、第二个词为子命令，必须能在
`easyeda <组> --help` 的输出里找到该子命令。

---

## 3. 怎么跑

```powershell
easyeda apply playbooks\<name>.playbook.json --dry-run   # 先看计划
easyeda apply playbooks\<name>.playbook.json --yes       # 执行
easyeda apply playbooks\<name>.playbook.json --yes --resume  # 断点续跑
```

执行会写 journal：`playbooks\<name>.playbook.json.journal.jsonl`（可回放、可审计）。

---

## 4. 怎么落运行日志（零一次性脚本的前提）

验收的 `negative-drift` N4–N6 需要运行日志。**用 PowerShell 的 `Tee-Object` 落盘，不要写新脚本**：

```powershell
$log = "runs\$(Get-Date -Format yyyyMMdd-HHmmss).log"
"easyeda pcb dump --out b1.json" | Tee-Object $log -Append
easyeda pcb dump --out b1.json | Out-Null
# 每执行一条命令，就把该命令行再追加进日志一次
```

**为什么这样做**：日志是"我到底调了什么"的唯一证据。门禁无法判断日志是否被事后编辑，
所以纪律是：**命令与日志同步生成，不补写**。

---

## 5. 撤销已落板的路径：正确做法

**错误**：`easyeda pcb rip-up --net VIN`（会删掉该网**所有**铜，包括你不想删的；
实测 VIN 未连 2→10、3V3 4→12，Connection 21→31）。

**正确**：只删这一次落的具体图元。

```powershell
easyeda pcb track-delete --ids <id1>,<id2>
easyeda pcb via-delete   --ids <id3>
```

id 从 `pcb track-list` / `pcb via-list` 里按坐标筛出。

门禁 N4 会在运行日志里抓 `rip-up --net`。

---

## 6. 写新 playbook 的检查单

- [ ] `run` 每一条都能在 `easyeda <组> --help` 里找到（P6 会核对）
- [ ] 破坏性步骤有 `confirm`/`assert`，或明确写在 `meta.description`
- [ ] `meta.description` 写的是**顺序理由**
- [ ] 跑过一次 `--dry-run`，并把结果贴进提交说明
- [ ] 跑过一次真实执行，并把 journal 路径记进台账

---

## 7. 与决策表的关系

playbook 里的每一步都应能在 `docs/tool-decision-table.md` 找到对应行；
若找不到，说明决策表缺一行——**先补决策表，再写 playbook**（否则知识会分裂成两套）。
