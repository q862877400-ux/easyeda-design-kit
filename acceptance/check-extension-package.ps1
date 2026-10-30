# acceptance/check-extension-package.ps1 — `.eext` 打包校验
#
# 目的：在**上传之前**把不合规项挡在本地。依据 docs/publish-extension.md §1 的官方要求。
#
# 用法：pwsh -NoProfile -File acceptance/check-extension-package.ps1 -Package path\x.eext
# 退出码：0 = 无 FAIL（允许 WARN）；1 = 有 FAIL；3 = 参数/文件问题。

[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)][string]$Package
)

$ErrorActionPreference = "Stop"
Add-Type -AssemblyName System.IO.Compression.FileSystem

$script:Fail = 0
$script:Warn = 0
function Ok   { param([string]$m) Write-Host "[PASS] $m" }
function Bad  { param([string]$m) Write-Host "[FAIL] $m"; $script:Fail++ }
function Warn { param([string]$m) Write-Host "[WARN] $m"; $script:Warn++ }

if (-not (Test-Path $Package)) { Write-Host "[FAIL] 包不存在： $Package"; exit 3 }

Write-Host "===== 扩展包校验： $Package ====="

# 1) ZIP 可读
$zip = $null
try { $zip = [System.IO.Compression.ZipFile]::OpenRead((Resolve-Path $Package)) }
catch { Write-Host "[FAIL] 不是可读的 ZIP（.eext 应为标准 ZIP）： $($_.Exception.Message)"; exit 3 }

try {
    $entries = $zip.Entries
    $names = @($entries | ForEach-Object { $_.FullName })

    # 2) extension.json
    $manifestEntry = $entries | Where-Object { $_.FullName -eq 'extension.json' } | Select-Object -First 1
    if (-not $manifestEntry) {
        Bad '包根缺 extension.json'
        $manifest = $null
    } else {
        $reader = New-Object System.IO.StreamReader($manifestEntry.Open())
        $raw = $reader.ReadToEnd(); $reader.Close()
        try { $manifest = $raw | ConvertFrom-Json; Ok 'extension.json 可解析' }
        catch { Bad "extension.json 不是合法 JSON： $($_.Exception.Message)"; $manifest = $null }
    }

    if ($manifest) {
        # 3) 必填字段
        foreach ($f in @('name', 'uuid', 'displayName', 'description', 'version', 'license')) {
            $v = $manifest.$f
            if ([string]::IsNullOrWhiteSpace([string]$v)) { Bad "extension.json 缺必填字段： $f" }
        }
        # 4) uuid 32 位小写字母数字
        if ($manifest.uuid) {
            if ($manifest.uuid -notmatch '^[0-9a-z]{32}$') { Bad "uuid 应为 32 位小写字母/数字： $($manifest.uuid)" }
        }
        # 5) version 语义化
        if ($manifest.version) {
            if ($manifest.version -notmatch '^\d+\.\d+\.\d+$') { Bad "version 应为 x.y.z： $($manifest.version)" }
        }
        # 6) categories
        $allowed = @('Schematic', 'Symbol', 'PCB', 'Footprint', 'Panel', 'Library', 'Project', 'Other')
        $cats = @($manifest.categories)
        if ($cats.Count -eq 0 -or [string]::IsNullOrWhiteSpace([string]$cats[0])) {
            Bad 'categories 为空（至少一个）'
        } else {
            $badCats = @($cats | Where-Object { $allowed -notcontains $_ })
            if ($badCats.Count -gt 0) { Bad "categories 含未允许取值： $($badCats -join ', ')" } else { Ok "categories 合法： $($cats -join ', ')" }
        }
        # 7) description 长度（参考实现要求 >=80，官方未强制 → WARN）
        if ($manifest.description -and $manifest.description.Length -lt 80) {
            Warn "description 仅 $($manifest.description.Length) 字符（参考实现要求 ≥80，官方未强制）"
        }
        # 8) entry / icon 必须在包内且非空
        foreach ($key in @('entry', 'icon')) {
            $rel = [string]$manifest.$key
            if ([string]::IsNullOrWhiteSpace($rel)) { continue }
            $e = $entries | Where-Object { $_.FullName -eq $rel } | Select-Object -First 1
            if (-not $e) { Bad "$key 指向的文件不在包内： $rel" }
            elseif ($e.Length -le 0) { Bad "$key 指向的文件为空： $rel" }
            else { Ok "$key 存在且非空： $rel ($($e.Length) B)" }
        }
        # 9) 图标规则：PNG 需 ≥200x200 且正方形
        $iconRel = [string]$manifest.icon
        if ($iconRel -and $iconRel -match '\.png$') {
            $e = $entries | Where-Object { $_.FullName -eq $iconRel } | Select-Object -First 1
            if ($e) {
                $ms = New-Object System.IO.MemoryStream
                $s = $e.Open(); $s.CopyTo($ms); $s.Close()
                $bytes = $ms.ToArray()
                if ($bytes.Length -ge 24 -and $bytes[1] -eq 0x50 -and $bytes[2] -eq 0x4E -and $bytes[3] -eq 0x47) {
                    $w = [int]$bytes[16] * 16777216 + [int]$bytes[17] * 65536 + [int]$bytes[18] * 256 + [int]$bytes[19]
                    $h = [int]$bytes[20] * 16777216 + [int]$bytes[21] * 65536 + [int]$bytes[22] * 256 + [int]$bytes[23]
                    if ($w -lt 200 -or $h -lt 200) { Bad "图标分辨率 ${w}x${h} < 200x200" }
                    elseif ($w -ne $h) { Warn "图标非 1:1（${w}x${h}）" }
                    else { Ok "图标 ${w}x${h}，正方形且达标" }
                } else { Warn '图标不是合法 PNG（无法校验尺寸）' }
            }
        }
        # 10) 隐私：不得含手机号样式
        $phoneish = @()
        foreach ($e in $entries) {
            if ($e.FullName -match '\.(md|json|js|txt)$' -and $e.Length -lt 2MB) {
                $r = New-Object System.IO.StreamReader($e.Open())
                $txt = $r.ReadToEnd(); $r.Close()
                if ($txt -match '(?<!\d)1[3-9]\d{9}(?!\d)') { $phoneish += $e.FullName }
            }
        }
        if ($phoneish.Count -gt 0) { Bad "疑似含手机号： $($phoneish -join ', ')" } else { Ok '未发现手机号样式字符串' }
    }
} finally { $zip.Dispose() }

Write-Host ""
Write-Host ("===== {0} FAIL / {1} WARN =====" -f $script:Fail, $script:Warn)
if ($script:Fail -gt 0) { exit 1 }
exit 0
