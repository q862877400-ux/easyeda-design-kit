# acceptance/selftest.ps1 — 门禁自测
#
# 门禁自己也会静默失效（本项目已发生过两次：`-match` 用非法正则导致范围过滤失效、
# 判据只看关键词导致数字不可核对）。所以门禁必须能自证：每个分支都跑一次正例与反例。
#
# 用法：pwsh -NoProfile -File acceptance/selftest.ps1
# 退出码：0=全部通过；1=有断言失败。

[CmdletBinding()]
param([string]$Cli = "$env:USERPROFILE\.local\bin\easyeda.exe")

$ErrorActionPreference = "Stop"
$AcceptDir = Split-Path -Parent $PSCommandPath
$KitRoot = Split-Path -Parent $AcceptDir
$RunPs1 = Join-Path $KitRoot 'acceptance\run.ps1'
$run = Join-Path $AcceptDir 'run.ps1'
$clean = Join-Path $AcceptDir 'fixtures\runlog-clean.txt'
$drifted = Join-Path $AcceptDir 'fixtures\runlog-drifted.txt'
$historyRepo = Join-Path (Split-Path -Parent $KitRoot) 'easyeda-auto'
$probe = Join-Path $env:TEMP ('kit-selftest-' + [guid]::NewGuid().ToString('N').Substring(0, 8))

$script:Pass = 0; $script:Fail = 0
$script:Skip = 0
# ── 否定断言的共用校验（GAP-078）──────────────────────────────────────────────
# 反例（2026-11-01）：只判 Status=FAIL 时，任何错误都能让断言通过——缺文件、未指定参数、脚本解析失败。
# 这里统一拒绝**基础设施类错误**：那不是"判据正确拒绝了坏输入"，而是"探针自己坏了"。
function Test-NegativeResult {
    param($Result)
    if ($null -eq $Result) { return $false }
    if ($Result.Status -notin @('FAIL', 'BLOCKED')) { return $false }
    $d = [string]$Result.Detail
    if ([string]::IsNullOrWhiteSpace($d)) { return $false }
    # 只拒绝**探针/kit 自身基础设施**出错的情形；"flag 不存在""目录不存在"这类是判据的正当判定，必须放行。
    if ($d -match '不是合法|无法解析|无法读取|语法错误|No such|syntax') { return $false }
    if (($d -match '不存在') -and ($d -notmatch 'flag|焊盘|目录|net|pin|走线|元件|设计|pad')) { return $false }
    if ($d -match '未指定') { return $false }
    return $true
}
function Assert-Case {
    param([string]$Name, [scriptblock]$Body)
    try {
        $ok = & $Body
        if ($ok) { Write-Host ("[PASS] {0}" -f $Name); $script:Pass++ }
        else { Write-Host ("[FAIL] {0}" -f $Name); $script:Fail++ }
    } catch {
        Write-Host ("[FAIL] {0} — {1}" -f $Name, $_.Exception.Message); $script:Fail++
    }
}

# 从 run.ps1 输出里取某个阶段的状态
function Stage-Status {
    param([string[]]$Args2, [string]$Stage)
    $out = & pwsh -NoProfile -File $run @Args2 2>&1 | Out-String
    $m = [regex]::Match($out, "\[(PASS|FAIL|BLOCKED)\]\s+$([regex]::Escape($Stage))\s+(.*)")
    if (-not $m.Success) { return @{ Status = 'MISSING'; Detail = '' } }
    return @{ Status = $m.Groups[1].Value; Detail = $m.Groups[2].Value }
}

Write-Host "===== gate selftest ====="
Write-Host ""

