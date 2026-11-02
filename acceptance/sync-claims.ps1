# acceptance/sync-claims.ps1 — 把 HANDOVER 的 claims 块按实测值重写
#
# 为什么需要它：claims 值必须与实测一致，而实测值每轮都在变（加阶段、加边界、加断言）。
# 我已连续三轮"先写文档、后忘同步"导致 claims-match 判 FAIL——靠记性维护必然出错。
# 这个脚本不改变判据：判据仍然是 claims-match（声明≠实测即 FAIL）；它只是把"保持同步"变成一条命令。
#
# 用法：pwsh -NoProfile -File acceptance/sync-claims.ps1 [-Check]
#   -Check  只打印将要写入的值，不写文件（用于核对）

[CmdletBinding()]
param(
    [switch]$Check
)

$ErrorActionPreference = "Stop"
$AcceptDir = Split-Path -Parent $PSCommandPath
$RepoRoot = Split-Path -Parent $AcceptDir

$runPs1 = Join-Path $RepoRoot 'acceptance\run.ps1'
$bdPath = Join-Path $RepoRoot 'docs\capability-boundary.md'
$tblPath = Join-Path $RepoRoot 'docs\tool-decision-table.md'
$iePath = Join-Path $RepoRoot 'docs\installed-extensions.json'
$hpPath = Join-Path $RepoRoot 'docs\HANDOVER.md'
$stPath = Join-Path $RepoRoot 'acceptance\selftest.ps1'

$live = [ordered]@{}
$live['stages'] = @(Select-String -Path $runPs1 -Pattern '^Test-[A-Za-z]+$').Count
$bd = Get-Content $bdPath -Raw
$live['boundaries'] = ([regex]::Matches($bd, '(?m)^##\s+GAP-\d+')).Count
$rows = @(Get-Content $tblPath | Where-Object { $_ -match '^\|' -and $_ -notmatch '^\|\s*-+' -and $_ -notmatch '情境' })
$live['decision_rows'] = $rows.Count

# 可执行行：与 decision-actionability 同口径（具体物 或 可核对界面入口 + 已装扩展）
$ie = @((Get-Content $iePath -Raw | ConvertFrom-Json).installed)
$act = 0
foreach ($r in $rows) {
    $cells = $r.Split('|')
    if ($cells.Count -lt 4) { continue }
    $tool = $cells[2].Trim()
    $params = $cells[3].Trim()
    $concrete = ($params -match '--[a-zA-Z]') -or ($params -match '`[^`]+`') -or ($params -match '\{[^}]*\}')
    $ui = ($params -match '→|菜单|面板|对话框|右键|工具栏|弹窗')
    $installed = @($ie | Where-Object { $tool -like "*$_*" -or $_ -like "*$tool*" }).Count -gt 0
    $blockedRow = ($params -match '未装') -and ($params -notmatch '替代|改用|命令|pcb ')
    if (($concrete -or ($ui -and $installed)) -and -not $blockedRow) { $act++ }
}
$live['decision_actionable'] = $act

$pbSteps = 0
foreach ($pf in (Get-ChildItem (Join-Path $RepoRoot 'playbooks') -File -Filter '*.playbook.json' -ErrorAction SilentlyContinue)) {
    try { $pbSteps += @((Get-Content $pf.FullName -Raw | ConvertFrom-Json).steps).Count } catch { }
}
$live['playbook_steps'] = $pbSteps
$live['selftest_cases'] = @(Get-Content $stPath | Where-Object { $_ -match '^\s*Assert-Case\s' }).Count

$line = '<!-- claims: ' + (($live.Keys | ForEach-Object { "$_=$($live[$_])" }) -join '; ') + ' -->'

if ($Check) {
    Write-Host $line
    return
}

$text = Get-Content $hpPath -Raw
if ($text -match '<!--\s*claims:.*?-->') {
    $text = [regex]::Replace($text, '<!--\s*claims:.*?-->', [System.Text.RegularExpressions.MatchEvaluator] { param($m) $line })
} else {
    # 没有就插在第一个二级标题之前
    $idx = $text.IndexOf("`n## ")
    if ($idx -lt 0) { $text = $line + "`n`n" + $text } else { $text = $text.Insert($idx + 1, "`n" + $line + "`n") }
}
Set-Content -Path $hpPath -Value $text -Encoding UTF8
Write-Host "claims 已同步:"
Write-Host $line
