# Tasks: EasyEDA AI Design Kit

**Input**: Design documents from `specs/004-ai-pcb-design-kit/`
**Prerequisites**: plan.md ✅, spec.md ✅, research.md ✅, data-model.md ✅, contracts/ ✅, quickstart.md ✅
**Tests**: 本项目**要求**自带测试——门禁本身曾两次静默失效，测试是产品的一部分（`selftest.ps1`、`mistake-matrix.ps1`）。
**Organization**: 按用户故事分组，每个故事可独立验收。

## Format: `[ID] [P?] [Story] Description`

- **[P]**: 可并行（不同文件、无未完成依赖）
- **状态**: `[x]` = 已完成并有证据；`[ ]` = 待做

## Path Conventions

产品仓库 = `easyeda-design-kit/`（**刻意无 `src/`**，见 plan.md「Structure Decision」）。
规划文档 = 本 workspace 的 `specs/004-ai-pcb-design-kit/`。

---

## Phase 1: Setup（共享基础）

**目的**：仓库与产品定义就位。

- [x] T001 建立独立仓库 `easyeda-design-kit/`（git init，main）— 提交 `51af5b8`
- [x] T002 写产品定义 `easyeda-design-kit/PRODUCT.md`（是什么/不是什么/复用优先/三态）
- [x] T003 [P] 写仓库说明 `easyeda-design-kit/README.md`（三件套、安装、验收、反偷换）
- [x] T004 [P] 写需求规格 `specs/004-ai-pcb-design-kit/spec.md` + `checklists/requirements.md`
- [x] T005 [P] 迁移可复用资产：`docs/extensions-index.md`、`docs/design-rules.md`、`playbooks/pcb-rebuild-routed.playbook.json`
- [x] T006 设定棘轮基线 `easyeda-design-kit/acceptance/baseline.json`

---

## Phase 2: Foundational（阻塞所有故事的前置）

**目的**：验收与门禁引擎。**没有它，任何"完成"都不可信。**

- [x] T007 [P] 验收主脚本 `acceptance/run.ps1`：9 阶段三态 + 退出码 0/1/2/3
- [x] T008 [P] 双向门禁 `acceptance/stages-gates.ps1`：正向 P1–P7、负向 N1–N9
- [x] T009 [P] 门禁自测 `acceptance/selftest.ps1`：8 条断言（每分支正例+反例）
- [x] T010 [P] 历史错误矩阵 `acceptance/mistake-matrix.ps1`：16 条用例，要求 16/16
- [x] T011 [P] 回归 fixture：`fixtures/runlog-clean.txt`、`runlog-drifted.txt`、`runlog-historical.txt`
- [x] T012 反偷换纪律文档 `docs/anti-drift.md`（判据 + 事故对照 + 每轮用法）
- [x] T013 决策表契约 `contracts/decision-row.schema.md`（解析算法为权威定义）
- [x] T014 验收报告契约 `contracts/acceptance-report.schema.md`（退出码不变式）
- [x] T015 [P] **批准宪法**：用 `speckit-constitution` 把 plan.md「Constitution Check」的 G1–G5 正式写入 `.specify/memory/constitution.md`（当前仍是未填模板）
- [x] T016 [P] `docs/capability-boundary.md` 骨架（E4 字段：capability/evidence/triedTools/alternative/status）

**Checkpoint**：门禁可运行且自测 8/8、矩阵 16/16 → 之后所有工作都可被判分。

---

## Phase 3: User Story 1 - 陌生人装上包只给需求就能画板 (P1) 🎯 MVP

**Goal**：给一段需求文本，端到端产出合格板；不依赖执行者的临场发明。
**Independent Test**：全新会话、零上下文，只读 `docs/` 与 `playbooks/`，按阶段文档走完并验收通过。

- [x] T017 [P] [US1] 决策表 `docs/tool-decision-table.md`：84 行，工具名全部可解析（`tool-decision-table` PASS）
- [x] T018 [P] [US1] 阶段文档 `docs/phases/schematic-s0-s6.md`：7 阶段，每阶段 entry/actions/exit/onFail（E2 字段）
- [x] T019 [P] [US1] 阶段文档 `docs/phases/pcb-p0-p10.md`：11 阶段，同上；每条 `exit` 必须是命令或数字阈值
- [x] T020 [US1] `playbooks/README.md`：现有链路索引（名称、用途、前置、影响面）
- [x] T021 [US1] 把 `pcb-rebuild-routed.playbook.json` 的「顺序理由」补进 playbooks/README
- [x] T022 [US1] 新增 playbook：`sch-import-then-place`（原理图→PCB 的导入与约束布局链）
- [x] T023 [US1] 在 `docs/phases/pcb-p0-p10.md` 写明每个阶段**首选扩展**（PCB Auto Router / 内电层自动分划 / 嘉立创下单检查 / PCB Delivery Export）
- [x] T024 [US1] 写 `docs/harness-install.md`：把 kit 装进任意 harness 的步骤（skill 目录形态）
- [x] T025 [US1] 未见板执行剧本 `docs/playbook-unseen-board.md`：从需求到验收的完整操作序列（含 tee 日志）

**Checkpoint**：一个没看过本项目的人能照文档画出板并自证。

---

## Phase 4: User Story 2 - 换模型/换 harness 结果一致 (P1)

**Goal**：产品能力不依赖特定模型。
**Independent Test**：同需求、两个执行者，各自跑完并都通过；阶段结论一致。

- [x] T026 [US2] `acceptance/compare-runs.ps1`：输入两份 `last-report.json`，输出阶段结论差异与一致性判定
- [x] T027 [US2] `docs/phases/pcb-p0-p10.md` 增加「执行者无关性」小节：哪些步骤允许顺序不同、哪些必须一致
- [x] T028 [US2] 记录模型/执行者到报告：`last-report.json` 增加 `executor` 字段（model + harness + session）
- [x] T029 [US2] 在 `quickstart.md` 加"第二执行者复跑"章节，含弱化验证（无模型切换时）的标注规则

**Checkpoint**：能证明（或诚实标注无法证明）SC-004。

---

## Phase 5: User Story 3 - 零一次性脚本 (P1)

**Goal**：所有写入来自具名命令/playbook，可被下一次直接复用。
**Independent Test**：审计运行日志，一次性脚本计数为 0。

- [x] T030 [US3] N1 判据：`.work/`、`*gen*.py`、`*apply*.json`、acceptance 外调用 easyeda 的脚本
- [x] T031 [US3] N4/N5/N6 日志审计：rip-up --net、求解>快照、save→drc 无 reload
- [x] T032 [US3] `playbooks/capture-run.ps1`→ 改为**文档化流程**：执行者用 `Tee-Object` 落日志（不引入新脚本，写进 playbooks/README 的操作说明）
- [x] T033 [US3] 把"撤销已落板路径"的正确做法写成 playbook 片段：`track-delete --ids` / `via-delete --ids`（对照 N4）

---

## Phase 6: User Story 4 - 产出可打样交付物 (P2)

**Goal**：Gerber / 钻孔 / 坐标 / BOM 齐备且非空。
**Independent Test**：导出到指定目录，`delivery` 阶段 PASS。

- [x] T034 [US4] 在 `docs/tool-decision-table.md` 的 J 节补「PCB Delivery Export」的实际参数与坑（实测后填）
- [x] T035 [US4] 用 `PCB Delivery Export` 在基线板上导出一次，记录文件清单与体积（证据入台账）
- [x] T036 [US4] `acceptance/run.ps1` 的 `delivery` 阶段支持扩展命名（当前仅 glob），避免导出命名差异导致误判
- [x] T037 [US4] 把"交付文件真实存在且非空"的证据格式写进 `contracts/acceptance-report.schema.md`

---

## Phase 7: User Story 5 - 能力边界诚实可查 (P2)

**Goal**：做不到的说清楚，给替代路径，不让执行者在失败里反复试。