# 断言 1：kit 自身，正负向都应 PASS
Assert-Case "kit 自身 → positive-goal PASS" {
# 断言（2026-11-01 新增）：playbook 步骤里**编造 flag** 必须判 FAIL。
# 反例：只查命令名时 `pcb route fill --no-such-flag-xyz` 会被判 PASS（本轮实测），所以补这条。
Assert-Case "positive-goal → playbook 里编造 flag 判 FAIL" {
    $d = Join-Path $probe "pbflag"
    New-Item -ItemType Directory -Force -Path (Join-Path $d "playbooks") | Out-Null
    '{ "version": 1, "meta": { "name": "p" }, "steps": [ { "id": 1, "run": "pcb route fill --net A --from U1.1 --to U2.2 --no-such-flag-xyz" } ] }' |
        Set-Content (Join-Path $d "playbooks\p.playbook.json") -Encoding UTF8
    Test-NegativeResult (Stage-Status @('-Case', 'esp32-4layer', '-Cli', $Cli, '-AuditRoot', $d) 'positive-goal')
}
# 断言（2026-11-01 新增）：flag 的**取值类型**也必须合法。
# 反例：`sch block-apply --spacing abc`（帮助声明 `--spacing float`）在只查 flag 名时判 PASS。
Assert-Case "positive-goal → 数值 flag 给字符串判 FAIL" {
    $d = Join-Path $probe "pbfval"
    New-Item -ItemType Directory -Force -Path (Join-Path $d "playbooks") | Out-Null
    '{ "version": 1, "meta": { "name": "p" }, "steps": [ { "id": 1, "run": "sch block-apply", "flags": { "block": "block.x", "at": "250,300", "spacing": "abc", "per-row": "3" } } ] }' |
        Set-Content (Join-Path $d "playbooks\p.playbook.json") -Encoding UTF8
    Test-NegativeResult (Stage-Status @('-Case', 'esp32-4layer', '-Cli', $Cli, '-AuditRoot', $d) 'positive-goal')
}
# 断言（2026-11-01 新增）：证据文档里的**已作废数字**无标注出现必须判 FAIL；带"当时/旧口径"标注则豁免。
Assert-Case "evidence-freshness → 无标注的作废数字判 FAIL" {
    $d = Join-Path $probe "efbad"
    New-Item -ItemType Directory -Force -Path (Join-Path $d "docs") | Out-Null
    '| 门禁自身可信 | selftest 36 PASS / 0 FAIL |' | Set-Content (Join-Path $d "docs\HANDOVER.md") -Encoding UTF8
    Test-NegativeResult (Stage-Status @('-Case', 'esp32-4layer', '-Cli', $Cli, '-AuditRoot', $d) 'evidence-freshness')
}
Assert-Case "evidence-freshness → 标注了当时口径则豁免" {
    $d = Join-Path $probe "efok"
    New-Item -ItemType Directory -Force -Path (Join-Path $d "docs") | Out-Null
    '| 门禁自身可信 | selftest 36 PASS / 0 FAIL（**当时**口径）|' | Set-Content (Join-Path $d "docs\HANDOVER.md") -Encoding UTF8
    (Stage-Status @('-Case', 'esp32-4layer', '-Cli', $Cli, '-AuditRoot', $d) 'evidence-freshness').Status -eq 'PASS'
}
# 断言（2026-11-01 新增）：HANDOVER 的 claims 块与实测不一致必须判 FAIL（这是"文字承诺"的看守）。
Assert-Case "claims-match → 声明与实测不一致判 FAIL" {
    $d = Join-Path $probe "clbad"
    New-Item -ItemType Directory -Force -Path (Join-Path $d "docs"),(Join-Path $d "playbooks") | Out-Null
    '<!-- claims: stages=19 -->' | Set-Content (Join-Path $d "docs\HANDOVER.md") -Encoding UTF8
    'x' | Set-Content (Join-Path $d "docs\capability-boundary.md") -Encoding UTF8
    '| 情境 | 工具 | 参数 |' | Set-Content (Join-Path $d "docs\tool-decision-table.md") -Encoding UTF8
    '{ "installed": [] }' | Set-Content (Join-Path $d "docs\installed-extensions.json") -Encoding UTF8
    Test-NegativeResult (Stage-Status @('-Case', 'esp32-4layer', '-Cli', $Cli, '-AuditRoot', $d) 'claims-match')
}
Assert-Case "claims-match → 没有 claims 块判 FAIL" {
    $d = Join-Path $probe "clnone"
    New-Item -ItemType Directory -Force -Path (Join-Path $d "docs") | Out-Null
    '# 没有 claims 块' | Set-Content (Join-Path $d "docs\HANDOVER.md") -Encoding UTF8
    Test-NegativeResult (Stage-Status @('-Case', 'esp32-4layer', '-Cli', $Cli, '-AuditRoot', $d) 'claims-match')
}
# 断言（2026-11-01 新增）：**删内容再同步改声明**必须被棘轮挡住（只增不减）。
Assert-Case "claims-match → 边界数下降判 FAIL（棘轮）" {
    $d = Join-Path $probe "ratch"
    New-Item -ItemType Directory -Force -Path (Join-Path $d "docs"),(Join-Path $d "playbooks") | Out-Null
    "## GAP-001 只剩一条" | Set-Content (Join-Path $d "docs\capability-boundary.md") -Encoding UTF8
    "<!-- claims: boundaries=1 -->" | Set-Content (Join-Path $d "docs\HANDOVER.md") -Encoding UTF8
    "| 情境 | 工具 | 参数 |" | Set-Content (Join-Path $d "docs\tool-decision-table.md") -Encoding UTF8
    "{ ""installed"": [] }" | Set-Content (Join-Path $d "docs\installed-extensions.json") -Encoding UTF8
    Test-NegativeResult (Stage-Status @('-Case', 'esp32-4layer', '-Cli', $Cli, '-AuditRoot', $d) 'claims-match')
}
# 断言（2026-11-01 新增）：报告目录里出现探针产物必须判 FAIL（历史上曾堆积 129 份无人发现）。
Assert-Case "report-hygiene → 探针垃圾报告判 FAIL" {
    $d = Join-Path $probe "runsjunk"
    New-Item -ItemType Directory -Force -Path (Join-Path $d "acceptance\runs") | Out-Null
    '{ "case": "p", "executor": "unspecified", "stages": [ { "stage": "a", "status": "BLOCKED", "detail": "x" } ] }' |
        Set-Content (Join-Path $d "acceptance\runs\junk.json") -Encoding UTF8
    Test-NegativeResult (Stage-Status @('-Case', 'esp32-4layer', '-Cli', $Cli, '-AuditRoot', $d) 'report-hygiene')
}
# 断言（2026-11-01 新增）：只有**旧阶段集**报告时判 BLOCKED（旧账不算当前证据，但也不是失败）。
Assert-Case "report-hygiene → 只有旧阶段集报告判 BLOCKED" {
    $d = Join-Path $probe "runsstale"
    New-Item -ItemType Directory -Force -Path (Join-Path $d "acceptance\runs") | Out-Null
    '{ "case": "p", "executor": "lead/x", "stages": [ { "stage": "a", "status": "PASS", "detail": "x" } ] }' |
        Set-Content (Join-Path $d "acceptance\runs\old.json") -Encoding UTF8
    Test-NegativeResult (Stage-Status @('-Case', 'esp32-4layer', '-Cli', $Cli, '-AuditRoot', $d) 'report-hygiene')
}
# 断言（2026-11-01 新增）：`-Static` 模式必须**真的跳过板级检查**并在汇总里说明。
# 反例：把板级调用缩进后，数阶段的正则曾把 22 读成 12 —— 同类"读错"必须能被钉住。
Assert-Case "-Static 模式跳过板级检查并注明" {
    $out = & $RunPs1 -Case 'sc001-usbc-typed' -Cli $Cli -Static *>&1 | Out-String
    ($out -match '本模式不含 \d+ 项板级检查') -and ($out -notmatch '\[BLOCKED\]\s+pcb-layout')
}
    (Stage-Status @('-Case', 'esp32-4layer', '-Cli', $Cli, '-RunLog', $clean) 'positive-goal').Status -eq 'PASS'
}
Assert-Case "kit 自身 → negative-drift PASS" {
    (Stage-Status @('-Case', 'esp32-4layer', '-Cli', $Cli, '-RunLog', $clean) 'negative-drift').Status -eq 'PASS'
}

