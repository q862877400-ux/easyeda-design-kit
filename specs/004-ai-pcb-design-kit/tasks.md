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
- [ ] T052 `.epro2` 导入为**一次性 GUI 操作**（动作目录无 project import）；导入后其余流程全 CLI 驱动——**需 GUI，未验证**
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
- [ ] T293 SC-001：两块**未见板**端到端通过（当前 0/2；素材依赖 T052 导入开源 .epro2）——**需 GUI**
- [x] T294 SC-004 **已验证（harness 维度）**：两个零上下文子 agent 复跑，运行 C 与运行 A 逐阶段 0 处不同（16/0/0，退出码 0）；**模型维度未验证**（均 deepseek-v4.1）


## Phase 13: 未见板与跨执行者（本轮收敛）

- [ ] T295 **[需人工一步]** 导入开源 `.epro2`（本机已有 `DSH-Data\tmp\osb\esp32s3-usb.epro2`，305.5 KB）。阻塞原因：网页版导入走原生文件框，自动化工具无 file-input 能力（GAP-032）。**需要业主**：点一次「导入 → 选文件」。
- [x] T296 外部板判定口径已固化：先记基线（`pcb drc` + `pcb check`，以 check 为准），基线违规照实报告，不得为变绿改判据 —— 见 `docs/playbook-unseen-external-board.md` 与 GAP-033。
- [ ] T297 SC-001 仍 0/2：两块未见板端到端通过验收。前置 = T295。
- [x] T298 SC-004 **已验证（harness 维度）**，证据见 `docs/executor-crosscheck.md`；换模型仍需业主提供入口