- [x] T038 [US5] `docs/capability-boundary.md` 首版：至少 8 条，来自 49 轮实测（双层求解边界、单层 solver 限制、rip-up 语义、丝印清除需 ids、Gerber 导出历史缺口等）
- [x] T039 [US5] 每条必须含 `triedTools`（≥1 个真实工具名）——由 `capability-boundary` 校验器检查
- [x] T040 [US5] 增加校验：`docs/capability-boundary.md` 的条目结构检查并入 `positive-goal`（缺字段即 FAIL）
- [x] T041 [US5] 抽样验证脚本：随机抽 5 条边界，检查 `alternative` 描述的路径确实存在（人工确认 + 记录）

---

## Phase 8: Polish & Cross-Cutting

- [x] T042 [P] 安装/发布形态：调研 `.eext` 打包（research.md U1 未决项），产出 `docs/publish-extension.md`
- [x] T043 [P] 扩展装机口径对账：以 `easyeda actions` 为准，更新 `docs/extensions-index.md` 中漂移的数字
- [x] T044 [P] `README.md` 链接 quickstart 与 tasks，避免新读者无从下手
- [x] T045 全量回归：`selftest.ps1` 8/8 + `mistake-matrix.ps1` 16/16 + `run.ps1` 无 FAIL
- [x] T046 台账记录：本轮改了什么工具、板子推进到哪、下一步
- [x] T047 [P] 把 plan/tasks/quickstart 同步一份到 kit 仓库 `specs/`（保持单一来源说明）

---

## Dependencies & Execution Order

### Phase Dependencies

- **Phase 1 Setup**：已完成
- **Phase 2 Foundational**：T015/T016 未完成 → **阻塞 US1 的文档类任务**（阶段文档要引用边界条目）
- **US1（P1）**：依赖 T016；T018/T019 是 T020–T023 的前提
- **US2（P1）**：依赖 T018/T019（需要阶段文档才能比对"阶段结论一致"）
- **US3（P1）**：N1/N4–N6 已就绪，剩余为文档与 playbook 片段
- **US4（P2）/ US5（P2）**：依赖 US1 的交付与边界文档骨架

### User Story Dependencies

- US1 无跨故事依赖
- US2 依赖 US1 的阶段文档（T018/T019）
- US3 与 US1 并行可行（判据已存在）
- US4 依赖 US1 的 J 节（决策表）
- US5 依赖 T016 骨架

### Within Each Story

- 文档骨架 → 内容 → 校验器 → 回归
- 先让门禁 FAIL（缺口被发现），再补内容让它 PASS

---

## Parallel Example: US1

```text
# 三件事互不依赖，可同时进行：
T018 docs/phases/schematic-s0-s6.md
T019 docs/phases/pcb-p0-p10.md
T020 playbooks/README.md

# 阶段文档完成后才能写（引用具体 exit 判据）：
T023 docs/phases/pcb-p0-p10.md 的首选扩展小节
T025 docs/playbook-unseen-board.md
```

---

## Implementation Strategy

### MVP First

1. Phase 2 收尾（T015 宪法、T016 边界骨架）
2. Phase 3（US1）→ **STOP & VALIDATE**：让一个零上下文的执行者只靠 `docs/` 走一遍
3. 若走不完，缺什么补什么——**不允许靠"我知道怎么做"补**，必须写进文档

### Incremental Delivery

1. US1 文档齐 → 验收里 `kit-integrity` 从 FAIL 变 PASS
2. US5 边界齐 → 抽查通过
3. US4 交付验证 → `delivery` 阶段可判
4. US2 比对脚本 → SC-004 有据可依

---

## Notes

- `/src` 不存在是**设计**，不是遗漏（P3 会拦）
- 每个任务完成即提交，提交信息写清"这轮长了什么能力"
- 每轮结束跑 `selftest.ps1` + `mistake-matrix.ps1`；任一失败视为该轮未完成
- **不要为了变绿去改判据**——历史上这么干过，被 matrix 抓出来

## Phase 9: 交付链路补全（converge 新增）

- [x] T048 **[已完成：结论=网页版不可用]** [US4] 验证扩展 `PCB Delivery Export` 的 GUI 导出路径（类型化动作面已打通：`pcb.export.gerber` 74,863 B、`pcb.export.pick_place` 13,358 B、`schematic.export.bom` 8,378 B 需 `--doc`）——**需 GUI 点击，未验证**
- [x] T049 [US4] BOM 导出：排查 `schematic.export.bom` 的 no-file（是否需模板/文档上下文），或改用 `PCB Delivery Export` 扩展

## Phase 10: 生态复用（按业主指示，避免重复造轮子）

- [x] T050 采用上游 `smart-hardware-engineer` 的 Design IR + Gate-1 校验器（MIT），并接入验收阶段 `design-ir`（实测：样例 PASS / 破坏后 FAIL；Windows 需 `PYTHONUTF8=1`）
- [x] T051 用**真实开源工程**做未见板用例：已下载 `ProPrj_ESP32S3_USB_2026-05-20.epro2`（0.3 MB，ZIP 魔数校验通过）→ 待导入后跑验收
- [ ] T052 **外部工程导入（别人画的板）**：动作目录无 import，网页版走原生文件框（GAP-032）。**不再是 SC-001 的前置**——SC-001 已由 typed 自造板达成 2/2；此项保留是为了验证"外部输入"这条线的鲁棒性
- [x] T053 评估把上游 `references/` 的电路架构知识并入决策表（去重后引用，不整份复制）
- [x] T054 封装 `acceptance/export-delivery.ps1`：一条命令跑完 Gerber/坐标/BOM 三个动作、收集制品、写 delivery-evidence.json（实测 74,869 / 13,358 / 8,379 B，exit 0）——修掉三个坑：`$args` 是自动变量、artifact 提示行污染 JSON、PCB 导出必须 `--doc`

## Phase 11: 收敛（converge）——剩余两个孤岛的处置

- [x] T055 **[已完成 2026-10-31]** [需业主授权]** 用扩展 `PCB Auto Router` 全板重布，取代命令行逐跳。理由：剩余 6 条（GAP-025）已是两个孤岛，命令行六种参数组合全部 incomplete。**需要业主**：允许我操作 EasyEDA GUI（浏览器自动化点击扩展面板）。
- [x] T056 **[已作废：自动布线后无需挪件]** ，需先具备回退基准]** 挪动 D2 或 U1/U3 之间器件腾出过孔位/走廊。前置：把当前 6 条未连 + 全部走线坐标落盘作为回退基准；失败时按坐标挪回。**需要业主**：确认可以承受「断掉现有走线再重连」的风险。
- [x] T057 命令行层面已穷尽：D2_5 三组参数（默认 / step15+detour1500 ×2 目标）与 U0TXD 七组参数全部 `incomplete`，已如实记入 GAP-019/025，不再盲试。


## Phase 12: 成功判据证据（SC）

- [x] T290 SC-005：新增 `decision-actionability` 门禁（机械定义：工具名 + 参数≥10字符 + 标未装须给替代），首跑 77/94=81.9% FAIL，逐行改写后 **93/94=98.9% PASS**
- [x] T291 SC-006：连续两次完整验收，各 15 阶段，**0 处判定不一致**（须两次都无 BLOCKED 才有效）
- [x] T292 SC-002/SC-003：`schematic-gates` + Connection 0 + DFM 0 + 交付三件齐备、`no-oneoff-scripts` PASS，均有门禁输出
- [x] T293 SC-001 **按自造板路径达成 2/2**（`sc001-led-typed` + `sc001-ldo-typed`，均 16 PASS / 0 FAIL / 0 BLOCKED）。原表述"0/2、素材依赖导入"已作废：导入只覆盖"别人画的板"这类输入，不是 SC-001 的唯一路径。口径限制见 `docs/sc-evidence.md`（两块均由本会话执行）
- [x] T294 SC-004 **已验证（harness 维度）**：两个零上下文子 agent 复跑，运行 C 与运行 A 逐阶段 0 处不同（16/0/0，退出码 0）；**模型维度未验证**（均 deepseek-v4.1）


