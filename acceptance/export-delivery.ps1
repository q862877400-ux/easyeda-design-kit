# acceptance/export-delivery.ps1 — 交付导出（封装三个类型化动作）
#
# 为什么需要它：交付要跑三个动作，而且每个都有坑（BOM 必须 --doc；制品落在 .easyeda\artifacts
# 而不是 payload 里的 fileName）。手敲三次必然漏。这里封成一条命令：
#   1) pcb.export.gerber      -> zip（钻孔数据在包内，drilling.* 默认 true）
#   2) pcb.export.pick_place  -> csv
#   3) schematic.export.bom --doc <原理图>  -> xlsx（不写 --doc 会返回 no file）
#   4) 把 artifact 复制到交付目录，并写 delivery-evidence.json 供验收读取
#
# 用法：
#   pwsh -NoProfile -File acceptance/export-delivery.ps1 `
#     -Project <p> -SchDoc <sch-uuid> -OutDir <dir> [-Doc <pcb-uuid>]
#
# 退出码：0 = 四类齐备；1 = 有缺项（会列出）；3 = 用法/连接问题。

[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)][string]$Project,
    [Parameter(Mandatory = $true)][string]$SchDoc,
    [Parameter(Mandatory = $true)][string]$OutDir,
    [Parameter(Mandatory = $true)][string]$Doc,
    [string]$Cli = "$env:USERPROFILE\.local\bin\easyeda.exe"
)

$ErrorActionPreference = "Stop"
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
$OutputEncoding = [System.Text.Encoding]::UTF8
New-Item -ItemType Directory -Force -Path $OutDir | Out-Null
# 前置检查（2026-11-01 实测，有反例）：**同时开着多个 EDA 窗口时，三条导出会全部失败且只报 "gerber FAIL"**——
# 看不出原因。反例：同三块板（ldo/buck/autodl）在 3 个窗口下 ok=0/fail=3；关到只剩 1 个窗口后立刻全部成功
# （ldo：gerber 11,469 B / cpl 1,944 B / bom 7,014 B）。这里显式拦下，避免把"多窗口"误判成"导出坏了"。
$__w = (& $Cli daemon health 2>$null | Out-String)
$__i = $__w.IndexOf("{")
if ($__i -ge 0) {
    try {
        $__d = $__w.Substring($__i) | ConvertFrom-Json
        $__n = if ($__d.found) { @($__d.found.raw.windows).Count } else { 0 }
        if ($__n -gt 1) {
            Write-Host "[BLOCKED] 当前有 $__n 个 EDA 窗口；导出在有多个窗口时会静默失败。请只保留目标工程一个窗口后重试。"
            exit 2
        }
    } catch { }
}


function Call-Action {
    param([string]$Name, [string]$Payload, [string]$PinDoc = "")
    $cliArgs = @('call', $Name, '--payload', $Payload)
    if ($PinDoc) { $cliArgs += @('--doc', $PinDoc) }
    $raw = & $Cli $cliArgs 2>&1 | Out-String
    # CLI 会把「📎 artifact saved: ...」异步打进 stdout，可能夹在 JSON 中间，导致解析失败（实测）
    $raw = (($raw -split "`n") | Where-Object { $_ -notmatch 'artifact saved:' }) -join "`n"
    $i = $raw.IndexOf('{'); $j = $raw.LastIndexOf('}')
    if ($i -lt 0 -or $j -le $i) { return @{ ok = $false; error = 'no-json' } }
    try {
        $d = $raw.Substring($i, $j - $i + 1) | ConvertFrom-Json
        return @{ ok = [bool]$d.ok; result = $d.result; error = $d.error }
    } catch { return @{ ok = $false; error = $_.Exception.Message } }
}

Write-Host "===== export-delivery ====="
$ev = [ordered]@{}
$fail = @()

