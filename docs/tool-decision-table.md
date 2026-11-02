# 情境 → 工具 决策表

**这张表的用途**：拿到一个念头（"我要把去耦电容挪到芯片旁边"），不必凭经验猜该调什么，
查表即可得到：用哪个工具、关键参数、已知的坑。

**填表纪律**

- 「用哪个」一栏只写**真实存在**的工具名（扩展名 / 命令 / 类型化动作），逐字照抄，不臆造。
- 「坑」一栏只写**实测过**的事实；没实测的写「未验证」。
- 一行一个情境；行数只增不减（`negative-drift` 的 N8 会记账）。
- 本表的性质是**学会后续工具的账本**，不是知识陈列：每行都对应一个真实任务。

---

## A. 开工 / 连接

| 情境 | 用哪个 | 参数 / 坑 |
|---|---|---|
| 要程序化驱动 EDA | AI 指令引擎 | 端口 49720；需先 `node bridge/command-proxy.mjs`，菜单「启动桥接」 |
| 要跑裸 `eda.*` JS | Run API Gateway | 端口 49620；`POST /execute {"code":"..."}` 返回 `{success,result}` |
| 要 CLI 风格类型化动作 | EDA Agent Connector | 端口 60832-60841；`easyeda.exe`，全量动作见 `--help` |
| 让 DSH 本体直接进 EDA | ai助手（deepseek-harness） | 自然语言驱动原理图/PCB，支持上传数据手册；**未装**（本机未安装该扩展，本行仅为目录信息，不能直接执行） |
| 窗口掉线、`windows` 为空 | EDA Agent Connector | 先修连接再往下跑；外部助手脚本 ensure_eda_window 可重开浏览器会话并等心跳 |

## B. 建库（符号 / 封装 / 器件）

| 情境 | 用哪个 | 参数 / 坑 |
|---|---|---|
| 只有芯片图片要符号 | 符号提取助手 | Qwen2.5-VL 视觉提取 → JSON(type/pinNumber/pinName) → 生成到画布；**未装**（本机未安装该扩展，本行仅为目录信息，不能直接执行） |
| 要 AI 生成符号+封装 | AI智能建库 | 大模型生成器；封装要与实际器件一致，别信默认；**未装**（本机未安装该扩展，本行仅为目录信息，不能直接执行） |
| 要查立创商城器件 | 主控芯片AI助手 | **未装**；**替代**：无 CLI 等价；用 `sch resolve-lcsc`（按 LCSC 号解析） |
| 批量查器件/数据手册 | 数据手册AI助手 | 选中器件后自动取手册；**未装**（本机未安装该扩展，本行仅为目录信息，不能直接执行） |
| 要器件的典型应用电路 | 原理图助手 | 选中器件后提取典型应用电路；**未装**（本机未安装该扩展，本行仅为目录信息，不能直接执行） |

## C. 原理图

| 情境 | 用哪个 | 参数 / 坑 |
|---|---|---|
| 自然语言 → 原理图 | AI巧绘 | **未装**；**替代**：无 CLI 等价；退一步用 `sch block-apply`（落标准块）+ `sch connect`（补网表） |
| AI 读/改原理图 | 让AI看看你的原理图 | **未装**；**替代**：无 CLI 等价；读用 `sch connectivity` / `sch list`，改用 `sch connect`/`sch modify` |
| 要喂给 LLM 的电路文本 | 局部原理图网表导出 | **未装**；**替代**：`sch netlist`（导出网表产物）+ `sch connectivity`（连通关系 JSON） |
| 导出整板网表拓扑 | 板卡拓扑导出器 | **未装**；**替代**：`pcb dump`（只读几何快照：器件/网络/焊盘/板框） |
| 芯片电源脚要整块放去耦 | 原理图自动去耦喵 | 主电容+去耦电容+标签+母线整块随鼠标放置；**未装**（本机未安装该扩展，本行仅为目录信息，不能直接执行） |
| 电源网络看不清 | 电源网络高亮助手 | **未装**；**替代**：`pcb nets`（列出网络）+ `pcb net-path`（验证两点确实连通） |
| 查悬空/单连接网络 | 信号缺失检测助手 | **未装**；**替代**：`sch check`（floating pin 计数） |
| 批量放元件  | 批量放置元件 | 导入 CSV（位号+封装+X/Y+旋转，mil），一键落位；放置后用 `pcb layout-lint` 查重叠；**未装**（本机未安装该扩展，本行仅为目录信息，不能直接执行） |
| 网表 → 原理图 | 网表重建原理图 | 导入网表 JSON 重建布局；**未装**（本机未安装该扩展，本行仅为目录信息，不能直接执行） |
| BOM 有重复值  | BOM元件查重 | **未装**；**替代**：`schematic.export.bom`（导出后按位号/封装比对） |
| 原理图 DRC | `sch drc` | 命令层；`runDrcDetailed` 带明细； |

