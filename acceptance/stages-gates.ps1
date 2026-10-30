# stages-gates.ps1 — 双向门禁
#
# 正向（positive-goal）：这一轮/这个仓库，是不是在朝「可安装、可验收的能力」走。
# 负面（negative-drift）：有没有再犯以前真实跑偏过的错误。
#
# 每条判据都对应一次**真实事故**，不是假想。事故出处写在判据旁边。

# ══════════════════════════════════════════════════════════════════════
# 正向：是不是符合目标
# ══════════════════════════════════════════════════════════════════════
function Test-PositiveGoal {
    $fail = @(); $note = @()

    # P1 规范产物只增不减（能力在长，而不是在整理）
    $baselinePath = Join-Path $script:AcceptDir 'baseline.json'
    if (Test-Path $baselinePath) {
        $b = Get-Content $baselinePath -Raw | ConvertFrom-Json
        $now = Get-CanonicalCounts
        foreach ($k in @('docs_files', 'playbooks', 'acceptance', 'spec_files')) {
            if ($null -ne $b.$k -and $now[$k] -lt [int]$b.$k) {
                $fail += "$k 从 $($b.$k) 降到 $($now[$k])（能力退化）"
            }
        }
        $note += "规范产物 $($now.docs_files)/$($now.playbooks)/$($now.acceptance)/$($now.spec_files)"
    }

    # P2 playbook 必须是**可执行的**，不能是"写段说明就叫 playbook"
    # （事故：把一段流程说明登记成「工具件」自我加分）
    $pbDir = Join-Path $script:AuditRoot 'playbooks'
    if (Test-Path $pbDir) {
        foreach ($f in Get-ChildItem $pbDir -File -Filter '*.playbook.json') {
            try {
                $j = Get-Content $f.FullName -Raw | ConvertFrom-Json
                if (-not $j.version -or -not $j.meta -or -not $j.steps -or $j.steps.Count -lt 1) {
                    $fail += "$($f.Name) 不是可执行 playbook（缺 version/meta/steps）"
                }
            } catch { $fail += "$($f.Name) 不是合法 JSON" }
        }
    }

    # P3 复用优先：kit 仓库里不许出现"实现类代码"
    # （事故：手搓布线器/DFM/丝印，而扩展中心已有对应工具）
    $impl = Get-ChildItem $script:AuditRoot -Recurse -File -Include '*.go', '*.ts', '*.js' -ErrorAction SilentlyContinue |
        Where-Object { $_.FullName -notmatch '\\(node_modules|\.git|dist|bin|vendor|target|_archive|acceptance)\\' -and $_.FullName.Contains($script:CodeScope) }
    $isExternal = ($script:AuditRoot -ne $script:RepoRoot)
    if ($isExternal) {
        # 外部审计：连接器/CLI 本身是合法基础设施，不能按"kit 里零实现代码"判。
        # 只判"功能与既有扩展重叠"的那部分——那才是重复造轮子。
        $dupSig = '(?i)(check|drc|dfm|autorout|shortroute|route_|silk|pour|export|gerber|bom)'
        $dup = @($impl | Where-Object { $_.Name -match $dupSig -and $_.Length -gt 20KB -and $_.Name -notmatch '_test' })
        if ($dup.Count -gt 0) {
            $fail += "P3(外部审计) $($dup.Count) 个实现文件与既有扩展功能重叠（重复造轮子）： $(($dup | Select-Object -First 4 | ForEach-Object { $_.Name }) -join ', ')"
        } else {
            $note += "外部审计：实现文件 $($impl.Count) 个，未命中功能重叠模式"
        }
    } elseif ($impl.Count -gt 0) {
        $fail += "kit 里出现 $($impl.Count) 个实现类源文件（应先复用扩展中心）： $(($impl | Select-Object -First 3 | ForEach-Object { $_.Name }) -join ', ')"
    }

    # P4 规格里必须有可测量的判据（否则"验收"无从谈起）
    $spec = Join-Path $script:RepoRoot 'specs\004-ai-pcb-design-kit\spec.md'
    if (Test-Path $spec) {
        $sc = (Select-String -Path $spec -Pattern '^\s*-\s+\*\*SC-\d{3}\*\*').Count
        if ($sc -lt 3) { $fail += "spec 里可测量判据只有 $sc 条（要求 ≥3）" }
        else { $note += "SC 判据 $sc 条" }
    } else { $fail += "spec.md 不存在" }

    # P5 验收得能区分三态：BLOCKED 不能被当 PASS
    if (Test-Path (Join-Path $script:AcceptDir 'baseline.json')) {
        $note += "三态语义由 run.ps1 保障（BLOCKED≠PASS，交付物查非空）"
    }

    # P6 每轮必须"学会用现有工具"：playbook 每一步的 run 必须是 CLI 里真实存在的命令。
    # 编一条不存在的命令 = 自己造工具 = 直接失败。
    $pbDir2 = Join-Path $script:AuditRoot 'playbooks'
    $helpCache = @{}
    $stepChecked = 0
    if (Test-Path $pbDir2) {
        foreach ($pf in Get-ChildItem $pbDir2 -File -Filter '*.playbook.json') {
            try { $pj = Get-Content $pf.FullName -Raw | ConvertFrom-Json } catch { continue }
            foreach ($st in @($pj.steps)) {
                $run = [string]$st.run
                if ([string]::IsNullOrWhiteSpace($run)) { $fail += "$($pf.Name) 有步骤没有 run（无法证明用的是现有工具）"; continue }
                $parts = $run.Trim() -split '\s+'
                $group = $parts[0]
                if (-not $helpCache.ContainsKey($group)) { $helpCache[$group] = (& $Cli @($group, '--help') 2>$null | Out-String) }
                $sub = if ($parts.Count -ge 2) { $parts[1] } else { $group }
                if ($helpCache[$group] -notmatch "(?m)^\s+$([regex]::Escape($sub))\s") { $fail += "$($pf.Name): 步骤 run='$run' 在 CLI 里不存在（疑似自编工具）" }
                $stepChecked++
            }
        }
        if ($fail.Count -eq 0) { $note += "playbook $stepChecked 步全部命中现有命令" }
    }
    # P7 门禁脚本自身必须可解析（事故：改了门禁但脚本已坏，门禁静默失效）
    $badScript = @()
    foreach ($sf in Get-ChildItem (Join-Path $script:AcceptDir '*.ps1') -File -ErrorAction SilentlyContinue) {
        $perr = $null
        [System.Management.Automation.Language.Parser]::ParseFile($sf.FullName, [ref]$null, [ref]$perr) | Out-Null
        if ($perr -and $perr.Count -gt 0) { $badScript += $sf.Name }
    }
    if ($badScript.Count -gt 0) { $fail += "P7 门禁脚本语法错误（门禁会静默失效）： $($badScript -join ', ')" } else { $note += "门禁脚本 $(@(Get-ChildItem (Join-Path $script:AcceptDir '*.ps1') -File).Count) 个均可解析" }
    if ($fail.Count -gt 0) { Add-Result "positive-goal" "FAIL" ($fail -join '；') }
    else { Add-Result "positive-goal" "PASS" ($note -join '；') }
}

