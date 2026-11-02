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
        $note += "规范产物 文档 $($now.docs_files) 个/playbooks 目录 $($now.playbooks) 个文件/acceptance $($now.acceptance) 个/specs $($now.spec_files) 个"
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
        $flagChecked = 0
        $valChecked = 0
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
                # 反例（2026-11-01）：只查命令名时，`pcb route fill --no-such-flag-xyz` 也能过（实测 probe 判 PASS）。
                # 因此再查每一步的 **flag 是否真实存在**——编 flag 和自己编命令一样，都是"假装会用工具"。
                # 帮助必须取**完整命令路径**（`pcb route fill`），不能只取前两段（会拼成 `pcb fill`）。
                $cmdTokens = @()
                foreach ($tk in $parts) { if ($tk -like '-*') { break }; $cmdTokens += $tk }
                $helpKey = ($cmdTokens -join ' ')
                if (-not $helpCache.ContainsKey($helpKey)) { $helpCache[$helpKey] = (& $Cli @($cmdTokens + '--help') 2>$null | Out-String) }
                if (-not $helpCache.ContainsKey($helpKey)) { $helpCache[$helpKey] = (& $Cli @($group, $sub, '--help') 2>$null | Out-String) }
                $stepFlags = @(
                    ([regex]::Matches($run, '--[a-zA-Z][a-zA-Z0-9-]*') | ForEach-Object { $_.Value })
                    if ($st.flags) { @($st.flags.PSObject.Properties.Name) } else { @() }
                ) | Where-Object { $_ } | Select-Object -Unique
                $missFlags = @($stepFlags | Where-Object { $helpCache[$helpKey] -notmatch [regex]::Escape($_) })
                if ($missFlags.Count -gt 0) { $fail += "$($pf.Name): 步骤 run='$run' 的 flag 不存在： $($missFlags -join ',')" }
                $flagChecked += @($stepFlags).Count
                # 反例（2026-11-01）：`sch block-apply --spacing abc` 在只查 flag 名时判 PASS，但帮助里写明 `--spacing float`。
                # 因此按帮助声明的类型校验取值：数值型 flag 给了值就必须能解析成数字。
                $typeMap = @{}
                foreach ($tm in [regex]::Matches($helpCache[$helpKey], '(?m)^\s+--([a-zA-Z][a-zA-Z0-9-]*)\s+(int|float|string|strings|stringArray|bool)\b')) {
                    $typeMap[$tm.Groups[1].Value] = $tm.Groups[2].Value
                }
                if ($st.flags) {
                    foreach ($fp in $st.flags.PSObject.Properties) {
                        $fn = $fp.Name; $fv = [string]$fp.Value
                        if ($typeMap.ContainsKey($fn) -and (@('int', 'float') -contains $typeMap[$fn]) -and $fv -ne '') {
                            if ($fv -notmatch '^-?\d+(\.\d+)?$') { $fail += "$($pf.Name): 步骤 flag --$fn 在帮助里声明为 $($typeMap[$fn])，取值 '$fv' 不是数字" }
                        }
                    }
                }
                $valChecked += 1
                $stepChecked++
            }
        }
