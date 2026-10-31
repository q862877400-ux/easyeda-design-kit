# acceptance/compare-runs.ps1 — 两次执行的阶段结论比对
#
# 用途：支撑 SC-004（换模型/换执行者结果一致）。单次运行通过不算模型无关；
# 必须证明"两个执行者在同一需求上得出同样的阶段结论"。
#
# 用法：
#   pwsh -NoProfile -File acceptance/compare-runs.ps1 -A run-a.json -B run-b.json
#   pwsh -NoProfile -File acceptance/compare-runs.ps1 -A run-a.json -B run-b.json `
#        -MetaA run-a-meta.json -MetaB run-b-meta.json
#
# 退出码：0 = 阶段结论一致；1 = 不一致（列出差异）；3 = 用法/读取错误。

[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)][string]$A,
    [Parameter(Mandatory = $true)][string]$B,
    [string]$MetaA = "",
    [string]$MetaB = ""
)

$ErrorActionPreference = "Stop"

function Read-Report {
    param([string]$Path)
    if (-not (Test-Path $Path)) { throw "找不到报告： $Path" }
    $raw = Get-Content $Path -Raw
    $json = $raw | ConvertFrom-Json
        # 兼容第三种形态（2026-10-31 起 run.ps1 入库的 per-run 报告）：
        # { case, executor, pass/fail/blocked, stages: [{stage,status,detail}] }
        if ($json.PSObject.Properties.Name -contains "stages") { $json = $json.stages }
    # 兼容：单对象（个别脚本会写成一个对象而非数组）
    $items = if ($json -is [array]) { $json } else { @($json) }
    $map = [ordered]@{}
    foreach ($it in $items) {
        $stage = if ($it.PSObject.Properties.Name -contains 'Stage') { $it.Stage } else { $it.stage }
        $status = if ($it.PSObject.Properties.Name -contains 'Status') { $it.Status } else { $it.status }
        if ($stage) { $map[$stage] = $status }
    }
    return $map
}

function Read-Meta {
    param([string]$Path)
    if ([string]::IsNullOrWhiteSpace($Path) -or -not (Test-Path $Path)) { return $null }
    return Get-Content $Path -Raw | ConvertFrom-Json
}

try {
    $mapA = Read-Report $A
    $mapB = Read-Report $B
} catch {
    Write-Host "[FAIL] 输入读取失败： $($_.Exception.Message)"
    exit 3
}

Write-Host "===== compare-runs ====="
$infoA = $null
if (-not [string]::IsNullOrWhiteSpace($MetaA) -and (Test-Path $MetaA)) { $infoA = Get-Content $MetaA -Raw | ConvertFrom-Json }
$infoB = $null
if (-not [string]::IsNullOrWhiteSpace($MetaB) -and (Test-Path $MetaB)) { $infoB = Get-Content $MetaB -Raw | ConvertFrom-Json }
$exA = if ($infoA) { "{0} exit={1} p/f/b={2}/{3}/{4}" -f [string]$infoA.executor, [string]$infoA.exitCode, [string]$infoA.pass, [string]$infoA.fail, [string]$infoA.blocked } else { "(未提供)" }
Write-Host ("A: " + $exA)
$exB = if ($infoB) { "{0} exit={1} p/f/b={2}/{3}/{4}" -f [string]$infoB.executor, [string]$infoB.exitCode, [string]$infoB.pass, [string]$infoB.fail, [string]$infoB.blocked } else { "(未提供)" }
Write-Host ("B: " + $exB)
Write-Host ""

$allStages = @($mapA.Keys) + @($mapB.Keys) | Select-Object -Unique
$same = 0; $diff = @(); $missing = @()

foreach ($s in $allStages) {
    $sa = if ($mapA.Contains($s)) { $mapA[$s] } else { $null }
    $sb = if ($mapB.Contains($s)) { $mapB[$s] } else { $null }
    if ($null -eq $sa -or $null -eq $sb) {
        $missing += ("{0}（A={1} B={2}）" -f $s, $(if ($null -eq $sa) { '-' } else { $sa }), $(if ($null -eq $sb) { '-' } else { $sb }))
    } elseif ($sa -eq $sb) {
        $same++
    } else {
        $diff += ("{0}: A={1} B={2}" -f $s, $sa, $sb)
    }
}

foreach ($d in $diff) { Write-Host "[DIFF]  $d" }
foreach ($m in $missing) { Write-Host "[MISS]  $m" }

Write-Host ""
if ($diff.Count -eq 0 -and $missing.Count -eq 0) {
    Write-Host ("===== CONSISTENT：{0} 个阶段结论一致 =====" -f $same)
    exit 0
}

Write-Host ("===== INCONSISTENT：一致 {0} / 差异 {1} / 缺失 {2} =====" -f $same, $diff.Count, $missing.Count)
exit 1

