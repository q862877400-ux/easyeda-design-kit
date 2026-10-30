# Contract: 决策表行（decision row）

**被谁执行**：`acceptance/run.ps1` 的 `tool-decision-table` 阶段。
**违反后果**：该阶段 FAIL（退出码 1）。

---

## 1. 行的物理形态

Markdown 表格行，四列：

```
| 情境 | 用哪个 | 参数 / 坑 |
```

实际是 4 个 `|` 分隔的单元格（首尾各一个空单元格），即：

```
|<situation>|<tool>|<params>|
```

**不计入行数的行**（解析时跳过）：
- 表头行（含 `情境`）
- 分隔行（`|---|`、`|:--|` 等）
- 空行

---

## 2. 字段契约

### 2.1 `situation`（第 2 个单元格）

- MUST 是**具体任务**，一句话内能看懂"什么时候用"。
- MUST NOT 是工具名本身（那是第 3 列的事）。
- 例：`整板按模块自动布局`、`等长走线`、`嘉立创下单前 DFM`。

### 2.2 `tool`（第 3 个单元格）

- MUST 是**真实工具名**：扩展名 / `easyeda` 命令 / 类型化动作。
- MUST 能通过下述解析算法。
- MUST NOT 含操作说明（如 `PCB自动化工具 → 整版全自动模块化布局`）；
  子功能写进 `params` 列。
- MUST NOT 是脚本路径、文件名、或"自研"字样。

### 2.3 `params`（第 4 个单元格）

- SHOULD 含关键参数（端口、阈值、格式）。
- 已知坑 MUST 用事实句写（`整板一次调用会超时`），不得写"注意性能"。
- 未实测的点 MUST 标 `未验证`。

---

## 3. 解析算法（权威定义）

给定 `tool` 文本 `T`（先后去除首尾空白、反引号、`*`）：

```
RESOLVED(T) :=
    T 出现在 `easyeda actions` 的命令输出中（子串匹配）
 OR T 出现在 docs/extensions-index.md 的文本中（子串匹配）
```

- 全部行 RESOLVED → 阶段 PASS，报告行数。
- 任一行不 RESOLVED → 阶段 FAIL，报告**前 5 个**未解析名。

**已知语义**：子串匹配偏宽松（`pcb drc` 会命中 `pcb drc-check` 之类）。
这是**有意的取舍**：宁可宽松，也不引入需要维护的正则/白名单；真正的把关靠"工具名逐字照抄索引"。

---

## 4. 数量契约

- `rows >= 30`，否则阶段 FAIL（低于此值说明表还没写起来）。
- 行数 MUST 单调不减：`rows >= baseline.decision_rows`（`negative-drift` 的 N8 判定）。
- 新增行 SHOULD 附一次真实使用记录（在 `docs/phases/*.md` 或 playbook 里被引用）。

---

## 5. 正例

```
| 全板自动布线（首选） | PCB Auto Router | AI+GPU 双引擎，最高 32 层，实时写回画布，不用手工导 DSN/SES |
| 按电流估线宽 | knowledge.widthForCurrent | 命令层；`currentA` 必须 >0 |
| 嘉立创下单前 DFM | 嘉立创下单检查 | 18 项检查，可点定位、可导报告 |
```

## 6. 反例（会被判 FAIL 或应写进 params）

```
| 窗口掉线 | tools/ensure_eda_window.py | ...        ← 脚本路径不是工具名
| 整板布局 | PCB自动化工具→整版全自动模块化布局 | ... ← 带了子功能说明
| 布线 | 写个脚本调 eda.pcb_* | ...                ← 自研，违反 G1
```
