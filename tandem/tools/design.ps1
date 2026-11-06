param(
    [Parameter(Position=0)][string]$Command='status',
    [string]$Task,[string]$Card,[ValidateSet('build','review')][string]$For='build',[string]$Review,[string]$Reason,[string]$By
)
# Design quality layer. Resolves a card's design platform ("Design: android"), prints the worker/reviewer brief that points at
# tandem/design/skills (Interfaces skills, read by path), validates a design review (round RD) and records its verdict in
# <docs>/log/design.jsonl. Always exits 0; the first output line of status/check/pass is machine-readable ("design=...").
try { [Console]::OutputEncoding = [Text.UTF8Encoding]::new($false) } catch {}
$ErrorActionPreference = 'Stop'
$utf8 = [Text.UTF8Encoding]::new($false)
$lang = 'en'
$known = @('web','android','ios','flutter','desktop','doc','ui')
$aliases = @{ 'html'='web'; 'css'='web'; 'react'='web'; 'vue'='web'; 'svelte'='web'; 'compose'='android'; 'kotlin'='android'; 'xml'='android'; 'swiftui'='ios'; 'uikit'='ios'; 'swift'='ios'; 'docs'='doc'; 'document'='doc'; 'markdown'='doc'; 'windows'='desktop'; 'macos'='desktop'; 'wpf'='desktop'; 'winui'='desktop'; 'electron'='web' }
$off = @('none','no','off','n','false','x','-','없음','아니오','해당없음')
$on = @('yes','y','on','true','auto','예','있음')
$domains = @('better-accessibility','better-layout','better-writing','better-typography','better-colors','better-ui')
function Resolve([string]$p) { if ([IO.Path]::IsPathRooted($p)) { return [IO.Path]::GetFullPath($p) }; return [IO.Path]::GetFullPath((Join-Path $root $p)) }
function Rel([string]$p) {
    $prefix = $root.TrimEnd('\','/') + '\'
    if ($p.StartsWith($prefix,[StringComparison]::OrdinalIgnoreCase)) { return $p.Substring($prefix.Length).Replace('\','/') }
    return $p.Replace('\','/')
}
function CardPath {
    if ($Card) { return (Resolve $Card) }
    if ($Task) { $guess = Join-Path $docs ("tasks/$Task.md"); if (Test-Path -LiteralPath $guess -PathType Leaf) { return $guess } }
    return ''
}
function Platforms([string]$path) {
    # Card line "디자인: android" / "Design: web, android". No line, an off word or no known platform = not a design task.
    $out = New-Object System.Collections.Generic.List[string]
    if (!$path -or !(Test-Path -LiteralPath $path -PathType Leaf)) { return $out.ToArray() }
    $text = [IO.File]::ReadAllText($path,[Text.Encoding]::UTF8)
    $match = [regex]::Match($text,'(?im)^[ \t]*(?:[-*][ \t]*)?(?:\*\*)?(?:디자인|design)(?:\*\*)?[ \t]*[:：][ \t]*(.+?)[ \t]*$')
    if (!$match.Success) { return $out.ToArray() }
    foreach ($raw in ($match.Groups[1].Value -split '[,/\s]+')) {
        $token = $raw.Trim('`','*','"',"'",'.','(',')','<','>').ToLowerInvariant()
        if (!$token) { continue }
        if ($off -contains $token) { $out.Clear(); return $out.ToArray() }
        if ($on -contains $token) { $token = if ($defaultPlatform) { $defaultPlatform } else { 'ui' } }
        if ($aliases.ContainsKey($token)) { $token = $aliases[$token] }
        if ($known -notcontains $token) { continue }
        if (!$out.Contains($token)) { $out.Add($token) }
    }
    return $out.ToArray()
}
function UiKind([string]$path) {
    $lower = $path.ToLowerInvariant()
    if ($lower -match '\.(css|scss|sass|less|styl|html|htm|vue|svelte|astro|tsx|jsx)$') { return 'web' }
    if ($lower -match '(^|/)res/(layout|values|drawable|color|font|anim|animator|menu)[^/]*/[^/]+\.xml$') { return 'android' }
    if ($lower -match '\.(storyboard|xib)$' -or $lower -match '\.xcassets/') { return 'ios' }
    if ($lower -match '\.(xaml|qml)$') { return 'desktop' }
    if ($lower -match '\.(kt|java|swift|dart)$') {
        $full = Join-Path $root $path
        if (!(Test-Path -LiteralPath $full -PathType Leaf)) { return '' }
        $text = ''
        try { if ((Get-Item -LiteralPath $full).Length -gt 1MB) { return '' }; $text = [IO.File]::ReadAllText($full,[Text.Encoding]::UTF8) } catch { return '' }
        if ($lower -match '\.(kt|java)$' -and $text -match '@Composable|androidx\.compose\.|setContentView\(|android\.widget\.|android\.view\.') { return 'android' }
        if ($lower.EndsWith('.swift') -and $text -match 'import\s+(SwiftUI|UIKit|AppKit)') { return 'ios' }
        if ($lower.EndsWith('.dart') -and $text -match 'package:flutter/') { return 'flutter' }
    }
    return ''
}
function UiFiles {
    # Uncommitted files that look like interface code. A hint for cards that carry no design line; TANDEM's own files are skipped.
    $list = New-Object System.Collections.Generic.List[object]
    $names = @()
    $old = $ErrorActionPreference; $ErrorActionPreference = 'Continue'
    try {
        Push-Location $root
        try { $names = @(& git -c core.quotepath=false status --porcelain -uall 2>$null) } finally { Pop-Location }
    } catch { $names = @() }
    $ErrorActionPreference = $old
    $docsPrefix = $docsRoot.TrimEnd('/') + '/'
    foreach ($entry in $names) {
        $line = [string]$entry
        if ($line.Length -lt 4) { continue }
        if ($line.Substring(0,2).Contains('D')) { continue }
        $path = $line.Substring(3)
        $arrow = $path.IndexOf(' -> '); if ($arrow -ge 0) { $path = $path.Substring($arrow + 4) }
        $path = $path.Trim('"').Replace('\','/')
        if ($path.StartsWith('tandem/') -or $path.StartsWith($docsPrefix) -or $path.StartsWith('.claude/') -or $path.StartsWith('.codex/') -or $path.StartsWith('.codex-last/')) { continue }
        $kind = UiKind $path
        if ($kind) { $list.Add([pscustomobject]@{ path=$path; platform=$kind }) }
    }
    return $list.ToArray()
}
function LastVerdict([string]$id) {
    $log = Join-Path $docs 'log/design.jsonl'
    $last = $null
    if (!$id -or !(Test-Path -LiteralPath $log)) { return $null }
    foreach ($line in [IO.File]::ReadLines($log,[Text.Encoding]::UTF8)) {
        if (!$line.Contains('"task"')) { continue }
        try { $r = $line | ConvertFrom-Json } catch { continue }
        if ([string]$r.task -ieq $id) { $last = $r }
    }
    return $last
}
function AppendLog($record) {
    $log = Join-Path $docs 'log/design.jsonl'
    [IO.Directory]::CreateDirectory((Split-Path $log)) | Out-Null
    [IO.File]::AppendAllText($log,($record | ConvertTo-Json -Compress -Depth 6) + "`n",$utf8)
}
function Brief([string[]]$platforms,[string]$kind) {
    $skills = 'tandem/design/skills'
    $taskId = if ($Task) { $Task } else { '<ID>' }
    $native = @($platforms | Where-Object { $_ -notin @('web','doc') })
    $lines = New-Object System.Collections.Generic.List[string]
    if (!(Test-Path -LiteralPath (Join-Path $root "$skills/better-interface/SKILL.md"))) { $lines.Add($m.noSkills) }
    $list = ($domains | ForEach-Object { "   - $skills/$_/SKILL.md" }) -join "`n"
    if ($kind -eq 'review') {
        $lines.Add(($m.reviewHead -f ($platforms -join ', ')))
        $lines.Add(($m.review1 -f $docsRoot))
        $lines.Add(($m.review2 -f $skills))
        $lines.Add($m.review3); $lines.Add($list)
        if ($native.Count) { $lines.Add(($m.native -f $docsRoot,($native -join ', '))) }
        if ($platforms -contains 'doc') { $lines.Add($m.doc) }
        $lines.Add(($m.review4 -f $docsRoot,$taskId))
        $lines.Add($m.review5)
    } else {
        $lines.Add(($m.buildHead -f ($platforms -join ', ')))
        $lines.Add(($m.build1 -f $docsRoot))
        $lines.Add($m.build2); $lines.Add($list)
        if ($native.Count) { $lines.Add(($m.native -f $docsRoot,($native -join ', '))) }
        if ($platforms -contains 'doc') { $lines.Add($m.doc) }
        $lines.Add($m.build3)
        $lines.Add(($m.build4 -f $skills,$docsRoot,$taskId))
    }
    return ($lines -join "`n")
}
try {
    $root = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..\..'))
    $config = $null
    $configPath = Join-Path $root 'tandem/config.json'
    if (Test-Path -LiteralPath $configPath) { try { $config = Get-Content -LiteralPath $configPath -Raw -Encoding UTF8 | ConvertFrom-Json } catch { $config = $null } }
    if ($config -and $config.lang -in @('ko','en')) { $lang = [string]$config.lang } elseif (!$config -and (Get-UICulture).Name -like 'ko*') { $lang = 'ko' }
    $docsRoot = if ($config -and $config.docs_root) { ([string]$config.docs_root).Replace('\','/') } else { 'docs/tandem' }
    $docs = Join-Path $root $docsRoot
    $enabled = $true; $defaultPlatform = ''
    if ($config -and $config.PSObject.Properties['design'] -and $config.design) {
        if ($config.design.PSObject.Properties['enabled'] -and $config.design.enabled -eq $false) { $enabled = $false }
        if ($config.design.PSObject.Properties['platform'] -and $config.design.platform) {
            $defaultPlatform = ([string]$config.design.platform).Trim().ToLowerInvariant()
            if ($aliases.ContainsKey($defaultPlatform)) { $defaultPlatform = $aliases[$defaultPlatform] }
            if ($known -notcontains $defaultPlatform) { $defaultPlatform = '' }
        }
    }
    $messages = @{
        ko = @{
            usage='사용법: design.ps1 status|brief|check|pass|platform -Task <ID> [-Card <카드 경로>] [-For build|review] [-Review <검수 파일>] [-Reason <한 줄>] [-By <이름>]'
            noSkills='[TANDEM] tandem/design/skills 가 없습니다. 설치 명령을 다시 실행해 스킬 사본을 배치하세요. 그때까지는 아래 문서만 따릅니다.'
            buildHead='[디자인 지시 - TANDEM] 이 과제는 사람이 보는 화면이나 문서를 만든다. 플랫폼: {0}. 아래는 카드의 완료 조건에 더해지는 필수 조건이다.'
            build1='1. 구현 전에 {0}/design.md 의 「만들 때」 절을 읽는다.'
            build2='2. 아래 스킬 파일을 이 순서로 읽고 그 규칙대로 만든다(경로는 프로젝트 루트 기준). 각 SKILL.md 가 가리키는 참고 파일은 그 주제를 다룰 때 읽는다.'
            native='   스킬 규칙은 웹(CSS·ARIA) 기준이다. {0}/design-platforms.md 의 {1} 절을 읽고 그 플랫폼의 수단으로 옮겨 적용한다. 원칙과 수치는 그대로, 구현 방법만 바꾼다.'
            doc='   문서(doc): HTML 은 웹 규칙을 그대로 적용한다. 마크다운처럼 보는 프로그램이 모양을 정하는 문서는 better-writing 과 구조(제목 위계, 표, 목록)만 적용한다.'
            build3='3. 프로젝트에 이미 있는 디자인 토큰·컴포넌트·디자인 문서가 먼저다. 새 값을 만들기 전에 있는 것을 쓴다. 취향으로 기존 결정을 뒤집지 않는다.'
            build4='4. 산출물에 「디자인」 절을 둔다: (a) 읽고 적용한 스킬, (b) {0}/better-interface/SKILL.md 의 최고 심각도 조건(Escalation triggers) 자체 점검 결과, (c) 렌더 증거(스크린샷을 {1}/reports/work/{2}-shots/ 에 저장한 경로) 또는 만들지 못한 이유. 최고 심각도 조건이 하나라도 남으면 완료가 아니다.'
            reviewHead='[디자인 검수 지시 - TANDEM] 플랫폼: {0}. 읽기 전용이다. 파일을 고치지 않는다. 일반 R2 검토의 "지적 최소 3개" 규칙은 이 검수에 적용하지 않는다.'
            review1='1. {0}/design.md 의 「검수」 절을 읽는다.'
            review2='2. {0}/better-interface/SKILL.md 와 review-format.md 를 읽고 그 절차(범위 확정, 정찰, 영역 순서 검수, 통합)를 따른다. 변경분 검수이므로 {0}/interface-review/SKILL.md 의 분류(Introduced, Regression, Pre-existing)와 "지워진 줄 읽기"를 쓴다. 검수 범위는 이 지시에 붙은 변경분 파일로 이미 정해져 있으니 범위를 새로 추측하지 않는다.'
            review3='3. 영역 스킬 6개를 이 순서로 읽고 영역마다 검수를 끝낸 뒤 통합한다.'
            review4='4. 렌더 증거가 {0}/reports/work/{1}-shots/ 또는 산출물의 「디자인」 절에 있으면 본다. 렌더를 봐야 판단되는데 증거가 없으면 지적하지 말고 needs_validation 으로 남긴다.'
            review5=@'
5. 출력 형식(전문을 마지막 메시지에 쓴다):
   - 첫 5줄 요약.
   - 범위와 커버리지 표: 영역(accessibility, layout, writing, typography, colors, ui)마다 살펴본 증거와 결과(지적 수, Clear, Not reviewed 와 이유).
   - 지적은 한 줄씩, 최대 15개, 심각도순: `- F1 [confirmed] [높음|중간|낮음] 근거=<경로:줄> | 영역=<영역> | 상태=<introduced|regression|pre-existing> | 지적=<한 줄> | 보완=<지금 -> 고칠 모양>`
     확인하지 못한 것은 `- F2 [needs_validation] 미확인=<어떤 사실> | 영역=<영역> | 지적=<한 줄>`, 기각한 후보는 `- F3 [rejected] 이유=<한 줄>`.
   - 최고 심각도 조건(Escalation triggers)에 해당하면 화면이 사소해도 항상 [높음] 이다. 취향 차이는 지적이 아니다. 지적이 없으면 지어내지 않는다.
   - 마지막 줄은 판정 한 줄: confirmed [높음] 중 상태가 introduced 또는 regression 인 것이 하나라도 있으면 `VERDICT: block`, 없으면 `VERDICT: approve`.
'@
            needArgs='-Task 와 -Review 가 필요합니다'; noReview='검수 파일이 없습니다'; noVerdict='마지막에 `VERDICT: approve` 또는 `VERDICT: block` 줄이 없습니다. 검수를 다시 받습니다'
            mismatch='검수자는 approve 라고 썼지만 confirmed [높음] 이 {0}건 있어 block 으로 판정합니다'; emptyBlock='검수자는 block 이라고 썼지만 confirmed [높음] 지적이 없습니다. 근거를 다시 받거나 총괄이 판정합니다'
            needReview='디자인 검수(RD)를 통과해야 완료로 옮길 수 있습니다. 검수 뒤 `design.ps1 check -Task <ID> -Review <검수 파일>` 로 기록합니다'
            unmarked='카드에 `디자인:` 줄이 없는데 화면 파일이 바뀌었습니다. 총괄이 카드에 `디자인: <플랫폼>` 을 적고 디자인 검수(RD)를 받습니다. 화면 과제가 아니면 `디자인: 없음` 을 적습니다'
            needPass='-Task 와 -Reason(1-200자, 큰따옴표·줄바꿈 금지)이 필요합니다'; passed='디자인 판정을 통과로 기록했습니다'
        }
        en = @{
            usage='Usage: design.ps1 status|brief|check|pass|platform -Task <ID> [-Card <card path>] [-For build|review] [-Review <review file>] [-Reason <one line>] [-By <name>]'
            noSkills='[TANDEM] tandem/design/skills is missing. Re-run the install command to place the skill copies. Until then follow only the documents below.'
            buildHead='[Design brief - TANDEM] This task makes a screen or document people look at. Platform: {0}. The items below are required in addition to the card completion checks.'
            build1='1. Before implementing, read the "When building" section of {0}/design.md.'
            build2='2. Read the skill files below in this order and build to their rules (paths are relative to the project root). Read the reference files each SKILL.md points to when you work on that topic.'
            native='   The skill rules are written for the web (CSS, ARIA). Read the {1} section of {0}/design-platforms.md and apply them with that platform''s own means. Principles and values stay; only the implementation changes.'
            doc='   Documents (doc): apply the web rules as they are to HTML. For Markdown and other documents whose viewer decides the look, apply only better-writing and structure (heading order, tables, lists).'
            build3='3. The design tokens, components and design documents the project already has come first. Use what exists before adding a value. Do not overturn an existing decision on taste.'
            build4='4. Add a "Design" section to the artifact: (a) the skills you read and applied, (b) a self-check against the Escalation triggers in {0}/better-interface/SKILL.md, (c) rendered evidence (screenshot paths under {1}/reports/work/{2}-shots/) or why none could be made. The task is not complete while any escalation trigger remains.'
            reviewHead='[Design review brief - TANDEM] Platform: {0}. Read-only: do not edit files. The "at least three findings" rule of the general R2 review does not apply to this review.'
            review1='1. Read the "Review" section of {0}/design.md.'
            review2='2. Read {0}/better-interface/SKILL.md and review-format.md and follow that procedure (resolve scope, recon, domain reviews in order, consolidate). This is a change review, so use the classification (Introduced, Regression, Pre-existing) and "read the removed lines" from {0}/interface-review/SKILL.md. The scope is already set by the changes file attached to this brief; do not guess a new one.'
            review3='3. Read the six domain skills in this order and finish each domain review before consolidating.'
            review4='4. Look at rendered evidence under {0}/reports/work/{1}-shots/ or in the artifact''s "Design" section when there is any. Where a judgement needs the rendered result and there is no evidence, do not report a finding; leave it as needs_validation.'
            review5=@'
5. Output format (write the full review in your final message):
   - A five-line summary first.
   - A scope and coverage table: for each domain (accessibility, layout, writing, typography, colors, ui) the evidence inspected and the result (finding count, Clear, or Not reviewed with the reason).
   - One line per finding, at most 15, by severity: `- F1 [confirmed] [high|medium|low] evidence=<path:line> | domain=<domain> | status=<introduced|regression|pre-existing> | finding=<one line> | fix=<now -> after>`
     What you could not verify is `- F2 [needs_validation] unknown=<which fact> | domain=<domain> | finding=<one line>`; a candidate you dismissed is `- F3 [rejected] reason=<one line>`.
   - An escalation trigger is always [high], however minor the surface. A difference of taste is not a finding. With no findings, do not invent any.
   - The last line is the verdict: `VERDICT: block` when any confirmed [high] finding has status introduced or regression, otherwise `VERDICT: approve`.
'@
            needArgs='-Task and -Review are required'; noReview='Review file not found'; noVerdict='No final `VERDICT: approve` or `VERDICT: block` line. Request the review again'
            mismatch='The reviewer wrote approve but there are {0} confirmed [high] findings, so the verdict is block'; emptyBlock='The reviewer wrote block but there is no confirmed [high] finding. Ask for the evidence again, or the lead decides'
            needReview='The design review (RD) must pass before the card can move to done. After the review, record it with `design.ps1 check -Task <ID> -Review <review file>`'
            unmarked='The card has no `Design:` line but interface files changed. The lead adds `Design: <platform>` to the card and gets a design review (RD). If this is not an interface task, write `Design: none`'
            needPass='-Task and -Reason (1-200 characters, no double quote or line break) are required'; passed='Recorded the design verdict as approve'
        }
    }
    $m = $messages[$lang]
    $Command = $Command.ToLowerInvariant()
    if ($Command -notin @('status','brief','check','pass','platform')) { Write-Output $m.usage; exit 0 }
    $cardPath = CardPath
    $platforms = @(Platforms $cardPath)

    if ($Command -eq 'platform') {
        if ($enabled -and $platforms.Count) { Write-Output ($platforms -join ',') }
        exit 0
    }
    if ($Command -eq 'brief') {
        if (!$enabled) { exit 0 }
        if (!$platforms.Count) {
            if ($For -ne 'review') { exit 0 }
            $platforms = @($(if ($defaultPlatform) { $defaultPlatform } else { 'ui' }))
        }
        Write-Output (Brief $platforms $For)
        exit 0
    }
    if ($Command -eq 'status') {
        if (!$enabled) { Write-Output 'design=off'; exit 0 }
        if ($platforms.Count) {
            $last = LastVerdict $Task
            $state = if ($last -and $last.verdict) { [string]$last.verdict } else { 'missing' }
            Write-Output "design=$($platforms -join ',') review=$state task=$Task"
            if ($state -ne 'approve') { Write-Output "- $($m.needReview)" }
            exit 0
        }
        $ui = @(UiFiles)
        if (!$ui.Count) { Write-Output 'design=none'; exit 0 }
        $guess = [string](@($ui | Group-Object platform | Sort-Object Count -Descending | Select-Object -First 1)[0].Name)
        Write-Output "design=unmarked ui_files=$($ui.Count) guess=$guess e.g.=$($ui[0].path)"
        Write-Output "- $($m.unmarked)"
        exit 0
    }
    if ($Command -eq 'pass') {
        if (!$Task -or $Reason -cnotmatch '^[^\r\n"]{1,200}$') { Write-Output "design=invalid $($m.needPass)"; exit 0 }
        $who = if ($By) { $By } else { 'lead' }
        AppendLog ([pscustomobject]@{ ts=[datetime]::Now.ToString('o'); task=$Task; verdict='approve'; declared=$null; findings=$null; review=$null; by=$who; reason=$Reason })
        Write-Output "design=approve task=$Task by=$who"
        Write-Output "- $($m.passed)"
        exit 0
    }
    # check
    if (!$Task -or !$Review) { Write-Output "design=invalid $($m.needArgs)"; exit 0 }
    $reviewPath = Resolve $Review
    if (!(Test-Path -LiteralPath $reviewPath -PathType Leaf)) {
        Write-Output "design=invalid task=$Task findings=0 confirmed=0 high=0 needs_validation=0 rejected=0"
        Write-Output "- $($m.noReview): $Review"
        exit 0
    }
    $text = [IO.File]::ReadAllText($reviewPath,[Text.Encoding]::UTF8)
    $pattern = '^\s*-?\s*(F\d+)\s*\[(confirmed|needs_validation|rejected)\]\s*(?:\[(높음|중간|낮음|high|medium|low)\])?\s*(.*)$'
    $counts = @{ confirmed=0; needs_validation=0; rejected=0 }
    $total = 0; $high = 0
    foreach ($line in ($text -split "`r?`n")) {
        $match = [regex]::Match($line,$pattern,'IgnoreCase')
        if (!$match.Success) { continue }
        $total++
        $kind = $match.Groups[2].Value.ToLowerInvariant()
        $counts[$kind]++
        $severity = $match.Groups[3].Value.ToLowerInvariant()
        $preExisting = $match.Groups[4].Value -match '(상태|status)\s*=\s*`?\s*pre-?\s*existing'
        if ($kind -eq 'confirmed' -and ($severity -eq '높음' -or $severity -eq 'high') -and !$preExisting) { $high++ }
    }
    $declared = ''
    foreach ($v in [regex]::Matches($text,'(?im)^[ \t>*`_-]*VERDICT[ \t]*[:：][ \t]*`?(approve|block)')) { $declared = $v.Groups[1].Value.ToLowerInvariant() }
    $issues = New-Object System.Collections.Generic.List[string]
    $verdict = 'invalid'
    if (!$declared) { $issues.Add("- $($m.noVerdict)") }
    elseif ($high -gt 0) { $verdict = 'block'; if ($declared -eq 'approve') { $issues.Add('- ' + ($m.mismatch -f $high)) } }
    elseif ($declared -eq 'block') { $verdict = 'block'; $issues.Add("- $($m.emptyBlock)") }
    else { $verdict = 'approve' }
    if ($total -gt 0) {
        $checker = Join-Path $PSScriptRoot 'review-check.ps1'
        if (Test-Path -LiteralPath $checker) {
            try { foreach ($extra in (@(& $checker -Review $reviewPath -MinFindings 0) | Select-Object -Skip 1)) { if ($extra) { $issues.Add([string]$extra) } } } catch {}
        }
    }
    $findings = [pscustomobject]@{ confirmed=$counts.confirmed; high=$high; needs_validation=$counts.needs_validation; rejected=$counts.rejected }
    $declaredValue = if ($declared) { $declared } else { $null }
    AppendLog ([pscustomobject]@{ ts=[datetime]::Now.ToString('o'); task=$Task; verdict=$verdict; declared=$declaredValue; findings=$findings; review=(Rel $reviewPath); by='review'; reason=$null })
    Write-Output "design=$verdict task=$Task findings=$total confirmed=$($counts.confirmed) high=$high needs_validation=$($counts.needs_validation) rejected=$($counts.rejected)"
    foreach ($issue in $issues) { Write-Output $issue }
} catch {
    Write-Output "design=invalid $($_.Exception.Message)"
}
exit 0
