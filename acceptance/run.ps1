# acceptance/run.ps1 — EasyEDA AI Design Kit 验收
#
# 一条命令判定「这块板画完没有」。判据只看三态：PASS / FAIL / BLOCKED。
# 退出码：0=全部 PASS；1=存在 FAIL；2=无 FAIL 但有 BLOCKED；3=用法错误。
#
# 设计要点（都是为了「不许自欺」）：
#   - 每个阶段独立判定，失败必须指出阶段名与判据数字；
#   - 缺前置条件（没有工程、没有 EDA 窗口）报 BLOCKED，不报 PASS，也不静默跳过；
#   - 交付文件必须真的存在且非空，不看命令是否返回 ok；
#   - 第 9 阶段审查「一次性脚本」，这是本产品反自欺的核心条款。

[CmdletBinding()]
param(
    [Parameter(Mandatory = $false)][string]$Case = "esp32-4layer",
    [Parameter(Mandatory = $false)][string]$Project = "",
    [Parameter(Mandatory = $false)][string]$Doc = "",
    [Parameter(Mandatory = $false)][string]$Cli = "$env:USERPROFILE\.local\bin\easyeda.exe",
    [Parameter(Mandatory = $false)][string]$DeliveryDir = "",
    [Parameter(Mandatory = $false)][string]$RunLog = "",
    [Parameter(Mandatory = $false)][switch]$Quiet
)

$ErrorActionPreference = "Stop"
$script:AcceptDir = Split-Path -Parent $PSCommandPath
$script:RepoRoot = Split-Path -Parent $script:AcceptDir
$script:Results = @()

function Add-Result {
    param([string]$Stage, [string]$Status, [string]$Detail)
    $script:Results += [pscustomobject]@{ Stage = $Stage; Status = $Status; Detail = $Detail }
    if (-not $Quiet) {
        $tag = switch ($Status) { "PASS" { "[PASS]   " } "FAIL" { "[FAIL]   " } default { "[BLOCKED]" } }
        Write-Host ("{0} {1,-22} {2}" -f $tag, $Stage, $Detail)
    }
}

# 从 CLI 输出里取第一段 JSON（CLI 会先打一行人读摘要）
function Invoke-Json {
    param([string[]]$CliArgs)
    $raw = & $Cli $CliArgs 2>$null | Out-String
    if ([string]::IsNullOrWhiteSpace($raw)) { return $null }
    $idx = $raw.IndexOf("{")
    if ($idx -lt 0) { return $null }
    try { return ($raw.Substring($idx) | ConvertFrom-Json) } catch { return $null }
}

function Get-FirstJsonNumber {
    param($Json, [string]$Pattern)
    if ($null -eq $Json) { return $null }
    $text = $Json | ConvertTo-Json -Depth 20 -Compress
    $m = [regex]::Match($text, $Pattern)
    if ($m.Success) { return [int]$m.Groups[1].Value }
    return $null
}

# ── 阶段 1：文件完整性 ────────────────────────────────────────────────────
function Test-KitIntegrity {
    $required = @(
        "PRODUCT.md",
        "specs\004-ai-pcb-design-kit\spec.md",
        "docs\tool-decision-table.md",
        "docs\capability-boundary.md",
        "docs\phases\schematic-s0-s6.md",
        "docs\phases\pcb-p0-p10.md",
        "playbooks\README.md"
    )
    $missing = @()
    foreach ($rel in $required) {
        $p = Join-Path $script:RepoRoot $rel
        if (-not (Test-Path $p)) { $missing += $rel }
    }
    if ($missing.Count -eq 0) {
        Add-Result "kit-integrity" "PASS" "$($required.Count) 份必需文档齐备"
    } else {
        Add-Result "kit-integrity" "FAIL" "缺 $($missing.Count)/$($required.Count) 份： $($missing -join ', ')"
    }
}

