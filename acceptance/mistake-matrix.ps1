# acceptance/mistake-matrix.ps1 — 历史错误矩阵
#
# 把我在这个项目里**真实犯过**的错逐条列成用例：植入复现物 → 看门禁是否给出预期判定。
# 判据不是"我认为抓住了"，而是脚本的可核对输出。
#
# 用法：pwsh -NoProfile -File acceptance/mistake-matrix.ps1

[CmdletBinding()]
param([string]$Cli = "$env:USERPROFILE\.local\bin\easyeda.exe")

$ErrorActionPreference = "Stop"
$AcceptDir = Split-Path -Parent $PSCommandPath
$KitRoot = Split-Path -Parent $AcceptDir
$run = Join-Path $AcceptDir 'run.ps1'
$clean = Join-Path $AcceptDir 'fixtures\runlog-clean.txt'
$drifted = Join-Path $AcceptDir 'fixtures\runlog-drifted.txt'

$script:Rows = @()

function Case {
    param(
        [string]$Id,
        [string]$Mistake,
        [string]$Stage,
        [string]$Expect,
        [scriptblock]$Plant,
        [hashtable]$Extra,
        [string]$Match,
        [switch]$RealKit
    )
    $probe = Join-Path $env:TEMP ('mx-' + [guid]::NewGuid().ToString('N').Substring(0, 6))
    New-Item -ItemType Directory -Force -Path "$probe\p", "$probe\src" | Out-Null
    try {
        if ($Plant) { & $Plant $probe }
        $a = @('-Case', 'esp32-4layer', '-SourceRoot', "$probe\src")
        if (-not ($Extra -and $Extra.ContainsKey('Cli'))) { $a += @('-Cli', $Cli) }
        if ($RealKit) { $a += @('-AuditRoot', $KitRoot) } else { $a += @('-AuditRoot', $probe) }
        if ($Extra) {
            foreach ($k in $Extra.Keys) {
                $v = $Extra[$k]
                if ($v -is [scriptblock]) { $v = & $v $probe }
                $a += @("-$k", [string]$v)
            }
        }
        $out = & pwsh -NoProfile -File $run @a 2>&1 | Out-String
        $m = [regex]::Match($out, "\[(PASS|FAIL|BLOCKED)\]\s+$([regex]::Escape($Stage))\s+(.*)")
        $status = if ($m.Success) { $m.Groups[1].Value } else { 'MISSING' }
        $detail = if ($m.Success) { $m.Groups[2].Value } else { '' }
        $ok = ($status -eq $Expect)
        if ($ok -and $Match) { $ok = ($detail -match $Match) }
        $script:Rows += [pscustomobject]@{ Id = $Id; Mistake = $Mistake; Expect = $Expect; Actual = $status; Ok = $ok; Detail = $detail }
    } finally {
        Remove-Item $probe -Recurse -Force -ErrorAction SilentlyContinue
    }
}

$bigContent = '// drc clearance rule padding padding padding padding padding'

Write-Host "===== 历史错误矩阵 ====="
Write-Host ""

# ── 一、目标偷换：用一次性产物推进 ───────────────────────────────────────
Case 'M01' '写一次性生成器脚本（.work/*-gen.py）' 'negative-drift' 'FAIL' {
    param($p); New-Item -ItemType Directory -Force -Path "$p\.work" | Out-Null
    Set-Content "$p\.work\hop-gen.py" -Value 'print(1)' -Encoding UTF8
} @{} 'N1'

Case 'M02' '写一次性 playbook（*-apply.json）' 'negative-drift' 'FAIL' {
    param($p); Set-Content "$p\pc-apply.json" -Value '{"steps":[]}' -Encoding UTF8
} @{} 'N1'

Case 'M03' 'acceptance 外写调用 easyeda 的脚本' 'negative-drift' 'FAIL' {
    param($p); Set-Content "$p\tool.ps1" -Value '& easyeda pcb drc' -Encoding UTF8
} @{} 'N1'

Case 'M04' '把说明文字冒充成 playbook' 'positive-goal' 'FAIL' {
    param($p); New-Item -ItemType Directory -Force -Path "$p\playbooks" | Out-Null
    Set-Content "$p\playbooks\x.playbook.json" -Value '{"note":"just prose"}' -Encoding UTF8
} @{} '不是可执行 playbook'

