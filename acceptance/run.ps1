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
    [Parameter(Mandatory = $false)][string]$SchDoc = "",
    [Parameter(Mandatory = $false)][string]$IR = "",
    [Parameter(Mandatory = $false)][string]$Cli = "$env:USERPROFILE\.local\bin\easyeda.exe",
    [Parameter(Mandatory = $false)][string]$DeliveryDir = "",
    [Parameter(Mandatory = $false)][string]$RunLog = "",
    [Parameter(Mandatory = $false)][string]$AuditRoot = "",
    [Parameter(Mandatory = $false)][string]$CodeScope = "",
    [Parameter(Mandatory = $false)][int]$DecisionBaseline = -1,
    [Parameter(Mandatory = $false)][string]$SourceRoot = "",
    [Parameter(Mandatory = $false)][string]$InstalledCli = "",
    [Parameter(Mandatory = $false)][string]$Executor = "",
    [Parameter(Mandatory = $false)][switch]$Quiet
)

$ErrorActionPreference = "Stop"
$script:AcceptDir = Split-Path -Parent $PSCommandPath
$script:RepoRoot = Split-Path -Parent $script:AcceptDir
if ([string]::IsNullOrWhiteSpace($AuditRoot)) { $script:AuditRoot = $script:RepoRoot } else { $script:AuditRoot = (Resolve-Path $AuditRoot).Path }
if ([string]::IsNullOrWhiteSpace($CodeScope)) { $script:CodeScope = "" } else { $script:CodeScope = $CodeScope }
. (Join-Path $script:AcceptDir "stages-gates.ps1")
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
    $raw = (($raw -split "`n") | Where-Object { $_ -notmatch 'artifact saved:' }) -join "`n"
    if ([string]::IsNullOrWhiteSpace($raw)) { return $null }
    $idx = $raw.IndexOf("{"); $last = $raw.LastIndexOf("}")
    if ($idx -lt 0 -or $last -le $idx) { return $null }
    try { return ($raw.Substring($idx, $last - $idx + 1) | ConvertFrom-Json) } catch { return $null }
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
        "docs\anti-drift.md",
        "docs\tool-decision-table.md",
        "docs\capability-boundary.md",
        "docs\phases\schematic-s0-s6.md",
        "docs\phases\pcb-p0-p10.md",
        "playbooks\README.md"
        "docs\playbook-unseen-board.md"
        "docs\publish-extension.md"
        "docs\prior-art-map.md"
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
$tablePath = Join-Path $script:RepoRoot "docs\tool-decision-table.md"
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
    $actionText = (& $Cli actions 2>$null | Out-String)
    $extIndex = Join-Path $script:RepoRoot "docs\extensions-index.md"
    $extText = if (Test-Path $extIndex) { Get-Content $extIndex -Raw } else { "" }

    $unresolved = @()
    foreach ($r in $rows) {
        $cells = $r.Split('|')
        if ($cells.Count -lt 4) { continue }
        $tool = $cells[2].Trim().Trim('`', '*')
        if ([string]::IsNullOrWhiteSpace($tool) -or $tool -match '^\.\.\.$') { continue }
        $hit = ($actionText -match [regex]::Escape($tool)) -or ($extText -match [regex]::Escape($tool))
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
# ── 阶段：Design IR 离线校验（Gate-1）──────────────────────────────────
# 采用上游 smart-hardware-engineer 的 IR schema 与校验器（见 vendor/prior-art 的 README）。
# 为什么需要它：直接从需求跳到 EDA 操作，改一次就要重画一次，且无法离线自检。
function Test-DesignIR {
    if ([string]::IsNullOrWhiteSpace($IR)) { Add-Result "design-ir" "BLOCKED" "未指定 -IR（design.ir.json）"; return }
    if (-not (Test-Path $IR)) { Add-Result "design-ir" "FAIL" "IR 文件不存在： $IR"; return }
    $validator = Join-Path $script:RepoRoot "vendor\prior-art\smart-hardware-engineer\scripts\ir_validate.py"
    if (-not (Test-Path $validator)) { Add-Result "design-ir" "FAIL" "IR 校验器缺失（vendor 未随包分发？）"; return }
    $env:PYTHONUTF8 = "1"
    $env:PYTHONIOENCODING = "utf-8"
    $raw = & python $validator $IR 2>&1 | Out-String
    $code = $LASTEXITCODE
    $last = ($raw -split "`n" | Where-Object { $_ -match "结果:" } | Select-Object -Last 1)
    if ([string]::IsNullOrWhiteSpace($last)) { $last = ($raw -split "`n" | Select-Object -Last 1) }
    $last = $last.Trim()
    if ($code -eq 0) { Add-Result "design-ir" "PASS" $last }
    else { Add-Result "design-ir" "FAIL" $last }
}

function Test-SchematicGates {
    if ([string]::IsNullOrWhiteSpace($Project)) { Add-Result "schematic-gates" "BLOCKED" "未指定 -Project"; return }
    if ([string]::IsNullOrWhiteSpace($SchDoc)) { Add-Result "schematic-gates" "BLOCKED" "未指定 -SchDoc（原理图文档 uuid）；无活动原理图页时 sch drc/check 均无法验证"; return }
    $args1 = @("sch", "drc", "--project", $Project, "--doc", $SchDoc)
    $raw = & $Cli $args1 2>&1 | Out-String
    # 实测：部分文档类型 sch drc 返回 "doctype(3) not support check sch drc"（GAP-014）
    if ($raw -match "not support") {
        $raw2 = & $Cli @("sch", "check", "--project", $Project, "--doc", $SchDoc) 2>&1 | Out-String
        if ($raw2 -match "(?i)failed|Cannot verify") {
            $msg = ($raw2 -split "`n" | Select-Object -First 1)
            Add-Result "schematic-gates" "BLOCKED" "sch drc 不支持该文档类型，sch check 亦无法验证： $msg"
        } else {
            Add-Result "schematic-gates" "PASS" "sch drc 不支持 doctype(3)，回退 sch check 且未报错"
        }
        return
    }
    if ($raw -match '"passed"\s*:\s*true') { Add-Result "schematic-gates" "PASS" "sch drc passed"; return }
    if ($raw -match '"passed"\s*:\s*false') { Add-Result "schematic-gates" "FAIL" "sch drc passed=false"; return }
    $msg = ($raw -split "`n" | Select-Object -First 1)
    Add-Result "schematic-gates" "BLOCKED" "sch drc 未给出可解析结论： $msg"
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
    # 优先用「导出证据」判定（delivery-evidence.json），因为真实导出有三个事实：
    #  1) 制品固定落盘到 .easyeda\artifacts，fileName 不控制路径（GAP-013）；
    #  2) Gerber 是一个 zip，钻孔数据在包内（drilling.metallic/nonMetallic 默认 true）；
    #  3) BOM 动作可能返回 no file（GAP-012）——必须如实报失败，不能当缺项蒙混。
    $evPath = Join-Path $DeliveryDir "delivery-evidence.json"
    if (Test-Path $evPath) {
        $ev = Get-Content $evPath -Raw | ConvertFrom-Json
        $problems = @(); $parts = @()
        foreach ($k in @("gerber", "pickPlace", "bom")) {
            if (-not $ev.PSObject.Properties.Name.Contains($k)) { $problems += "证据缺 $k 条目（不得跳过）" }
        }
        if ($ev.gerber) {
            if ((Test-Path $ev.gerber.path) -and (Get-Item $ev.gerber.path).Length -gt 0) {
                $parts += ("Gerber=" + [System.IO.Path]::GetFileName($ev.gerber.path) + " (" + (Get-Item $ev.gerber.path).Length + " B)")
            } else { $problems += "Gerber 文件不存在或为空" }
            $drillOk = $false
            if ($ev.gerber.drilling -and $ev.gerber.drilling.metallic -and $ev.gerber.drilling.nonMetallic) { $drillOk = $true }
            $drl = Get-ChildItem $DeliveryDir -Filter "*.drl" -File -ErrorAction SilentlyContinue | Where-Object { $_.Length -gt 0 } | Select-Object -First 1
            if ($drl) { $parts += ("钻孔=" + $drl.Name + " (" + $drl.Length + " B)") }
            elseif ($drillOk) { $parts += "钻孔=在 Gerber 包内（drilling.metallic/nonMetallic=true）" }
            else { $problems += "无钻孔证据（既无 .drl，也不在 Gerber 包内）" }
        }
        if ($ev.pickPlace) {
            if ((Test-Path $ev.pickPlace.path) -and (Get-Item $ev.pickPlace.path).Length -gt 0) {
                $parts += ("坐标=" + [System.IO.Path]::GetFileName($ev.pickPlace.path) + " (" + (Get-Item $ev.pickPlace.path).Length + " B)")
            } else { $problems += "坐标文件不存在或为空" }
        }
        if ($ev.bom) {
            if ($ev.bom.error) { $problems += ("BOM=" + $ev.bom.error) }
            elseif ((Test-Path $ev.bom.path) -and (Get-Item $ev.bom.path).Length -gt 0) { $parts += ("BOM=" + (Get-Item $ev.bom.path).Length + " B)") }
            else { $problems += "BOM 不存在或为空" }
        }
        if ($problems.Count -eq 0) { Add-Result "delivery" "PASS" ($parts -join "；") }
        else { Add-Result "delivery" "FAIL" (($problems -join "；") + "  [" + ($parts -join "；") + "]") }
        return
    }

    if (-not (Test-Path $DeliveryDir)) { Add-Result "delivery" "FAIL" "交付目录不存在： $DeliveryDir"; return }
    $need = [ordered]@{
        "Gerber" = @("*.g*", "*.zip")
        "钻孔"   = @("*.drl", "*.txt")
        "坐标"   = @("*.csv", "*.xlsx")
        "BOM"    = @("*.xlsx", "*.csv")
    }
    $missing = @()
    $found = [ordered]@{}
    foreach ($k in $need.Keys) {
        $hit = $null
        foreach ($pat in $need[$k]) {
            $cand = Get-ChildItem $DeliveryDir -Filter $pat -File -ErrorAction SilentlyContinue |
                Where-Object { $_.Length -gt 0 } | Sort-Object Length -Descending | Select-Object -First 1
            if ($cand) { $hit = $cand; break }
        }
        if ($hit) { $found[$k] = "{0} ({1:N0} B)" -f $hit.Name, $hit.Length } else { $found[$k] = $null }
    }
    $missing = @($found.Keys | Where-Object { -not $found[$_] })
    if ($missing.Count -eq 0) {
        Add-Result "delivery" "PASS" (($found.Keys | ForEach-Object { "$_=$($found[$_])" }) -join "；")
    } else {
        Add-Result "delivery" "FAIL" "缺交付物： $($missing -join "", "")（目录 $DeliveryDir）"
    }
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
    Write-Host "case: $Case   project: $(if ($Project) { $Project } else { '<none>' })   auditRoot: $script:AuditRoot   codeScope: [$script:CodeScope]"
    Write-Host ""
}

Test-KitIntegrity
Test-DecisionTable
Test-CapabilityBoundary
Test-Environment
Test-SchematicGates
Test-DesignIR
Test-PcbLayout
Test-PcbConnectivity
Test-PcbDfm
Test-Delivery
Test-NoOneOffScripts
Test-PositiveGoal
Test-NegativeDrift

$fail = @($script:Results | Where-Object Status -eq "FAIL").Count
$blocked = @($script:Results | Where-Object Status -eq "BLOCKED").Count
$pass = @($script:Results | Where-Object Status -eq "PASS").Count
if (-not $Quiet) {
    Write-Host ""
    Write-Host "===== $pass PASS / $fail FAIL / $blocked BLOCKED ====="
}

$report = Join-Path $script:AcceptDir "last-report.json"
$script:Results | ConvertTo-Json -Depth 5 | Set-Content $report -Encoding UTF8
if ([string]::IsNullOrWhiteSpace($Executor)) { $Executor = "unspecified" }
$meta = [ordered]@{
    case = $Case
    executor = $Executor
    finishedAt = (Get-Date).ToString("s")
    exitCode = $(if ($fail -gt 0) { 1 } elseif ($blocked -gt 0) { 2 } else { 0 })
    pass = $pass; fail = $fail; blocked = $blocked
    stages = @($script:Results | ForEach-Object { [ordered]@{ stage = $_.Stage; status = $_.Status } })
}
$meta | ConvertTo-Json -Depth 6 | Set-Content (Join-Path $script:AcceptDir "last-run-meta.json") -Encoding UTF8

if ($fail -gt 0) { exit 1 }
if ($blocked -gt 0) { exit 2 }
exit 0







