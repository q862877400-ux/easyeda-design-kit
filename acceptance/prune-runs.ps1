# acceptance/prune-runs.ps1 — 验收报告保留策略（每 case 只留最新 N 份，其余归档）
#
# 为什么需要它：`acceptance/runs/` 会随着重跑持续膨胀。2026-11-01 实测已累计 **32 份**，
# 其中既有 17/18/19 阶段的旧报告、也有 23 阶段的新报告。`run-consistency` 取"最近两份"比对时，
# 一旦混进旧阶段集就会报 **"两次运行的阶段集不同（门禁改过：18 vs 22 个阶段）"**——
# 这是**累积造成的误报**，不是真的不一致。证据目录越跑越乱，判据就越来越不可信。
#
# 做法：按 case 分组，按文件时间倒序，保留最新 N 份在 `runs/`，其余移到 `runs/archive/`。
# 两个阶段都是**非递归**枚举 `runs/*.json`，所以 archive 子目录自然被排除在判据之外。
#
# 用法：
#   pwsh -NoProfile -File acceptance/prune-runs.ps1            # 保留每 case 最新 3 份
#   pwsh -NoProfile -File acceptance/prune-runs.ps1 -Keep 5
#   pwsh -NoProfile -File acceptance/prune-runs.ps1 -DryRun    # 只报告，不动文件

[CmdletBinding()]
param(
    [string]$KitRoot = "",
    [int]$Keep = 3,
    [switch]$DryRun
)

$ErrorActionPreference = "Stop"
if ([string]::IsNullOrWhiteSpace($KitRoot)) { $KitRoot = Split-Path -Parent $PSScriptRoot }
$runsDir = Join-Path $KitRoot 'acceptance\runs'
$archive = Join-Path $runsDir 'archive'

if (-not (Test-Path $runsDir)) { Write-Host "[BLOCKED] 没有 acceptance/runs 目录"; exit 2 }
if ($Keep -lt 1) { Write-Host "[FAIL] -Keep 必须 ≥1"; exit 1 }

$files = @(Get-ChildItem $runsDir -File -Filter '*.json' -ErrorAction SilentlyContinue)
Write-Host ("=== 报告保留策略：保留每 case 最新 {0} 份，其余归档 ===" -f $Keep)
Write-Host ("当前 runs/ 下 {0} 份" -f $files.Count)

# 从文件名取 case：<timestamp>-<case>-<executor>.json
$groups = @{}
foreach ($f in $files) {
    # 从报告 JSON 的 case 字段取（权威），文件名分段会把 executor 一起截进去。
    $case = 'unknown'
    try { $case = [string](Get-Content $f.FullName -Raw | ConvertFrom-Json).case } catch { }
    if ([string]::IsNullOrWhiteSpace($case) -or $case -eq 'unknown') {
        if ($f.Name -match '^\d{8}-\d{6}-(.+?)-lead_') { $case = $Matches[1] }
        elseif ($f.Name -match '^\d{8}-\d{6}-(.+?)-[^-]+\.json$') { $case = $Matches[1] }
    }
    if (-not $groups.ContainsKey($case)) { $groups[$case] = @() }
    $groups[$case] += $f
}

$moved = 0
foreach ($case in ($groups.Keys | Sort-Object)) {
    $sorted = @($groups[$case] | Sort-Object LastWriteTime -Descending)
    $drop = @($sorted | Select-Object -Skip $Keep)
    Write-Host ("  {0}: 共 {1} 份，保留 {2}，归档 {3}" -f $case, $sorted.Count, [Math]::Min($Keep, $sorted.Count), $drop.Count)
    foreach ($d in $drop) {
        if ($DryRun) {
            Write-Host ("    [dry] {0}" -f $d.Name)
        } else {
            if (-not (Test-Path $archive)) { New-Item -ItemType Directory -Force -Path $archive | Out-Null }
            Move-Item -LiteralPath $d.FullName -Destination (Join-Path $archive $d.Name) -Force
        }
        $moved++
    }
}

if ($DryRun) {
    Write-Host ("[dry] 将归档 {0} 份（未动文件）" -f $moved)
} else {
    $left = @(Get-ChildItem $runsDir -File -Filter '*.json').Count
    Write-Host ("已归档 {0} 份；runs/ 现在 {1} 份，archive/ {2} 份" -f $moved, $left, @(Get-ChildItem $archive -File -Filter '*.json' -ErrorAction SilentlyContinue).Count)
}
exit 0