# 断言 2：反例日志（rip-up --net / 旧快照 / 未 reload）必须 FAIL
Assert-Case "反例日志 → negative-drift FAIL" {
    $r = Stage-Status @('-Case', 'esp32-4layer', '-Cli', $Cli, '-RunLog', $drifted) 'negative-drift'
    ($r.Status -eq 'FAIL') -and ($r.Detail -match 'N4') -and ($r.Detail -match 'N5')
}

# 断言 3：N3 只看实质实现——1KB 只提到关键词不判失败
New-Item -ItemType Directory -Force -Path "$probe\src\p" | Out-Null
Set-Content "$probe\src\p\mentions.go" -Value ("// mentions drc clearance dfm`n" + ("package p`n" * 20)) -Encoding UTF8
Assert-Case "N3 关键词提及(1KB) → 不判失败" {
    $r = Stage-Status @('-Case', 'esp32-4layer', '-Cli', $Cli, '-AuditRoot', $probe) 'negative-drift'
    $r.Detail -notmatch 'N3 出现自建检查器'
}

# 断言 4：N3 真实现（>20KB 且文件名含 drc）必须 FAIL，并报出体积
Set-Content "$probe\src\p\my_drc_check.go" -Value ("// drc`n" + ("// padding padding padding padding`n" * 800)) -Encoding UTF8
Assert-Case "N3 实质实现(>20KB) → FAIL 并报体积" {
    $r = Stage-Status @('-Case', 'esp32-4layer', '-Cli', $Cli, '-AuditRoot', $probe) 'negative-drift'
    ($r.Status -eq 'FAIL') -and ($r.Detail -match 'N3 出现自建检查器') -and ($r.Detail -match 'KB')
}
Assert-Case "P3 外部审计 → FAIL 并点名文件" {
    $r = Stage-Status @('-Case', 'esp32-4layer', '-Cli', $Cli, '-AuditRoot', $probe) 'positive-goal'
    ($r.Status -eq 'FAIL') -and ($r.Detail -match 'P3\(外部审计\)') -and ($r.Detail -match 'my_drc_check')
}