if ($fail.Count -eq 0) { $note += "playbook $stepChecked 步全部命中现有命令；$flagChecked 个 flag 全部存在；$valChecked 步做过取值类型校验" }
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
        # 反例（2026-11-01 自查）：这一项原来统计 `acceptance/` 下**所有**文件，于是把「运行产出物」也算成能力：
        # 我修 bug 前每次静态跑都写一份报告，一夜之间涨到 274 个；清理这些垃圾又被判「能力退化」。
        # 正确口径：只数**代码与测试**（.ps1/.md/fixtures），排除 acceptance/runs/ 这类运行产物。
        acceptance = @(Get-ChildItem (Join-Path $script:RepoRoot 'acceptance') -Recurse -File -ErrorAction SilentlyContinue |
            Where-Object { $_.FullName -notmatch '\\acceptance\\runs\\' }).Count
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
        if ($body -match '(?im)^-\s+\*\*status\*\*\s*[:：]\s*`?([a-z]+)`?') {
            if ($Matches[1] -notin @('open', 'accepted', 'resolved')) { $missing += "status=$($Matches[1])" }
        }
        if ($missing.Count -gt 0) { $bad += "$($e.id): $($missing -join '/')" }
    }

    if ($bad.Count -gt 0) {
        Add-Result "capability-boundary" "FAIL" "$($bad.Count)/$($entries.Count) 条结构不全 — $($bad -join '; ')"
    } else {
    # 反例（2026-11-01）：GAP-006 标题写着「已更正：能力以类型化动作存在」、GAP-032/GAP-061 各自已有「结案/续：解法」段，
    # 但原始段的 status 仍是 open —— 语义上已解决却计入待办，导致"还剩多少条"虚高。
    $inconsistent = @()
    foreach ($e in $entries) {
        $titleLine = ($e.text | Where-Object { $_ -match '^##\s+' } | Select-Object -First 1)
        $stVal = ([regex]::Match(($e.text -join "`n"), '(?m)^- \*\*status\*\*[：:]\s*`?([a-z]+)`?').Groups[1].Value)
        # 标题里的"已完成"标记也可能写在 id 之后第一行；这里用整段标题行判断
        $hdr = (Get-Content $path | Where-Object { $_ -match "^##\s+$($e.id)\s" } | Select-Object -First 1)
        if ($hdr -match '已更正|结案|解法|已解决' -and $stVal -eq 'open') {
            $inconsistent += "$($e.id)（标题称已解决，status 仍 open）"
        }
    }
    if ($inconsistent.Count -gt 0) {
        Add-Result "capability-boundary" "FAIL" "$($inconsistent.Count) 条状态与标题矛盾： $(($inconsistent -join '; '))"
        return
    }
        Add-Result "capability-boundary" "PASS" "$($entries.Count) 条边界，字段齐全且 status 合法"
    }
}


