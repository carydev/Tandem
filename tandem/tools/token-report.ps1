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
try {
    $root=if ($ProjectRoot) {[IO.Path]::GetFullPath($ProjectRoot)} else {[IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..\..'))}
    $configPath=Join-Path $root 'tandem/config.json'
    $config=if (Test-Path $configPath) {Get-Content $configPath -Raw -Encoding UTF8 | ConvertFrom-Json} else {[pscustomobject]@{docs_root='docs/tandem';lang='ko';mode='claude-main'}}
    $project=[IO.Path]::GetFullPath($root).TrimEnd('\')
    $docs=Join-Path $root $(if ($DocsRoot) {$DocsRoot} else {$config.docs_root})
    if (!$Out) { $Out=Join-Path $docs ('reports/usage/usage-'+(Get-Date -Format yyyyMMdd)+'.md') }
    $since=(Get-Date).AddDays(-$Days)
    $lang=if ($config.lang -eq 'en') {'en'} else {'ko'}
    $groups=@{}; $mainContexts=[Collections.Generic.List[double]]::new(); $subRequests=[Collections.Generic.List[int]]::new()
    $claudeSessions=0; $subCount=0; $nonTandem=[double]0; $allClaude=[double]0
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
                    $eq=$inTokens+1.25*$write+0.1*$read+5*$output; $allClaude+=$eq
                    if ($sub -and $role -notmatch '(?i)tandem|general-purpose|explore') { $nonTandem+=$eq }
                    if (!$sub) { $mainContexts.Add($inTokens+$write+$read) }
                    $requests++
                }
            } catch { Write-Warning ("Claude {0}: {1}" -f $file.Name,$_.Exception.Message) }
            finally { if ($reader) { $reader.Dispose() } }
            if ($sub) { $subRequests.Add($requests) }
        }
    }
    $codexRoot=Join-Path $env:USERPROFILE '.codex/sessions'
    $codexSessions=0; $codexUnreadable=0; $turns=[long]0; $toolBytes=[long]0; $modelDist=@{}; $effortDist=@{}; $topInput=[long]0; $allCodexInput=[long]0
    if (Test-Path $codexRoot) {
        $dates=0..$Days | ForEach-Object { (Get-Date).AddDays(-$_).ToString('yyyy/MM/dd',[Globalization.CultureInfo]::InvariantCulture) }
        foreach ($date in $dates) {
            $folder=Join-Path $codexRoot $date
            if (!(Test-Path $folder)) { continue }
            foreach ($file in (Get-ChildItem $folder -Filter 'rollout-*.jsonl' -File -ErrorAction SilentlyContinue)) {
                $belongs=$false; $model='unknown'; $effort='unknown'; $lastUsage=$null; $sessionTurns=0; $sessionBytes=[long]0
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
                        if ($line.Contains('"token_count"') -and $line.Contains('"total_token_usage"')) {
                            $sessionTurns++; $at=$line.IndexOf('"total_token_usage"')
                            $lastUsage=$line.Substring($at,[Math]::Min(350,$line.Length-$at))
                        }
                        if ($line.Contains('"function_call_output"') -or $line.Contains('"custom_tool_call_output"')) { $sessionBytes += [Text.Encoding]::UTF8.GetByteCount($line) }
                    }
                } catch { $codexUnreadable++; continue }
                finally { if ($reader) { $reader.Dispose() } }
                if (!$belongs) { continue }
                $codexSessions++; $turns+=$sessionTurns; $toolBytes+=$sessionBytes
                if (!$modelDist.ContainsKey($model)) { $modelDist[$model]=0 }; $modelDist[$model]++
                if (!$effortDist.ContainsKey($effort)) { $effortDist[$effort]=0 }; $effortDist[$effort]++
                if ($lastUsage) {
                    $inTokens=NumberIn $lastUsage 'input_tokens'; $cached=NumberIn $lastUsage 'cached_input_tokens'; $output=NumberIn $lastUsage 'output_tokens'
                    $allCodexInput+=$inTokens; if ($model -match 'astra|top') { $topInput+=$inTokens }
                    $key="codex|$model|$effort"
                    if (!$groups.ContainsKey($key)) { $groups[$key]=@{requests=0;input=[long]0;write=[long]0;read=[long]0;output=[long]0;equivalent=[double]0} }
                    $g=$groups[$key]; $g.requests+=$sessionTurns; $g.input+=$inTokens; $g.read+=$cached; $g.output+=$output
                    $g.equivalent+=($inTokens-$cached+0.1*$cached+4*$output)
                }
            }
        }
    }
    $runPath=Join-Path $docs 'log/runs.jsonl'; if (!(Test-Path $runPath)) { $runPath=Join-Path $docs 'runs.jsonl' }; $runs=0
    if (Test-Path $runPath) { foreach ($line in [IO.File]::ReadLines($runPath)) { if ($line.Contains('"ts"')) { try { $run=$line | ConvertFrom-Json; if ($run.ts -and [datetime]$run.ts -ge $since) { $runs++ } } catch {} } } }
    $avgContext=if ($mainContexts.Count) { [math]::Round(($mainContexts | Measure-Object -Average).Average) } else { 0 }
    $avgSub=if ($subRequests.Count) { [math]::Round(($subRequests | Measure-Object -Average).Average,1) } else { 0 }
    $avgTurns=if ($codexSessions) { [math]::Round($turns/$codexSessions,1) } else { 0 }
    $avgBytes=if ($codexSessions) { [math]::Round($toolBytes/$codexSessions/1024) } else { 0 }
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
    $lines.Add('# TANDEM token report'); $lines.Add('Period: '+$Days+' days. Equivalent tokens are relative comparison estimates.')
    $lines.Add("Claude main sessions: $claudeSessions; subagents: $subCount; average main context/request: $avgContext; average subagent requests/call: $avgSub")
    $lines.Add("Codex sessions: $codexSessions; unreadable: $codexUnreadable; turns/session: $avgTurns; tool output KB/session: $avgBytes; runs.jsonl: $runs")
    $lines.Add(''); $lines.Add('| Role / model | Requests | Input | Cache write | Cache read | Output | Equivalent |'); $lines.Add('|---|---:|---:|---:|---:|---:|---:|')
    foreach ($key in ($groups.Keys | Sort-Object)) { $g=$groups[$key]; $lines.Add("| $key | $($g.requests) | $($g.input) | $($g.write) | $($g.read) | $($g.output) | $([math]::Round($g.equivalent)) |") }
    $lines.Add(''); $lines.Add('Codex models: '+(($modelDist.GetEnumerator() | ForEach-Object { "$($_.Key)=$($_.Value)" }) -join ', '))
    $lines.Add('Codex effort: '+(($effortDist.GetEnumerator() | ForEach-Object { "$($_.Key)=$($_.Value)" }) -join ', '))
    $lines.Add(''); $lines.Add('## Diagnosis'); foreach ($item in $diagnosis) { $lines.Add('- '+$item) }
    $dir=Split-Path -Parent $Out; if (!(Test-Path $dir)) { New-Item -ItemType Directory $dir -Force | Out-Null }
    [IO.File]::WriteAllText($Out,($lines -join "`n")+"`n",[Text.UTF8Encoding]::new($false))
    $watch.Stop()
    $summary=@($lines[0],$lines[2],$lines[3],"Report: $Out",("Elapsed: {0:n1}s" -f $watch.Elapsed.TotalSeconds))
    $summary+=$diagnosis | Select-Object -First 30
    [Console]::OutputEncoding=[Text.UTF8Encoding]::new($false)
    $summary | Select-Object -First 40
} catch { Write-Error $_ }