## Phase 13: 未见板与跨执行者（本轮收敛）

- [ ] T295 **[需人工一步]** 导入 `esp32s3-usb.epro2`（`DSH-Data\tmp\osb\`，305.5 KB）验证外部板输入线。**需要业主**：点一次「导入 → 选文件」。**不阻塞任何已完成判据**
- [x] T296 外部板判定口径已固化：先记基线（`pcb drc` + `pcb check`，以 check 为准），基线违规照实报告，不得为变绿改判据 —— 见 `docs/playbook-unseen-external-board.md` 与 GAP-033。
- [x] T297 SC-001 **2/2 达成**（两块均由 typed 动作现场生成并通过验收；零上下文复跑见 `docs/executor-crosscheck.md` 方法）
- [x] T298 SC-004 **已验证（harness 维度）**，证据见 `docs/executor-crosscheck.md`；换模型仍需业主提供入口


## Phase 14: SC-001 第 1 块（typed 生成）

- [x] T301 **SC-001 第 1 块 `sc001-led-typed` 全绿**：纯 typed 生成（无 GUI/粘贴），验收 **16 PASS / 0 FAIL / 0 BLOCKED**，交付 Gerber 10,150 B / CPL 1,040 B / BOM 6,815 B。口径：本会话执行，非零上下文会话。
- [x] T302 修 `pcb-dfm` 判据缺陷：`pcb check` 零违规时输出 `0 issue(s)` 而无 `ERROR=` 计数行，旧判据会把**干净板**判 FAIL。抽 `acceptance/dfm-parse.ps1` 兼容两种形态，配 3 条自测断言（33/33）。
- [x] T303 **SC-001 第 2 块 `sc001-ldo-typed` 全绿**：AMS1117 供电板（4 件/3 网），DSN→`pcb_autorouter` 全自动布线 7/7（116ms），验收 **16 PASS / 0 FAIL / 0 BLOCKED**；SC-001 达成 **2/2**（口径：均由本会话执行）



## Phase 15: SC-001 第 3 块（换电路类型）

- [x] T306 **SC-001 第 3 块 `sc001-buck-blk`（P-MOS 高侧负载开关）全绿**：`block.pmos_highside_softstart` 6 件/7 网，`--spacing 220 --per-row 3` 下 **6 组 0 重叠 / 0 出图纸**，DSN→`pcb_autorouter` **15/15 连通（135ms）**，DFM **ERROR=0**，交付 Gerber 16,151 B / CPL 2,882 B / BOM 7,111 B，验收 **16 PASS / 0 FAIL / 0 BLOCKED**；据此**更正 GAP-042/044**（GAP-045：放不下是块相关，不是 A4 普遍限制）；SC-001 达成 **3/3**。

## Phase 16: SC-001 第 4 块（自动下载电路）

- [x] T307 **SC-001 第 4 块 `sc001-autodl-blk`（ESP32 自动下载电路）全绿**：`block.esp32_autodownload` 4 件/6 网；该块模板把两电阻夹在三极管中间（3 处 1mil 级细缝重叠），改用「disconnect → modify 移到 y=680/760 → connect」后 **0 重叠 / 0 悬空引脚**；DSN→`pcb_autorouter` **6/6 连通**，DFM **ERROR=0**，交付 Gerber 14,671 B / CPL 2,116 B / BOM 6,885 B，验收 **16 PASS / 0 FAIL / 0 BLOCKED**。同时记录两个坑（GAP-048）：connect 方向必须等于引脚外朝方向；export-dsn 的 stale 报错会假称"板没有网络"。SC-001 达成 **4/4**（四种电路类型）。

## Phase 17: SC-001 第 5 块（USB-C 输入前端，GAP-047 结案）

- [x] T308 **SC-001 第 5 块 `sc001-usbc-blk`（USB-C 输入前端）全绿**：配方 = `220/3` 进框 + 补 `J:A6↔USB_HOST_DP`（reconcile 7/7）+ 把 ESD 挪到 (350,700) 且同侧三标签桩长错开（18/96/174）+ `no-connect` 标 SBU 两脚；`clusters` **0 重叠/0 出图**、**29/29 布通**、DFM **ERROR=0**、交付 Gerber 22,154 B / CPL 2,760 B / BOM 7,124 B，验收 **16 PASS / 0 FAIL / 0 BLOCKED**。同时记录三个坑（GAP-049）：多页污染致 30 器件、`no-connect` 语法与 `connect` 不同、`destagger` 半途失败会留待恢复清单。**SC-001 = 5/5**（五种电路类型），GAP-047 结案。

## Phase 18: 大块配方固化为 playbook + 五板全量回归

- [x] T309 **`big-block-fit` playbook（14 步）**：把「大块塞进 A4」的四步配方写成可重放资产——换页重置缓存（GAP-043）→ 非单调研判（GAP-046）→ 先进框再对账补脚 → 挪单件+桩长错开 → 显式 NC → 清试验页（GAP-049）→ save+reload 后导出。门禁 P6 核对：**5 个 playbook / 37 步全部命中现有命令**；实证 `sc001-usbc-blk` 16 PASS / 0 FAIL / 0 BLOCKED。
- [x] T310 **五块板全量回归**：`sc001-led-typed`、`sc001-ldo-typed`、`sc001-pmos-typed`、`sc001-autodl-typed`、`sc001-usbc-typed` 同一次顺序运行，**每块 16 PASS / 0 FAIL / 0 BLOCKED**，0 退化。

## Phase 19: 决策表补本会话学到的 10 条

- [x] T311 **决策表 97 → 107 行**：新增「大块放不进 A4 / 能否换页重置缓存 / 落块后如何对账 / 组包络重叠 / 引脚悬空如何揭穿 / 不用脚标 NC / 挪件后按外朝方向重连 / 多页污染导入件数 / DSN 导出的假错误 / destagger 半途失败的恢复」共 10 条，每条都带真实命令与实测坑。门禁：`tool-decision-table` **107 行全部可解析**，`decision-actionability` **106/107 = 99.1%**（SC-005 要求 ≥90%）。

## Phase 20: 修 M12 测试缺陷（硬编码基线）

- [x] T312 **修 `mistake-matrix` 的 M12 假通过**：M12「决策表行数缩水」里把 `DecisionBaseline` **硬编码成 99**。表 97 行时它比基线小 → 判 FAIL（测试通过）；本轮把表补到 107 行后，107 > 99 → 判 PASS，**矩阵从 16/16 掉到 15/16**，这才暴露出来。修法：基线改为**按当前表行数动态计算**（`$decRows + 5`），保持「模拟表比基线少」这一原意不变。
  **反例验证**（证明不是把测试改绿）：把 `baseline.json` 的 `decision_rows` 临时改成 200，`negative-drift` 立刻报 `N8 决策表行数从 200 降到 107（工具经验在减少）`；改回 107 后恢复。矩阵回到 **16/16**，自测 **36/36**。

## Phase 21: 自查（数字对账 + 措辞歧义 + 未验证用例标注）

- [x] T313 **数字对账**：逐项核对文档声称 vs 文件实数——阶段 **16 ✓**、边界 **49 ✓**、决策表 **107 行 ✓**、playbook **4 个 / 37 步**（此前我在报告里把"playbooks 目录 5 个文件（含 README）"说成"5 个 playbook"，**是我的措辞错误，已改正**）、case 文件 **7 个**（其中 1 个从未跑过）。
- [x] T314 **消除门禁消息歧义**：`positive-goal` 原先把四个计数输出成 `规范产物 22/5/28/9`，容易被读成"5 个 playbook"（实际是 playbooks 目录的文件数，含 README）。改为带标签：`文档 22 个/playbooks 目录 5 个文件/acceptance 28 个/specs 9 个`。这是**消息可读性**修改，判据逻辑未变。
- [x] T315 **标注未验证用例**：`acceptance/cases/open-source-esp32s3-usb.md` 从未跑过验收（导入 `.epro2` 需人工点文件框，GAP-032），文件头加「**状态：未验证**」「不要把这个用例当成证据引用」，并写明 SC-001 的 5/5 全部来自五块自造板。

## Phase 22: 外部审计整改（6 类真缺陷）

- [x] T316 **修外部审计查实的 6 类缺陷**：(1) `delivery` 钻孔证据改为**真开 Gerber zip**（原来硬编码 true，文本文件改名 .zip 也能过）；(2) `no-oneoff-scripts` 加「日志至少 3 条实质行」门槛 + 豁免改精确文件名白名单（原来 `acceptance\任意.ps1` 可绕过）；(3) `schematic-gates` 回退分支改为 `sch check --strict` + 解析 floating pin 计数（原来「没出现 failed 字样就 PASS」）；(4) `capability-boundary` 的 status 正则 `[::]`→`[:：]`（原来死代码，任意非法 status 都 PASS）；(5) `selftest` 汇总如实报 SKIP（安装形态 35 PASS/1 SKIP，不再冒充 36）；(6) `kit-portability` 补 `C:\Program Files` / `C:\ProgramData` 模式。
- [x] T317 **新增第 17 阶段 `pcb-drc-clean`**：判据 = `pcb drc` 的 `passed=true` 且所有分类为 0，解析不到 passed 判 BLOCKED。**实测暴露真相**：练习板 27 条违规（Clearance 26 + Netlist 1）、USB-C 板 3 条（Clearance 2 + Netlist 1）→ 两板均为 **16 PASS / 1 FAIL**。SC-A 的「DRC 0」标注为**未达成**（GAP-050）。
- [ ] T318 **（待办）把 DRC 违规清零**：先修 Netlist Error（每板 1 条），再修 Clearance（练习板 26 / USB-C 2）。这是 SC-A 达成的实际前置。
- [ ] T319 **（待办）per-board 验收报告入库**：`acceptance/last-report.json` 被 gitignore，导致「16 PASS」没有版本库物证；改为 `acceptance/runs/<日期>-<case>.json` 并解除忽略（审计 S2）。
- [ ] T320 **（待办）把 `sample-boundaries.ps1` 接入主链路**：当前未接入且 3/5 不合格（GAP-028、GAP-037 的 triedTools 解析不到）（审计 S10）。

- [ ] T321 **（本轮实测，未完成）USB-C 板 DRC 清零**：3 条违规（2 间距 + 1 网表）。已证：`import-changes`(verified) + save + reload 后**三条原样**；把原理图 `J5:A6` 桩长从 174 改到 30 也**不影响**那条 5.1mil 间距（说明是 PCB 走线几何，不是原理图桩）。下一步：备份后 `rip-up --net USB_HOST_DM` 重布，或用更高间距重跑 autoroute；Netlist Error 需从 GUI 的 Import Changes 面板取差异条目。

- [ ] T322 **（本轮实测）诊断结论**：`sc001-usbc-blk` 的 3 条 DRC 违规中——(a) 两条间距属 **PCB 走线几何**，CLI **无走线级编辑命令**，只能撕网重布或整板重跑；(b) **PCB 备份在本项目上失败**（`project export` / `export-source` 均不产出文件）→ 无回滚，**未执行**撕线；(c) Netlist 差异：7 个网名与原理图**完全一致**，差异在**焊盘级**，而 `pcb nets`/`pcb list` 不暴露焊盘→网络，CLI 读不到 → 需 GUI 的 Import Changes 面板。下一步（需人或在有备份时）：先解决备份、再看差异面板。

- [x] T323 **（审计 S2）per-board 验收报告入库**：`run.ps1` 现在除 `last-report.json`（仍 ignore）外，另写 `acceptance/runs/<时间>-<case>-<executor>.json`（含 case/executor/project/doc/exitCode/逐阶段结论），并解除 `acceptance/runs/` 的 gitignore。**五块板的报告已入库并 `git ls-files` 可查**，内容如实记录 `pass=16 fail=1 blocked=0`，失败阶段均为 `pcb-drc-clean`。
- [x] T324 **（审计 S9）文档数字统一**：README（0/1/8 → 8/0/9、8/8 → 36 PASS）、HANDOVER（7/0/7 → 8/0/9、23/23 → 36）、executor-crosscheck（7/0/9 → 8/0/9）、cases/esp32-4layer（7 份 → 16 份必需文档）已改；crosscheck 与 HANDOVER 顶部加「口径更正」说明：2026-10-31 前的「16 PASS / 0 FAIL」属旧 16 阶段口径，当前诚实数字是 **16 PASS / 1 FAIL**。**历史 progress-log 行不改**（当时口径下是真的）。

- [x] T320 **（审计 S10）把 `sample-boundaries.ps1` 接成门禁第 18 阶段 `capability-sample`**：脚本 exit 0 → PASS、exit 1 → FAIL（附不合格条目）、脚本缺失 → BLOCKED。**接入即暴露它是 3/5 不合格**，随后修掉解析器的三个真缺陷：(1) 多行 `alternative` 只取首行（导致误判"过短"）→ 改为整段取值；(2) 括号注释 `（4 个方向）` 未剥离 → 先剥再匹配；(3) `bsk_*` 工具族、`CLI x`、`easyeda --help`、`扩展 X` 等合法写法解析不到 → 扩语料（装机清单 + 外部工具 JSON）并加归一化。另修 `GAP-031` 的 triedTools：把非工具的「手动预建目录」换成真实替代 `` `pcb.export.gerber`（类型化动作）``。**结果 5 通过 / 0 不合格**，门禁实测 `[PASS] capability-sample 5 通过 / 0 不合格`。

- [x] T325 **（本轮自查，已修）新增阶段打断流程**：`capability-sample` 第一版对数组调 `.Trim()` 抛异常，因 `$ErrorActionPreference=Stop` **中止整条验收**（矩阵 16/16 → **2/16**、自测 36/36 → **33/36**，大量 `MISSING`）。**是错误矩阵抓住了我自己**。修法：先转 `[string]` 再 Trim + 阶段整体 `try/catch`（异常降级 BLOCKED，不打断流程）。修后 **36/36、16/16 恢复**。记入 GAP-054。

- [x] T327 **运行中检测窗口丢失**：起跑与收尾各测一次 `daemon health` 的窗口数；若起跑有窗口、收尾没有，打印
  `[WARN] 运行期间 EDA 窗口消失`、汇总行加 `[PARTIAL]`、durable 报告写 `partial=true`，并以 **exit 2（BLOCKED）** 结束——
  不再留下"前面 PASS、后面 BLOCKED"的混合结论。实测：窗口在线的完整运行为 **18 PASS / 1 FAIL / 0 BLOCKED**、无 PARTIAL；无窗口时正常 BLOCKED 且不误标。
- [x] T328 **（自查，已修）两个新缺陷**：① 静态跑也写 per-run 报告 → `acceptance/` 涨到 274 个文件，改为**只给带 `-Project` 的真实运行**写；② `positive-goal` 的能力计数把运行产物算进去，清理垃圾被判"能力退化"（矩阵 14/16、自测 35/36）→ 计数排除 `acceptance/runs/` 并按新口径重设基线。修正后三件套恢复 **36/36、16/16、9 PASS / 0 FAIL / 10 BLOCKED**（GAP-056）。

- [ ] T329 **（本轮开工，未完成）重建 DRC-clean 的 USB-C 板**：新工程 `sc001-usbc-clean` 已建、块已在 P2 以 `220/3` 落好（6 件），但补 `J1:A6` 时**窗口掉线**，配方没跑完。下一步（窗口稳定时）：补 A6 → 挪 ESD（错开桩长 18/96/174）→ 标 SBU 为 NC → 导入 PCB → 板框 margin 200 → autoroute → `pcb drc` 复查是否 0 违规。

- [x] T330 **（结论任务）DRC 0 判定为当前工具链不可达**：按 GAP-049 配方**独立重建**了一块新板 `sc001-usbc-clean`（新工程、新页、`220/3`、补 A6、挪 ESD、标 NC、板框 margin 200、autoroute **29/29**），`pcb drc` 仍报 **3 条**，且与旧板 `sc001-usbc-blk` **逐条相同**（Slot Region 11.7/11.8、Pad-to-Track 5.1/6、Netlist Error）。两次独立构建得出同一组违规 ⇒ 不是摆放问题，是**布线器间距模型 vs DRC 判定口径不一致 + 网表记账差异**，而修它需要的能力（slot/pad 级 clearance 参数、走线级编辑、GUI 操作）当前**三者皆不可得**（GAP-053/058）。**SC-A 的「DRC 0」据此标注为：当前工具链不可达。**

- [x] T295 **外部 `.epro2` 导入成功（GAP-032 结案）**：开始页「快速开始 → 导入专业版」→ 页面内模态框 → `···` 唤起原生「打开」框（**先导航到目录再填文件名**）→ 第二次确认框（新建工程，默认名 `ESP32S3_USB`）→ 导入。CLI 立即可见：**8 张原理图页**（Power_In & Regulation / ESP32S3_Core / Boot_Reset / Clock / RF_WiFi_Antenna / HMI_Keys_LED / Pin_Config / PSRAM）+ **PCB2**（`87d68529660f4a39`）。最终两次「导入」确认需人点击（本次业主点一次、我点第二次）。
- [ ] T331 **（下一步）给导入的 `ESP32S3_USB` 跑 P4 基线**：这是真正的「别人画的板」（8 页 + 4 层）。按 GAP-033 纪律：**先记基线**（DRC/DFM/连接数/器件数），再跑 acceptance，外部板自带的历史违规**如实判 FAIL**，不改判据。

- [x] T331 **外部板 `ESP32S3_USB` P4 基线已记**：见 `acceptance/cases/open-source-esp32s3-usb.md` 的「P4 基线」——
  **45 器件**（bottom 12/top 33）、**29 信号网**、ratsnest **9816 mil**、60 crossings（**未布线**）、
  `pcb drc` passed=False **1 条**（Netlist Error）、`pcb check` **215 条**（含 1 个畸形焊盘的 `LIMIT`）、
  `layout-lint` **0/100**。基线先记后动，符合 GAP-033。
- [ ] T332 **（卡点，下一步）外部板 DSN 导出失败**：`pcb export-dsn` 报"没有网络"但板上 45 器件/29 网；按 GAP-048 的
  save→reload→等→重连 序列重试仍失败 ⇒ 不是 stale。首要嫌疑是该板 DFM 报的 1 个畸形焊盘（缺源形状/可读宽高），
  次嫌疑是 PCB 文档前台状态。见 GAP-059。需要：焊盘级诊断能力（CLI 无），或 GUI 侧手工导出 DSN 验证是否能出。

- [x] T333 **查明「窗口反复掉线」根因（GAP-060）**：不是 EDA/连接器问题，是 **bsk 会话空闲约 5 分钟自动关闭**，
  连带关掉它打开的 Agent Window 与 EDA 标签（`session not registered or already stopped … --session-idle (default 5m)`）。
  这解释了 GAP-055（连跑两次 10 处不一致）与 GAP-057（重建中断）。
- [ ] T334 **（新卡点）导入板连接器绑不上（GAP-061）**：新开会话→点工程 `ESP32S3_USB` 后，
  `daemon health` 显示**窗口数 2 但上下文全空**，`board list`/`pcb autoroute` 均被 `no connected window for project` 拒绝。
  下一步：用 bsk 观察确认工程是否真进入编辑器；或从标签 URL 取 `projectUuid` 直接拼 `#id=…,tab=…` 打开。