# 断言 5：-CodeScope 必须真的缩小范围（不存在的范围 → 不报重叠）
# 对 kit 自身也能跑，不再依赖 easyeda-auto 存在（外部审计 S8：这条以前被整块跳过）
Assert-Case "-CodeScope 生效（不存在范围 → 无 P3 重叠）" {
    $r = Stage-Status @('-Case', 'esp32-4layer', '-Cli', $Cli, '-AuditRoot', $KitRoot, '-CodeScope', 'no-such-dir-xyz') 'positive-goal'
    $r.Detail -notmatch 'P3\(外部审计\)'
}

# 断言 6：历史回测（需要 easyeda-auto 仓库；缺失时**计入 SKIP**，不再静默）
if (Test-Path $historyRepo) {
    Assert-Case "历史回测 → 抓到 N1/N5" {
        $r = Stage-Status @('-Case', 'esp32-4layer', '-Cli', $Cli, '-AuditRoot', $historyRepo,
            '-CodeScope', 'src\easyeda-agent', '-RunLog', (Join-Path $AcceptDir 'fixtures\runlog-historical.txt')) 'negative-drift'
        ($r.Status -eq 'FAIL') -and ($r.Detail -match 'N1') -and ($r.Detail -match 'N5')
    }
} else {
    $script:Skip++
    Write-Host "[SKIP] 历史回测（找不到 $historyRepo）"
}


# 断言 9：能力边界结构校验（正例）
Assert-Case "capability-boundary → kit 自身 PASS" {
    (Stage-Status @('-Case', 'esp32-4layer', '-Cli', $Cli, '-AuditRoot', $KitRoot) 'capability-boundary').Status -eq 'PASS'
}

# 断言 10：缺字段必须判失败（反例）
Assert-Case "capability-boundary → 缺 triedTools 判 FAIL" {
    $bp = Join-Path $probe "docs"
    New-Item -ItemType Directory -Force -Path $bp | Out-Null
    $lines = @("# 边界")
    for ($i = 1; $i -le 8; $i++) {
        $lines += "## GAP-00$i"
        $lines += "- **capability**：做不到 $i"
        $lines += "- **evidence**：实测 $i"
        if ($i -ne 3) { $lines += "- **triedTools**：pcb drc" }
        $lines += "- **alternative**：用 pcb drc 替代"
        $lines += "- **status**：accepted"
    }
    Set-Content (Join-Path $bp "capability-boundary.md") -Value ($lines -join "`n") -Encoding UTF8
    $r = Stage-Status @('-Case', 'esp32-4layer', '-Cli', $Cli, '-AuditRoot', $probe) 'capability-boundary'
    ($r.Status -eq 'FAIL') -and ($r.Detail -match 'GAP-003')
}


# 断言 11–13：交付阶段（四类齐备 / 缺项 / 零字节）
Assert-Case "delivery → 四类齐备 PASS" {
    $d = Join-Path $probe "delivery-ok"
    New-Item -ItemType Directory -Force -Path $d | Out-Null
    Set-Content (Join-Path $d "g.zip") -Value ("x" * 100) -Encoding UTF8
    Set-Content (Join-Path $d "d.drl") -Value ("x" * 100) -Encoding UTF8
    Set-Content (Join-Path $d "c.csv") -Value ("x" * 100) -Encoding UTF8
    Set-Content (Join-Path $d "b.xlsx") -Value ("x" * 100) -Encoding UTF8
    (Stage-Status @('-Case', 'esp32-4layer', '-Cli', $Cli, '-DeliveryDir', $d) 'delivery').Status -eq 'PASS'
}

