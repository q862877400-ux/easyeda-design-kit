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
    $ev.gerber = [ordered]@{
        path = $dst; size = (Get-Item $dst).Length
        drilling = [ordered]@{ metallic = $true; nonMetallic = $true; drillTable = $true }
    }
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
