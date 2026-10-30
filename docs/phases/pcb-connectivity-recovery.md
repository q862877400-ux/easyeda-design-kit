# 连线恢复流程（Connection Error 从 39 降到 6 的实战提炼）

**用途**：板子布完线但 DRC 仍报一堆 `Connection Error` 时，按本流程逐条降，**不要**凭直觉反复试。
**适用**：四层板（内层平面供电）为主；两层板可跳过平面相关步骤。

**铁律（都被实测违反过）**

1. **绝不删 DRC 标记「未连」的过孔** —— 它们仍在承载层间连接。实测删 4 个：33→38；删 2 个：14→16。
   撤销后按原坐标 `pcb via` 重建可精确恢复。
2. **绝不用 `pcb rip-up --net` 撤销** —— 会把该网全部铜删掉（实测 VIN 2→10、3V3 4→12）。
   要撤就按 id 精确删（`pcb track-delete` / `pcb via-delete`）。
3. **每次改动后必须** `pour-rebuild` → `save` → `doc reload` → 再测，否则读到中间态。

---

## 第 0 步：先看分诊，不要看总数

```powershell
easyeda pcb drc --project <p> --doc <pcb> --json
```

- 扁平输出自带 `counts`（每规则条数）与 `violations[]`（每行 `rule`/`net`/`objType`/`x`/`y`）。
- **坐标单位**：`--json` 是 **mil**；嵌套输出是 **mm**。混用会把孔打到空地（实测 19→22）。
- 我们的验收阶段已把这一步做成输出：`Connection Error N 条（焊盘 x / 过孔 y）：GND=9, 3V3=4 …`

**为什么重要**：总数不变时，可能是「接上了 1 个、同时冒出 2 个过孔」；只有按网看才发现真实进展。

---

## 第 1 步：电源/地先交给平面

```powershell
easyeda pcb power-planes --project <p> --doc <pcb>      # 内层平面 + 共享过孔缝合
```

- 看输出里的 `stitch.<net>.unplaced`：>0 说明**该焊盘周围没有干净落孔位**。
- 看 `warnings`：会明确写 `9 pad(s) had no clearance-clean via spot`。

**注意**：`pcb pour-fit` 铺的是**整板 bbox 矩形**，所以"平面没覆盖到某处"基本不成立；
真正原因是**铺铜避让（anti-pad）**把焊盘与邻网铜隔开。

---

## 第 2 步（最有效）：把未连焊盘走线到"已连通"的同网焊盘

```powershell
easyeda pcb route fill --project <p> --doc <pcb> --net <N> \
  --from <未连焊盘> --to <已连焊盘> --layers 1,2 --width 10 [--step 10] [--max-detour 600]
```

**实测战果**（本板，39→6 主要靠这一步）：

| 网络 | 跳线 | 结果 |
|---|---|---|
| GND | J2.11 → U3.1 | 33 段，接通 |
| GND | J2.B1A12 → U3.1 | 15 段 |
| GND | J2.A1B12 → U3.1 | 11 段 |
| 3V3 | C5.1 → U1.2 | 7 段 |
| 3V3 | C7.1 → U1.2 | 101 段 + 2 孔 |
| 3V3 | U3.4 → C5.1 | 99 段 + 4 孔 |
| 3V3 | C7.1 → C5.1 | 82 段 + 2 孔 |
| 5V_IN | C8.1 → J1.1 | 15–16 段 + 2 孔 |

**为什么它比加孔强**：加孔受"焊盘周围有没有干净落孔位"限制；走线只要两端有铜就能走，
可以绕开密集区。**每跳落完立刻测**，因为下一跳的目标可能是这一跳刚变成"已连通"的焊盘。

---

## 第 3 步：实在要加孔时，矩形必须在焊盘铜内

```powershell
easyeda pcb via-stitch --net GND --rect "x0,y0,x1,y1" --pitch 30 --diameter 16 --hole 8 --dry-run
```

- 矩形**以焊盘中心为基准、落在焊盘铜内**。EPAD 示例：中心 (474,619) → `--rect "458,603,492,637"`。
- **默认 24/12 孔径在密集板上常常一个都放不下**（实测 U3_4 放 4 孔全失败）；用 16/8 才落得下。
- `via-stitch` **不做间距校验**，`--dry-run` 只打印网格，**不报告冲突**。
- 落完必测；若某孔引入 Clearance（实测 U3_4 的角孔距 DTR 仅 1.3–2.7mil），
  **只删那一个孔**，其余保留。

**有效点**：U1_41、U3_1（EPAD 散热孔，各 4 孔）、J2_9（屏蔽盘）。
**无效/受阻点**：U3_4（被 DTR 走线封死）、D2_5（距邻焊盘仅 4.0mil）、J2_11（落孔也不改变判定）。

---

## 第 4 步：以上都不行 → 布局或自动布线

- **布局**：挪器件腾出过孔位/走廊。风险：会断现有走线，**必须先落盘回退基准**（未连清单 + 走线坐标）。
- **自动布线**：扩展 `PCB Auto Router`（AI+GPU，写回画布）。需 GUI 操作。

**判据**：同一跳在 **3 组以上参数**（不同 `--step` / `--max-detour` / 目标焊盘）都 `incomplete`，
才可判定为"需要布局/自动布线"，并**写进 `docs/capability-boundary.md`**，不要继续盲试。

---

## 与验收的配合

| 阶段 | 判据 |
|---|---|
| `pcb-connectivity` | Connection Error = 0 |
| `pcb-dfm` | DFM ERROR = 0（改连线期间必须始终为 0，否则先清违规） |
| `negative-drift` | 运行日志里不得出现 `rip-up --net`；`route solve` 次数不得多于 `dump` 次数（`route fill` 自带快照，不计入） |

**收尾顺序**：连线 → `pour-rebuild` → `save` → `doc reload` → `pcb drc` → `pcb check`（DFM）→ 交付导出。