Case 'M05' 'playbook 里编造 CLI 不存在的命令' 'positive-goal' 'FAIL' {
    param($p); New-Item -ItemType Directory -Force -Path "$p\playbooks" | Out-Null
    Set-Content "$p\playbooks\f.playbook.json" -Value '{"version":1,"meta":{"name":"f"},"steps":[{"id":"s","run":"pcb not-real","flags":{}}]}' -Encoding UTF8
} @{} '在 CLI 里不存在'

# ── 二、重复造轮子 ───────────────────────────────────────────────────────
Case 'M06' '自建 DFM 检查器（check 型）' 'negative-drift' 'FAIL' {
    param($p); Set-Content "$p\p\my_drc_check.go" -Value (($bigContent + "`n") * 600) -Encoding UTF8
} @{} 'N3'

Case 'M07' '自建布线器（route 型）' 'positive-goal' 'FAIL' {
    param($p); Set-Content "$p\p\my_route_solver.go" -Value (($bigContent + "`n") * 600) -Encoding UTF8
} @{} 'P3'

Case 'M08' '自建丝印/铺铜工具（silk 型）' 'positive-goal' 'FAIL' {
    param($p); Set-Content "$p\p\my_silk_align.go" -Value (($bigContent + "`n") * 600) -Encoding UTF8
} @{} 'P3'

# ── 三、布线操作错误（历史事故）──────────────────────────────────────────
Case 'M09' '用 rip-up --net 撤销已落板路径' 'negative-drift' 'FAIL' { param($p) } @{ RunLog = $drifted } 'N4'
Case 'M10' '对着同一份快照求解多对' 'negative-drift' 'FAIL' { param($p) } @{ RunLog = $drifted } 'N5'
Case 'M11' 'save 后未 reload 就读 DRC' 'negative-drift' 'FAIL' { param($p) } @{ RunLog = $drifted } 'N6'

# ── 四、记账/能力退化 ────────────────────────────────────────────────────
# 动态基线：M12 模拟「表比基线少」，基线必须跟着真实表行数走；
# 否则表长大到超过硬编码数字后 M12 会假通过（2026-10-31 实测：表 97→107 时漏网）。
$decRows = (Select-String -Path (Join-Path $KitRoot 'docs\tool-decision-table.md') -Pattern '^\|').Count
$decBaseline = $decRows + 5
Case 'M12' '决策表行数缩水' 'negative-drift' 'FAIL' { param($p) } @{ RunLog = $clean; DecisionBaseline = $decBaseline } 'N8'

# ── 五、工具自身失效（我犯过）────────────────────────────────────────────
Case 'M15' '改完源码没重装就跑了旧二进制' 'negative-drift' 'FAIL' {
    param($p)
    Set-Content "$p\src\a.go" -Value 'package a' -Encoding UTF8
    New-Item -ItemType Directory -Force -Path "$p\bin" | Out-Null
    Set-Content "$p\bin\easyeda.exe" -Value 'old' -Encoding UTF8
    (Get-Item "$p\bin\easyeda.exe").LastWriteTime = (Get-Date).AddDays(-3)
} @{ RunLog = $clean; InstalledCli = { param($p) "$p\bin\easyeda.exe" } } 'N9'

Case 'M16' '（对照）门禁脚本自身可解析' 'positive-goal' 'PASS' { param($p) } @{ RunLog = $clean } '门禁脚本' -RealKit

# ── 六、对照：干净状态必须不被误判 ───────────────────────────────────────
Case 'M13' '（对照）空工作区' 'negative-drift' 'PASS' { param($p) } @{ RunLog = $clean }
Case 'M14' '（对照）kit 自身' 'positive-goal' 'PASS' { param($p) } @{ RunLog = $clean } -RealKit

# ── 输出 ────────────────────────────────────────────────────────────────
foreach ($r in $script:Rows) {
    $mark = if ($r.Ok) { '[抓到了]' } else { '[漏了]  ' }
    Write-Host ("{0} {1} {2,-40} 期望 {3,-7} 实际 {4}" -f $mark, $r.Id, $r.Mistake, $r.Expect, $r.Actual)
    if (-not $r.Ok) {
        $d = ($r.Detail -replace '\s+', ' ')
        Write-Host ("         └ {0}" -f $d.Substring(0, [Math]::Min(120, $d.Length)))
    }
}
$caught = @($script:Rows | Where-Object Ok).Count
$missed = @($script:Rows | Where-Object { -not $_.Ok }).Count
Write-Host ""
Write-Host ("===== {0}/{1} 抓到，{2} 漏网 =====" -f $caught, $script:Rows.Count, $missed)
if ($missed -gt 0) { exit 1 }
exit 0