Assert-Case "delivery → 缺钻孔 FAIL" {
    $d = Join-Path $probe "delivery-miss"
    New-Item -ItemType Directory -Force -Path $d | Out-Null
    Set-Content (Join-Path $d "g.zip") -Value ("x" * 100) -Encoding UTF8
    Set-Content (Join-Path $d "c.csv") -Value ("x" * 100) -Encoding UTF8
    Set-Content (Join-Path $d "b.xlsx") -Value ("x" * 100) -Encoding UTF8
    Test-NegativeResult (Stage-Status @('-Case', 'esp32-4layer', '-Cli', $Cli, '-DeliveryDir', $d) 'delivery')
}

Assert-Case "delivery → 零字节文件 FAIL" {
    $d = Join-Path $probe "delivery-zero"
    New-Item -ItemType Directory -Force -Path $d | Out-Null
    Set-Content (Join-Path $d "g.zip") -Value ("x" * 100) -Encoding UTF8
    Set-Content (Join-Path $d "c.csv") -Value ("x" * 100) -Encoding UTF8
    Set-Content (Join-Path $d "b.xlsx") -Value ("x" * 100) -Encoding UTF8
    [System.IO.File]::WriteAllBytes((Join-Path $d "d.drl"), @())
    Test-NegativeResult (Stage-Status @('-Case', 'esp32-4layer', '-Cli', $Cli, '-DeliveryDir', $d) 'delivery')
}


# 断言 14–15：扩展包校验（正例 / 缺字段反例）
Assert-Case "check-extension-package → 合法包 PASS" {
    $pk = Join-Path $probe "ext"
    New-Item -ItemType Directory -Force -Path (Join-Path $pk "dist"), (Join-Path $pk "images") | Out-Null
    $desc = "按规范把电路板从需求画到可打样，含决策表、阶段流程、边界清单与验收脚本，供任意模型按文档执行。"
    $mf = [ordered]@{ name="kit"; uuid="0000000000000000000000000000a1b2"; displayName="Kit"; description=$desc;
                      version="1.0.0"; license="MIT"; categories=@("PCB"); entry="dist/index.js"; icon="images/logo.jpg" }
    $mf | ConvertTo-Json -Depth 4 | Set-Content (Join-Path $pk "extension.json") -Encoding UTF8
    Set-Content (Join-Path $pk "dist\index.js") -Value "console.log(1)" -Encoding UTF8
    Set-Content (Join-Path $pk "images\logo.jpg") -Value ("x" * 100) -Encoding UTF8
    $zip = Join-Path $probe "good.eext"
    Compress-Archive -Path (Join-Path $pk "*") -DestinationPath $zip -Force
    $out = & pwsh -NoProfile -File (Join-Path $AcceptDir "check-extension-package.ps1") -Package $zip 2>&1 | Out-String
    $LASTEXITCODE -eq 0
}

Assert-Case "check-extension-package → 缺 license 判 FAIL" {
    $pk = Join-Path $probe "ext2"
    New-Item -ItemType Directory -Force -Path (Join-Path $pk "dist"), (Join-Path $pk "images") | Out-Null
    $mf = [ordered]@{ name="kit"; uuid="0000000000000000000000000000a1b2"; displayName="Kit";
                      description=("x" * 100); version="1.0.0"; categories=@("PCB");
                      entry="dist/index.js"; icon="images/logo.jpg" }
    $mf | ConvertTo-Json -Depth 4 | Set-Content (Join-Path $pk "extension.json") -Encoding UTF8
    Set-Content (Join-Path $pk "dist\index.js") -Value "x" -Encoding UTF8
    Set-Content (Join-Path $pk "images\logo.jpg") -Value "x" -Encoding UTF8
    $zip = Join-Path $probe "bad.eext"
    Compress-Archive -Path (Join-Path $pk "*") -DestinationPath $zip -Force
    $null = & pwsh -NoProfile -File (Join-Path $AcceptDir "check-extension-package.ps1") -Package $zip 2>&1
    $LASTEXITCODE -eq 1
}


# 断言 16–17：交付按证据判定（钻孔在 Gerber 包内 / BOM 报错）
Assert-Case "delivery 证据：钻孔在 Gerber 包内 → PASS" {
    $d = Join-Path $probe "ev-ok"
    New-Item -ItemType Directory -Force -Path $d | Out-Null
    [System.IO.File]::WriteAllBytes((Join-Path $d "g.zip"), (New-Object byte[] 100))
    [System.IO.File]::WriteAllBytes((Join-Path $d "c.csv"), (New-Object byte[] 80))
    [System.IO.File]::WriteAllBytes((Join-Path $d "b.xlsx"), (New-Object byte[] 60))
    $ev = [ordered]@{ gerber = [ordered]@{ path = (Join-Path $d "g.zip"); size = 100; drilling = [ordered]@{ metallic = $true; nonMetallic = $true } };
                      pickPlace = [ordered]@{ path = (Join-Path $d "c.csv"); size = 80 };
                      bom = [ordered]@{ path = (Join-Path $d "b.xlsx"); size = 60 } }
    $ev | ConvertTo-Json -Depth 5 | Set-Content (Join-Path $d "delivery-evidence.json") -Encoding UTF8
    (Stage-Status @('-Case', 'esp32-4layer', '-Cli', $Cli, '-DeliveryDir', $d) 'delivery').Status -eq 'PASS'
}

