# DFM 计数解析（供 acceptance/run.ps1 与 acceptance/selftest.ps1 共用）
#
# 为什么单独成文件：`pcb check` 有**两种输出形态**，
#   有违规时：  `ERROR=3 WARN=245  | dangling=2 ...`
#   零违规时：  `PCB check (DFM): 7 track(s), 0 via(s), 4 pad(s) — 0 issue(s)`
#                 `✓ no DFM issues found`
# 早期判据只认 `ERROR=(\d+)`，于是**干净的板**被判成「未给出 ERROR 计数」→ 假 FAIL。
# 反例（2026-10-31，sc001-led-blk 实测）：7 条走线 / 4 个焊盘 / 0 issue(s)，原文无 `ERROR=`。
#
# 返回：检测到的错误数；无法判定时返回 -1（调用方据此报 FAIL，不能当 0）。

function Parse-DfmErrorCount {
    param([string]$Text)
    if ([string]::IsNullOrWhiteSpace($Text)) { return -1 }
    if ($Text -match 'ERROR=(\d+)') { return [int]$Matches[1] }
    # 零违规形态：整份报告只有 "— N issue(s)" 汇总，且没有 ERROR= 计数行
    if ($Text -match '(\d+)\s+issue\(s\)') { return [int]$Matches[1] }
    return -1
}