- [x] T334 **恢复外部工程绑定（GAP-061 解法）**：外部工程第一跳**必须走 UI** —— 在开始页点工程名后，
  标签 URL 变为 `#id=<projectUuid>`，uuid 只能从这里取到；`project find` 在没有绑定窗口时返回
  `empty_uuid_list`（鸡生蛋）。绑定后 `daemon health` 显示 `project=ESP32S3_USB / uuid=8b44c965…`，
  `board list` 恢复（`PCB2 / 87d68529660f4a39`）。
- [ ] T335 **（新卡点）外部板 DSN 仍导不出**：绑定恢复后 `documentType/documentUuid` 仍为空，
  `pcb export-dsn` 报"没有网络"。对照自造板同流程正常 ⇒ 差异在该板文档激活状态（GAP-063）。
  下一步：在界面里双击打开 PCB2 使其成为活动文档，或用 `project info`/`doc ls` 确认当前文档。

- [x] T335 **排除"文档未激活"假设并确定可复用操作**：工程树里**单击只选中、双击才打开**——双击 `PCB2` 后
  `daemon health` 变成 `documentType=pcb / documentUuid=87d68529660f4a39`（正确板子）；**但** DSN 导出与一体化
  `pcb autoroute` 仍报 `DSN export returned no file`。⇒ 卡点在**板自身数据**（首要嫌疑：DFM 报的畸形焊盘），
  不在文档激活。