## D. PCB 布局

| 情境 | 用哪个 | 参数 / 坑 |
|---|---|---|
| 整板按模块自动布局 | PCB自动化工具 | **未装**；**替代**：`pcb auto-place`（模块感知自动布局：把每个卫星件拉到它连的芯片脚旁） |
| 把散器件按原理图页分组 | PCB器件分组器 | **未装**；**替代**：`pcb arrange`（按共享网络聚类）或 `pcb auto-place`（按连接关系拉近） |
| BGA 底下塞滤波电容 | BGA 滤波电容放置 | 按焊盘网络与位置摆放，给每网络电容数量检查 |
| 板框/定位孔 | 板框定位孔生成助手 | **未装**；**替代**：`pcb mount-holes`（按板框生成安装孔） |
| 异形板框（图片/SVG） | 轮廓转换工具 | **未装**；**替代**：`pcb outline-round`（圆角矩形）或 `pcb outline-set`（自定义折线） |

## E. 布线 / 扇出 / 等长

| 情境 | 用哪个 | 参数 / 坑 |
|---|---|---|
| 全板自动布线（**已装可用**） | JsPCB自动布线 | 扩展菜单里唯一实际安装的自动布线器（基于 JS-PCB）；**PCB Auto Router / FreeRouting 本机未装** |
| 想用开源布线器（**未装**） | FreeRouting | **未装**；**替代**：`pcb autoroute`（内置 Freerouting 通道：DSN→布线→SES→导入→DRC） |
| 命令行逐跳布线（已装，实测 39→6） | `pcb route fill` | `--net <网名> --from <位号.脚> --to <位号.脚>`；每跳后 `pcb pour-rebuild` 再 `pcb drc` 复测（实测把 39 条未连降到 6 条）； |
| 全板自动布线（DSN→SES，主程序无头 CLI） | pcb_autorouter.exe | `-i board.dsn -a -o board.ses --threads 8 --auto-rules`；配合 `pcb export-dsn` / `pcb import-autoroute`；需主程序已登录（免费档 100 网/600 焊盘/4 层）； |
| 管脚扇出打孔 | PCB自动化工具 | **未装**；**替代**：`pcb escape-plan`（离线计算逃逸路径，**只读不写板**） |
| 模块级扇出 | PCB自动化工具 | **未装**；**替代**：`pcb escape-plan`（按 layout 意图预留逃逸通道） |
| 单焊盘/批量扇出 | 焊盘扇出 | **未装**；**替代**：`pcb escape-plan`（离线规划）+ `pcb via-hop`（落一个跳孔） |
| 短线自动布线 | PCB自动化工具 | **未装**；**替代**：`pcb route-short`（启发式短走线，còn需外部布线器补长跳） |
| 群组/总线布线 | PCB自动化工具 | 子功能「群组草图布线」；画总线路径生成等间距导线；**未装**（本机未安装该扩展，本行仅为目录信息，不能直接执行） |
| 等长走线 | 一键等长 | 单边/双边蛇形、大折返、混合 |
| 走线等距  | 走线等距 | 选两点间走线按推挤计算等距；等长需求改用 `一键等长` 或 `pcb.diff_pair`；**未装**（本机未安装该扩展，本行仅为目录信息，不能直接执行） |
| 拐角圆弧/线宽平滑 | 熔化/优化/美化PCB | **未装**；**替代**：`pcb beautify`（把尖锐拐角改成圆弧 arc） |

## F. 铜 / 内层