# ── 阶段 2：决策表可用性（每行点名的工具必须真实存在）────────────────────
function Test-DecisionTable {
    $tablePath = Join-Path $script:RepoRoot "easyeda-auto\docs\tool-decision-table.md"
    if (-not (Test-Path $tablePath)) {
        Add-Result "tool-decision-table" "BLOCKED" "决策表不存在，无法校验"
        return
    }
    $rows = Get-Content $tablePath | Where-Object { $_ -match '^\|' -and $_ -notmatch '^\|\s*-+' -and $_ -notmatch '情境' }
    if ($rows.Count -lt 30) {
        Add-Result "tool-decision-table" "FAIL" "只有 $($rows.Count) 行（要求 ≥30 个情境）"
        return
    }
    # 点名的工具必须能在动作目录或扩展索引里找到
    $actions = Invoke-Json @("actions")
    $actionText = if ($actions) { $actions | ConvertTo-Json -Depth 8 -Compress } else { "" }
    $extIndex = Join-Path $script:RepoRoot "docs\extensions-index.md"
    $extText = if (Test-Path $extIndex) { Get-Content $extIndex -Raw } else { "" }

    $unresolved = @()
    foreach ($r in $rows) {
        $cells = $r.Split('|')
        if ($cells.Count -lt 4) { continue }
        $tool = $cells[2].Trim().Trim('`', '*')
        if ([string]::IsNullOrWhiteSpace($tool) -or $tool -match '^\.\.\.$') { continue }
        $hit = ($actionText -like "*$tool*") -or ($extText -like "*$tool*")
        if (-not $hit) { $unresolved += $tool }
    }
    if ($unresolved.Count -eq 0) {
        Add-Result "tool-decision-table" "PASS" "$($rows.Count) 行，点名工具全部可解析"
    } else {
        Add-Result "tool-decision-table" "FAIL" "$($unresolved.Count) 个工具名解析不到： $(($unresolved | Select-Object -First 5) -join ', ')"
    }
}

# ── 阶段 3：环境 ──────────────────────────────────────────────────────────
function Test-Environment {
    if (-not (Test-Path $Cli)) {
        Add-Result "environment" "BLOCKED" "CLI 不存在： $Cli"
        return
    }
    $health = Invoke-Json @("daemon", "health")
    if (-not $health) {
        Add-Result "environment" "FAIL" "daemon health 读不到 JSON"
        return
    }
    $windows = $health.found.raw.windows
    if (-not $windows -or $windows.Count -lt 1) {
        Add-Result "environment" "BLOCKED" "没有在线的 EDA 窗口（windows 为空）"
        return
    }
    Add-Result "environment" "PASS" "窗口在线 $($windows.Count) 个，connector $($windows[0].connectorVersion)"
}

# ── 阶段 4–8：需要一个真实工程 ────────────────────────────────────────────
function Test-SchematicGates {
    if ([string]::IsNullOrWhiteSpace($Project)) { Add-Result "schematic-gates" "BLOCKED" "未指定 -Project"; return }
    $drc = Invoke-Json @("sch", "drc", "--project", $Project)
    if (-not $drc) { Add-Result "schematic-gates" "FAIL" "sch drc 读不到 JSON"; return }
    $passed = $drc.result.passed
    if ($passed -eq $true) { Add-Result "schematic-gates" "PASS" "sch drc passed" }
    else { Add-Result "schematic-gates" "FAIL" "sch drc 未通过" }
}

function Test-PcbLayout {
    if ([string]::IsNullOrWhiteSpace($Project)) { Add-Result "pcb-layout" "BLOCKED" "未指定 -Project"; return }
    $args = @("pcb", "layout-lint", "--project", $Project)
    if ($Doc) { $args += @("--doc", $Doc) }
    $out = & $Cli $args 2>$null | Out-String
    if ($out -match "0 short" -and $out -match "0 overlap" -and $out -match "0 off-board") {
        Add-Result "pcb-layout" "PASS" "0 短路/0 重叠/0 出框"
    } else {
        Add-Result "pcb-layout" "FAIL" (($out -split "`n" | Select-String 'layout-lint' | Select-Object -First 1) -join ' ')
    }
}

function Test-PcbConnectivity {
    if ([string]::IsNullOrWhiteSpace($Project)) { Add-Result "pcb-connectivity" "BLOCKED" "未指定 -Project"; return }
    $args = @("pcb", "drc", "--project", $Project)
    if ($Doc) { $args += @("--doc", $Doc) }
    $drc = Invoke-Json $args
    if (-not $drc) { Add-Result "pcb-connectivity" "FAIL" "pcb drc 读不到 JSON"; return }
    $n = Get-FirstJsonNumber $drc '"errorType"\s*:\s*"Connection Error"'
    $text = $drc | ConvertTo-Json -Depth 20 -Compress
    $count = ([regex]::Matches($text, '"errorType"\s*:\s*"Connection Error"')).Count
    if ($count -eq 0) { Add-Result "pcb-connectivity" "PASS" "Connection Error 0" }
    else { Add-Result "pcb-connectivity" "FAIL" "Connection Error $count 条" }
}

