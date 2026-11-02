# acceptance/epru-audit.ps1 — 离线审计 `.epro2` 里的板数据（无需 EDA 窗口）
#
# 为什么需要它：`pcb export-dsn` / `project export` 失败时，命令只回一句"没有网络/没有文件"，
# 看不出**板数据本身**哪里畸形。而 `.epro2` 是 ZIP，里面的 `<工程名>.epru` 是**可读 JSON 行**
# （记录用 `||` 分隔），因此可以脱离 EDA 直接检查数据。
#
# 本工具回答三个问题：
#   1. 这份归档是否**完整**（含 project2.json + 非空 *.epru + docType=PCB）
#   2. 板上有多少器件 / 焊盘 / 过孔 / 走线 / 网络 / 铺铜
#   3. 有没有**畸形焊盘**——`defaultPad` 为空或 width/height 非正（对应 DFM 报的
#      "pad lacks both source shape and readable width/height"，GAP-059 的首要嫌疑）
#
# 用法：pwsh -NoProfile -File acceptance/epru-audit.ps1 -Path <file.epro2> [-Json]

[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)][string]$Path,
    [switch]$Json
)

$ErrorActionPreference = "Stop"
Add-Type -AssemblyName System.IO.Compression.FileSystem

if (-not (Test-Path $Path)) { Write-Error "文件不存在： $Path"; exit 3 }

$zip = [System.IO.Compression.ZipFile]::OpenRead($Path)
$meta = $null
$epruText = $null
$epruName = $null
foreach ($e in $zip.Entries) {
    if ($e.FullName -eq 'project2.json') {
        $sr = New-Object System.IO.StreamReader($e.Open())
        $meta = $sr.ReadToEnd() | ConvertFrom-Json
        $sr.Close()
    } elseif ($e.FullName -like '*.epru') {
        $epruName = $e.FullName
        $sr = New-Object System.IO.StreamReader($e.Open())
        $epruText = $sr.ReadToEnd()
        $sr.Close()
    }
}
$zip.Dispose()

$result = [ordered]@{
    file          = (Split-Path $Path -Leaf)
    sizeKB        = [math]::Round((Get-Item $Path).Length / 1KB, 1)
    hasMetadata   = ($null -ne $meta)
    editorVersion = if ($meta) { $meta.editorVersion } else { $null }
    title         = if ($meta) { $meta.title } else { $null }
    epruName      = $epruName
    epruKB        = if ($epruText) { [math]::Round($epruText.Length / 1KB, 1) } else { 0 }
    docTypes      = @{}
    counts        = [ordered]@{ component = 0; pad = 0; via = 0; line = 0; net = 0; poured = 0 }
    badPads       = @()
    complete      = $false
}

if ($epruText) {
    $parts = $epruText -split '\|\|'
    foreach ($p in $parts) {
        if ($p -match '"docType"\s*:\s*"([A-Z_]+)"') {
            $t = $Matches[1]
            $result.docTypes[$t] = 1 + ($result.docTypes[$t] -as [int])
        }
        if ($p -match '"type"\s*:\s*"COMPONENT"') { $result.counts.component++ }
        if ($p -match '"type"\s*:\s*"VIA"') { $result.counts.via++ }
        if ($p -match '"type"\s*:\s*"LINE"') { $result.counts.line++ }
        if ($p -match '"type"\s*:\s*"NET"') { $result.counts.net++ }
        if ($p -match '"type"\s*:\s*"POURED"') { $result.counts.poured++ }
        if ($p -match '"type"\s*:\s*"PAD"') {
            # 反例（2026-11-01）：PAD 是**两条记录**——头行 `{"type":"PAD","ticket":N,"id":"e36"}`，
            # 数据在紧跟的下一行。初版只判头行，于是 4 份备份都"有 15 个畸形焊盘"（纯属解析假象）。
            # 这里按换行切分后配对：头行之后的第一个 `{` 开头行才是它的数据。
            $result.counts.pad++
        }
    }
    # 结构（实测，读数据才看清）：**每一行 = 头 + || + 数据**，例如
    #   {"type":"PAD","ticket":85,"id":"e51"}||{"groupId":0,...,"defaultPad":{...},"specialPad":[...]
    # 前两次修正（按"下一行是数据"配对、按 specialPad 放行）都是错的——三次都报同样的 15 个假阳性才发现。
    foreach ($line in ($epruText -split "`n")) {
        $segs = $line -split '\|\|'
        if ($segs.Count -lt 2 -or $segs[0] -notmatch '"type"\s*:\s*"PAD"') { continue }
        $data = $segs[1]
        $ok = $false
        if ($data -match '"defaultPad"\s*:\s*\{[^}]*"width"\s*:\s*(-?[0-9.]+)[^}]*"height"\s*:\s*(-?[0-9.]+)') {
            if ([double]$Matches[1] -gt 0 -and [double]$Matches[2] -gt 0) { $ok = $true }
        }
        if (-not $ok -and ($data -match '"specialPad"\s*:\s*\[\s*\{')) { $ok = $true }
        if (-not $ok) {
            $num = if ($segs[0] -match '"id"\s*:\s*"([^"]*)"') { $Matches[1] } else { '?' }
            $result.badPads += $num
        }
    }

    $result.complete = ($result.hasMetadata -and $result.epruKB -gt 0 -and $result.docTypes.ContainsKey('PCB'))
}

if ($Json) {
    $result | ConvertTo-Json -Depth 5
} else {
    Write-Host ("文件        : {0} ({1} KB)" -f $result.file, $result.sizeKB)
    Write-Host ("元数据      : {0}  editorVersion={1}" -f $result.hasMetadata, $result.editorVersion)
    Write-Host ("数据体      : {0} ({1} KB)" -f $result.epruName, $result.epruKB)
    Write-Host ("完整        : {0}（需 元数据 + 非空 .epru + docType=PCB）" -f $result.complete)
    Write-Host ("文档类型    : {0}" -f (($result.docTypes.GetEnumerator() | Sort-Object Name | ForEach-Object { "$($_.Key)=$($_.Value)" }) -join ' '))
    Write-Host ("板数据      : 器件 {0} / 焊盘 {1} / 过孔 {2} / 走线 {3} / 网络 {4} / 已铺铜 {5}" -f `
        $result.counts.component, $result.counts.pad, $result.counts.via, $result.counts.line, $result.counts.net, $result.counts.poured)
    if ($result.badPads.Count -eq 0) {
        Write-Host "畸形焊盘    : 0"
    } else {
        Write-Host ("畸形焊盘    : {0} 个 → {1}" -f $result.badPads.Count, (($result.badPads | Select-Object -First 8) -join ', '))
    }
}

if ($result.badPads.Count -gt 0) { exit 1 }
exit 0