| 情境 | 用哪个 | 参数 / 坑 |
|---|---|---|
| 内电层要分划 | 内电层自动分划 | **未装**；**替代**：`pcb power-planes`（4 层 GND 内电层 + 电源内层 + 缝合过孔） |
| 走线跨参考层分割缝 | 跨平面检查 | 5 类违规：跨铺铜岛/跨缝隙/铜皮骑跨/跨走线/无参考平面；**未装**（本机未安装该扩展，本行仅为目录信息，不能直接执行） |
| 局部铺铜 | 自动生成铜皮 | **未装**；**替代**：`pcb pour`（铺铜）+ `pcb fill`（异形大块铜） |
| 空白区补铜提高良率 | 平衡铜工具 | 银角式补铜；另有盗铜工具自动避让 |
| 查铺铜填充状态 | pcb.listPours | **`filled` 未知时不能当空，也不能当完成**； |
| 重新填充铺铜 | `pcb pour-rebuild` | 新过孔/走线落板后必须重铺，否则 `pcb drc` 读到假间隙；重铺后 `pcb save` → `doc reload` 再读； |

## G. DRC / 规则 / DFM

| 情境 | 用哪个 | 参数 / 坑 |
|---|---|---|
| 按网名/电流/叠层生成规则 | 设计规则生成器 | **未装**；**替代**：`pcb drc-rules-set`（按 JSON 设全量规则，或只抬 pour clearance） |
| 规则导出/迁移 | 规则配置管理 | **未装**；**替代**：`pcb config`（读改真实设计规则）+ `pcb drc-rules`（读规则配置） |
| 嘉立创下单前 DFM | 嘉立创下单检查 | 18 项检查，可点定位、可导报告 |
| 飞控类硬件规范 | 飞控硬件设计规范 | 叠层/阻抗、晶振、电源去耦、CAN FD、USB-C、隔离/EMC；**未装**（本机未安装该扩展，本行仅为目录信息，不能直接执行） |
| 时序余量 | 时序图分析工具 | 路径延迟 + Setup/Hold + Timing Budget；**未装**（本机未安装该扩展，本行仅为目录信息，不能直接执行） |
| 设计统计 | 设计报告 | **未装**；**替代**：`pcb report`（只读设计统计） |

## H. 仿真

| 情境 | 用哪个 | 参数 / 坑 |
|---|---|---|
| 电路级 SPICE | NGspice 电路仿真 | transient/AC/DC + 蒙特卡洛 + 最坏情况；**未装**（本机未安装该扩展，本行仅为目录信息，不能直接执行） |
| 动态仿真 | SimulIDE仿真引擎 | 在仿真图页放置仿真器件后运行；只验证电路行为，不产出 PCB；**未装**（本机未安装该扩展，本行仅为目录信息，不能直接执行） |
| 轻量电路仿真 | CircuitJS1 | 内嵌，可一键导出到原理图；**未装**（本机未安装该扩展，本行仅为目录信息，不能直接执行） |
| 电流密度 / 功率密度 | PCB 电流密度仿真 | FEM；自动从网名推电压边界(+5V→5V)； |
| 电源直流压降 | PhySim DC仿真 | 需另装 PhySim DC 客户端；推 ODB++；**未装**（本机未安装该扩展，本行仅为目录信息，不能直接执行） |
| PDN 电源分配网络 | PADEN仿真 | 本地 Python 后端 FEM，WebGL 热力图；**未装**（本机未安装该扩展，本行仅为目录信息，不能直接执行） |

## I. 逆向 / 复刻 / 格式互转

| 情境 | 用哪个 | 参数 / 坑 |
|---|---|---|
| Gerber → 可编辑 PCB | Gerber 转 PCB (G2PCB) | 导入时勾选"带网络"，恢复铜箔与网络；元件位号需另补；**未装**（本机未安装该扩展，本行仅为目录信息，不能直接执行） |
| PCB → 原理图 | PCB 转 原理图 | 带网络可编辑；另有狼黑工具含改网络/换器件； |
| 读别人的工程文件 | 格式转换 | Xpedition/Cadstar/Fabmaster/P-CAD/Allegro/gEDA 互转；**未装**（本机未安装该扩展，本行仅为目录信息，不能直接执行） |
| 只有原理图 PDF 要对位 | 原理图PDF交互 | PCB 里预览 PDF，点位号自动选中+平移缩放；**未装**（本机未安装该扩展，本行仅为目录信息，不能直接执行） |
| 图片 → PCB | 图片转 PCB | 当前未装；需时用扩展广场现装 |

## J. 交付 / 导出