function Test-PcbDfm {
    if ([string]::IsNullOrWhiteSpace($Project)) { Add-Result "pcb-dfm" "BLOCKED" "未指定 -Project"; return }
    $args = @("pcb", "check", "--project", $Project)
    if ($Doc) { $args += @("--doc", $Doc) }
    $out = & $Cli $args 2>$null | Out-String
    $m = [regex]::Match($out, 'ERROR=(\d+)')
    if (-not $m.Success) { Add-Result "pcb-dfm" "FAIL" "pcb check 未给出 ERROR 计数"; return }
    $err = [int]$m.Groups[1].Value
    if ($err -eq 0) { Add-Result "pcb-dfm" "PASS" "DFM ERROR 0" }
    else { Add-Result "pcb-dfm" "FAIL" "DFM ERROR $err" }
}

function Test-Delivery {
    if ([string]::IsNullOrWhiteSpace($DeliveryDir)) { Add-Result "delivery" "BLOCKED" "未指定 -DeliveryDir"; return }
    if (-not (Test-Path $DeliveryDir)) { Add-Result "delivery" "FAIL" "交付目录不存在： $DeliveryDir"; return }
    $need = @{ "Gerber" = "*.g*"; "钻孔" = "*.drl"; "坐标" = "*.csv"; "BOM" = "*.xlsx" }
    $missing = @()
    foreach ($k in $need.Keys) {
        $hit = Get-ChildItem $DeliveryDir -Filter $need[$k] -File -ErrorAction SilentlyContinue |
            Where-Object { $_.Length -gt 0 } | Select-Object -First 1
        if (-not $hit) { $missing += $k }
    }
    if ($missing.Count -eq 0) { Add-Result "delivery" "PASS" "Gerber/钻孔/坐标/BOM 均非空" }
    else { Add-Result "delivery" "FAIL" "缺交付物： $($missing -join ', ')" }
}

# ── 阶段 9：不许一次性脚本（反自欺条款）────────────────────────────────
function Test-NoOneOffScripts {
    if ([string]::IsNullOrWhiteSpace($RunLog)) { Add-Result "no-oneoff-scripts" "BLOCKED" "未指定 -RunLog（无法审计）"; return }
    if (-not (Test-Path $RunLog)) { Add-Result "no-oneoff-scripts" "FAIL" "审计日志不存在： $RunLog"; return }
    $lines = Get-Content $RunLog
    $suspects = $lines | Where-Object {
        $_ -match '\\\.work\\' -or
        $_ -match 'python\s+.*\bgen\w*\.py' -or
        $_ -match 'pwsh\s+.*\.ps1' -and $_ -notmatch 'acceptance\\run\.ps1'
    }
    if ($suspects.Count -eq 0) { Add-Result "no-oneoff-scripts" "PASS" "无临时脚本调用" }
    else { Add-Result "no-oneoff-scripts" "FAIL" "$($suspects.Count) 处疑似一次性脚本，首条： $($suspects[0])" }
}

# ── 主流程 ────────────────────────────────────────────────────────────────
$caseFile = Join-Path $script:AcceptDir "cases\$Case.md"
if (-not (Test-Path $caseFile)) {
    Write-Host "[FAIL]    case                    用例不存在： $caseFile"
    exit 3
}
if (-not $Quiet) {
    Write-Host "===== EasyEDA AI Design Kit acceptance ====="
    Write-Host "case: $Case   project: $(if ($Project) { $Project } else { '<none>' })"
    Write-Host ""
}

Test-KitIntegrity
Test-DecisionTable
Test-Environment
Test-SchematicGates
Test-PcbLayout
Test-PcbConnectivity
Test-PcbDfm
Test-Delivery
Test-NoOneOffScripts

$fail = @($script:Results | Where-Object Status -eq "FAIL").Count
$blocked = @($script:Results | Where-Object Status -eq "BLOCKED").Count
$pass = @($script:Results | Where-Object Status -eq "PASS").Count
if (-not $Quiet) {
    Write-Host ""
    Write-Host "===== $pass PASS / $fail FAIL / $blocked BLOCKED ====="
}

$report = Join-Path $script:AcceptDir "last-report.json"
$script:Results | ConvertTo-Json -Depth 5 | Set-Content $report -Encoding UTF8

if ($fail -gt 0) { exit 1 }
if ($blocked -gt 0) { exit 2 }
exit 0


