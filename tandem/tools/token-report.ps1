param([int]$Days=7,[string]$Out,[string]$ProjectRoot,[string]$DocsRoot)
$ErrorActionPreference = 'Stop'
$watch = [Diagnostics.Stopwatch]::StartNew()
function NumberIn([string]$s,[string]$name) {
    $m = [regex]::Match($s,'"'+[regex]::Escape($name)+'"\s*:\s*(\d+)')
    if ($m.Success) { return [long]$m.Groups[1].Value }; return [long]0
}
function FieldIn([string]$s,[string]$name) {
    $m = [regex]::Match($s,'"'+[regex]::Escape($name)+'"\s*:\s*"([^"\\]*(?:\\.[^"\\]*)*)"')
    if ($m.Success) { return $m.Groups[1].Value }; return ''
}
function OpenLines([string]$path) {
    $stream=[IO.FileStream]::new($path,[IO.FileMode]::Open,[IO.FileAccess]::Read,[IO.FileShare]::ReadWrite)
    return [IO.StreamReader]::new($stream,[Text.Encoding]::UTF8)
}
function SessionCwd([string]$line) {
    # The session metadata can contain another "cwd" inside base_instructions.
    $head=$line.Substring(0,[Math]::Min(16384,$line.Length))
    $m=[regex]::Match($head,'"payload"\s*:\s*\{[^{}]*?"cwd"\s*:\s*("(?:[^"\\]|\\.)*")')
    if (!$m.Success) { return '' }
    return (('{"cwd":'+$m.Groups[1].Value+'}') | ConvertFrom-Json).cwd
}
function AddGroup([string]$key,[long]$inTokens,[long]$write,[long]$read,[long]$output) {
    if (!$groups.ContainsKey($key)) { $groups[$key]=@{requests=0;input=[long]0;write=[long]0;read=[long]0;output=[long]0;equivalent=[double]0} }
    $g=$groups[$key]; $g.requests++; $g.input+=$inTokens; $g.write+=$write; $g.read+=$read; $g.output+=$output
    $g.equivalent += $inTokens + 1.25*$write + 0.1*$read + 5*$output
}
function LocalMessage([string]$ko,[string]$en) { if ($lang -eq 'ko') { return $ko }; return $en }
function TableCell($value) { return ([string]$value).Replace('|','\|').Replace("`r",' ').Replace("`n",' ') }
try {
    $root=if ($ProjectRoot) {[IO.Path]::GetFullPath($ProjectRoot)} else {[IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..\..'))}
    $configPath=Join-Path $root 'tandem/config.json'
    $localConfigPath=Join-Path ([IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..\..'))) 'tandem/config.json'
    $config=if (Test-Path $configPath) {Get-Content $configPath -Raw -Encoding UTF8 | ConvertFrom-Json} elseif (Test-Path $localConfigPath) {Get-Content $localConfigPath -Raw -Encoding UTF8 | ConvertFrom-Json} else {[pscustomobject]@{docs_root='docs/tandem';lang=$(if ((Get-UICulture).Name -like 'ko*') {'ko'} else {'en'});mode='claude-main'}}
    $models=$config.models
    $codexTop=if ($models) {[string]$models.codex_top} else {''}
    $claudeTop=if ($models) {[string]$models.claude_top} else {''}
    $project=[IO.Path]::GetFullPath($root).TrimEnd('\')
    $docs=Join-Path $root $(if ($DocsRoot) {$DocsRoot} else {$config.docs_root})
    if (!$Out) { $Out=Join-Path $docs ('reports/usage/usage-'+(Get-Date -Format yyyyMMdd)+'.md') }
    $since=(Get-Date).AddDays(-$Days)
    $lang=if ($config.lang -eq 'en') {'en'} else {'ko'}
    $groups=@{}; $mainContexts=[Collections.Generic.List[double]]::new(); $subRequests=[Collections.Generic.List[int]]::new()
    $claudeStarts=[Collections.Generic.List[long]]::new(); $mainRequests=[Collections.Generic.List[int]]::new()
    $claudeSessions=0; $subCount=0; $topClaudeRequests=0; $nonTandem=[double]0; $allClaude=[double]0
    $encoded=[regex]::Replace($project,'[^A-Za-z0-9]','-')
    $claudeRoot=[IO.Path]::GetFullPath((Join-Path $env:USERPROFILE ('.claude/projects/'+$encoded)))
    if (Test-Path $claudeRoot) {
        $files=Get-ChildItem $claudeRoot -Filter '*.jsonl' -File -Recurse | Where-Object { $_.LastWriteTime -ge $since -and ($_.DirectoryName -eq $claudeRoot -or $_.Name -like 'agent-*.jsonl') }
        foreach ($file in $files) {
            $sub=$file.Name -like 'agent-*.jsonl'; $role=if ($sub) {'sub'} else {'main'}
            if ($sub) {
                $subCount++; $meta=$file.FullName -replace '\.jsonl$','.meta.json'
                if (Test-Path $meta) { try { $role=(Get-Content $meta -Raw -Encoding UTF8 | ConvertFrom-Json).agentType } catch {} }
            } else { $claudeSessions++ }
            $ids=[Collections.Generic.HashSet[string]]::new(); $requests=0
            $reader=$null
            try {
                $reader=OpenLines $file.FullName
                while ($null -ne ($line=$reader.ReadLine())) {
                    if (!$line.Contains('"type":"assistant"') -or !$line.Contains('"usage"')) { continue }
                    $id=FieldIn $line 'id'; if (!$id -or !$ids.Add($id)) { continue }
                    $usageAt=$line.IndexOf('"usage":'); if ($usageAt -lt 0) { continue }
                    $tail=$line.Substring($usageAt,[Math]::Min(700,$line.Length-$usageAt))
                    $inTokens=NumberIn $tail 'input_tokens'; $write=NumberIn $tail 'cache_creation_input_tokens'
                    $read=NumberIn $tail 'cache_read_input_tokens'; $output=NumberIn $tail 'output_tokens'
                    $model=FieldIn $line 'model'; if (!$model) { $model='unknown' }
                    AddGroup "$role|$model" $inTokens $write $read $output
                    if ($sub -and $role -ne 'main' -and $claudeTop -and $model -eq $claudeTop) { $topClaudeRequests++ }
                    $eq=$inTokens+1.25*$write+0.1*$read+5*$output; $allClaude+=$eq
                    if ($sub -and $role -notmatch '(?i)tandem|general-purpose|explore') { $nonTandem+=$eq }
                    if (!$sub) {
                        $context=$inTokens+$write+$read
                        $mainContexts.Add($context)
                        if ($requests -eq 0) { $claudeStarts.Add($context) }
                    }
                    $requests++
                }
            } catch { Write-Warning (LocalMessage "Claude 파일을 읽지 못했습니다: $($file.Name)" "Could not read Claude file: $($file.Name)") }
            finally { if ($reader) { $reader.Dispose() } }
            if ($sub) { $subRequests.Add($requests) } else { $mainRequests.Add($requests) }
        }
    }
    $codexRoot=Join-Path $env:USERPROFILE '.codex/sessions'
    $codexSessions=0; $topCodexSessions=0; $codexUnreadable=0; $turns=[long]0; $toolBytes=[long]0; $modelDist=@{}; $effortDist=@{}; $topInput=[long]0; $allCodexInput=[long]0
    $codexStarts=[Collections.Generic.List[long]]::new(); $codexTurnCounts=[Collections.Generic.List[int]]::new()
    if (Test-Path $codexRoot) {
        $dates=0..$Days | ForEach-Object { (Get-Date).AddDays(-$_).ToString('yyyy/MM/dd',[Globalization.CultureInfo]::InvariantCulture) }
        foreach ($date in $dates) {
            $folder=Join-Path $codexRoot $date
            if (!(Test-Path $folder)) { continue }
            foreach ($file in (Get-ChildItem $folder -Filter 'rollout-*.jsonl' -File -ErrorAction SilentlyContinue)) {
                $belongs=$false; $model='unknown'; $effort='unknown'; $lastUsage=$null; $sessionTurns=0; $sessionBytes=[long]0; $firstTokenCount=$false
                $reader=$null
                try {
                    $reader=OpenLines $file.FullName
                    $line=$reader.ReadLine()
                    if (!$line -or !$line.Contains('"session_meta"')) { continue }
                    $cwd=SessionCwd $line
                    $cwd=$cwd.Replace('/','\').TrimEnd('\')
                    if ($cwd -ine $project) { continue }
                    $belongs=$true
                    while ($null -ne ($line=$reader.ReadLine())) {
                        if (!$belongs) { continue }
                        if ($line.Contains('"turn_context"') -and $model -eq 'unknown') {
                            $model=FieldIn $line 'model'; $effort=FieldIn $line 'effort'
                            if (!$effort) { $effort=FieldIn $line 'model_effort' }
                        }
                        if (!$firstTokenCount -and $line.Contains('"token_count"') -and $line.Contains('"input_tokens"')) {
                            $firstTokenCount=$true
                            $startMatch=[regex]::Match($line,'"last_token_usage"\s*:\s*\{')
                            $startAt=if ($startMatch.Success) { $startMatch.Index } else { $line.IndexOf('"total_token_usage"') }
                            if ($startAt -ge 0) { $codexStarts.Add((NumberIn $line.Substring($startAt,[Math]::Min(350,$line.Length-$startAt)) 'input_tokens')) }
                        }
                        if ($line.Contains('"token_count"') -and $line.Contains('"total_token_usage"')) {
                            $sessionTurns++; $at=$line.IndexOf('"total_token_usage"')
                            $lastUsage=$line.Substring($at,[Math]::Min(350,$line.Length-$at))
                        }
                        if ($line.Contains('"function_call_output"') -or $line.Contains('"custom_tool_call_output"')) { $sessionBytes += [Text.Encoding]::UTF8.GetByteCount($line) }
                    }
                } catch { $codexUnreadable++; continue }
                finally { if ($reader) { $reader.Dispose() } }
                if (!$belongs) { continue }
                $codexSessions++; $turns+=$sessionTurns; $toolBytes+=$sessionBytes; $codexTurnCounts.Add($sessionTurns)
                $isTopCodex=if ($codexTop) {$model -eq $codexTop} else {$model -match 'astra|top'}
                if ($isTopCodex) { $topCodexSessions++ }
                if (!$modelDist.ContainsKey($model)) { $modelDist[$model]=0 }; $modelDist[$model]++
                if (!$effortDist.ContainsKey($effort)) { $effortDist[$effort]=0 }; $effortDist[$effort]++
                if ($lastUsage) {
                    $inTokens=NumberIn $lastUsage 'input_tokens'; $cached=NumberIn $lastUsage 'cached_input_tokens'; $output=NumberIn $lastUsage 'output_tokens'
                    $allCodexInput+=$inTokens; if ($isTopCodex) { $topInput+=$inTokens }
                    $key="codex|$model|$effort"
                    if (!$groups.ContainsKey($key)) { $groups[$key]=@{requests=0;input=[long]0;write=[long]0;read=[long]0;output=[long]0;equivalent=[double]0} }
                    $g=$groups[$key]; $g.requests+=$sessionTurns; $g.input+=$inTokens; $g.read+=$cached; $g.output+=$output
                    $g.equivalent+=($inTokens-$cached+0.1*$cached+4*$output)
                }
            }
        }
    }
    $runPath=Join-Path $docs 'log/runs.jsonl'; if (!(Test-Path $runPath)) { $runPath=Join-Path $docs 'runs.jsonl' }; $runs=0; $runsWithoutReason=0
    $topRuns=[Collections.Generic.List[object]]::new()
    if (Test-Path $runPath) { foreach ($line in [IO.File]::ReadLines($runPath)) { if ($line.Contains('"ts"')) { try { $run=$line | ConvertFrom-Json; if ($run.ts -and [datetime]$run.ts -ge $since) {
        $runs++
        if (($codexTop -and $run.model -eq $codexTop) -or ($claudeTop -and $run.model -eq $claudeTop)) {
            $topRuns.Add($run)
            if (!$run.escalated_from -and $run.decided_by -ne 'human') { $runsWithoutReason++ }
        }
    } } catch {} } } }
    $avgContext=if ($mainContexts.Count) { [math]::Round(($mainContexts | Measure-Object -Average).Average) } else { 0 }
    $avgSub=if ($subRequests.Count) { [math]::Round(($subRequests | Measure-Object -Average).Average,1) } else { 0 }
    $avgTurns=if ($codexSessions) { [math]::Round($turns/$codexSessions,1) } else { 0 }
    $avgBytes=if ($codexSessions) { [math]::Round($toolBytes/$codexSessions/1024) } else { 0 }
    $avgClaudeStart=if ($claudeStarts.Count) { [math]::Round(($claudeStarts | Measure-Object -Average).Average) } else { 0 }
    $maxClaudeStart=if ($claudeStarts.Count) { ($claudeStarts | Measure-Object -Maximum).Maximum } else { 0 }
    $avgCodexStart=if ($codexStarts.Count) { [math]::Round(($codexStarts | Measure-Object -Average).Average) } else { 0 }
    $maxCodexStart=if ($codexStarts.Count) { ($codexStarts | Measure-Object -Maximum).Maximum } else { 0 }
    $avgMainRequests=if ($mainRequests.Count) { [math]::Round(($mainRequests | Measure-Object -Average).Average,1) } else { 0 }
    $maxMainRequests=if ($mainRequests.Count) { ($mainRequests | Measure-Object -Maximum).Maximum } else { 0 }
    $maxCodexTurns=if ($codexTurnCounts.Count) { ($codexTurnCounts | Measure-Object -Maximum).Maximum } else { 0 }
    $diagnosis=[Collections.Generic.List[string]]::new()
    if ($avgContext -gt 150000) { $diagnosis.Add($(if ($lang -eq 'ko') {'메인 맥락 과다: 무관한 작업은 새 세션 또는 /clear, 같은 작업은 이어서 진행하고 인계 문서를 작성하세요.'} else {'Main context high: start unrelated work in a new session or /clear; write a handoff before switching.'})) }
    if ($allClaude -and $nonTandem/$allClaude -gt .3 -and $config.mode -in @('claude-main','codex-main')) { $diagnosis.Add((LocalMessage 'TANDEM 외 Claude 서브에이전트가 환산 토큰의 30%를 넘습니다. 실무를 Codex에 위임하세요.' 'Non-TANDEM Claude subagents exceed 30%; delegate implementation to Codex.')) }
    if ($avgSub -gt 15) { $diagnosis.Add((LocalMessage '서브 호출당 요청이 15회를 넘습니다. 폴링을 확인하고 codex-run.ps1 -Wait를 사용하세요.' 'Subagent requests exceed 15 per call; check polling and use codex-run.ps1 -Wait.')) }
    if ($allCodexInput -and $topInput/$allCodexInput -gt .5) { $diagnosis.Add((LocalMessage 'Codex 최상위 모델 입력 비중이 50%를 넘습니다. model-routing.md의 하위 단계 배치를 검토하세요.' 'Top Codex model exceeds 50% of input; review model-routing.md for a lower tier.')) }
    $high=0; foreach ($key in $effortDist.Keys) { if ($key -match 'high|xhigh|max|ultra') { $high+=$effortDist[$key] } }
    if ($codexSessions -and $high/$codexSessions -gt .7) { $diagnosis.Add((LocalMessage 'Codex high 이상 강도가 70%를 넘습니다. model-routing.md를 검토하세요.' 'High Codex effort exceeds 70%; review model-routing.md.')) }
    if ($avgTurns -gt 60 -or $avgBytes -gt 300) { $diagnosis.Add((LocalMessage 'Codex 세션이 큽니다. 카드 범위를 좁히고 먼저 검색한 뒤 긴 로그를 요약하세요.' 'Codex session is large; narrow the card, search first, and summarize long logs.')) }
    if ($codexSessions -gt $runs) { $diagnosis.Add((LocalMessage 'Codex 세션이 runs.jsonl 기록보다 많습니다. 기록 누락이나 중복 실행을 확인하세요.' 'Codex sessions exceed runs.jsonl entries; inspect unlogged or duplicate runs.')) }
    if ($codexUnreadable) { $diagnosis.Add((LocalMessage "Codex 세션 파일 $codexUnreadable 개를 읽지 못해 Codex 집계가 불완전합니다." "Could not read $codexUnreadable Codex session files; Codex totals are incomplete.")) }
    $globalConfig=Join-Path $env:USERPROFILE '.codex/config.toml'
    if ((Test-Path $globalConfig) -and ((Get-Content $globalConfig -Raw) -match '(?m)^service_tier\s*=\s*["''](fast|priority)')) { $diagnosis.Add((LocalMessage '전역 Codex Fast/Priority 계열이 감지됐습니다. 한도 영향을 확인하세요.' 'Global Codex Fast/Priority tier detected; check quota impact.')) }
    $settings=Join-Path $root '.claude/settings.json'
    if ((Test-Path $settings) -and ((Get-Content $settings -Raw) -match 'CLAUDE_CODE_SUBAGENT_MODEL["'']?\s*:\s*["'']inherit')) { $diagnosis.Add((LocalMessage 'Claude 서브에이전트가 메인 모델을 상속합니다. 하위 모델을 명시하세요.' 'Claude subagent model inherits the main model; choose an explicit lower model.')) }
    $lines=[Collections.Generic.List[string]]::new()
    $lines.Add((LocalMessage '# TANDEM 토큰 보고서' '# TANDEM token report'))
    $lines.Add((LocalMessage "기간: $Days 일. 환산 토큰은 상대 비교용 추정치입니다." "Period: $Days days. Equivalent tokens are relative comparison estimates."))
    $lines.Add((LocalMessage "Claude 메인 세션: $claudeSessions; 하위 에이전트: $subCount; 메인 요청당 평균 맥락: $avgContext; 하위 호출당 평균 요청: $avgSub" "Claude main sessions: $claudeSessions; subagents: $subCount; average main context/request: $avgContext; average subagent requests/call: $avgSub"))
    $lines.Add((LocalMessage "Codex 세션: $codexSessions; 읽기 실패: $codexUnreadable; 세션당 턴: $avgTurns; 세션당 도구 출력(KB): $avgBytes; runs.jsonl: $runs" "Codex sessions: $codexSessions; unreadable: $codexUnreadable; turns/session: $avgTurns; tool output KB/session: $avgBytes; runs.jsonl: $runs"))
    $lines.Add((LocalMessage "최상위 모델 서브 사용: Codex 세션 $topCodexSessions, Claude 서브 요청 $topClaudeRequests, 사유 없는 실행 $runsWithoutReason" "Top-model subagent use: Codex sessions $topCodexSessions, Claude subagent requests $topClaudeRequests, runs without reason $runsWithoutReason"))
    $lines.Add((LocalMessage "세션 시작 비용(첫 요청 맥락): Claude 평균 $avgClaudeStart / 최대 $maxClaudeStart, Codex 평균 $avgCodexStart / 최대 $maxCodexStart" "Session start cost (first request context): Claude average $avgClaudeStart / maximum $maxClaudeStart, Codex average $avgCodexStart / maximum $maxCodexStart"))
    $lines.Add((LocalMessage "세션 길이(요청 수): Claude 평균 $avgMainRequests / 최대 $maxMainRequests, Codex 턴 평균 $avgTurns / 최대 $maxCodexTurns" "Session length (requests): Claude average $avgMainRequests / maximum $maxMainRequests, Codex turns average $avgTurns / maximum $maxCodexTurns"))
    $lines.Add((LocalMessage '이어하기·압축된 세션은 시작 비용이 크게 잡힐 수 있습니다.' 'Resumed or compacted sessions may show a high start cost.'))
    $lines.Add(''); $lines.Add((LocalMessage '| 역할 / 모델 | 요청 | 입력 | 캐시 쓰기 | 캐시 읽기 | 출력 | 환산 |' '| Role / model | Requests | Input | Cache write | Cache read | Output | Equivalent |')); $lines.Add('|---|---:|---:|---:|---:|---:|---:|')
    foreach ($key in ($groups.Keys | Sort-Object)) { $g=$groups[$key]; $displayKey=$key.Replace('|',' / '); $lines.Add("| $displayKey | $($g.requests) | $($g.input) | $($g.write) | $($g.read) | $($g.output) | $([math]::Round($g.equivalent)) |") }
    $lines.Add(''); $lines.Add((LocalMessage 'Codex 모델: ' 'Codex models: ')+(($modelDist.GetEnumerator() | ForEach-Object { "$($_.Key)=$($_.Value)" }) -join ', '))
    $lines.Add((LocalMessage 'Codex 추론 강도: ' 'Codex effort: ')+(($effortDist.GetEnumerator() | ForEach-Object { "$($_.Key)=$($_.Value)" }) -join ', '))
    $lines.Add(''); $lines.Add((LocalMessage '## 최상위 모델 실행' '## Top-model runs'))
    $lines.Add((LocalMessage '| 작업 | 라운드 | 모델 | 승격 전 모델 | 사유 |' '| Task | Round | Model | Escalated from | Reason |'))
    $lines.Add('|---|---|---|---|---|')
    foreach ($run in $topRuns) { $lines.Add('| '+((@($run.task,$run.round,$run.model,$run.escalated_from,$run.reason) | ForEach-Object { TableCell $_ }) -join ' | ')+' |') }
    $lines.Add(''); $lines.Add((LocalMessage '## 진단' '## Diagnosis')); foreach ($item in $diagnosis) { $lines.Add('- '+$item) }
    $dir=Split-Path -Parent $Out; if (!(Test-Path $dir)) { New-Item -ItemType Directory $dir -Force | Out-Null }
    [IO.File]::WriteAllText($Out,($lines -join "`n")+"`n",[Text.UTF8Encoding]::new($false))
    $watch.Stop()
    $summary=@($lines[0],$lines[2],$lines[3],$lines[4],$lines[5],$lines[6],((LocalMessage '보고서: ' 'Report: ')+$Out),((LocalMessage '소요 시간: {0:n1}초' 'Elapsed: {0:n1}s') -f $watch.Elapsed.TotalSeconds))
    $summary+=$diagnosis | Select-Object -First 30
    [Console]::OutputEncoding=[Text.UTF8Encoding]::new($false)
    $summary | Select-Object -First 40
} catch {
    $errorLang=if ($lang -in @('ko','en')) {$lang} elseif ((Get-UICulture).Name -like 'ko*') {'ko'} else {'en'}
    if ($errorLang -eq 'ko') { Write-Error '토큰 보고서를 만들지 못했습니다.' } else { Write-Error 'Could not create token report.' }
}