# ══════════════════════════════════════════════════════════════════════
# 可移植性：文档里不得出现本机绝对路径
#
# 为什么：这个包要能装进任意 harness、换台机器就能用。文档里若写死
# "D:\Agent-Studio\..." 或 "C:\Users\xxx"，换环境后读者会照着找不到东西，
# 或以为必须在本机构造才有意义。
# ══════════════════════════════════════════════════════════════════════
function Test-KitPortability {
    $roots = @('docs', 'playbooks', 'specs')
    $patterns = @(
        '[A-Za-z]:\\Users\\',
        'D:\\Agent-Studio',
        'C:\\Users\\',
        '/Users/[A-Za-z]',
        '/home/[A-Za-z]'
    )
    $bad = @()
    foreach ($r in $roots) {
        $p = Join-Path $script:AuditRoot $r
        if (-not (Test-Path $p)) { continue }
        foreach ($f in Get-ChildItem $p -Recurse -File -Include '*.md', '*.json' -ErrorAction SilentlyContinue) {
            foreach ($pat in $patterns) {
                if (Select-String -Path $f.FullName -Pattern $pat -Quiet -ErrorAction SilentlyContinue) {
                    $bad += $f.FullName.Replace($script:RepoRoot + '\', '')
                    break
                }
            }
        }
    }
    $skill = Join-Path $script:AuditRoot 'SKILL.md'
    if (Test-Path $skill) {
        foreach ($pat in $patterns) {
            if (Select-String -Path $skill -Pattern $pat -Quiet -ErrorAction SilentlyContinue) { $bad += 'SKILL.md'; break }
        }
    }
    if ($bad.Count -gt 0) {
        Add-Result "kit-portability" "FAIL" ("$($bad.Count) 份文档含本机绝对路径： " + (($bad | Select-Object -Unique -First 5) -join ', '))
    } else {
    # 反例（2026-11-01）：探针里只放 1 份文档且不含任何路径，本阶段报「文档无本机绝对路径」PASS——
    # 那是"没扫到路径"，不是"路径都合法"。扫到的文件太少时按 BLOCKED 处理。
    $scanned = @($roots | ForEach-Object { $pp = Join-Path $script:AuditRoot $_; if (Test-Path $pp) { Get-ChildItem $pp -Recurse -File -Include '*.md', '*.json' -ErrorAction SilentlyContinue } } | Where-Object { $_ }).Count
    if ($scanned -lt 10) {
        Add-Result "kit-portability" "BLOCKED" "只扫到 $scanned 个文件（<10），无法证明可移植性"
        return
    }
        Add-Result "kit-portability" "PASS" "文档无本机绝对路径"
    }
}

# ══════════════════════════════════════════════════════════════════════
# 装机宣称校验：标为「首选 / 已装 / 推荐」的扩展，必须真在装机清单里。
#
# 事故：决策表把 PCB Auto Router 写成"全板自动布线（首选）"，而 GUI 实测本机只装了 22 个扩展，
# 其中没有它。任何照文档执行的模型都会去拿一个不存在的工具。
# ══════════════════════════════════════════════════════════════════════
function Test-InstalledClaims {
    $listPath = Join-Path $script:AuditRoot 'docs\installed-extensions.json'
    $tablePath = Join-Path $script:AuditRoot 'docs\tool-decision-table.md'
    if (-not (Test-Path $listPath)) { Add-Result "installed-claims" "FAIL" "缺 docs/installed-extensions.json（装机清单）"; return }
    if (-not (Test-Path $tablePath)) { Add-Result "installed-claims" "BLOCKED" "决策表不存在，无法校验装机宣称"; return }
    try { $inv = Get-Content $listPath -Raw | ConvertFrom-Json } catch { Add-Result "installed-claims" "FAIL" "装机清单不是合法 JSON"; return }
    $installed = @($inv.installed)
    $rows = Get-Content $tablePath | Where-Object { $_ -match '^\|' -and $_ -notmatch '^\|\s*-+' -and $_ -notmatch '情境' }
    $bad = @()
    foreach ($r in $rows) {
        $cells = $r.Split('|')
        if ($cells.Count -lt 4) { continue }
        $situation = $cells[1].Trim()
        $tool = $cells[2].Trim().Trim('`', '*')
        $params = $cells[3].Trim()
        if ([string]::IsNullOrWhiteSpace($tool)) { continue }
        # 只在"宣称可用"的行上校验
        if ($situation -notmatch '首选|已装|推荐|默认') { continue }
        # CLI 命令与类型化动作不算扩展，跳过
        if ($tool -cmatch '^pcb\s' -or $tool -match '^[a-z][a-z0-9-]*\.[a-z0-9_.]+$') { continue }
        $isInstalled = $false
        foreach ($i in $installed) { if ($tool -like "*$i*" -or $i -like "*$tool*") { $isInstalled = $true; break } }
        if (-not $isInstalled -and $params -notmatch '未装|需现装|需先在扩展广场') {
            $bad += "$tool（$situation）"
        }
    }
    # 阶段文档里凡是写「首选 <某扩展>」的，同样必须在装机清单里
    $phaseDir = Join-Path $script:AuditRoot "docs\phases"
    if (Test-Path $phaseDir) {
        foreach ($pf in Get-ChildItem $phaseDir -File -Filter "*.md") {
            $text = Get-Content $pf.FullName -Raw
            foreach ($u in @($inv.knownUninstalled)) {
                if ($text -match ("首选[^\r\n]{0,40}" + [regex]::Escape($u))) { $bad += "$u（$($pf.Name) 首选）" }
            }
        }
    }
    if ($bad.Count -gt 0) {
        Add-Result "installed-claims" "FAIL" ("$($bad.Count) 个被判『首选/已装』但不在装机清单且未标注未装： " + (($bad | Select-Object -First 4) -join '; '))
    } else {
        Add-Result "installed-claims" "PASS" ("装机清单 $($installed.Count) 项；决策表里所有『首选/已装』宣称均与之一致")
    }
}

# ══════════════════════════════════════════════════════════════════════
# 决策表可执行率（SC-005）
#
# 「可执行答案」的机械定义（不靠人读）：
#   1) 有工具名；2) 参数列 ≥10 字符（说明怎么用，不是空话）；
#   3) 若参数里标了「未装」，必须同时给出替代（替代/改用/命令 之一），否则等于没答案。
# 要求比例 ≥ 90%。
# ══════════════════════════════════════════════════════════════════════
function Test-DecisionActionability {
    $tablePath = Join-Path $script:AuditRoot 'docs\tool-decision-table.md'
    if (-not (Test-Path $tablePath)) { Add-Result "decision-actionability" "BLOCKED" "决策表不存在"; return }
    $rows = @(Get-Content $tablePath | Where-Object { $_ -match '^\|' -and $_ -notmatch '^\|\s*-+' -and $_ -notmatch '情境' })
    if ($rows.Count -lt 20) { Add-Result "decision-actionability" "FAIL" "只有 $($rows.Count) 行，样本不足 20"; return }
    $bad = @()
    foreach ($r in $rows) {
        $cells = $r.Split('|')
        if ($cells.Count -lt 4) { $bad += '列数不足'; continue }
        $situation = $cells[1].Trim(); $tool = $cells[2].Trim(); $params = $cells[3].Trim()
        if ([string]::IsNullOrWhiteSpace($tool) -or $tool -eq '-') { $bad += "$situation（无工具）"; continue }
        if ($params.Length -lt 10) { $bad += "$situation（参数过短）"; continue }
        # 反例（2026-10-31 外部审计 A1）：旧判据只量长度 ≥10 字符，于是 30 行纯散文参数也能拿到 100%。
        # 参数列必须含**至少一个具体物**：flag / 反引号命令 / 数值+单位 / 文件名 / JSON 载荷，否则不算可执行。
        $concrete = ($params -match '--[a-zA-Z]') -or ($params -match '`[^`]+`') -or
                    ($params -match '\d+(\.\d+)?\s*(mil|mm|um|nm|V|A|W|%|kHz|MHz|s|ms|dB)') -or
                    ($params -match '\.[a-z]{2,5}\b') -or ($params -match '\{[^}]*\}')
        # 判据细分（2026-11-01）：扩展类工具**没有 CLI flag**，硬要求 flag 会逼人编造参数。
        # 因此"具体物"分两类：① CLI/动作类物证（flag/命令/数值单位/文件/JSON）；
        # ② 可核对的**界面入口**（含 → 或 菜单/面板/对话框/右键），且工具列必须是**已装扩展**。
        # 纯散文（既无物证、也无入口）仍然判不合格——这一条不变。
        $uiEntry = ($params -match '→|菜单|面板|对话框|右键|工具栏|弹窗')
        $isInstalledExt = $false
        try {
            $iePath = Join-Path $script:AuditRoot 'docs\installed-extensions.json'
            if (Test-Path $iePath) {
                $ie = Get-Content $iePath -Raw | ConvertFrom-Json
                $isInstalledExt = @($ie.installed | Where-Object { $tool -and ($tool -like "*$_*") }).Count -gt 0
            }
        } catch { $isInstalledExt = $false }
        if (-not $concrete -and -not ($uiEntry -and $isInstalledExt)) { $bad += "$situation（参数无具体物、也无可用界面入口）"; continue }
        if ($params -match '未装' -and $params -notmatch '替代|改用|命令|pcb ') { $bad += "$situation（标未装但无替代）"; continue }
    }
    $total = $rows.Count
    $ok = $total - $bad.Count
    $ratio = [math]::Round(100.0 * $ok / $total, 1)
    if ($ratio -ge 90.0) {
        Add-Result "decision-actionability" "PASS" ("可执行 $ok/$total = $ratio%（SC-005 要求 ≥90%）")
    } else {
        Add-Result "decision-actionability" "FAIL" ("可执行 $ok/$total = $ratio%（<90%）；问题行示例： " + (($bad | Select-Object -First 3) -join '; '))
    }
}





# ── 阶段：证据新鲜度（已知作废的数字不得无标注出现）────────────────────────
function Test-EvidenceFreshness {
    # 反例（2026-11-01）：HANDOVER 与 executor-crosscheck 长期写「selftest 36 PASS」「99.1%」「107 行」，
    # 而真实值是 38 / 16.2% / 111 行——数字靠记性维护必然过期，且过期时没人报错。
    # 这里机械检查：**已被取代的取值**不得在正文里无标注出现；带「当时/历史/旧口径/此前/作废」的行豁免。
    # 2026-11-01 扩面：原来只扫 4 份，其余 20+ 份文档里的作废数字无人看。现在扫 docs 下全部 .md + 根 README。
    # 2026-11-01 扩面 2：specs 下的 spec/plan/quickstart 等"照做"文档同样会过期（quickstart 曾长期写 8 PASS）；
    $docs = @('README.md') + @(Get-ChildItem (Join-Path $script:AuditRoot 'docs') -Recurse -File -Filter '*.md' -ErrorAction SilentlyContinue |
        ForEach-Object { $_.FullName.Substring($script:AuditRoot.Length).TrimStart('\') })
    # tasks.md 与 progress-log 一样是只增不改的历史，豁免。
    $specDir = Join-Path $script:AuditRoot 'specs'
    if (Test-Path $specDir) {
        $docs += @(Get-ChildItem $specDir -Recurse -File -Filter '*.md' -ErrorAction SilentlyContinue |
            Where-Object { $_.Name -ne 'tasks.md' } |
            ForEach-Object { $_.FullName.Substring($script:AuditRoot.Length).TrimStart('\') })
    }
    $stale = @{
        'selftest 36 PASS' = '现为 38'
        '36 PASS / 0 FAIL' = '现为 38 PASS / 0 FAIL'
        '99.1%'            = '现为 16.2%（可执行率口径已收紧）'
        '106/107'          = '现为 110/111 计数 / 18 可执行'
        '107 行'           = '现为 111 行'
        '2 PASS / 1 FAIL / 8 BLOCKED' = '现为 10 PASS / 1 FAIL / 1 BLOCKED'
        '16 PASS / 0 FAIL / 0 BLOCKED' = '现为 18 PASS / 1 FAIL / 0 BLOCKED（22 阶段）'
    }
    $exempt = '当时|历史|旧口径|此前|作废|口径更正'
    $hits = @()
    foreach ($rel in $docs) {
        if ($rel -match 'progress-log\.md$') { continue }   # 历史日志只增不改，整份豁免
        $p = Join-Path $script:AuditRoot $rel
        if (-not (Test-Path $p)) { continue }
        $ln = 0
        foreach ($line in (Get-Content $p)) {
            $ln++
            if ($line -match $exempt) { continue }
            foreach ($k in $stale.Keys) {
                if ($line.Contains($k)) { $hits += "${rel}:${ln} 出现已作废的「$k」（$($stale[$k])）" }
            }
        }
    }
    if ($hits.Count -eq 0) {
    # 反例（2026-11-01）：空审计根下只扫到 **1 份**文档却判 PASS —— "没发现问题"被当成"没有问题"。
    # 文档数太少时无法证明新鲜，按 BLOCKED 处理（缺前置证据，不是通过）。
    if ($docs.Count -lt 10) {
        Add-Result "evidence-freshness" "BLOCKED" "审计根下只有 $($docs.Count) 份文档（<10），无法证明证据新鲜"
        return
    }
        Add-Result "evidence-freshness" "PASS" "全部文档（$($docs.Count) 份，含 docs 子树；历史日志整份豁免）未出现未标注的作废数字（检查 $(($stale.Keys).Count) 类模式）"
    } else {
        Add-Result "evidence-freshness" "FAIL" "$($hits.Count) 处过期数字： $(($hits | Select-Object -First 3) -join '; ')"
    }
}


# ── 阶段：能力声明与实测一致（HANDOVER 的 claims 块）────────────────────────
function Test-ClaimsMatch {
    # 反例（2026-11-01）：HANDOVER 写「三块板全绿」「19 阶段」这类**文字承诺**，没有任何门禁核对，
    # 于是它随我每轮改动慢慢变歪（数字层已被 evidence-freshness 看住，文字层没人看）。
    # 做法：HANDOVER 里放一行 `<!-- claims: stages=N; boundaries=N; ... -->`，本阶段用**同一轮的数据**核对。
    $hp = Join-Path $script:AuditRoot 'docs\HANDOVER.md'
    if (-not (Test-Path $hp)) { Add-Result "claims-match" "FAIL" "HANDOVER.md 不存在"; return }
    $text = Get-Content $hp -Raw
    $m = [regex]::Match($text, '<!--\s*claims:(.*?)-->')
    if (-not $m.Success) { Add-Result "claims-match" "FAIL" "HANDOVER 里没有 claims 块（无法核对能力声明）"; return }
    $claims = @{}
    foreach ($pair in ($m.Groups[1].Value -split ';')) {
        $kv = $pair.Trim() -split '=', 2
        if ($kv.Count -eq 2) { $claims[$kv[0].Trim()] = $kv[1].Trim() }
    }
    # 实测值：全部在本轮内可算，不递归
    $runPs1 = Join-Path $script:RepoRoot 'acceptance\run.ps1'
    $live = @{}
    $live['stages'] = @(Select-String -Path $runPs1 -Pattern '^\s*Test-[A-Za-z]+\s*$').Count
    $bd = Get-Content (Join-Path $script:AuditRoot 'docs\capability-boundary.md') -Raw
    $live['boundaries'] = ([regex]::Matches($bd, '(?m)^##\s+GAP-\d+')).Count
    $tbl = Join-Path $script:AuditRoot 'docs\tool-decision-table.md'
    $rows = @(Get-Content $tbl | Where-Object { $_ -match '^\|' -and $_ -notmatch '^\|\s*-+' -and $_ -notmatch '情境' })
    $live['decision_rows'] = $rows.Count
    $ie = @((Get-Content (Join-Path $script:AuditRoot 'docs\installed-extensions.json') -Raw | ConvertFrom-Json).installed)
    $act = 0
    foreach ($r in $rows) {
        $cells = $r.Split('|'); if ($cells.Count -lt 4) { continue }
        $tool = $cells[2].Trim(); $params = $cells[3].Trim()
        $concrete = ($params -match '--[a-zA-Z]') -or ($params -match '`[^`]+`') -or ($params -match '\{[^}]*\}')
        $ui = ($params -match '→|菜单|面板|对话框|右键|工具栏|弹窗')
        $inst = @($ie | Where-Object { $tool -like "*$_*" -or $_ -like "*$tool*" }).Count -gt 0
        $bad = ($params -match '未装') -and ($params -notmatch '替代|改用|命令|pcb ')
        if (($concrete -or ($ui -and $inst)) -and -not $bad) { $act++ }
    }
    $live['decision_actionable'] = $act
    $pbSteps = 0
    foreach ($pf in (Get-ChildItem (Join-Path $script:AuditRoot 'playbooks') -File -Filter '*.playbook.json' -ErrorAction SilentlyContinue)) {
        try { $pj = Get-Content $pf.FullName -Raw | ConvertFrom-Json; $pbSteps += @($pj.steps).Count } catch { }
    }
    $live['playbook_steps'] = $pbSteps
    # selftest 项数：静态数 `Assert-Case`，不递归执行 selftest
    $stPath = Join-Path $script:RepoRoot 'acceptance\selftest.ps1'
    $live['selftest_cases'] = @(Get-Content $stPath | Where-Object { $_ -match '^\s*Assert-Case\s' }).Count
    # 棘轮（2026-11-01）：上面的 claims 只判"相等"，删掉内容再同步改声明仍能换绿；这里加**只增不减**的地板。
    # 反例：把边界从 70 删到 1、claims 也改成 1 —— 声明自洽但能力缩水，必须 FAIL。
    $floorPath = Join-Path $script:RepoRoot 'acceptance\baseline.json'
    $floorFail = @()
    if (Test-Path $floorPath) {
        $floor = Get-Content $floorPath -Raw | ConvertFrom-Json
        foreach ($fk in @('stages', 'boundaries', 'decision_rows', 'playbook_steps', 'selftest_cases', 'decision_actionable')) {
            if ($null -ne $floor.$fk -and $live.ContainsKey($fk)) {
                if ([int]$live[$fk] -lt [int]$floor.$fk) { $floorFail += "$fk 从 $($floor.$fk) 降到 $($live[$fk])" }
            }
        }
    }
    $mismatch = @()
    foreach ($k in $claims.Keys) {
        if (-not $live.ContainsKey($k)) { $mismatch += "$k 是未知字段"; continue }
        if ([string]$claims[$k] -ne [string]$live[$k]) { $mismatch += "$k 声明 $($claims[$k]) ≠ 实测 $($live[$k])" }
    }
    if ($floorFail.Count -gt 0) { $mismatch += ("棘轮： " + ($floorFail -join " / ")) }
    if ($mismatch.Count -eq 0) {
        Add-Result "claims-match" "PASS" ("HANDOVER 的 $($claims.Count) 项能力声明与实测一致：" + (($claims.Keys | Sort-Object | ForEach-Object { "$_=$($live[$_])" }) -join ', '))
    } else {
        Add-Result "claims-match" "FAIL" ("$($mismatch.Count) 项不一致： " + (($mismatch | Select-Object -First 3) -join '; '))
    }
}





# ── 阶段：报告目录卫生（探针产物必须为 0，真实运行份数不得低于板数）─────────
function Test-ReportHygiene {
    # 反例（2026-11-01）：`acceptance/runs/` 曾被自测探针塞进 129 份垃圾报告，**没有任何阶段报警**——
    # 我是靠"主动去数"才发现的。这里把它机械化：探针产物（executor=unspecified 且 blocked>0）必须为 0；
    # 真实运行（具名 executor 且 blocked=0）份数不得低于板数 5。
    $dir = Join-Path $script:AuditRoot 'acceptance\runs'
    if (-not (Test-Path $dir)) { Add-Result "report-hygiene" "BLOCKED" "acceptance/runs 不存在（尚无运行报告）"; return }
    $junk = @(); $real = @()
    foreach ($r in (Get-ChildItem $dir -File -Filter '*.json' -ErrorAction SilentlyContinue)) {
        try {
            $j = Get-Content $r.FullName -Raw | ConvertFrom-Json
            $blk = @($j.stages | Where-Object { $_.status -eq 'BLOCKED' }).Count
            if ([string]$j.executor -eq 'unspecified' -and $blk -gt 0) { $junk += $r.Name }
            elseif (-not [string]::IsNullOrWhiteSpace([string]$j.executor) -and $blk -eq 0) { $real += $r.Name }
        } catch { $junk += "$($r.Name)（无法解析）" }
    }
    # 阶段集一致性（2026-11-01）：旧报告（阶段数 ≠ 当前）**不算当前证据**——否则"报告入库"会永远靠旧账过关。
    $curStages = @(Select-String -Path (Join-Path $script:RepoRoot 'acceptance\run.ps1') -Pattern '^\s*Test-[A-Za-z]+\s*$').Count
    $fresh = @(); $stale = @()
    foreach ($name in $real) {
        try {
            $j = Get-Content (Join-Path $dir $name) -Raw | ConvertFrom-Json
            if (@($j.stages).Count -eq $curStages) { $fresh += $name } else { $stale += $name }
        } catch { $stale += $name }
    }
    if ($junk.Count -gt 0) {
        Add-Result "report-hygiene" "FAIL" ("探针产物 $($junk.Count) 份： " + (($junk | Select-Object -First 3) -join ', '))
        return
    }
    if ($fresh.Count -ge 5) {
        Add-Result "report-hygiene" "PASS" "探针产物 0；与当前 $curStages 阶段一致的真实运行 $($fresh.Count) 份（旧阶段集 $($stale.Count) 份，仅作历史）"
    } elseif ($fresh.Count -gt 0) {
        Add-Result "report-hygiene" "FAIL" "与当前 $curStages 阶段一致的真实运行仅 $($fresh.Count) 份 < 板数 5（旧阶段集 $($stale.Count) 份）"
    } else {
        Add-Result "report-hygiene" "BLOCKED" "没有任何与当前 $curStages 阶段一致的真实运行（$($stale.Count) 份都是旧阶段集）——需重跑板子，当前无窗口"
    }
}