# ══════════════════════════════════════════════════════════════════════
# 负面：有没有再犯以前跑偏的错
# ══════════════════════════════════════════════════════════════════════
function Test-NegativeDrift {
    $fail = @(); $blocked = @(); $note = @()

    # N1 一次性产物（事故：26 个生成器 + 28 个一次性 playbook，能力归零）
    $oneoffPatterns = @('*\gen*.py', '*apply*.json')
    $oneoffDirs = @('.work', 'scratch', 'tmp', 'oneoff', '_scratch')
    $offenders = @()
    foreach ($pat in $oneoffPatterns) {
        $offenders += Get-ChildItem $script:AuditRoot -Recurse -File -Filter $pat -ErrorAction SilentlyContinue |
            Where-Object { $_.FullName -notmatch '\\(node_modules|\.git|dist|bin|vendor|target|_archive)\\' -and $_.FullName -notmatch '\\playbooks\\' }
    }
    foreach ($d in $oneoffDirs) {
        $p = Join-Path $script:AuditRoot $d
        if (Test-Path $p) { $offenders += Get-ChildItem $p -Recurse -File | Select-Object -First 5 }
    }
    $stray = Get-ChildItem $script:AuditRoot -Recurse -File -Include '*.py', '*.ps1' -ErrorAction SilentlyContinue |
        Where-Object {
            $_.FullName -notmatch '\\acceptance\\' -and $_.FullName -notmatch '\\\.git\\' -and
            (Select-String -Path $_.FullName -Pattern 'easyeda' -Quiet -ErrorAction SilentlyContinue)
        }
    $offenders += $stray
    if ($offenders.Count -gt 0) {
        $fail += "N1 一次性产物 $($offenders.Count) 个： $(($offenders | Select-Object -Unique -First 3 | ForEach-Object { $_.Name }) -join ', ')"
    }

    # N2 提交只动板子/临时文件（事故：49 轮里大量"只改板子"的轮次）
    Push-Location $script:RepoRoot
    try {
        $lastFiles = & git show --pretty=format: --name-only HEAD 2>$null
        $canonical = @($lastFiles | Where-Object { $_ -match '^(docs|playbooks|acceptance|specs)/' })
        if ($lastFiles.Count -gt 0 -and $canonical.Count -eq 0) {
            $fail += "N2 最近提交没动任何规范产物，只动了： $(($lastFiles | Select-Object -First 3) -join ', ')"
        }
        # N3 工程内不该有"自建检查器给自己打分"（事故：用自写 DFM 给自己开绿灯）
        $selfScorer = Get-ChildItem $script:AuditRoot -Recurse -File -Include '*.go', '*.py' -ErrorAction SilentlyContinue |
            Where-Object { $_.FullName -notmatch '\\(node_modules|\.git|dist|bin|vendor|target|acceptance)\\' -and $_.FullName.Contains($script:CodeScope) -and
                (Select-String -Path $_.FullName -Pattern 'clearance|drc|dfm' -Quiet -ErrorAction SilentlyContinue) }
        # 只把"实质性检查器"算进来：真正实现检查器的文件必然够大；仅提到 drc/dfm 字样的不算。
        $bigChecker = @($selfScorer | Where-Object { $_.Name -match '(?i)(check|drc|dfm)' -and $_.Length -gt 20KB -and $_.Name -notmatch '_test' })
        if ($bigChecker.Count -gt 0) {
            $fail += "N3 出现自建检查器实现 $($bigChecker.Count) 个（应使用既有检查器）： $(($bigChecker | ForEach-Object { '{0} {1:N0}KB' -f $_.Name, ($_.Length/1KB) }) -join ', ')"
        } else {
            $note += "自建检查器 0 个（提字样 $($selfScorer.Count) 个均非实现）"
        }
    } finally { Pop-Location }

    # 以下需要运行日志；没有日志时如实报 BLOCKED（不报 PASS）
    if ([string]::IsNullOrWhiteSpace($RunLog) -or -not (Test-Path $RunLog)) {
        $blocked += "N4–N6 需要 -RunLog 才能审计（缺快照重取 / rip-up 撤路径 / 未重载就读 DRC）"
    } else {
        $log = Get-Content $RunLog
        # N4 用 rip-up --net 撤销已落板路径（事故：第 46 轮整网被删，Connection 21→31）
        $ripupNet = @($log | Where-Object { $_ -match 'rip-up.*--net' })
        if ($ripupNet.Count -gt 0) { $fail += "N4 使用了 rip-up --net $($ripupNet.Count) 次（会删掉该网原有合法铜）" }

        # N5 一次快照求解多对（事故：第 43/46 轮，Clearance 18→31）
        # N5：`route solve` 需要外部 board 文件（可能对着旧快照），`route fill` 自带取快照。
        # 反例（2026-10-31）：日志里 3 次 `route fill`、0 次显式 dump，`fill` 内部每次都重取快照，
        # 旧判据把 fill 也算作"求解"，于是误报 FAIL。
        $dumps = @($log | Where-Object { $_ -match 'pcb\s+dump' }).Count
        $solves = @($log | Where-Object { $_ -match 'route\s+solve' }).Count
        $fills = @($log | Where-Object { $_ -match 'route\s+fill' }).Count
        if ($solves -gt $dumps -and $solves -gt 0) {
            $fail += "N5 求解 $solves 次但只取快照 $dumps 次（存在对着旧快照求解）"
        }
        $note += "日志审计：dump $dumps / solve $solves / fill $fills（fill 自带快照）"

        # N6 改完没重载就读 DRC（事故：第 20/36/46 轮，读到中间态并据此下结论）
        $saved = -1; $reloaded = -1; $drcAfterSave = -1
        for ($i = 0; $i -lt $log.Count; $i++) {
            if ($saved -lt 0 -and $log[$i] -match 'pcb\s+save') { $saved = $i }
            if ($log[$i] -match 'doc\s+reload') { $reloaded = $i }
            if ($saved -ge 0 -and $log[$i] -match 'pcb\s+drc') { $drcAfterSave = $i; break }
        }
        if ($saved -ge 0 -and $drcAfterSave -ge 0 -and $reloaded -lt $saved) {
            $fail += "N6 save 之后、DRC 之前没有 doc reload（会读到中间态）"
        }
    }

    # N7 新增实现代码必须同提交带边界证据（证明试过现有工具）
    # N8 决策表行数只增不减（"学会的工具"账本）
    Push-Location $script:RepoRoot
    try {
        $files = & git show --pretty=format: --name-only HEAD 2>$null
        $code = @($files | Where-Object { $_ -match '\.(go|py|ts|js)$' -and $_ -notmatch '^acceptance/' })
        $bt = @($files | Where-Object { $_ -match 'capability-boundary\.md$' }).Count -gt 0
        if ($code.Count -gt 0 -and -not $bt) {
            $fail += "N7 新增实现代码但同提交未更新 capability-boundary.md（无法证明试过现有工具）： $(($code | Select-Object -First 3) -join ', ')"
        }
        $dt = Join-Path $script:RepoRoot 'docs\tool-decision-table.md'
        $rows = if (Test-Path $dt) { @(Get-Content $dt | Where-Object { $_ -match '^\|' -and $_ -notmatch '^\|\s*-+' -and $_ -notmatch '情境' }).Count } else { 0 }
        $bp = Join-Path $script:AcceptDir 'baseline.json'
        if (Test-Path $bp) {
            $b2 = Get-Content $bp -Raw | ConvertFrom-Json
            if ($null -ne $b2.decision_rows -and $rows -lt [int]$b2.decision_rows) { $fail += "N8 决策表行数从 $($b2.decision_rows) 降到 $rows（工具经验在减少）" }
            elseif ($script:DecisionBaseline -ge 0 -and $rows -lt $script:DecisionBaseline) { $fail += "N8 决策表行数 $rows < 注入基线 $script:DecisionBaseline（工具经验在减少）" }
        }
        $note += "决策表 $rows 行"
    } finally { Pop-Location }
    # N9 改了源码却没重装就继续跑（事故：我改完 Go 代码，跑的仍是旧 exe，据此下了错误结论）
    if (-not [string]::IsNullOrWhiteSpace($script:SourceRoot) -and (Test-Path $script:SourceRoot) -and (Test-Path $script:InstalledCli)) {
        $newest = Get-ChildItem $script:SourceRoot -Recurse -File -Include '*.go' -ErrorAction SilentlyContinue |
            Where-Object { $_.FullName -notmatch '\\\.git\\' } | Sort-Object LastWriteTime -Descending | Select-Object -First 1
        if ($newest) {
            $exeTime = (Get-Item $script:InstalledCli).LastWriteTime
            if ($newest.LastWriteTime -gt $exeTime) {
                $fail += "N9 源码比已安装 CLI 新（改了没重装就跑了旧二进制）： $($newest.Name) 新于 $([System.IO.Path]::GetFileName($script:InstalledCli))"
            } else { $note += "已安装 CLI 不旧于源码" }
        }
    }
    if ($fail.Count -gt 0) { Add-Result "negative-drift" "FAIL" ($fail -join '；') }
    elseif ($blocked.Count -gt 0) { Add-Result "negative-drift" "BLOCKED" (($blocked + $note) -join '；') }
    else { Add-Result "negative-drift" "PASS" ($note -join '；') }
}