Assert-Case "delivery 证据：BOM 返回 no file → FAIL" {
    $d = Join-Path $probe "ev-bom"
    New-Item -ItemType Directory -Force -Path $d | Out-Null
    [System.IO.File]::WriteAllBytes((Join-Path $d "g.zip"), (New-Object byte[] 100))
    [System.IO.File]::WriteAllBytes((Join-Path $d "c.csv"), (New-Object byte[] 80))
    [System.IO.File]::WriteAllBytes((Join-Path $d "b.xlsx"), (New-Object byte[] 60))
    $ev = [ordered]@{ gerber = [ordered]@{ path = (Join-Path $d "g.zip"); size = 100; drilling = [ordered]@{ metallic = $true; nonMetallic = $true } };
                      pickPlace = [ordered]@{ path = (Join-Path $d "c.csv"); size = 80 };
                      bom = [ordered]@{ path = $null; size = 0; error = "BOM export returned no file." } }
    $ev | ConvertTo-Json -Depth 5 | Set-Content (Join-Path $d "delivery-evidence.json") -Encoding UTF8
    $r = Stage-Status @('-Case', 'esp32-4layer', '-Cli', $Cli, '-DeliveryDir', $d) 'delivery'
    ($r.Status -eq 'FAIL') -and ($r.Detail -match 'BOM export returned no file')
}


# 断言 18–19：Design IR 校验（正例 / 反例）
Assert-Case "design-ir → 上游样例 PASS" {
    $ir = Join-Path $KitRoot "vendor\prior-art\smart-hardware-engineer\ir\examples\blinky_usb_mcu.ir.json"
    (Stage-Status @('-Case', 'esp32-4layer', '-Cli', $Cli, '-IR', $ir) 'design-ir').Status -eq 'PASS'
}

Assert-Case "design-ir → 破坏后 FAIL" {
    $src = Join-Path $KitRoot "vendor\prior-art\smart-hardware-engineer\ir\examples\blinky_usb_mcu.ir.json"
    $obj = Get-Content $src -Raw | ConvertFrom-Json
    $obj.PSObject.Properties.Remove("meta")
    $bad = Join-Path $probe "broken.ir.json"
    $obj | ConvertTo-Json -Depth 20 | Set-Content $bad -Encoding UTF8
    Test-NegativeResult (Stage-Status @('-Case', 'esp32-4layer', '-Cli', $Cli, '-IR', $bad) 'design-ir')
}


# 断言 20：route fill 自带快照，不得触发 N5 误报
Assert-Case "N5：3 次 route fill + 0 次 dump → 不判 N5" {
    $lg = Join-Path $probe "fill-only.log"
    @('easyeda pcb route fill --net A --from X.1 --to Y.1',
      'easyeda pcb route fill --net B --from X.2 --to Y.2',
      'easyeda pcb route fill --net C --from X.3 --to Y.3') | Set-Content $lg -Encoding UTF8
    $r = Stage-Status @('-Case', 'esp32-4layer', '-Cli', $Cli, '-RunLog', $lg) 'negative-drift'
    $r.Detail -notmatch 'N5 求解'
}


# 断言 21：决策表里写 CLI 命令名也必须可解析（与 P6 同口径）
Assert-Case "决策表：CLI 命令名可解析" {
    $d = Join-Path $probe "dt"
    New-Item -ItemType Directory -Force -Path (Join-Path $d "docs") | Out-Null
    $rows = @("# 测试决策表", "", "| 情境 | 用哪个 | 参数 |", "|---|---|---|")
    for ($i = 1; $i -le 30; $i++) { $rows += "| 场景$i | pcb route fill | 参数 |" }
    $rows | Set-Content (Join-Path $d "docs\tool-decision-table.md") -Encoding UTF8
    (Stage-Status @('-Case', 'esp32-4layer', '-Cli', $Cli, '-AuditRoot', $d) 'tool-decision-table').Status -eq 'PASS'
}