- [ ] T336 **（下一步）外部板 DSN 导出失败的真因验证**：两选一——
  ① 在 GUI 里手工「PCB → 导出 DSN」试一次：若能出，说明是 CLI 侧 ;若同样失败，则是板数据；
  ② 定位那个 `LIMIT` 焊盘（需要焊盘级查询，CLI 无此能力）。

- [x] T336 **查明 CLI 可用性的两个必要条件（GAP-060 续）**：可用 = **守护进程在线 ∧ bsk 会话在线（有窗口）**。
  实测：`daemon start` 是前台常驻命令（600 s 后被转后台）；守护在线但会话回收后 `窗口数: 0`，
  所有 `--project/--doc` 动作不可用。
- [ ] T337 **（下一个可执行）把 bsk `--session-idle` 调大或加保活**：这是解除 GAP-055/057/061/063 的共同前置。
  具体：查 bsk 插件/守护进程的 idle 配置项（未验证位置），或在工作流里每 ≤4 分钟发一次轻量 `bsk_inspect` 保活。

- [x] T337 **查明 GUI 自动化三条前置（GAP-064）**：① 浏览器+扩展必须 `connected`（本轮 `bsk_session start` 报
  `no browser is currently connected`，这是**人的动作**）；② 会话需**每 ≤4 分钟一次 bsk 调用**保活（否则 5 分钟回收并关掉 EDA 标签）；③ `easyeda daemon start` 常驻在线。
- [ ] T338 **（需业主一步）让浏览器与扩展连上**：打开浏览器并确认 browser-skill 扩展弹窗显示 connected。
  之后才能继续 T336（GUI 手工导出 DSN 验证）与外部板布线。**这不是我能代做的动作。**

- [x] T339 **新增 `docs/boundary-index.md`（64 条边界的自动索引）**：按 status 分组（open 28 / resolved 23 / accepted 13），
  每段一张「编号 + 标题」表；文件头声明"由源文件生成、门禁校验的是源文件、本文件只是导航"。
  用途：64 条平铺时"还有哪些没解决"要翻全文，现在一屏即可（open 段即待办清单）。
- [x] T340 **决策表补 3 条 GUI 前置的实操行（107 → 110 行）**：① CLI 报 `no connected window` → `daemon health` 看窗口数；
  ② 动作报 `no easyeda-agent daemon found` → `daemon start`（前台常驻，会转后台任务）；
  ③ 要在网页版点 GUI → 先验三前置（扩展 connected / 会话 ≤4min 保活 / daemon 在线）。
  门禁：`tool-decision-table` **110 行全部可解析**，`decision-actionability` **109/110 = 99.1%**。

