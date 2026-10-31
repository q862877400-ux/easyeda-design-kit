# 接一块「没见过的板」的流程（P4 / SC-001 用）

**适用**：客户丢来一个工程（`.epro2`），或从开源广场拿一块别人的板，要求"按我们的规范处理/检查/交付"。

**核心区别**：这块板**不是我们画的**，它可能本来就带违规。所以第一步永远不是"改"，而是**记基线**。

---

## 0. 拿到工程（两种入口）

| 入口 | 怎么走 | 状态 |
|---|---|---|
| A. 本机 `.epro2` | 编辑器打开工程 → **导入/打开本地工程**（网页版是原生文件框，需人工点一次；见 GAP-032） | 人工一步 |
| B. 在线工程 | `easyeda project find --name <名字>` 定位 → `easyeda project open --project-uuid <uuid>` | 全自动 |

> 本机没有 `import` 类动作/命令：`project.create` 只建空容器，`project.open` 只能开已存在的。

## 1. 先测基线（不许先改）

```powershell
easyeda pcb drc   --project <名字> --doc <PCB uuid> --json     # 记 Connection/Clearance 计数
easyeda pcb check --project <名字> --doc <PCB uuid> --json     # 记 DFM ERROR 数
easyeda sch drc   --project <名字> --doc <原理图 uuid> --json   # 原理图门禁
```

把三个数字写进本次的 case 文件（`acceptance/cases/<名字>.md`）的「基线」段。**这是后面判断进步的唯一尺子。**

**口头纪律**：`pcb drc --json` 对同一块板可能报 0 而 `pcb check` 报 N（本会话实测到 Clearance 0 vs 3）。
**以 `pcb check` 为准**，因为验收的 `pcb-dfm` 阶段读它。

## 2. 判定这块板属于哪种情况

| 情况 | 判据 | 怎么报 |
|---|---|---|
| 干净板 | 基线 Connection=0 且 DFM=0 | 直接进第 3 步；验收全绿即完成 |
| 带既有违规 | 基线有 FAIL 项 | **基线照实写进交付说明**；验收会如实 FAIL，这是**信息不是缺陷**（GAP-033） |
| 无法打开/缺文档 | `project.open` 失败或缺 PCB/原理图 | 报 `BLOCKED`，写明缺什么 |

## 3. 只改需求相关的部分

- 按 `docs/phases/schematic-s0-s6.md` / `pcb-p0-p10.md` 推进，但**只动本次需求涉及的对象**。
- 别顺手"修"整块别人板子的 DRC：会把客户的原始设计意图改掉，且不可回溯。
- 任何删除铜/走线的操作前先 `project.export_source` 留档（本会话的 `.work\backup-before-autoroute.epro2` 就是这个做法）。

## 4. 交付 + 验收

```powershell
pwsh -NoProfile -File acceptance/export-delivery.ps1 -Project <名字> -Doc <PCB> -SchDoc <原理图> -OutDir <目录>
pwsh -NoProfile -File acceptance/run.ps1 -Case <名字> -Project <名字> -SchDoc <原理图> -Doc <PCB> `
  -DeliveryDir <目录> -RunLog <日志> -Executor "<模型>/<harness>"
```

## 5. 报告口径（关键）

必须分开写两行，不许混成一句：

```
基线：Connection 12 / DFM 3（接手时状态）
本次：Connection 12 / DFM 3（未做相关改动）→ 验收 FAIL，属预期
```

或者

```
基线：Connection 12 / DFM 3
本次：Connection 0  / DFM 0 → 验收 PASS
```

**禁止**：为了让整块板变绿而改判据或用例；也禁止把"基线本来就不绿"说成"套件跑不了"。

---

## 这份流程自己怎么被检验

- `acceptance/run.ps1` 的 `no-oneoff-scripts`、`negative-drift` 对**任何**工程都生效（不依赖具体板子）。
- `docs/capability-boundary.md` 的 GAP-032/033 记录了两个已知限制与口径。
- 本节没有"实测过的外部板"样本——**SC-001 仍为 0/2**，等第一块板真正导入后才有证据。