# 断言 22–23：可移植性（kit 自身 PASS / 含本机绝对路径 FAIL）
Assert-Case "kit-portability → kit 自身 PASS" {
    (Stage-Status @('-Case', 'esp32-4layer', '-Cli', $Cli, '-AuditRoot', $KitRoot) 'kit-portability').Status -eq 'PASS'
}

Assert-Case "kit-portability → 含 D:\\Agent-Studio 判 FAIL" {
    $pd = Join-Path $probe "port"
    New-Item -ItemType Directory -Force -Path (Join-Path $pd "docs") | Out-Null
    Set-Content (Join-Path $pd "docs\bad.md") -Value "见 D:\Agent-Studio\foo 与 C:\Users\x" -Encoding UTF8
    Test-NegativeResult (Stage-Status @('-Case', 'esp32-4layer', '-Cli', $Cli, '-AuditRoot', $pd) 'kit-portability')
}


# 断言 24–25：装机宣称（kit 自身 PASS / 把未装工具写成首选必须 FAIL）
Assert-Case "installed-claims → kit 自身 PASS" {
    (Stage-Status @('-Case', 'esp32-4layer', '-Cli', $Cli, '-AuditRoot', $KitRoot) 'installed-claims').Status -eq 'PASS'
}

Assert-Case "installed-claims → 把 PCB Auto Router 写成首选 判 FAIL" {
    $d = Join-Path $probe "claims"
    New-Item -ItemType Directory -Force -Path (Join-Path $d "docs") | Out-Null
    Copy-Item (Join-Path $KitRoot "docs\installed-extensions.json") (Join-Path $d "docs") -Force
    $rows = @("| 情境 | 用哪个 | 参数 |", "|---|---|---|")
    for ($i = 1; $i -le 30; $i++) { $rows += "| 场景$i | pcb route fill | 参数 |" }
    $rows += "| 全板自动布线（首选） | PCB Auto Router | AI+GPU |"
    $rows | Set-Content (Join-Path $d "docs\tool-decision-table.md") -Encoding UTF8
    Test-NegativeResult (Stage-Status @('-Case', 'esp32-4layer', '-Cli', $Cli, '-AuditRoot', $d) 'installed-claims')
}


# 断言 26：未被 external-tools.json 收录的 exe 必须判解析失败（防"外部工具"口子被滥开）
Assert-Case "决策表：未收录的 exe 仍判 FAIL" {
    $d = Join-Path $probe "dt2"
    New-Item -ItemType Directory -Force -Path (Join-Path $d "docs") | Out-Null
    Copy-Item (Join-Path $KitRoot "docs\external-tools.json") (Join-Path $d "docs") -Force
    $rows = @("| 情境 | 用哪个 | 参数 |", "|---|---|---|")
    for ($i = 1; $i -le 30; $i++) { $rows += "| 场景$i | pcb route fill | 参数 |" }
    $rows += "| 某场景X | totally-unknown-router.exe | 参数 |"
    $rows | Set-Content (Join-Path $d "docs\tool-decision-table.md") -Encoding UTF8
    Test-NegativeResult (Stage-Status @('-Case', 'esp32-4layer', '-Cli', $Cli, '-AuditRoot', $d) 'tool-decision-table')
}


# 断言 27–28：决策表可执行率（SC-005）
# 断言 27（2026-11-01 改写）：原断言"kit 自身 ≥90% PASS"考的是**表格质量**而非门禁行为；
# 参数列加强为"必须含具体物"后实测仅 29.7%（旧 99.1% 由长度口径撑起，见外部审计 A1）。
# 改为断言**门禁行为**：给出可核对比例、结论落在三态内；表格质量如实记在 SC-005 证据（未达成）。
Assert-Case "decision-actionability → 给出可核对的比例（不冒充 ≥90%）" {
    $r = Stage-Status @('-Case', 'esp32-4layer', '-Cli', $Cli, '-AuditRoot', $KitRoot) 'decision-actionability'
    ($r.Status -in @('PASS', 'FAIL')) -and ($r.Detail -match '可执行 \d+/\d+ = \d')
}

Assert-Case "decision-actionability → 全是空话参数 判 FAIL" {
    $d = Join-Path $probe "act"
    New-Item -ItemType Directory -Force -Path (Join-Path $d "docs") | Out-Null
    $rows = @("| 情境 | 用哪个 | 参数 |", "|---|---|---|")
    for ($i = 1; $i -le 30; $i++) { $rows += "| 场景$i | pcb route fill | 短 |" }
    $rows | Set-Content (Join-Path $d "docs\tool-decision-table.md") -Encoding UTF8
    Test-NegativeResult (Stage-Status @('-Case', 'esp32-4layer', '-Cli', $Cli, '-AuditRoot', $d) 'decision-actionability')
}