- [x] T341 **新增 `docs/boundary-root-causes.md`：28 条 open → 7 个根因**（并核实 28/28 全覆盖）：
  R1 走线/过孔资源与布线器能力（7）· R2 DRC 几何闭环缺失（5）· R3 组包络与 A4 排版（6）·
  R4 GUI 自动化前置与环境回收（5）· R5 外部板 DSN/绑定（2）· R6 CLI 只读查询缺口（2）· R7 扩展装上≠能用（1）。
  关键结论：**R1/R2/R3/R5 都卡在同一条能力——"缺走线级编辑 / 焊盘级诊断"**，说明真正该投资的是那一件工具能力，
  而不是逐个现象打补丁；R4 只差"开浏览器"这一个人类动作。

- [x] T342 **动作目录清扫（169 条 × 边界）：又查出 1 条"没试专用工具就下结论"** —— `pcb via-bond`
  （给焊盘内无网过孔赋网，带 `--dry-run`/`--component`）在 `capability-boundary.md` 里**出现 0 次**，
  而 `GAP-024「焊盘内打过孔仍不连通」` 正是它要解决的事 ⇒ 该结论目前只能算**未验证**。
  同轮核对确认 `pcb route fill` 与 `pcb power-planes` 在 GAP-008/019/021/022/025 都试过，那 4 条不改判。
  新增规矩（写进根因图谱）：**下"做不到"前先按语义扫 169 条动作目录**——本会话已因此误判两次（GAP-006、GAP-024）。
  决策表补 1 行（焊盘内过孔 → `pcb via-bond --dry-run`）。
- [ ] T343 **（需窗口）用 `pcb via-bond --dry-run` 实测 GAP-024**：确认计划是否覆盖该焊盘 → 实跑 → 立即 `pcb net-path` 复核（注意 #118 限制：赋值不跨 reload 存活）→ 据实重写 GAP-024。

- [x] T344 **把新导航文件纳入 `kit-integrity` 必需清单**：`docs/boundary-index.md`、`docs/boundary-root-causes.md`
  加入 `$required`（16 → **18 份**），防止它们被悄悄删掉；`kit-integrity` 实测 **18 份必需文档齐备**。
- [x] T345 **`sc-evidence.md` 按 19 阶段口径全面校订**：SC-001（5/5 但每块现为 18 PASS / 1 FAIL）、SC-002、SC-004（标注"当时口径 16 阶段"）、
  SC-005（110/111 = 99.1%）、SC-006（18 个可比阶段 0 处不一致、两次均 0 BLOCKED），以及**跨板回归表 5 行**从 16/0/0 改为 **18 PASS / 1 FAIL**，
  并在表前加口径说明。残留 3 处旧数字均为**已标注的历史引用**（不删，保留"口径是怎么变的"这条线索）。

- [x] T346 **修 `decision-actionability` 的假达标（外部审计 A1）**：旧判据只量"参数列 ≥10 字符"，纯散文也能 100%。
  收紧为**必须含具体物**（flag / 反引号命令 / 数值+单位 / 文件名 / JSON 载荷）。实测：**33/111 = 29.7%**（旧 99.1% 作废）。
  同时把自测里那条"kit 自身 PASS ≥90%"改写为"**给出可核对的比例、结论落在三态内**"——原断言考的是表格质量而不是门禁行为。
  **SC-005 如实标注为未达成**（29.7% < 90%）；静态 acceptance 因此变为 **8 PASS / 1 FAIL / 10 BLOCKED**。
- [ ] T347 **（新待办）重写决策表 78 行**：把"参数无具体物"的行补成可执行内容（具体 flag / 命令 / 数值单位 / 文件），
  目标把可执行率从 29.7% 提到 ≥90%。每条补全都必须来自实测，不允许编造参数。

- [x] T347 **决策表可执行率的真实数字：18/111 = 16.2%**。本轮做了三件事：
  ① 判据细分——扩展类没有 CLI flag，硬要 flag 会逼人编造；改为「CLI 物证 **或** 可核对界面入口 + 工具是已装扩展」；
  ② 把 6 行 CLI 行补上**真实参数**（`pcb route fill --net/--from/--to`、`pcb pour-rebuild`、`pcb via-stitch --dry-run` 孔径 16/8、
  `pcb.export.pick_place --payload {"fileType":"csv"}`、`project.open --project-uuid`）；
  ③ **发现根本问题**：失败行点名的 73 个工具里 **60 个本机根本没装**（对照已装 22 个）⇒ 这张表大半是"市面扩展目录"，
  不是可执行手册。已给 90 行打上 **`未装`** 标记（诚实标注"仅为目录信息，不能直接执行"）。
  结果：可执行率 **99.1% → 16.2%**。**SC-005 未达成，且不是补文案能解决的**。
- [ ] T348 **（需业主决策）SC-005 的口径二选一**：① **装扩展**——把目录里真正要用的扩展装上并在本机验证入口
  （需要浏览器 + 逐个安装验证，GUI 动作）；② **重划范围**——SC-005 只对「CLI/动作类行」统计可执行率
  （当前 18 行里 CLI 类占比高），把扩展目录单独列为"库存清单"不计入该判据。**未获业主选择前，按未达成记录。**

- [x] T349 **逐行核验那 18 行"可执行"是否名副其实**（不许虚报）：用完整命令路径跑 `--help` 比对每一行的 flag。
  结果：**7 行 CLI✓ 且 flag 全部真实存在**（`pcb route fill` 的 `--net/--from/--to/--layers/--dry-run` 经实测确认存在；
  我第一版核验脚本误把 `pcb route fill` 拼成 `pcb route --help`，因此误报"缺 flag"，已修正脚本重验）。
  **3 行按真名更正**：`schematic.runDrc`→`sch drc`（真实子命令）、`PCB 交付`→`pcb.export.gerber`（类型化动作，经 `call` 调用）、
  `pcb_autorouter.exe` 标注为**外部程序**（`--threads/--auto-rules` 是它自己的 flag，不在 easyeda 帮助里）。
  仍为 **18/111**（行数未变，内容更准）。核验方法已写进 SC-005 证据。

- [x] T350 **修 playbook 门禁的"只查命令名"缺陷（GAP-067）**：先造反例（`pcb route fill --no-such-flag-xyz`）证明旧门禁**判 PASS**，
  再补 flag 级校验（按**完整命令路径**取帮助——`pcb route fill --help` 而非 `pcb fill --help`，第一版就是这么错的）。
  修后：反例只报那一个假 flag；真 kit `37 步 / 27 个 flag 全部存在`；自测加断言 **37/37**。
  **未验证的下一层**：flag 的**取值合法性**（如 `--layers 1,2` 的合法域）仍没校验。

- [x] T351 **补 playbook 的 flag 取值类型校验（GAP-068）**：伪造 `sch block-apply --spacing abc`（帮助声明 `float`）证明旧门禁判 PASS；
  修后按 `--help` 的类型声明校验 `int`/`float` 型取值，反例精确报错、真 kit 报 **37 步 / 27 flag / 37 步做过类型校验**；
  自测加断言，**38/38**。
- [ ] T352 **（未验证的两层，如实留档）**：① 枚举/区间域（`--layers` 合法组合、`--margin` 合理范围）；② 跨 flag 约束（`--per-row`×`--spacing`、`--at` vs 图纸边界）。这两层目前**没有任何校验**。

- [x] T353 **新增第 20 阶段 `evidence-freshness`（GAP-069）**：三份文档残留作废数字（16 PASS×6、36 PASS×4、107 行、99.1%），
  无人看守。新阶段扫描四份证据文档的 6 类**已作废取值**，出现即 FAIL；带「当时/历史/旧口径/作废」的行豁免。
  上线后**立刻又抓到 2 处**上轮漏改（`executor-crosscheck.md:135`、`sc-evidence.md:11`）。
  正反例与两条自测断言齐备：自测 **38 → 40**。静态 **9 PASS / 1 FAIL / 10 BLOCKED**（阶段 **19 → 20**）。