| 情境 | 用哪个 | 参数 / 坑 |
|---|---|---|
| Gerber+BOM+坐标一键 | PCB Delivery Export | CPL 过滤 + 双语制造要求；**打样交付首选**； |
| 只要 Gerber（含钻孔） | pcb.export.gerber | 动作面：`--payload {"unit":"mm","integerNumber":4,"decimalNumber":6}`；**产出是一个 zip，钻孔数据在包内**（metallic/nonMetallic/drillTable 默认 true）；空板/无铜返回 null；实测 74,863 B； |
| 要坐标文件（CPL） | `pcb.export.pick_place` | `--payload '{"fileType":"csv","unit":"mm"}'`；缺 `fileType` 会返回 no file； |
| 要 BOM | schematic.export.bom | 动作面：**必须 `--doc <原理图页 uuid>`**，否则返回 `ok:false`「BOM export returned no file.」；`fileType=csv； |xlsx`；实测 xlsx 8,378 B |
| 多子板生产+测试资料 | 多板生产文件一键导出 | 17 类接口，6 语言；**未装**（本机未安装该扩展，本行仅为目录信息，不能直接执行） |
| 工程源文件批量 | 工程文档批量导出 | .epro2，每工程一子目录；需开「项目管理>下载工程」 |
| 工程+库压缩包 | 导出设计压缩包 | 生成工程压缩包用于备份/交接；制造文件走 pcb.export.gerber / PCB 交付 |
| 装配图 | 装配图导出 | 丝印轮廓+焊盘开窗+板框三层 |

## K. 丝印 / 装配 / 外观

| 情境 | 用哪个 | 参数 / 坑 |
|---|---|---|
| 按网络名批量生成丝印 | 生成丝印 | **未装**；**替代**：`pcb silk-netnames`（按网络名批量生成丝印） |
| 按网络标签生成丝印 | 丝印生成器 | 当前未装；替代：easyeda pcb silk-import-svg 导入自绘 SVG 到丝印层 |
| 丝印填充避让 | 动态丝印填充 | 当前未装；替代：pcb silk-import-svg 放置已排版 SVG（even-odd 填充） |
| 3D 渲染 | PCB Blender 渲染工具 | WebSocket 发 Blender； |

| 未连焊盘要接到同网已连通铜 | `pcb route fill` | `--net` 指定网 + `--from/--to` 给两端焊盘；逐跳落线，每跳后重铺复测；实测 39→6； |
| 自动布线后剩 5.x mil 微差（5.4–5.8 对 6mil） | pcb via | 把肇事过孔从 24mil 原位缩到 20mil（位置不变、走线连接不受影响），实测 3 条清零； |
| 网页版要出富交付（STEP/交互BOM/工程源） | `pcb.export.gerber` | 扩展；仅桌面客户端可用；网页版点导出必报 `非客户端环境无法调用本接口`，改用 CLI 三动作 |
| 接一块别人的板（开源/客户给的） | pcb check | 先记基线再动手：`pcb drc --json` + `pcb check --json`，以 pcb check 为准；基线有违规就照实写进交付说明； |
| 本机 `.epro2` 要进编辑器 | `project.open` | 只能开**已有**工程：`--project-uuid <uuid>`；导入本地文件需人工点原生文件框（GAP-032），`project.create` 只建空容器； |
| 板子布完仍报一堆未连 | pcb drc | 用 `--json` 扁平输出；坐标是 **mil**（嵌套输出是 mm）；先按网分诊再动手； |
| 未连集中在电源/地 | pcb power-planes | 看 `stitch.<net>.unplaced`，>0 表示该焊盘周围无干净落孔位； |
| 必须在焊盘内打散热孔 | `pcb via-stitch` | 先 `--dry-run` 看计划；孔径用 `16/8`（默认 24/12 常放不下）；**dry-run 不校验间距**，落板后必须 `pcb drc`； |
| 撤销本次落的铜 | pcb via-delete | 按 id 精确删；**绝不删 DRC 标的未连过孔**，也绝不用 rip-up --net； |
## L. 计算 / 知识

| 情境 | 用哪个 | 参数 / 坑 |
|---|---|---|
| 线宽/间距/过孔/趋肤深度 | PCB 工具箱 | IPC-2221B/C 全套：导体内阻、电气间隙、过孔属性 |
| 查设计规则依据 | knowledge.query | 命令层；这就是「布线知识库」； |
| 列出可用规则 | knowledge.listRules | 命令层返回规则清单 JSON；配合 pcb drc-rules-set 生效； |
| 按电流估线宽 | knowledge.widthForCurrent | 命令层；`currentA` 必须 >0； |
| 电路基础/元件识别/单位换算 | Toolbox工具箱 | 分压/欧姆/LED/555/RC + 电阻色环 + SMD 代码；**未装**（本机未安装该扩展，本行仅为目录信息，不能直接执行） |

