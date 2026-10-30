# acceptance/sample-boundaries.ps1 — 能力边界抽样核对
#
# 目的：`capability-boundary.md` 容易退化成"感觉做不到"的散文。
# 这里每次抽 5 条，检查：
#   1) 五要素齐全（capability/evidence/triedTools/alternative/status）；
#   2) triedTools 里点名的工具，能在决策表或扩展索引里找到；
#   3) alternative 不是空话（长度 >= 10 个字符，且不是"另行处理"这类占位）。
#
# 用法：pwsh -NoProfile -File acceptance/sample-boundaries.ps1 [-Count 5]
# 退出码：0 = 抽到的条目全部通过；1 = 有不合格条目。

[CmdletBinding()]
param(
    [int]$Count = 5,
    [string]$KitRoot = "",
    [string]$Cli = "$env:USERPROFILE\.local\bin\easyeda.exe"
)

$ErrorActionPreference = "Stop"
$AcceptDir = Split-Path -Parent $PSCommandPath
if ([string]::IsNullOrWhiteSpace($KitRoot)) { $KitRoot = Split-Path -Parent $AcceptDir }

$script:HelpCache = @{}
$boundary = Join-Path $KitRoot 'docs\capability-boundary.md'
$decision = Join-Path $KitRoot 'docs\tool-decision-table.md'
$extIndex = Join-Path $KitRoot 'docs\extensions-index.md'

foreach ($p in @($boundary, $decision)) {
    if (-not (Test-Path $p)) { Write-Host "[FAIL] 缺文件： $p"; exit 1 }
}
$corpus = (Get-Content $decision -Raw)
if (Test-Path $extIndex) { $corpus += (Get-Content $extIndex -Raw) }
$actionsRaw = (& $Cli actions 2>$null | Out-String); if ($actionsRaw) { $corpus += $actionsRaw }

# 解析条目
$entries = @()
$cur = $null
foreach ($ln in Get-Content $boundary) {
    if ($ln -match '^##\s+(GAP-\d+)') {
        if ($cur) { $entries += $cur }
        $cur = [pscustomobject]@{ Id = $Matches[1]; Lines = @() }
    } elseif ($cur) { $cur.Lines += $ln }
}
if ($cur) { $entries += $cur }

if ($entries.Count -eq 0) { Write-Host "[FAIL] 没解析到任何 GAP 条目"; exit 1 }

# 确定性抽样：排序后等距取 Count 条（可复现，不用随机）
$sorted = $entries | Sort-Object Id
$step = [Math]::Max(1, [Math]::Floor($sorted.Count / $Count))
$sample = @()
for ($i = 0; $i -lt $sorted.Count -and $sample.Count -lt $Count; $i += $step) { $sample += $sorted[$i] }

Write-Host "===== 能力边界抽样（$($sample.Count)/$($entries.Count) 条）====="
$bad = 0
foreach ($e in $sample) {
    $body = $e.Lines -join "`n"
    $problems = @()

    # 1) 五要素
    foreach ($field in @('capability', 'evidence', 'triedTools', 'alternative', 'status')) {
        if ($body -notmatch "(?i)\*\*$field\*\*") { $problems += "缺 $field" }
    }

    # 2) triedTools 可解析
    $tools = @()
    if ($body -match '(?im)^-\s+\*\*triedTools\*\*\s*[:：]\s*(.*)$') {
        $tools = ($Matches[1] -split '[、,，/]') | ForEach-Object { $_.Trim().Trim('`', '*') } | Where-Object { $_ }
    }
    if ($tools.Count -eq 0) { $problems += 'triedTools 为空' }
    # 解析规则（与决策表一致，另加 CLI 命令面）：
    #  a) 出现在决策表 / 扩展索引 / actions 输出里；或
    #  b) 形如 "<组> <子命令>" 且 `easyeda <组> --help` 里能查到该子命令。
    $unresolved = @()
    foreach ($t in $tools) {
        $hit = ($corpus -match [regex]::Escape($t))
        if (-not $hit -and $t -match '^([a-z][a-z0-9-]*)\s+(\S+)') {
            $grp = $Matches[1]; $sub = $Matches[2]
            if (-not $script:HelpCache.ContainsKey($grp)) {
                $script:HelpCache[$grp] = (& $Cli @($grp, '--help') 2>$null | Out-String)
            }
            if ($script:HelpCache[$grp] -match [regex]::Escape($sub)) { $hit = $true }
        }
        if (-not $hit -and $t -match '^([a-z][a-z0-9-]*)$') {
            if (-not $script:HelpCache.ContainsKey($t)) { $script:HelpCache[$t] = (& $Cli @($t, '--help') 2>$null | Out-String) }
            if (-not [string]::IsNullOrWhiteSpace($script:HelpCache[$t])) { $hit = $true }
        }
        if (-not $hit) { $unresolved += $t }
    }
    foreach ($u in $unresolved) { $problems += "工具解析不到：$u" }

    # 3) alternative 不是占位
    $alt = ''
    if ($body -match '(?im)^-\s+\*\*alternative\*\*\s*[:：]\s*(.*)$') { $alt = $Matches[1].Trim() }
    if ($alt.Length -lt 10) { $problems += 'alternative 过短或缺失' }
    if ($alt -match '(?i)另行处理|待定|以后再说|TODO') { $problems += 'alternative 是占位话术' }

    if ($problems.Count -eq 0) {
        Write-Host ("[PASS] {0}" -f $e.Id)
        Write-Host ("       triedTools: {0}" -f ($tools -join ' / '))
        Write-Host ("       alternative: {0}" -f $alt.Substring(0, [Math]::Min(90, $alt.Length)))
    } else {
        Write-Host ("[FAIL] {0} — {1}" -f $e.Id, ($problems -join '；'))
        $bad++
    }
}

Write-Host ""
$okCount = $sample.Count - $bad
Write-Host ("===== {0} 通过 / {1} 不合格 =====" -f $okCount, $bad)
if ($bad -gt 0) { exit 1 }
exit 0