# 1) Gerber（含钻孔数据）
$g = Call-Action 'pcb.export.gerber' '{"unit":"mm","integerNumber":4,"decimalNumber":6}' $Doc
if ($g.ok -and $g.result.artifactPath) {
    $dst = Join-Path $OutDir 'board-gerber.zip'
    Copy-Item $g.result.artifactPath $dst -Force
    # 反例（2026-10-31 外部审计 S3）：这里原来硬编码 metallic/nonMetallic/drillTable = $true，
    # 于是 36 字节的文本文件改名 board-gerber.zip 也能让 delivery 报「钻孔=在 Gerber 包内」。
    # 改成**真开包**：读 zip 目录表，按成员名判定钻孔是否存在；不是合法 zip 就直接判失败。
    $zipEntries = @(); $zipOk = $false
    try {
        Add-Type -AssemblyName System.IO.Compression.FileSystem -ErrorAction Stop
        $z = [System.IO.Compression.ZipFile]::OpenRead($dst)
        $zipEntries = @($z.Entries | ForEach-Object { $_.FullName })
        $z.Dispose(); $zipOk = $true
    } catch { $zipOk = $false }
    $hasDrill = @($zipEntries | Where-Object { $_ -match '(?i)\.drl$|drill|pth' }).Count -gt 0
    $hasNpth  = @($zipEntries | Where-Object { $_ -match '(?i)npth|non-?plated|slot' }).Count -gt 0
    $ev.gerber = [ordered]@{
        path = $dst; size = (Get-Item $dst).Length; zipValid = $zipOk; entries = $zipEntries.Count
        drilling = [ordered]@{ metallic = $hasDrill; nonMetallic = $hasNpth; drillTable = $zipOk }
    }
    if (-not $zipOk) { $fail += "gerber: 不是合法 zip（钻孔无法核对）" }
    elseif (-not $hasDrill) { $fail += "gerber: 包内无钻孔成员（.drl/drill/pth）" }
    Write-Host ("[ok]   gerber   {0}  {1:N0} B" -f (Split-Path $dst -Leaf), (Get-Item $dst).Length)
} else { $fail += "gerber: $($g.error.message)"; Write-Host "[FAIL] gerber   $($g.error.message)" }

# 2) 坐标文件
$p = Call-Action 'pcb.export.pick_place' '{"fileType":"csv","unit":"mm"}' $Doc
if ($p.ok -and $p.result.artifactPath) {
    $dst = Join-Path $OutDir 'board-cpl.csv'
    Copy-Item $p.result.artifactPath $dst -Force
    $ev.pickPlace = [ordered]@{ path = $dst; size = (Get-Item $dst).Length }
    Write-Host ("[ok]   pick&place {0}  {1:N0} B" -f (Split-Path $dst -Leaf), (Get-Item $dst).Length)
} else { $fail += "pick_place: $($p.error.message)"; Write-Host "[FAIL] pick&place $($p.error.message)" }

# 3) BOM（必须固定原理图文档，否则 no file）
$b = Call-Action 'schematic.export.bom' '{"fileType":"xlsx"}' $SchDoc
if ($b.ok -and $b.result.artifactPath) {
    $dst = Join-Path $OutDir 'board-bom.xlsx'
    Copy-Item $b.result.artifactPath $dst -Force
    $ev.bom = [ordered]@{ path = $dst; size = (Get-Item $dst).Length }
    Write-Host ("[ok]   bom       {0}  {1:N0} B" -f (Split-Path $dst -Leaf), (Get-Item $dst).Length)
} else {
    $msg = if ($b.error.message) { $b.error.message } else { 'unknown' }
    $fail += "bom: $msg"
    $ev.bom = [ordered]@{ path = $null; size = 0; error = $msg }
    Write-Host "[FAIL] bom       $msg"
}

$evPath = Join-Path $OutDir 'delivery-evidence.json'
$ev | ConvertTo-Json -Depth 5 | Set-Content $evPath -Encoding UTF8
Write-Host ""
Write-Host "证据已写: $evPath"
if ($fail.Count -gt 0) {
    Write-Host ("===== 缺 {0} 类： {1} =====" -f $fail.Count, ($fail -join '; '))
    exit 1
}
Write-Host "===== 四类齐备 ====="
exit 0