## M. AI 助手（按场景挑）

| 情境 | 用哪个 | 参数 / 坑 |
|---|---|---|
| 多模态看图 | EDA Copilot | 看原理图/PCB 截图；**未装**（本机未安装该扩展，本行仅为目录信息，不能直接执行） |
| 对话式分析电路 | AI分析助手 | 原理图分析 + 规则检查 + 草案生成；**未装**（本机未安装该扩展，本行仅为目录信息，不能直接执行） |
| 自定义本地知识库 RAG | AI 本地知识库 | 公司规范/自有资料喂给它；**未装**（本机未安装该扩展，本行仅为目录信息，不能直接执行） |
| 复用模块（CBB）对话 | 复用模块AI助手 | 复用已保存的复用模块；需先把该电路在工程里保存为模块；**未装**（本机未安装该扩展，本行仅为目录信息，不能直接执行） |
| JLCEDA 工作流 AI | JLCEDA AI Agent | 端到端工作流导向；本会话未实测，仅登记不推荐；**未装**（本机未安装该扩展，本行仅为目录信息，不能直接执行） |

## N. 专项（不属于通用画板，别混进通用清单）

| 情境 | 用哪个 | 参数 / 坑 |
|---|---|---|
| 发热膜蛇形线路 | 电热膜线路生成器 | 只生成电热膜蛇形线路；PCB 布线/铺铜不适用 |
| FPC 排线/金手指 | FPC 速成引擎 | 只服务 FPC 排线/金手指；刚性板不适用 |
| PCB 线圈 | 线圈生成器 | 只服务 PCB 线圈（无线充/变压器）；当前未装，需现装后用 |
| 番茄钟/待办/项目管理 | EE Workbench | 只服务番茄钟/待办/项目管理类工作流，不参与画板 |
| 物料库存 | PartLab 元器件库存管理 | 只服务物料库存查询；画板流程不依赖它；**未装**（本机未安装该扩展，本行仅为目录信息，不能直接执行） |
| 六件以上的块放不进 A4 | `sch block-apply` | 先试 `--spacing 220 --per-row 3`，再试 260/3；**判定非单调**（实测 220/260 接受，240/250 被拒）； |
| 同一页反复重试都被拒（说放不下） | `sch page-new` | 「放不下」判定**按页缓存**，`sch clear` 清不掉；换参数必须开新页（GAP-043）； |
| 块落好了，想知道连线对不对 | `sch reconcile` | 从块库重推应有连接逐条对账；块自带 autoconnect 会**漏脚**（实测漏 `J:A6`），漏了先补再谈布局； |
| 器件组（本体+marker+桩线）互相压 | `sch clusters` | 加 `--strict`；看「体积 vs 本体」；消重叠靠挪单件或同侧标签错开 `--offset`（实测 18/96/174），不靠 `sch destagger`； |
| 怀疑有引脚没连上 | `sch check` | 只看 floating pin 计数；`connect` 失败时 `clusters` 会显示 `marker 0`（假干净），只有这里能揭穿（GAP-048）； |
| 有些脚设计上就不接 | `sch no-connect` | `--designator J5 --pin A8,B8`；写成 `--pin J5:A8` 会**静默 ok:false** 且脚仍算悬空（GAP-049）； |
| 挪完器件要重新接线 | `sch connect` | `--direction` 必须等于**引脚外朝方向**（左脚 left/右脚 right），反了被几何守卫拒（`wire segment enters component body`）； |
| 导入 PCB 时件数明显偏多 | `pcb import-changes` | 它会把**所有页**的块都导进来（实测 9 页→30 器件）；导入前对试验页 `sch clear`（**不要 `sch page-delete`，无撤销**）； |
| 导出 DSN 报「板是空的、没有网络」 | `pcb export-dsn` | 这句是**假错误**（实测 4 器件 4 网、layout-lint 96/100 时仍报）；先 `pcb save` → `doc reload` → 等 8–12s 再导出（GAP-048）； |
| `sch destagger` 跑到一半出错 | `sch connect` | destagger 会打印「待手工恢复」的每只脚期望网，照单逐脚 `sch connect --pin <REF>:<n> --net <net>` 即可复原（GAP-049）； |
| CLI 报 `no connected window` | `daemon health` | 跑 `daemon health` 看 `found.raw.windows` 数组长度：0 = 守护在但无窗口（浏览器没连或 bsk 会话被回收，GAP-060/064） |
| 动作报 `no easyeda-agent daemon found` | `daemon start` | 前台常驻命令（会自动转后台任务才继续）；启动后再 `daemon health` 确认 status=found； |
| 要在网页版里点 GUI（导入/导出/菜单） | `daemon health` | 跑 `daemon health` 看 `found.raw.windows` 数组长度：0 = 守护在但无窗口（浏览器没连或 bsk 会话被回收，GAP-060/064） |
| 焊盘内打过孔仍不连通 | `pcb via-bond` | 先 `--dry-run` 看计划、`--component U1` 限定器件；注意平台限制：赋值**不能跨 doc reload 存活**（#118），改完立刻 `pcb net-path` 复核； |

