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
$run = Join-Path $AcceptDir 'run.ps1'
$clean = Join-Path $AcceptDir 'fixtures\runlog-clean.txt'
$drifted = Join-Path $AcceptDir 'fixtures\runlog-drifted.txt'
$historyRepo = Join-Path (Split-Path -Parent $KitRoot) 'easyeda-auto'
$probe = Join-Path $env:TEMP ('kit-selftest-' + [guid]::NewGuid().ToString('N').Substring(0, 8))

$script:Pass = 0; $script:Fail = 0
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
if (Test-Path $historyRepo) {
    Assert-Case "-CodeScope 生效（不存在范围 → 无 P3 重叠）" {
        $r = Stage-Status @('-Case', 'esp32-4layer', '-Cli', $Cli, '-AuditRoot', $historyRepo, '-CodeScope', 'no-such-dir-xyz') 'positive-goal'
        $r.Detail -notmatch 'P3\(外部审计\)'
    }
    Assert-Case "历史回测 → 抓到 N1/N5" {
        $r = Stage-Status @('-Case', 'esp32-4layer', '-Cli', $Cli, '-AuditRoot', $historyRepo,
            '-CodeScope', 'src\easyeda-agent', '-RunLog', (Join-Path $AcceptDir 'fixtures\runlog-historical.txt')) 'negative-drift'
        ($r.Status -eq 'FAIL') -and ($r.Detail -match 'N1') -and ($r.Detail -match 'N5')
    }
} else {
    Write-Host "[SKIP] 历史回测（找不到 easyeda-auto）"
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
    (Stage-Status @('-Case', 'esp32-4layer', '-Cli', $Cli, '-DeliveryDir', $d) 'delivery').Status -eq 'FAIL'
}

Assert-Case "delivery → 零字节文件 FAIL" {
    $d = Join-Path $probe "delivery-zero"
    New-Item -ItemType Directory -Force -Path $d | Out-Null
    Set-Content (Join-Path $d "g.zip") -Value ("x" * 100) -Encoding UTF8
    Set-Content (Join-Path $d "c.csv") -Value ("x" * 100) -Encoding UTF8
    Set-Content (Join-Path $d "b.xlsx") -Value ("x" * 100) -Encoding UTF8
    [System.IO.File]::WriteAllBytes((Join-Path $d "d.drl"), @())
    (Stage-Status @('-Case', 'esp32-4layer', '-Cli', $Cli, '-DeliveryDir', $d) 'delivery').Status -eq 'FAIL'
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
    (Stage-Status @('-Case', 'esp32-4layer', '-Cli', $Cli, '-IR', $bad) 'design-ir').Status -eq 'FAIL'
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
    (Stage-Status @('-Case', 'esp32-4layer', '-Cli', $Cli, '-AuditRoot', $pd) 'kit-portability').Status -eq 'FAIL'
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
    (Stage-Status @('-Case', 'esp32-4layer', '-Cli', $Cli, '-AuditRoot', $d) 'installed-claims').Status -eq 'FAIL'
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
    (Stage-Status @('-Case', 'esp32-4layer', '-Cli', $Cli, '-AuditRoot', $d) 'tool-decision-table').Status -eq 'FAIL'
}


# 断言 27–28：决策表可执行率（SC-005）
Assert-Case "decision-actionability → kit 自身 PASS ≥90%" {
    (Stage-Status @('-Case', 'esp32-4layer', '-Cli', $Cli, '-AuditRoot', $KitRoot) 'decision-actionability').Status -eq 'PASS'
}

Assert-Case "decision-actionability → 全是空话参数 判 FAIL" {
    $d = Join-Path $probe "act"
    New-Item -ItemType Directory -Force -Path (Join-Path $d "docs") | Out-Null
    $rows = @("| 情境 | 用哪个 | 参数 |", "|---|---|---|")
    for ($i = 1; $i -le 30; $i++) { $rows += "| 场景$i | pcb route fill | 短 |" }
    $rows | Set-Content (Join-Path $d "docs\tool-decision-table.md") -Encoding UTF8
    (Stage-Status @('-Case', 'esp32-4layer', '-Cli', $Cli, '-AuditRoot', $d) 'decision-actionability').Status -eq 'FAIL'
}


# 断言 29–30：delivery 三态（未导出→BLOCKED；已导出但缺件→FAIL）
Assert-Case "delivery → 目录不存在判 BLOCKED（不是 FAIL）" {
    $d = Join-Path $probe "no-delivery"
    (Stage-Status @('-Case', 'esp32-4layer', '-Cli', $Cli, '-AuditRoot', $KitRoot, '-DeliveryDir', $d) 'delivery').Status -eq 'BLOCKED'
}

Assert-Case "delivery → 目录有文件但缺 BOM 判 FAIL" {
    $d = Join-Path $probe "partial-delivery"
    New-Item -ItemType Directory -Force -Path $d | Out-Null
    'fake gerber' | Set-Content (Join-Path $d "board.gbr") -Encoding UTF8
    'fake drill'  | Set-Content (Join-Path $d "board.drl") -Encoding UTF8
    'a,b'         | Set-Content (Join-Path $d "board-cpl.csv") -Encoding UTF8
    (Stage-Status @('-Case', 'esp32-4layer', '-Cli', $Cli, '-AuditRoot', $KitRoot, '-DeliveryDir', $d) 'delivery').Status -eq 'FAIL'
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
    (Stage-Status @('-Case', 'sc001-ldo-typed', '-Cli', $Cli, '-Project', 'sc001-ldo-blk', '-RunLog', $lg) 'no-oneoff-scripts').Status -eq 'BLOCKED'
}

Assert-Case "no-oneoff：.work 中间件（DSN/SES）不算一次性脚本" {
    $lg = Join-Path $probe "log-workfiles.log"
    @("project sc001-ldo-blk", "pcb export-dsn --project sc001-ldo-blk --doc x", "pcb_autorouter -i .work\ldo.dsn -a -o .work\ldo.ses") | Set-Content $lg -Encoding UTF8
    (Stage-Status @('-Case', 'sc001-ldo-typed', '-Cli', $Cli, '-Project', 'sc001-ldo-blk', '-RunLog', $lg) 'no-oneoff-scripts').Status -eq 'PASS'
}

Assert-Case "no-oneoff：.work 下的脚本仍判 FAIL" {
    $lg = Join-Path $probe "log-workscript.log"
    @("project sc001-ldo-blk", "pwsh .work\scratch-gen.ps1") | Set-Content $lg -Encoding UTF8
    (Stage-Status @('-Case', 'sc001-ldo-typed', '-Cli', $Cli, '-Project', 'sc001-ldo-blk', '-RunLog', $lg) 'no-oneoff-scripts').Status -eq 'FAIL'
}

Remove-Item $probe -Recurse -Force -ErrorAction SilentlyContinue

Write-Host ""
Write-Host ("===== {0} PASS / {1} FAIL =====" -f $script:Pass, $script:Fail)
if ($script:Fail -gt 0) { exit 1 }
exit 0



