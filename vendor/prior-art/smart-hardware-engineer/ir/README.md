# Design IR（代码优先的设计中间表示）

把"设计是什么"与"怎么在 JLCEDA 里画"彻底分开。IR 是设计的**唯一真相**，落图前先在 IR 上校验。

## 文件

- `schema/design_ir.schema.json` —— JSON Schema（draft 2020-12）。
- `examples/blinky_usb_mcu.ir.json` —— USB-C 点灯板示例（已通过 `ir_validate.py`）。

## 生命周期

```
方案确认(Gate-0)
   ↓ 填 meta/requirements/architecture
逐层填充 components/nets → schematic → board → placement → routing → manufacturing → firmware
   ↓ 每补一层就跑校验
python3 ../scripts/ir_validate.py design.ir.json      # Gate-1
   ↓ 通过后
确定性驱动 IR → JLCEDA（见 ../references/13-jlceda-control.md）
   ↓ 各阶段门(Gate-2..7)失败时
回到 IR 修改 → 重放（不要直接在 JLCEDA 里手改而不回写 IR）
```

> 原则：**IR 与 JLCEDA 必须保持一致**。在 GUI 里手动改了结构，要回写 IR；否则下次重放会覆盖。

## 顶层结构

| key | 内容 | 对应阶段/门 |
|-----|------|-------------|
| `meta` | 项目名/版本/单位/目标厂/确认状态 | Gate-0 |
| `requirements` | 中文需求与假设、成功判据、约束 | 02/03 |
| `architecture` | 电源树(rails+电流预算+余量)、功能块、风险 | 04 |
| `components[]` | 位号/类别/value/MPN/LCSC/封装/库UUID/装配/电源脚 | 06 |
| `nets[]` | 网名/网类/节点(refdes.pin)/差分伙伴 | 04/05 |
| `schematic` | page_rect/usable_rect/keepout_rects/分块/图纸尺寸 | 05 / Gate-2 |
| `board` | 板框/叠层/铜厚/按网类规则/机械孔/keepout | 07 / Gate-3 |
| `placement` | 放置顺序 + 每件坐标/旋转/层/分组 | 08 / Gate-4 |
| `routing` | 布线顺序/关键手布网/自动布线前置 | 09 / Gate-5 |
| `manufacturing` | 导出清单/丝印检查/订单边界 | 11 / Gate-6 |
| `firmware` | 目标MCU/工具链/引脚映射/构建 | 12 / Gate-7 |

## 驱动约定（IR → JLCEDA）

驱动（建议实现为 `../scripts/ir_to_jlceda.py`，本脚手架给出约定，由 Codex 落地）必须：

1. **幂等**：以稳定 `refdes`/`net name` 为键。进入任一写步骤先读 JLCEDA 现状（`getAll`/`getAllPrimitiveId`/`getNetlist`），存在则核对/修补，不存在则创建；重跑不产生重复对象。
2. **分阶段提交 + 立即回读**：原理图连通→回读确认→再进 PCB；每批小操作后回读校验，不信返回值。
3. **写 op-log**：每个操作记 `{op_id, target, input, readback, verdict}`，便于定位与回滚。
4. **失败给根因四分类**：原理/网表 · 布局 · 规则 · 桥/环境（见 `../references/01`），交 replan。
5. **遵守控制通道优先级与桥接前置**（见 `../references/13`）。

### 字段 → API 映射（速查）

| IR | JLCEDA 扩展 API（形态） |
|----|------------------------|
| `components[].` 选型 | `lib_Device.search(keyword)` → `sch_PrimitiveComponent.create(完整库搜索项)` |
| `nets[]` 连接 | `sch_PrimitiveWire` / 网标；回读 `sch_PrimitiveWire.getAll` |
| `schematic.page/keepout` | 放置前预算；右下角标题/明细表硬 keepout |
| 原理图→PCB | `pcb_Document.importChanges` → 点"应用修改" → 核对 `pcb_Net.getNetlist().pinInfoMap` |
| `board.outline` | `pcb_MathPolygon.createPolygon(['R',...])` → 原生 `pcb_PrimitivePolyline` |
| `board.mounting_holes` | 非金属化焊盘 `pcb_PrimitivePad.create(...metallization=false)` |
| `placement.items` | `pcb_PrimitiveComponent` 定位（大集合分批 get） |
| `routing` | 关键网手布 + 受控自动布线；回读 line/via 计数 + DRC |
| `manufacturing.exports` | `getGerberFile(prefix)` / `getPickAndPlaceFile(prefix,'csv')` / `getNetlistFile(prefix)` |

## 可选前端

IR 可手写，也可用代码生成以获得"连通性自检"：
- **SKiDL**（Python→网表）：用 Python 描述电路，导出后转成 IR 的 `components/nets`。
- **atopile / tscircuit / circuit-synth**：声明式/代码式描述，思路一致。

无论用哪种前端，最终都归一到本 IR，再走统一的校验与驱动。
