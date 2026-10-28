param([string[]]$Task,[string]$Since,[int]$Max=10,[string]$Path)
try { [Console]::OutputEncoding = [Text.UTF8Encoding]::new($false) } catch {}
$ErrorActionPreference = 'Stop'
$inv = [Globalization.CultureInfo]::InvariantCulture
function Cell($value) { $t = ([string]$value).Replace('|','\|').Replace("`r",' ').Replace("`n",' ').Trim(); if (!$t) { return [string][char]0x2014 }; return $t }
function Short([string]$t,[int]$n) { if ($t.Length -gt $n) { return $t.Substring(0,$n-1) + [char]0x2026 }; return $t }
function Num([double]$n) {
    if ($n -ge 1e6) { return [string]::Format($inv,'{0:0.0}M',$n/1e6) }
    if ($n -ge 1e4) { return [string]::Format($inv,'{0:0}k',$n/1e3) }
    if ($n -ge 1e3) { return [string]::Format($inv,'{0:0.0}k',$n/1e3) }
    return [string][long]$n
}
function Dur([long]$s) {
    if ($s -lt 60) { return "${s}s" }
    if ($s -lt 3600) { return ('{0}m {1}s' -f [long][math]::Floor($s/60),($s%60)) }
    return ('{0}h {1}m' -f [long][math]::Floor($s/3600),[long][math]::Floor(($s%3600)/60))
}
function Has($o,[string]$name) { return ($null -ne $o) -and ($o.PSObject.Properties[$name]) -and ($null -ne $o.$name) }
function TokenTotal($t) {
    # Wrapper records: {input,cached,output} (input includes cached). Native records may carry {total}.
    if ($null -eq $t) { return $null }
    if (Has $t 'total') { return [double]$t.total }
    if ((Has $t 'input') -or (Has $t 'output')) { $v = 0.0; if (Has $t 'input') { $v += [double]$t.input }; if (Has $t 'output') { $v += [double]$t.output }; return $v }
    return $null
}
function CodexSessionTokens([string]$id) {
    # Best effort for native Codex subagents that logged a session id but no tokens.
    if ($id -notmatch '^[0-9a-fA-F-]{20,}$') { return $null }
    if ($null -eq $script:rollouts) {
        $dir = Join-Path $env:USERPROFILE '.codex/sessions'
        $script:rollouts = if (Test-Path $dir) { @(Get-ChildItem $dir -Recurse -Filter 'rollout-*.jsonl' -File -ErrorAction SilentlyContinue) } else { @() }
    }
    $file = $script:rollouts | Where-Object { $_.Name -like "*$id.jsonl" } | Select-Object -First 1
    if (!$file) { return $null }
    $last = $null
    try {
        $stream = [IO.FileStream]::new($file.FullName,[IO.FileMode]::Open,[IO.FileAccess]::Read,[IO.FileShare]::ReadWrite)
        $reader = [IO.StreamReader]::new($stream,[Text.Encoding]::UTF8)
        try { while ($null -ne ($line = $reader.ReadLine())) { if ($line.Contains('"total_token_usage"')) { $last = $line } } } finally { $reader.Dispose() }
    } catch { return $null }
    if (!$last) { return $null }
    $at = $last.IndexOf('"total_token_usage"'); $part = $last.Substring($at,[Math]::Min(350,$last.Length-$at))
    $in = [regex]::Match($part,'"input_tokens"\s*:\s*(\d+)'); $out = [regex]::Match($part,'"output_tokens"\s*:\s*(\d+)')
    if (!$in.Success) { return $null }
    return [double]$in.Groups[1].Value + $(if ($out.Success) { [double]$out.Groups[1].Value } else { 0 })
}
$lang = 'ko'; $mode = ''
try {
    $root = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..\..'))
    $configPath = Join-Path $root 'tandem/config.json'
    $config = if (Test-Path $configPath) { Get-Content $configPath -Raw -Encoding UTF8 | ConvertFrom-Json } else { $null }
    $lang = if ($config -and $config.lang -eq 'en') { 'en' } elseif ($config) { 'ko' } elseif ((Get-UICulture).Name -like 'ko*') { 'ko' } else { 'en' }
    $mode = if ($config) { [string]$config.mode } else { '' }
    $docsRoot = if ($config -and $config.docs_root) { [string]$config.docs_root } else { 'docs/tandem' }
    if (!$Path) { $Path = Join-Path (Join-Path $root $docsRoot) 'log/runs.jsonl' } elseif (![IO.Path]::IsPathRooted($Path)) { $Path = Join-Path (Get-Location).Path $Path }
    $text = @{
        ko = @{ head='| 종류 | 에이전트 | 모델 | 맡긴 작업 | 상태 | 시간 | 토큰 |'; none='없음'; total='합계'; runs='{0}건'
                kinds=@{R1='작업';R2='검토';R3='대응';single='단일';batch='배치'}
                status=@{ok='완료';fail='실패';failed='실패';partial='일부';stopped='중단';running='진행 중'}
                cached='캐시 {0}'; more='표에는 최근 {0}건만 표시, 합계는 전체 {1}건.'; unknown='토큰 모름 {0}건.'
                excludeMain='총괄 자신의 사용량은 빠져 있습니다(token-report.ps1).'; excludeTeam='총괄·팀장·전달책 자신의 사용량은 빠져 있습니다(token-report.ps1).' }
        en = @{ head='| Kind | Agent | Model | Task | Status | Time | Tokens |'; none='none'; total='Total'; runs='{0} runs'
                kinds=@{R1='work';R2='review';R3='response';single='single';batch='batch'}
                status=@{ok='done';fail='failed';failed='failed';partial='partial';stopped='stopped';running='running'}
                cached='{0} cached'; more='Showing the latest {0}; totals cover all {1}.'; unknown='Tokens unknown for {0}.'
                excludeMain="The lead's own usage is not included (token-report.ps1)."; excludeTeam="The lead, manager and dispatcher usage is not included (token-report.ps1)." }
    }
    $m = $text[$lang]
    $tasks = @($Task | ForEach-Object { ([string]$_).Split(',') } | ForEach-Object { $_.Trim() } | Where-Object { $_ })
    $from = $null
    if ($Since -and $Since -ne 'all') {
        if ($Since -eq 'today') { $from = [datetimeoffset][datetime]::Today }
        elseif ($Since -match '^(\d+)([mhd])$') { $n = [int]$matches[1]; $from = [datetimeoffset]::Now.Add($(switch ($matches[2]) { 'm' { [timespan]::FromMinutes($n) } 'h' { [timespan]::FromHours($n) } 'd' { [timespan]::FromDays($n) } }).Negate()) }
        else { $from = [datetimeoffset]::Parse($Since,$inv) }
    } elseif (!$Since -and !$tasks.Count) { $from = [datetimeoffset][datetime]::Today }
    $rows = New-Object System.Collections.Generic.List[object]
    if (Test-Path -LiteralPath $Path) {
        foreach ($line in [IO.File]::ReadLines($Path,[Text.Encoding]::UTF8)) {
            if (!$line.Trim()) { continue }
            try { $r = $line | ConvertFrom-Json } catch { continue }
            if (!(Has $r 'ts')) { continue }
            $ts = [datetimeoffset]::MinValue
            if (![datetimeoffset]::TryParse([string]$r.ts,$inv,[Globalization.DateTimeStyles]::None,[ref]$ts)) { continue }
            if ($from -and $ts -lt $from) { continue }
            if ($tasks.Count -and !($tasks | Where-Object { $_ -ieq [string]$r.task })) { continue }
            $rows.Add([pscustomobject]@{ts=$ts; i=$rows.Count; r=$r})
        }
    }
    $lines = New-Object System.Collections.Generic.List[string]
    $lines.Add($m.head); $lines.Add('|---|---|---|---|---|---:|---:|')
    if (!$rows.Count) {
        $dash = [string][char]0x2014
        $lines.Add("| $dash | $($m.none) | $dash | $dash | $dash | $dash | $dash |")
        $lines | ForEach-Object { Write-Output $_ }
        exit 0
    }
    $ordered = @($rows | Sort-Object { $_.ts },{ $_.i })
    $sumTime = [long]0; $sumTokens = 0.0; $sumCached = 0.0; $unknown = 0; $timed = 0
    $cells = foreach ($row in $ordered) {
        $r = $row.r
        $kindKey = if ((Has $r 'kind') -and $r.kind -eq 'batch') { 'batch' } else { [string]$r.round }
        $kind = if ($m.kinds.ContainsKey($kindKey)) { $m.kinds[$kindKey] } else { $kindKey }
        $agent = if (Has $r 'agent') { [string]$r.agent } else { '' }
        $model = [string]$r.model; if ((Has $r 'effort') -and $model) { $model += " ($($r.effort))" }
        $job = [string]$r.task; if (Has $r 'title') { $job = ($job + ' ' + [string]$r.title).Trim() }
        $status = if ($m.status.ContainsKey([string]$r.result)) { $m.status[[string]$r.result] } else { [string]$r.result }
        $time = ''
        if (Has $r 'duration_s') { $sec = [long]$r.duration_s; $sumTime += $sec; $timed++; $time = Dur $sec }
        $tok = TokenTotal $(if (Has $r 'tokens') { $r.tokens } else { $null })
        if ($null -eq $tok -and (Has $r 'session')) { $tok = CodexSessionTokens ([string]$r.session) }
        if ($null -eq $tok) { $unknown++ } else { $sumTokens += $tok; if ((Has $r 'tokens') -and (Has $r.tokens 'cached')) { $sumCached += [double]$r.tokens.cached } }
        '| ' + ((@($kind,$agent,$model,(Short $job 48),$status,$time,$(if ($null -ne $tok) { Num $tok } else { '' })) | ForEach-Object { Cell $_ }) -join ' | ') + ' |'
    }
    $cells = @($cells)
    $shown = if ($Max -gt 0 -and $cells.Count -gt $Max) { $cells[($cells.Count-$Max)..($cells.Count-1)] } else { $cells }
    foreach ($c in $shown) { $lines.Add($c) }
    $timeText = if ($timed) { Dur $sumTime } else { [string][char]0x2014 }
    $tokenText = if ($unknown -lt $ordered.Count) { Num $sumTokens } else { [string][char]0x2014 }
    if ($sumCached -gt 0) { $tokenText += ' (' + ($m.cached -f (Num $sumCached)) + ')' }
    $lines.Add("| **$($m.total)** | $($m.runs -f $ordered.Count) | | | | $timeText | $tokenText |")
    $notes = @()
    if ($shown.Count -lt $cells.Count) { $notes += ($m.more -f $shown.Count,$cells.Count) }
    if ($unknown) { $notes += ($m.unknown -f $unknown) }
    $notes += $(if ($mode -eq 'claude-main') { $m.excludeTeam } else { $m.excludeMain })
    $lines.Add(''); $lines.Add($notes -join ' ')
    $lines | ForEach-Object { Write-Output $_ }
} catch {
    if ($lang -eq 'en') { Write-Output "run-table failed: $($_.Exception.Message)" } else { Write-Output "실행 표를 만들지 못했습니다: $($_.Exception.Message)" }
}
exit 0
