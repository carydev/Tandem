param(
    [string]$Name,[string]$Fixed,[string]$Items,[string]$Out,[string]$Model,
    [ValidateSet('low','medium','high')][string]$Effort='low',
    [ValidateSet('read-only','workspace-write')][string]$Sandbox='read-only',
    [string]$Schema,[int]$ItemsPerSession=30,[long]$MaxThreadTokens=150000,
    [switch]$OnlyChanged,[switch]$AllowTools,[switch]$DryRun,
    [string]$EscalatedFrom,[string]$Reason,
    [ValidateSet('jev','table','human')][string]$DecidedBy='table'
)
try { [Console]::OutputEncoding=[Text.UTF8Encoding]::new($false) } catch {}
$ErrorActionPreference='Stop'
$utf8=[Text.UTF8Encoding]::new($false)
function Fail([string]$message) { Write-Output "status=fail $message"; exit 0 }
$lang='en'
try { $cfgEarly=Get-Content (Join-Path ([IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..\..'))) 'tandem/config.json') -Raw -Encoding UTF8 | ConvertFrom-Json; if ($cfgEarly.lang -eq 'ko') { $lang='ko' } } catch { if ((Get-UICulture).Name -like 'ko*') { $lang='ko' } }
$msg=@{
    ko=@{ required='Name, Fixed, Items, Out가 필요합니다'; quote='경로에 큰따옴표가 있습니다'; limits='세션 상한은 1 이상이어야 합니다'; config='tandem/config.json이 없습니다'; model='Model 값이 올바르지 않습니다'; top='최상위 모델은 -Reason 과 -EscalatedFrom(또는 -DecidedBy human)이 필요합니다'; files='Fixed 또는 Items 파일이 없습니다'; schema='Schema 파일이 없습니다'; item='항목 id/text가 잘못되었거나 중복입니다'; images='이미지가 12장을 넘습니다'; image='이미지 경로가 올바르지 않습니다'; exit='종료 코드 {0}'; noturn='turn.completed 없음'; nooutput='출력 없음'; badjson='스키마 JSON 파싱 실패'; resumeFailed='resume 실패, 새 세션으로 시작'; stoppedRun='연속 실패 {0}건' }
    en=@{ required='Name, Fixed, Items, Out are required'; quote='path contains a double quote'; limits='session limits must be positive'; config='tandem/config.json missing'; model='invalid Model'; top='Top model requires -Reason and -EscalatedFrom (or -DecidedBy human)'; files='Fixed or Items file missing'; schema='Schema file missing'; item='invalid or duplicate item id/text'; images='more than 12 images'; image='invalid image path'; exit='exit {0}'; noturn='turn.completed missing'; nooutput='output missing'; badjson='schema JSON parsing failed'; resumeFailed=$msg.resumeFailed; stoppedRun='{0} consecutive failures' }
}[$lang]
function Quote([string]$value) { return '"'+$value+'"' }
function AddJson([string]$path,$value) { [IO.File]::AppendAllText($path,(ConvertTo-Json -InputObject $value -Compress -Depth 12)+"`n",$utf8) }
function Full([string]$value) { return [IO.Path]::GetFullPath((Join-Path $root $value)) }
function UsageNumber($usage,[string]$name) { if ($null -eq $usage) { return 0L }; $v=$usage.$name; if ($null -eq $v) { return 0L }; return [long]$v }
function InvokeItem($item,[bool]$resume,[string]$thread,[string]$prompt,[string]$stem) {
    $promptFile=$stem+'.prompt'; $events=$stem+'.events'; $errors=$stem+'.err'; $last=$stem+'.txt'
    [IO.File]::WriteAllText($promptFile,$prompt,$utf8)
    foreach ($path in @($events,$errors,$last)) { if (Test-Path -LiteralPath $path) { Remove-Item -LiteralPath $path -Force } }
    # --image takes several files, so it must be followed by another option, never by 'resume' or '-'
    $args=@('exec','--json')
    foreach ($imagePath in $item.images) { $args+=@('--image',(Quote (Full $imagePath))) }
    $args+=@('--skip-git-repo-check','-C',(Quote $root),'-m',(Quote $Model),'-c',('model_reasoning_effort='+$Effort),'--sandbox',$Sandbox,'-c','features.multi_agent=false','-c','web_search="disabled"')
    if (!$AllowTools) { $args+=@('-c','features.shell_tool=false') }
    $args+=@('--output-last-message',(Quote $last))
    if ($Schema) { $args+=@('--output-schema',(Quote $schemaPath)) }
    if ($resume) { $args+=@('resume',(Quote $thread)) }
    $args+='-'
    $exitCode=1; $exception=''
    try {
        $exe=(Get-Command codex.cmd -ErrorAction Stop).Source
        $proc=Start-Process -FilePath $exe -ArgumentList ($args -join ' ') -WorkingDirectory $root -RedirectStandardInput $promptFile -RedirectStandardOutput $events -RedirectStandardError $errors -PassThru -Wait -WindowStyle Hidden
        $exitCode=$proc.ExitCode
    } catch { $exception=$_.Exception.Message }
    $newThread=$thread; $seen=$false; $usage=$null
    if (Test-Path -LiteralPath $events) {
        foreach ($line in [IO.File]::ReadLines($events)) {
            try {
                $event=$line | ConvertFrom-Json
                if ($event.type -eq 'thread.started') { $newThread=[string]$event.thread_id }
                if ($event.type -eq 'turn.completed') { $seen=$true; $usage=$event.usage }
            } catch {}
        }
    }
    $raw=''; if (Test-Path -LiteralPath $last) { $raw=[IO.File]::ReadAllText($last,$utf8) }
    $reason=$exception
    if (!$reason -and $exitCode -ne 0) { $reason=$msg.exit.Replace('{0}',[string]$exitCode) }
    if (!$reason -and !$seen) { $reason=$msg.noturn }
    if (!$reason -and !$raw.Trim()) { $reason=$msg.nooutput }
    if (!$reason -and $Schema) {
        try { $null=$raw | ConvertFrom-Json -ErrorAction Stop } catch { $reason=$msg.badjson }
    }
    $errText=''; if (Test-Path -LiteralPath $errors) { $errText=[IO.File]::ReadAllText($errors,$utf8) }
    if ($exitCode -ne 0 -and $errText.Trim()) { $reason=($errText.Trim() -split "`r?`n" | Select-Object -First 1) }
    return @{ok=(!$reason);reason=$reason;error=$errText;thread=$newThread;usage=$usage;raw=$raw;args=($args -join ' ')}
}
try {
    $root=[IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..\..'))
    if (!$Name -or !$Fixed -or !$Items -or !$Out) { Fail $msg.required }
    if (@($root,$Fixed,$Items,$Out,$Schema) | Where-Object { $_ -and $_.Contains('"') }) { Fail $msg.quote }
    if ($ItemsPerSession -lt 1 -or $MaxThreadTokens -lt 1) { Fail $msg.limits }
    $configPath=Join-Path $root 'tandem/config.json'
    if (!(Test-Path -LiteralPath $configPath)) { Fail $msg.config }
    $config=Get-Content -LiteralPath $configPath -Raw -Encoding UTF8 | ConvertFrom-Json
    if (!$Model) { $Model=if ($config.models.codex_light) { [string]$config.models.codex_light } else { [string]$config.models.codex_mid } }
    if ($Model -cnotmatch '^[A-Za-z0-9._:/-]+$') { Fail $msg.model }
    if ($config.models.codex_top -and $Model -ieq $config.models.codex_top) {
        if ($Reason -cnotmatch '^[^\r\n"]{1,200}$' -or (($EscalatedFrom -cnotmatch '^[A-Za-z0-9._:/-]+$') -and $DecidedBy -cne 'human')) { Fail $msg.top }
    }
    $fixedPath=Full $Fixed; $itemsPath=Full $Items; $outPath=Full $Out
    if (!(Test-Path -LiteralPath $fixedPath -PathType Leaf) -or !(Test-Path -LiteralPath $itemsPath -PathType Leaf)) { Fail $msg.files }
    $schemaPath=''; if ($Schema) { $schemaPath=Full $Schema; if (!(Test-Path -LiteralPath $schemaPath -PathType Leaf)) { Fail $msg.schema } }
    $fixedText=[IO.File]::ReadAllText($fixedPath,$utf8)
    $rows=New-Object System.Collections.ArrayList; $ids=@{}
    foreach ($line in [IO.File]::ReadLines($itemsPath)) {
        if (!$line.Trim()) { continue }
        $item=$line | ConvertFrom-Json -ErrorAction Stop
        if ($item.id -cnotmatch '^[A-Za-z0-9._-]+$' -or $ids.ContainsKey([string]$item.id) -or $null -eq $item.text) { Fail $msg.item }
        $ids[[string]$item.id]=$true
        $images=@($item.images | Where-Object { $_ })
        if ($images.Count -gt 12) { Fail $msg.images }
        foreach ($imagePath in $images) { if ([string]$imagePath -match '"' -or !(Test-Path -LiteralPath (Full $imagePath) -PathType Leaf)) { Fail $msg.image } }
        [void]$rows.Add([pscustomobject]@{id=[string]$item.id;text=[string]$item.text;images=$images})
    }
    if ($DryRun) {
        $sessions=[Math]::Ceiling($rows.Count / $ItemsPerSession)
        Write-Output "items=$($rows.Count) sessions_estimate=$sessions first_prompt_chars=$($fixedText.Length + $(if ($rows.Count) {$rows[0].text.Length} else {0}) + 5)"
        exit 0
    }
    [IO.Directory]::CreateDirectory($outPath) | Out-Null
    $usagePath=Join-Path $outPath 'usage.jsonl'; [IO.File]::WriteAllText($usagePath,'',$utf8)
    $thread=''; $threadCount=0; $threadTotal=@{input=0L;cached=0L;output=0L}; $sessions=0; $seenThreads=@{}; $streak=0; $okCount=0; $skipCount=0; $failCount=0; $progress=New-Object System.Collections.ArrayList
    $sum=@{input=0L;cached=0L;output=0L}; $stopped=$false; $stopReason=''
    foreach ($item in $rows) {
        $stem=Join-Path $outPath $item.id
        $hashBytes=New-Object System.Collections.Generic.List[byte]
        $hashBytes.AddRange([byte[]]$utf8.GetBytes($fixedText+[string]$item.text))
        foreach ($imagePath in $item.images) { $hashBytes.AddRange([byte[]][IO.File]::ReadAllBytes((Full $imagePath))) }
        $sha=[Security.Cryptography.SHA256]::Create(); try { $hash=([BitConverter]::ToString($sha.ComputeHash($hashBytes.ToArray()))).Replace('-','').ToLowerInvariant() } finally { $sha.Dispose() }
        $hashPath=$stem+'.hash'; $record=@{ts=[datetime]::Now.ToString('o');id=$item.id;thread=$thread;resumed=$false;tokens=@{input=0L;cached=0L;output=0L};thread_total=@{input=$threadTotal.input;cached=$threadTotal.cached;output=$threadTotal.output};images=$item.images.Count;result='';note=''}
        if ($OnlyChanged -and (Test-Path -LiteralPath $hashPath) -and ([IO.File]::ReadAllText($hashPath,$utf8).Trim() -eq $hash)) {
            $record.result='skipped'; $skipCount++; AddJson $usagePath $record; [void]$progress.Add("$($item.id) skipped 0/0/0"); continue
        }
        $rotated=$false
        if ($thread -and ($threadCount -ge $ItemsPerSession -or $threadTotal.input -ge $MaxThreadTokens)) { $thread=''; $threadCount=0; $threadTotal=@{input=0L;cached=0L;output=0L}; $rotated=$true }
        $previous=$thread; $resuming=[bool]$thread; $attempt=0; $result=$null; $resumeRecovered=$false
        while ($attempt -lt 2) {
            $prompt=if ($resuming) { $item.text } else { $fixedText+"`n---`n"+$item.text }
            $result=InvokeItem $item $resuming $thread $prompt $stem
            if ($result.thread -and !$seenThreads.ContainsKey($result.thread)) { $seenThreads[$result.thread]=$true; $sessions++ }
            if ($result.ok) { break }
            if ($resuming -and ($result.error -match 'no rollout found|not found|unknown thread')) {
                $thread=''; $threadCount=0; $threadTotal=@{input=0L;cached=0L;output=0L}; $resuming=$false; $resumeRecovered=$true
            } elseif (!$resuming -and $result.thread) {
                $thread=$result.thread; $resuming=$true
            }
            $attempt++
        }
        if ($result.thread) { $thread=$result.thread }
        $record.thread=$thread; $record.resumed=($resuming -and !$resumeRecovered)
        if ($rotated) { $record.note='session rotated' }
        if ($resumeRecovered) { $record.note='resume failed; started new session' }
        if ($result.ok) {
            $now=@{input=(UsageNumber $result.usage 'input_tokens');cached=(UsageNumber $result.usage 'cached_input_tokens');output=(UsageNumber $result.usage 'output_tokens')}
            if ($resuming) { $delta=@{input=[Math]::Max(0,$now.input-$threadTotal.input);cached=[Math]::Max(0,$now.cached-$threadTotal.cached);output=[Math]::Max(0,$now.output-$threadTotal.output)} } else { $delta=$now }
            $threadTotal=$now; $record.tokens=$delta; $record.thread_total=$now
            foreach ($key in @('input','cached','output')) { $sum[$key]+=$delta[$key] }
            $threadCount++; $okCount++; $streak=0; $record.result='ok'
            [IO.File]::WriteAllText($stem+'.txt',$result.raw,$utf8)
            if ($Schema) { [IO.File]::WriteAllText($stem+'.json',$result.raw,$utf8) }
            [IO.File]::WriteAllText($hashPath,$hash,$utf8)
        } else {
            if ($result.usage) {
                $now=@{input=(UsageNumber $result.usage 'input_tokens');cached=(UsageNumber $result.usage 'cached_input_tokens');output=(UsageNumber $result.usage 'output_tokens')}
                $delta=@{input=[Math]::Max(0,$now.input-$threadTotal.input);cached=[Math]::Max(0,$now.cached-$threadTotal.cached);output=[Math]::Max(0,$now.output-$threadTotal.output)}
                $threadTotal=$now; $record.tokens=$delta; $record.thread_total=$now
                foreach ($key in @('input','cached','output')) { $sum[$key]+=$delta[$key] }
            }
            if ($thread) { $threadCount++ }
            $failCount++; $streak++; $record.result='failed'; $record.note=($record.note+' '+$result.reason).Trim()
        }
        AddJson $usagePath $record
        [void]$progress.Add("$($item.id) $($record.result) $($record.tokens.input)/$($record.tokens.cached)/$($record.tokens.output)")
        if ($streak -ge 3) { $stopped=$true; $stopReason=$result.reason; break }
    }
    $resultName=if ($stopped) {'stopped'} elseif ($failCount) {'partial'} else {'ok'}
    $docs=Join-Path $root $config.docs_root; $log=Join-Path $docs 'log/runs.jsonl'; [IO.Directory]::CreateDirectory((Split-Path $log)) | Out-Null
    $relativeOut=$outPath; $prefix=$root.TrimEnd('\','/')+'\'; if ($outPath.StartsWith($prefix,[StringComparison]::OrdinalIgnoreCase)) { $relativeOut=$outPath.Substring($prefix.Length).Replace('\','/') }
    $note="items $($rows.Count) ok $okCount skipped $skipCount failed $failCount sessions $sessions"
    AddJson $log @{ts=[datetime]::Now.ToString('o');task=$Name;round='single';model=$Model;effort=$Effort;result=$resultName;workers=$null;out=$relativeOut;session=$thread;tokens=$sum;decided_by=$DecidedBy;escalated_from=$(if ($EscalatedFrom) {$EscalatedFrom} else {$null});reason=$(if ($Reason) {$Reason} else {$null});note=$note}
    if ($stopped) { Write-Output "STOPPED: $stopReason" }
    $progress | ForEach-Object { Write-Output $_ }
    $rate=if ($sum.input) { [Math]::Round(100.0*$sum.cached/$sum.input,1) } else { 0 }
    Write-Output "items=$($rows.Count)"
    Write-Output "ok=$okCount skipped=$skipCount failed=$failCount"
    Write-Output "sessions=$sessions"
    Write-Output "input=$($sum.input) cached=$($sum.cached) cache_rate=$rate% output=$($sum.output)"
    Write-Output "usage=$usagePath"
} catch { Write-Output "status=fail $($_.Exception.Message)" }
