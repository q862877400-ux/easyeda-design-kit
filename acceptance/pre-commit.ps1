# acceptance/pre-commit.ps1 — 提交前强制跑三件套，红了就不许提交
#
# 为什么需要它：本会话我**两次带红灯提交**（一次 claims 落后、一次抽样失败），都是因为我先 commit 后跑门禁，
# 或者改完没核对就提交。纪律写在文档里没用，要变成一道会拦人的检查。
#
# 允许清单（唯一的例外，且每次都打印出来）：
#   `decision-actionability` 的 FAIL —— 决策表可执行率 18/111 是**已知未达成**项（SC-005），
#   它的存在不代表本轮改坏了东西。除此之外任何 FAIL 都会拦住提交。
#
# 用法：
#   pwsh -NoProfile -File acceptance/pre-commit.ps1 -Message "commit message"          # 校验后提交
#   pwsh -NoProfile -File acceptance/pre-commit.ps1 -Message "..." -DryRun             # 只校验不提交
#
# 退出码：0=已提交或可提交；1=被拦下

[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)][string]$Message,
    [switch]$DryRun
)

$ErrorActionPreference = "Continue"
$AcceptDir = Split-Path -Parent $PSCommandPath
$KitRoot = Split-Path -Parent $AcceptDir
$Cli = "$env:USERPROFILE\.local\bin\easyeda.exe"

$allowFail = @('decision-actionability')   # 已知未达成项，不阻塞提交

function Run-Gate {
    param([string]$Name, [string[]]$Argv)
    $out = & pwsh -NoProfile @Argv 2>&1 | Out-String
    $code = $LASTEXITCODE
    Write-Host ("  {0,-10} 退出码 {1}" -f $Name, $code)
    return @{ Name = $Name; Code = $code; Out = $out }
}

Write-Host "=== pre-commit：三件套 ==="
$self = Run-Gate "selftest" @('-File', (Join-Path $AcceptDir 'selftest.ps1'))
$mat = Run-Gate "matrix" @('-File', (Join-Path $AcceptDir 'mistake-matrix.ps1'))
$acc = Run-Gate "acceptance" @('-File', (Join-Path $AcceptDir 'run.ps1'), '-Case', 'sc001-usbc-typed', '-Cli', $Cli, '-Static')

$problems = @()
if ($self.Code -ne 0) { $problems += "selftest 退出码 $($self.Code)（期望 0）" }
if ($mat.Code -ne 0) { $problems += "mistake-matrix 退出码 $($mat.Code)（期望 0）" }

# acceptance -Static 允许 1（有 FAIL），但 FAIL 必须全部落在允许清单里
$failLines = @($acc.Out -split "`n" | Where-Object { $_ -match '\[FAIL\]' })
$unexpected = @($failLines | Where-Object { $l = $_; -not ($allowFail | Where-Object { $l -match [regex]::Escape($_) }) })
if ($unexpected.Count -gt 0) { $problems += "acceptance 出现未预期的 FAIL：$($unexpected.Count) 条" }
if ($acc.Code -notin @(0, 1)) { $problems += "acceptance 退出码 $($acc.Code)（期望 0 或 1）" }

if ($allowFail.Count -gt 0) {
    Write-Host "  允许清单（不算本轮改坏）：$($allowFail -join ', ')"
}
Write-Host ("  静态结论：{0}" -f (($acc.Out -split "`n" | Where-Object { $_ -match '===== \d' }) -join '').Trim())

if ($problems.Count -gt 0) {
    Write-Host ""
    Write-Host "=== 拦截：不许提交 ===" -ForegroundColor Red
    $problems | ForEach-Object { Write-Host "  - $_" -ForegroundColor Red }
    $unexpected | ForEach-Object { Write-Host "    $($_.Trim())" -ForegroundColor Red }
    exit 1
}

Write-Host ""
Write-Host "=== 三件套通过（无未预期 FAIL）===" -ForegroundColor Green
if ($DryRun) { Write-Host "  -DryRun：不提交"; exit 0 }

Push-Location $KitRoot
try {
    & git add -A 2>&1 | Out-Null
    $msgFile = Join-Path $env:TEMP ("precommit-msg-" + [guid]::NewGuid().ToString('N').Substring(0, 8) + ".txt")
    Set-Content -Path $msgFile -Value $Message -Encoding UTF8
    $out = & git commit -q -F $msgFile 2>&1 | Out-String
    Remove-Item $msgFile -Force -ErrorAction SilentlyContinue
    if ($LASTEXITCODE -ne 0) { Write-Host "  git commit 失败：$out" -ForegroundColor Red; exit 1 }
    Write-Host ("  已提交：{0}" -f ((& git log --oneline -1) -join ''))
} finally {
    Pop-Location
}
exit 0