- [x] T354 **新增第 21 阶段 `claims-match`（GAP-070）**：HANDOVER 顶部放 `<!-- claims: … -->`，
  与**同轮可算**的实测值比对（阶段数 / 边界数 / 决策表行数 / playbook 步数 / 自测断言数），不递归跑 selftest。
  反例（stages 声明 19 / 缺块）均判 FAIL；真文档 5 项一致 PASS。自测 **40 → 42**，claims 内 `selftest_cases` 同步。
  静态 **10 PASS / 1 FAIL / 10 BLOCKED**（阶段 **20 → 21**）。
- [ ] T355 **（未覆盖，如实留档）**：① claims 目前只判**相等**，没有"只增不减"棘轮（阶段数/断言数不该降）；
  ② 自然语言结论（"五块板全绿"这类）仍不在任何门禁的核对范围。

- [x] T356 **给 claims 加"只增不减"棘轮（GAP-071）**：修前存在换绿通道——**删内容 + 同步改 claims** 即判 PASS（反例：边界删到 1 条、claims 改 1 → 修前 PASS）。
  修后 `baseline.json` 增 6 项地板（阶段/边界/决策表行/playbook 步/断言数/可执行行），`claims-match` 同时判"声明=实测"与"实测≥地板"；
  反例改判 `棘轮： boundaries 从 70 降到 1`。自测 **42 → 43**。
  **两个自己踩的坑也记进 GAP**：地板必须读仓库 baseline（读 -AuditRoot 会静默跳过）；两次"改了但没生效"都是靠反例仍 PASS 才发现的。
- [ ] T357 **（未覆盖）**：地板只覆盖 6 项；SC 状态与每板三态没有地板；自然语言结论**明确不自动化**（判定该由人工评审，避免正则硬凑）。

- [x] T358 **止血：自测探针在 `acceptance/runs/` 堆积 129 份垃圾报告（GAP-072）**：根因是 `selftest.ps1` 的三条
  `no-oneoff-scripts` 断言用 `-Project sc001-ldo-blk` 调 `run.ps1`，而"带 -Project 就归档" ⇒ 每次自测写 3 份。
  修：`run.ps1` 加 `-NoArchive`，三处调用带上；实测自测/矩阵/静态跑完报告数**恒为 8**。
  清理：按 `executor=unspecified 且 blocked>0` 删 129 份，保留 **8 份真实运行**。
- [ ] T359 **（未覆盖）**：`acceptance/runs/` 的**份数没有地板也没有上限**——若再堆积不会自动报警。
  考虑加一条：真实运行份数 ≥ 板数（当前 5）且探针产物（unspecified∧blocked>0）必须为 0。

- [x] T359 **新增第 22 阶段 `report-hygiene`（GAP-073）**：反例（放一份 `unspecified`+BLOCKED 报告）修前**无任何阶段报警**；
  修后判 `探针产物 1 份： zzz-probe-junk.json`。规则：探针产物必须为 0、真实运行份数 ≥ 板数 5。
  真 kit：`探针产物 0 份；真实运行 7 份`。踩坑：目录初版取 `RepoRoot` 使探针读真 kit、断言永远 PASS → 改 `AuditRoot` 才可测。
  自测 **43 → 44**；静态 **11 PASS / 1 FAIL / 10 BLOCKED**（阶段 **21 → 22**）。
- [ ] T360 **（未覆盖）**：① 真实运行**上限**（同一板反复跑不限量）；② 旧报告（17/18 阶段）不算"过期"，其结论与现阶段集不一致时无提示。

- [x] T360 **`report-hygiene` 增加"阶段集一致性"分级（GAP-074）**：把真实运行分为 fresh（阶段数=当前 22）与 stale（≠），
  fresh ≥ 5 才 PASS；fresh=0 但有 stale → **BLOCKED**（缺前置证据，不是缺陷）；junk>0 仍 FAIL。
  **实测暴露真相：8 份真实运行的阶段数是 17/17/17/17/17/19/19/19，没有一份与当前 22 阶段一致** ⇒
  此前"报告入库"一直是旧账。自测 **44 → 45**；静态 **10 PASS / 1 FAIL / 11 BLOCKED**。
- [ ] T361 **（需窗口）重跑五块板产生与新阶段集一致的证据**：`sc001-led/ldo/pmos/autodl/usbc-typed` 各跑一次带 `-Project` 的完整验收。
  当前 daemon 不可达、窗口 0，因此 `report-hygiene` 维持 BLOCKED。**这一项不需要新判据，只需要窗口。**

- [x] T362 **新增 `acceptance/sync-claims.ps1`（结构性修复"忘记同步"）**：按与门禁同口径算 6 项并重写 HANDOVER 的 claims 行，
  带 `-Check` 预览。**背景：我连续三轮"先写文档后忘同步"导致 claims-match 判 FAIL**——判据没错，是流程有洞。
  该工具不削弱判据（手改错值照旧 FAIL、地板照旧挡下降），只把合规从记忆负担变成一条命令。

- [x] T363 **新增 `-Static` 模式，纠正"11 项 BLOCKED"的夸大（GAP-075）**：逐条拆开后，11 项里**只有 2 项是真阻塞**
  （`environment` 无窗口、`report-hygiene` 无新证据），其余 **9 项只是没传板级参数**。
  `-Static` 只跑 12 项文档/门禁检查，汇总行注明"本模式不含 10 项板级检查，未计入 BLOCKED"：
  实测 **`10 PASS / 1 FAIL / 1 BLOCKED`**。
  顺带修掉被它暴露的真缺陷：板级调用缩进后 `^Test-` 正则把阶段数从 22 数成 12 → 三处改为允许缩进。

- [x] T364 **把 `-Static` 模式钉成断言（T363 的收尾）**：断言「`-Static` 必须真的跳过板级检查并在汇总注明」。
  踩坑两个：① 断言里用 `2>&1` 捕不到 `Write-Host`（属信息流），必须 `*>&1`；
  ② 我又把 `param` 块改坏了（`$RunPs1` 用到了未定义的 `$KitRoot`）——**第四次"改脚本但改坏"**，仍是断言先红才暴露。
  自测 **45 → 46**；claims 同步 46。

- [x] T365 **新增 `docs/README.md` 读者路径（产品可用性，不是门禁）**：21 份文档此前没有入口。
  按三条路径组织：**5 分钟**（PRODUCT → sc-evidence → 自己跑 `-Static` 验一次）、
  **半小时**（HANDOVER → 根因图谱 → 决策表 → phases）、**要动手**（playbooks 4 个/37 步）、
  另加「查具体条目」（索引 → 完整边界）与「这些结论可靠吗」（crosscheck / progress-log / anti-drift / retro-audit）。
  写清三条阅读纪律：数字只信门禁；看到"未验证"当没做过；「未达成」不是失败是记录。
  **把它接进门禁**：`docs/README.md` 进入必需文档（18→19），`kit-integrity` 校验其 **22 个链接**；
  反例（临时改名 `retro-audit.md`）实测判 `FAIL … 有 1 个死链： retro-audit.md`，恢复后 PASS。

- [x] T366 **`evidence-freshness` 扫描面从 4 份扩到全部文档（24 份）**：此前只扫 HANDOVER/crosscheck/README/sc-evidence，
  其余 20+ 份里的作废数字无人看。扩面后**立刻抓到 14 处**（`capability-boundary.md` 4 处、`progress-log.md` 9 处、
  `vendor-claims-easyeda-v4-ai.md` 1 处）。
  处理口径：`progress-log.md` 按纪律「历史只增不改」**整份豁免**；其余按语义标注（历史结论加"当时 16 阶段口径"、
  GAP-069 标题改写以免把旧值当断言、vendor 表加"当时口径"）。同时修正阶段号措辞（19 → 22）与 PASS 文案（"四份" → "全部文档 24 份"）。