---

## 这张表怎么维护

1. **每轮学到新工具用法** → 加一行；行数只增不减（N8 会抓缩水）。
2. **点名工具必须能解析**：`acceptance/run.ps1` 的 `tool-decision-table` 阶段会拿
   `easyeda actions` 与 `docs/extensions-index.md` 逐行核对，解析不到即 FAIL。
3. **坑一栏只写实测**。没实测写「未验证」——宁可空着，不写猜测。






---





## 由 playbook 反查补入（2026-11-01 第 78 轮）

> 反例：`playbook` 的 37 步里有 **10 步**用到决策表**根本没有**的命令（`sch titleblock` / `pcb outline-fit` /
> `pcb rip-up` / `pcb pour-fit` / `pcb place-constrained` / `project create` / `sch pages`）——
> 说明"情境→工具"表漏了这些，读者查表会查不到，只能去读 playbook。以下补上。

| 情境 | 工具 | 参数/坑 |
|---|---|---|
| 建一个空工程 | `project create` | `--name <工程名> --description <说明> --open`；返回里取 `uuid` 作为后续 `--project` |
| 查原理图页 uuid | `sch pages` | 输出 `pages[].uuid`；`--project <名>` 路由，不要用 `--window`（窗口会变） |
| 填图签（可制造信息） | `sch titleblock` | `--data '{"Name":{"value":"…","showTitle":true,"showValue":true}}'`；缺省不显示标题 |
| 按器件自动定板框 | `pcb outline-fit` | `--margin 100`（给布线留空隙用 200）；异形板改 `pcb outline-round` / `pcb outline-set` |
| 重布前先拆旧铜 | `pcb rip-up` | `--net <网名>` 只拆该网，省略=全拆；板框与锁定图元安全 |
| 按网名铺铜（GND/3V3） | `pcb pour-fit` | `--net GND`；落孔后必须 `pcb pour-rebuild` 再 `pcb drc` |
| 约束放置（给关键器件留位） | `pcb place-constrained` | 先 `pcb layout-plan` 出方案，再落位；坐标单位是 mil |
| 挪器件前要断开原连线 | `sch disconnect` | `--pin <位号:脚>`；断开后再 `sch modify` 挪位，最后 `sch connect` 重连（不先断会留悬空线） |
| 查原理图布局是否过密/重叠 | `sch layout-lint` | 跑 `sch layout-lint --strict`：只读，看 marker 包络与是否出图框；块放置前先跑一次 |
| 板子与原理图不同步 | `board rebind` | 原理图改了器件/封装后把 PCB 重新绑定；绑定后仍需 `pcb import-changes` |
| 删掉某条走线（重布/改线） | `pcb track-delete` | 按 id 或 `--net <网名>` 批量删；删完要 `pcb pour-rebuild` 再 `pcb drc` |

| 查板子是几层 / 有哪些层 | `pcb layers` | 看 `copperLayerCount`；`currentLayer` 可能为 null（未选层时）|
| 查原理图↔PCB 是否还关联 | `pcb board-info` | 看 `linked`；导入工程常需要确认这一项 |
| 查板框是否存在/尺寸 | `pcb outline-get` | 返回 bbox 与 arcs；`arcs=0` 表示纯矩形 |
| 列出全部网络与布线长度 | `pcb nets` | 字段是 `color/length/net`（**没有 pads 字段**，别按 pads 解析）|
| 查叠层（层厚/材质） | `pcb stackup` | 4 层板做阻抗/电源平面时必看 |
