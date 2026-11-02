# 发布为 EasyEDA 扩展（`.eext`）——调研与方案

**结论先行**：`.eext` 是**标准 ZIP**，内含 `extension.json` + 编译后的入口包 + 图标 + README/CHANGELOG。
上传走 [EasyEDA 扩展中心](https://ext.easyeda.cn) / [英文站](https://ext.easyeda.com/) 的「扩展管理」。
**但本 Kit 的完整能力依赖 `easyeda` CLI，扩展内无法携带可执行文件**——所以扩展形态只能是
「文档 + 提示词 + 调 `eda.*` 的薄指令」，完整能力仍需 CLI 形态。这一限制已记为 GAP-011。

---

## 1. 已核实的打包要求（来源：官方文档）

来源：[Extensions Marketplace 官方文档](https://prodocs.easyeda.com/en/api/guide/extensions-marketplace.html)

| 要求 | 内容 |
|---|---|
| 包格式 | `.eext`（标准 ZIP，含编译产物与元数据）|
| `extension.json` 必填 | `name`、`uuid`、`displayName`、`description`、`version`、`license` |
| 分类 | `categories` 至少一个；文档给出的取值：`Schematic` / `Symbol` / `PCB` / `Footprint` / `Panel` / `Library` / `Project` / `Other` |
| 图标 | 必须**自定义**（不得用 SDK 默认 logo）；建议 1:1；PNG/JPEG；**≤5 MiB** |
| 入口 | `entry` 必须存在且有效（编译后的 bundle，非源码）|
| 命名唯一 | 不同 `uuid` 的扩展不得共用同一 `name` |
| 文档 | `README.md` 要写清功能与用法；`CHANGELOG.md` 记版本历史 |
| 隐私 | 不得含手机号等私人信息 |

补充（来自社区实现，**非官方**，标为参考）：
[EasyEDA 扩展打包说明](https://deepwiki.com/oaslananka/easyeda-mcp-pro/3.2-extension-packaging-and-release)
——`.eext` 是 ZIP；入口 bundle 需 IIFE 格式（EasyEDA 扩展加载器要求）；
`uuid` 建议 32 位小写字母与数字。

---

## 2. 本 Kit 的扩展包结构（计划）

```text
easyeda-design-kit.eext   (ZIP)
├── extension.json          # 见 §3
├── dist/index.js           # IIFE bundle：注册菜单 + 把 docs 注入 AI 对话 + 调 eda.* 
├── images/logo.png         # 1:1，≤5MiB，非 SDK 默认图
├── docs/                   # 本 Kit 的知识包原样带入
│   ├── tool-decision-table.md
│   ├── capability-boundary.md
│   ├── phases/*.md
│   └── anti-drift.md
├── README.md
└── CHANGELOG.md
```

**为什么把 docs 打进包里**：扩展没有"仓库路径"概念，若不带文档，用户装上只得到一个空菜单。

---

## 3. `extension.json` 样例（可直接改）

```json
{
  "name": "easyeda-design-kit",
  "uuid": "0000000000000000000000000000a1b2",
  "displayName": "EasyEDA AI Design Kit",
  "description": "按规范把电路板落地并自证：情境→工具决策表、S0–S6 / P0–P10 阶段流程、能力边界清单与验收脚本。",
  "version": "1.0.0",
  "license": "MIT",
  "categories": ["PCB", "Schematic"],
  "entry": "dist/index.js",
  "icon": "images/logo.png",
  "publisher": "…",
  "bugs": "…"
}
```

**校验规则**（写进打包校验器，见 §5）：
`uuid` 为 32 位小写字母/数字；`version` 为 `x.y.z`；`description` ≥ 80 字符（参考实现的要求，官方未强制）；
`entry`/`icon` 指向的文件在包内存在且非空；`categories` 至少 1 个且在允许集合内。

---

## 4. 硬约束：扩展带不动 CLI（GAP-011）

| 形态 | 能做 | 不能做 |
|---|---|---|
| **CLI 形态**（`easyeda` 可执行 + Connector 扩展）| 全部：169 动作、193 命令、playbook、验收脚本 | 需要用户自己装可执行文件 |
| **扩展形态**（`.eext`）| 在编辑器内展示决策表/阶段文档；调用 `eda.*` 与类型化动作；给 AI 提供流程提示 | **无法**携带 `easyeda.exe`；无法运行 `acceptance/*.ps1`；无法执行 playbook |

**因此扩展形态定位为「入门与随身手册」**，不是完整能力。完整能力仍需 CLI 形态。
这不是缺陷掩盖，而是已记录的边界（`docs/capability-boundary.md` GAP-011）。

---

## 5. 打包校验器（本仓库提供）

```powershell
pwsh -NoProfile -File acceptance/check-extension-package.ps1 -Package <path\to\x.eext>
```

它检查：ZIP 可读、`extension.json` 必填字段齐全、`uuid`/`version` 格式、`categories` 合法、
`entry` 与 `icon` 在包内存在且非空、图标尺寸（若为 PNG，读 IHDR 校验 ≥200×200 且为正方形）、
不得含疑似手机号字符串。

**为什么先写校验器**：上传前能把不合规项挡在本地，比等审核打回快。

---

## 6. 未验证项（如实标注）

| 项 | 状态 |
|---|---|
| 实际上传、命名空间创建、审核时长 | **未验证**（需开发者账号，未操作）|
| 审核对 `description` 长度/图标像素的硬性阈值 | **未验证**（社区实现提到 ≥80 字符、≥200×200，官方文档未给具体数值）|
| 扩展内调用 `eda.*` 的权限边界 | **未验证**（未在扩展内实测）|
| IIFE bundle 的具体构建链 | **参考实现**（esbuild → IIFE）；本项目未实际构建 |

**结论**：打包**要求**已核实到官方文档级别；**执行链路**未实测。按铁律，前者可作为文档依据，
后者必须在真正上传一次后才能标"已验证"。