- [x] T367 **核实 `acceptance/cases/` 7 个用例**：全部只写**需求 + 配方 + 实测基线**，没有阶段数/PASS 声明 ⇒ 与当前判据无冲突，无需改动。

- [x] T368 **新增 `docs/status.md`：一页纸诚实盘点**（能做什么 / 不能做什么 / 为什么 / 需要业主什么）。
  - **能做**（6 项，带可复跑证据）：五块板端到端（18 PASS / 1 FAIL）、外部 `.epro2` 导入（8 页 + PCB2）、
    A4 塞大块配方、37 步可执行 playbook、外部布线器 29/29、门禁自证（本会话被自己抓到 6 次回归）。
  - **不能做**（6 项，逐条附原因，明确写"不再重试"）：DRC 0（GAP-058 两次重建同 3 条）、走线级编辑、
    焊盘级诊断、决策表当手册（18/111，60/73 工具未装）、全自动 GUI（三前置）、换模型（SC-004 阻塞）。
  - **7 个根因**一句话版 + **"补上走线级编辑可一次解开四个根因"**这一投资判断。
  - **三条阻塞**全部只需业主一个动作；附三条自验命令（已实测与文档一致）。
  接入：`docs/README.md` 顶部指引、根 README 指向、进入必需文档（19 → **20**）。

- [x] T369 **维护：核对 `docs/status.md` 里每个数字是否可核**。发现一处不可核——「本会话门禁抓到我 6 次」
  无法从 `progress-log.md` 数出（只能数到 3 行显式记录），已换成**可核引用**：
  指向 `capability-boundary.md` 的 GAP-067/068/069/070/072/073/074/075（实测 8 个条目全部存在）。
  同时清理本会话在 `%TEMP%` 留下的 8 项探针（6 个目录 + 2 个文件）。

- [x] T370 **发现并修复 `specs/` 双副本分叉（GAP-076）**：kit 内 `tasks.md` 停在 239 行（工作区 489 行），
  `T360`/`T368` 等任务记录**在宿主产物里不存在**；`quickstart.md` 同样分叉（kit 内仍是 `2 PASS / 1 FAIL / 8 BLOCKED` 的旧状态）。
  修：同步两份 + `kit-integrity` 增加**两份逐字节一致**检查（6 份 spec 文件），反例（加一空格）实测判 FAIL、恢复后 PASS。
  同时把 `evidence-freshness` 扫描面扩到 `specs/`（`tasks.md` 作为历史豁免）。

- [x] T371 **修 agent 入口 `SKILL.md`（GAP-077）**：它的阅读顺序里**缺** `docs/status.md`（一页纸结论）与 `docs/README.md`（分层路径）
  ⇒ agent 会直接扎进细节文档，读不到"能做什么/不能做什么"。已加「0.5 先看结论（30 秒）」并作为第 0 步。
  同时 `kit-integrity` 增加 **SKILL.md 引用校验**（解析 `` `docs/...` `` 逐个 Test-Path），反例（改名 `pcb-p0-p10.md`）实测判 FAIL。
  另排查全库同名副本：仅 `specs/004` 一对（GAP-076 已修），无新增分叉。

- [x] T371b **发现并部分修复"僵尸断言"（GAP-078）**：46 条断言里 **25 条**只判 `Status=FAIL/BLOCKED`，不看理由。
  僵尸探针（缺 HANDOVER.md）让 `claims-match` 以「HANDOVER.md 不存在」失败，而『边界数下降判 FAIL』断言仍然通过。
  已给 2 条（棘轮 / 探针产物）加 **Detail 关键词**校验；正常探针仍 46/46，僵尸探针下正确判失败。
- [ ] T372 **（剩余 23 条）把否定断言全部升级为"状态 + 理由"双校验**：逐条确定该阶段**只可能因**什么理由失败，
  写成关键词；写不出唯一关键词的，说明该判据的失败原因是开放的，需先收紧判据。另需检查**正向断言**是否会被"空数据"空过。

- [x] T372 **否定断言统一加固（GAP-078 收尾）**：新增 `Test-NegativeResult`（状态合法 + 明细非空 + **拒绝基础设施类错误**），
  机械替换 **19 处**；另 5 处本就在校验明细关键词。**6 样例单元验证全对**：缺 HANDOVER ⇒ 拒、假 flag/目录/棘轮 ⇒ 放行、
  未指定参数 ⇒ 拒、JSON 损坏 ⇒ 拒。踩坑：初版把"不存在"一律拒，误杀 2 条正当断言（44/2），收窄后恢复 **46/46**。
- [ ] T373 **（剩余风险）**：正向断言 `Status -eq 'PASS'` 可能被"数据为空"空过——例如某阶段在空表上判 PASS。需逐条检查。

- [x] T373 **查正向断言的"空数据空过"（GAP-079）**：空 `-AuditRoot` 实测 → `evidence-freshness` 只扫到 **1 份**文档就判 PASS。
  修为"文档数 <10 ⇒ BLOCKED（无法证明新鲜）"；空目录实测 BLOCKED、真 kit PASS（33 份）。
  同探针还确认 `kit-integrity`/`positive-goal` **按设计**读 `$script:RepoRoot`，在探针里不能证明任何事（已写明）。
- [ ] T374 **（未做）**：逐条探测其他阶段在"零样本"下的行为（如 `capability-boundary` 在 0 条边界时、`capability-sample` 在 0 条可抽时），
  凡"扫到 0 个却说没问题"的都要加下限。

- [x] T374 **零样本普查（GAP-080）**：逐条探测 16 项静态阶段的零样本行为。**4 项本来就有下限**（决策表 ≥30 行、
  可执行率 ≥20 行、边界 ≥8 条、抽样需解析到条目）；**`kit-portability` 空过**（1 份无路径文档 → PASS），已加下限
  （扫到 <10 文件 → BLOCKED）；上一轮已修 `evidence-freshness`。两项按设计读 RepoRoot（kit-integrity / positive-goal）已写明。
- [ ] T375 **（未做）**：`installed-claims` / `run-consistency` / `report-hygiene` 在**部分缺失**数据下的行为未逐条探测。

- [x] T376 **新增 `acceptance/pre-commit.ps1`（GAP-081）**：提交前强制三件套，任一未达预期即 exit 1 并列出问题行，
  不执行 commit。允许清单只有 `decision-actionability`（SC-005 已知未达成）且每次打印。
  反例（塞 `GAP-999` 缺字段）实测被拦并点名两条未预期 FAIL；还原后放行。**本会话两次带红灯提交（`3a016e7`/`614d45d`）的成因已机械化拦截。**
- [ ] T377 **（未做）**：把 `pre-commit.ps1` 装成 git hook（`.git/hooks/pre-commit`）才能真正防绕过；当前依赖"我主动用它"。

- [x] T377 **把 pre-commit 装成真正的 git hook（GAP-081 收尾）**：`.githooks/pre-commit` + `git config core.hooksPath .githooks`；
  `pre-commit.ps1` 加 `-Check`（只校验）。**反例实测**：塞 `GAP-998` 缺字段后直接 `git commit` → hook 拦下、退出码 1、
  **未产生提交**；正常提交可通过（本轮即用它提交）。未覆盖：`core.hooksPath` 不随仓库分发，新克隆需一次性配置（已写明）。

- [x] T378 **可移植性实测：把 kit 复制到临时目录并跑三件套（GAP-082）**。结果：`45 PASS / 0 FAIL / 1 SKIP`、
  矩阵 `16/16`、静态 `10 PASS / 1 FAIL / 1 BLOCKED`。**核心检查不依赖母目录**，但 `历史回测` 需要兄弟目录
  `../easyeda-auto` 作为夹具（脱离后诚实 SKIP，未被算作 PASS）。已写入 `docs/status.md` 的"怎么自己验"。
- [ ] T379 **（待定）是否把历史回测夹具随 kit 分发**：需要评估体积与许可；不随包时应在文档标明"该项为开发期专有"。