# 规范产物计数（正向 P1 与基线共用）
function Get-CanonicalCounts {
    return [ordered]@{
        docs_files = @(Get-ChildItem (Join-Path $script:RepoRoot 'docs') -Recurse -File -ErrorAction SilentlyContinue).Count
        playbooks  = @(Get-ChildItem (Join-Path $script:RepoRoot 'playbooks') -Recurse -File -ErrorAction SilentlyContinue).Count
        acceptance = @(Get-ChildItem (Join-Path $script:RepoRoot 'acceptance') -Recurse -File -ErrorAction SilentlyContinue).Count
        spec_files = @(Get-ChildItem (Join-Path $script:RepoRoot 'specs') -Recurse -File -ErrorAction SilentlyContinue).Count
    }
}











# ══════════════════════════════════════════════════════════════════════
# 能力边界的结构校验（E4 字段：capability / evidence / triedTools / alternative / status）
#
# 为什么要机械校验：边界清单最容易退化成"感觉做不到"的散文。
# triedTools 为空 = 还没试过现有工具就宣布做不到，这条无效。
# ══════════════════════════════════════════════════════════════════════
function Test-CapabilityBoundary {
    $path = Join-Path $script:AuditRoot 'docs\capability-boundary.md'
    if (-not (Test-Path $path)) {
        Add-Result "capability-boundary" "FAIL" "文件不存在： docs\capability-boundary.md"
        return
    }
    $lines = Get-Content $path
    $entries = @()
    $cur = $null
    foreach ($ln in $lines) {
        if ($ln -match '^##\s+(GAP-\d+)') {
            if ($cur) { $entries += $cur }
            $cur = [ordered]@{ id = $Matches[1]; text = @() }
        } elseif ($cur) {
            $cur.text += $ln
        }
    }
    if ($cur) { $entries += $cur }

    if ($entries.Count -lt 8) {
        Add-Result "capability-boundary" "FAIL" "只有 $($entries.Count) 条边界（要求 ≥8）"
        return
    }

    $bad = @()
    foreach ($e in $entries) {
        $body = $e.text -join "`n"
        $missing = @()
        foreach ($field in @('capability', 'evidence', 'triedTools', 'alternative', 'status')) {
            if ($body -notmatch "(?i)\*\*$field\*\*") { $missing += $field }
        }
        # triedTools 必须有实际内容（去掉标记后仍有工具名）
        if ($body -match '(?im)^-\s+\*\*triedTools\*\*\s*[:：]\s*(.*)$') {
            $tools = $Matches[1].Trim()
            if ([string]::IsNullOrWhiteSpace($tools) -or $tools -eq '无' -or $tools -eq '-') { $missing += 'triedTools(空)' }
        } else {
            # 解析不到 vs 内容为空：必须区分。过去"解析不到就跳过"让校验器空转。
            $missing += 'triedTools(格式不可解析，需 `- **triedTools**：...`)'
        }
        # status 必须是三值之一
        if ($body -match '(?im)^-\s+\*\*status\*\*\s*[::]\s*`?([a-z]+)`?') {
            if ($Matches[1] -notin @('open', 'accepted', 'resolved')) { $missing += "status=$($Matches[1])" }
        }
        if ($missing.Count -gt 0) { $bad += "$($e.id): $($missing -join '/')" }
    }

    if ($bad.Count -gt 0) {
        Add-Result "capability-boundary" "FAIL" "$($bad.Count)/$($entries.Count) 条结构不全 — $($bad -join '; ')"
    } else {
        Add-Result "capability-boundary" "PASS" "$($entries.Count) 条边界，字段齐全且 status 合法"
    }
}