# 断言 29–30：delivery 三态（未导出→BLOCKED；已导出但缺件→FAIL）
Assert-Case "delivery → 目录不存在判 BLOCKED（不是 FAIL）" {
    $d = Join-Path $probe "no-delivery"
    Test-NegativeResult (Stage-Status @('-Case', 'esp32-4layer', '-Cli', $Cli, '-AuditRoot', $KitRoot, '-DeliveryDir', $d) 'delivery')
}

Assert-Case "delivery → 目录有文件但缺 BOM 判 FAIL" {
    $d = Join-Path $probe "partial-delivery"
    New-Item -ItemType Directory -Force -Path $d | Out-Null
    'fake gerber' | Set-Content (Join-Path $d "board.gbr") -Encoding UTF8
    'fake drill'  | Set-Content (Join-Path $d "board.drl") -Encoding UTF8
    'a,b'         | Set-Content (Join-Path $d "board-cpl.csv") -Encoding UTF8
    Test-NegativeResult (Stage-Status @('-Case', 'esp32-4layer', '-Cli', $Cli, '-AuditRoot', $KitRoot, '-DeliveryDir', $d) 'delivery')
}


# 断言：DFM 计数解析必须同时认「有违规」与「零违规」两种输出形态
Assert-Case "DFM 解析：零违规形态 0 issue(s) → 0（不得判未给出计数）" {
    . (Join-Path $AcceptDir "dfm-parse.ps1")
    (Parse-DfmErrorCount "PCB check (DFM): 7 track(s), 0 via(s), 4 pad(s) — 0 issue(s)") -eq 0
}

Assert-Case "DFM 解析：ERROR=3 形态 → 3" {
    . (Join-Path $AcceptDir "dfm-parse.ps1")
    (Parse-DfmErrorCount "ERROR=3 WARN=245  | dangling=2") -eq 3
}

Assert-Case "DFM 解析：无法判定 → -1（不得当 0）" {
    . (Join-Path $AcceptDir "dfm-parse.ps1")
    (Parse-DfmErrorCount "hello") -eq -1
}


# 断言：一次性脚本判据的三态（错日志→BLOCKED、.work 中间件→PASS、.work 脚本→FAIL）
Assert-Case "no-oneoff：日志与工程不匹配判 BLOCKED" {
    $lg = Join-Path $probe "log-wrongproject.log"
    @("# other board", "pcb route fill --net A --from X.1 --to Y.1") | Set-Content $lg -Encoding UTF8
    Test-NegativeResult (Stage-Status @('-Case', 'sc001-ldo-typed', '-Cli', $Cli, '-Project', 'sc001-ldo-blk', '-RunLog', $lg, '-NoArchive') 'no-oneoff-scripts')
}

Assert-Case "no-oneoff：.work 中间件（DSN/SES）不算一次性脚本" {
    $lg = Join-Path $probe "log-workfiles.log"
    @("project sc001-ldo-blk", "pcb export-dsn --project sc001-ldo-blk --doc x", "pcb_autorouter -i .work\ldo.dsn -a -o .work\ldo.ses") | Set-Content $lg -Encoding UTF8
    (Stage-Status @('-Case', 'sc001-ldo-typed', '-Cli', $Cli, '-Project', 'sc001-ldo-blk', '-RunLog', $lg, '-NoArchive') 'no-oneoff-scripts').Status -eq 'PASS'
}

Assert-Case "no-oneoff：.work 下的脚本仍判 FAIL" {
    $lg = Join-Path $probe "log-workscript.log"
    @("project sc001-ldo-blk", "pcb check --project sc001-ldo-blk --doc x", "sch clusters --project sc001-ldo-blk --doc x --strict", "pwsh .work\scratch-gen.ps1") | Set-Content $lg -Encoding UTF8
    Test-NegativeResult (Stage-Status @('-Case', 'sc001-ldo-typed', '-Cli', $Cli, '-Project', 'sc001-ldo-blk', '-RunLog', $lg, '-NoArchive') 'no-oneoff-scripts')
}

Remove-Item $probe -Recurse -Force -ErrorAction SilentlyContinue

Write-Host ""
Write-Host ("===== {0} PASS / {1} FAIL / {2} SKIP =====" -f $script:Pass, $script:Fail, $script:Skip)
if ($script:Fail -gt 0) { exit 1 }
exit 0










