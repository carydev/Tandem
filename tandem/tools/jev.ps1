param([switch]$Route,[switch]$Escalate,[switch]$NeedCritic,[string]$Card,[string]$FailNote,[string[]]$Tiers=@('top','mid','light'),[string]$Request,[switch]$DryRun,[string]$Endpoint='https://openrouter.ai/api/alpha/decisions')
$ErrorActionPreference = 'Stop'
function Fallback([string]$reason,[string]$notice) {
    Write-Output (@{ok=$false;decided_by='table';reason=$reason;notice=$notice} | ConvertTo-Json -Compress)
}
function ValidProbability($value) {
    if ($null -eq $value -or $value -is [bool] -or $value -is [string]) { return $false }
    try { $n=[double]$value; return ![double]::IsNaN($n) -and $n -ge 0 -and $n -le 1 } catch { return $false }
}
function LimitState($state) {
    $order=@($state.Keys | Where-Object { $_ -ne 'fail_note' })
    if ($state.ContainsKey('fail_note')) { $order+= 'fail_note' }
    foreach ($name in $order) {
        $over=(($state | ConvertTo-Json -Compress -Depth 10).Length-6000)
        if ($over -le 0) { break }
        $value=[string]$state[$name]
        $state[$name]=$value.Substring(0,[Math]::Max(0,$value.Length-$over))
    }
}
function ValidateAnswers($questions,$answers,[double]$minConfidence) {
    if (!$answers) { return 'invalid_answer' }
    foreach ($question in $questions.PSObject.Properties) {
        $answer=$answers.PSObject.Properties[$question.Name]
        if (!$answer -or !$answer.Value) { return 'invalid_answer' }
        $value=$answer.Value; $type=$question.Value.type
        if ($type -eq 'noul') {
            if (!(ValidProbability $value.noul)) { return 'invalid_answer' }
            if ([math]::Abs([double]$value.noul-0.5) -lt ($minConfidence-0.5)) { $low=$true }
        } elseif ($type -eq 'choice') {
            if (!$value.choice -or !$question.Value.criteria.PSObject.Properties[$value.choice] -or !(ValidProbability $value.confidence) -or !$value.probabilities) { return 'invalid_answer' }
            foreach ($p in $value.probabilities.PSObject.Properties) { if (!$question.Value.criteria.PSObject.Properties[$p.Name] -or !(ValidProbability $p.Value)) { return 'invalid_answer' } }
            if ([double]$value.confidence -lt $minConfidence) { $low=$true }
        } elseif ($type -eq 'score') {
            if ($null -eq $value.score -or $value.score -is [string] -or [int]$value.score -ne $value.score -or [int]$value.score -lt 0 -or [int]$value.score -ge $question.Value.criteria.Count -or !(ValidProbability $value.confidence) -or !$value.probabilities) { return 'invalid_answer' }
            if ([double]$value.confidence -lt $minConfidence) { $low=$true }
        } else { return 'invalid_answer' }
    }
    if ($low) { return 'low_confidence' }
    return ''
}
try {
    $root = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..\..'))
    $config = Get-Content (Join-Path $root 'tandem/config.json') -Raw -Encoding UTF8 | ConvertFrom-Json
    $lang = if ($config.lang -eq 'en') { 'en' } else { 'ko' }
    $messages = @{
        ko = @{ disabled='Jev 사용이 꺼져 있습니다. 배치표로 결정합니다.'; no_key='Jev 키가 없습니다. 배치표로 결정합니다.'; no_sections='카드에 인식할 수 있는 절이 없습니다. 배치표로 결정합니다.'; invalid='Jev 응답을 검증하지 못했습니다. 배치표로 결정합니다.'; low='Jev 확신도가 낮습니다. 배치표로 결정합니다.'; error='Jev 요청에 실패했습니다. 배치표로 결정합니다.'; tier='필요한 능력을 충족하는 가장 낮은 모델 단계를 고르세요'; effort='충분한 추론 강도 중 가장 낮은 단계를 고르세요'; useTier='{0} 모델 사용'; simple='단순함'; moderate='보통'; complex='복잡함'; escalate='이 실패 때문에 단계를 높여야 합니까?'; raise='단계 높이기'; keep='현재 단계 유지'; critic='이 결정은 되돌리기 어렵습니까?'; needCritic='검수 필요'; noCritic='검수 불필요' }
        en = @{ disabled='Jev is disabled. Using the routing table.'; no_key='Jev key is missing. Using the routing table.'; no_sections='No recognized card sections. Using the routing table.'; invalid='Jev response validation failed. Using the routing table.'; low='Jev confidence is low. Using the routing table.'; error='Jev request failed. Using the routing table.'; tier='Choose the least capable sufficient tier'; effort='Choose the least sufficient effort'; useTier='Use {0} model'; simple='Simple'; moderate='Moderate'; complex='Complex'; escalate='Does the failure require escalation?'; raise='Escalate'; keep='Keep tier'; critic='Is this decision hard to reverse?'; needCritic='Needs critic'; noCritic='No critic' }
    }
    $m = $messages[$lang]
    if ($config.jev.PSObject.Properties['enabled'] -and $config.jev.enabled -eq $false) {
        Fallback 'disabled' $m.disabled
        exit 0
    }
    if ($Request) { $body = Get-Content -LiteralPath $Request -Raw -Encoding UTF8 | ConvertFrom-Json }
    else {
        if (!$Card -or !(Test-Path -LiteralPath $Card)) { throw 'card_required' }
        $text = Get-Content -LiteralPath $Card -Raw -Encoding UTF8
        $parts = [regex]::Matches($text,'(?ims)^##\s*(목표|목적|제약(?:사항)?|완료\s*조건|성공\s*조건|goal|objectives?|constraints?|requirements?|done\s*when|completion(?:\s*criteria)?|acceptance\s*criteria)[^\r\n]*\r?\n(.*?)(?=^##\s|\z)')
        $state = @{}
        foreach ($part in $parts) {
            $name=$part.Groups[1].Value; $state[$name]=$part.Groups[2].Value.Trim()
            LimitState $state
            if (($state | ConvertTo-Json -Compress -Depth 10).Length -ge 6000) { break }
        }
        if ($state.Count -eq 0) { Fallback 'no_card_sections' $m.no_sections; exit 0 }
        $questions = @{}
        if ($Route) {
            $criteria = @{}; foreach ($tier in $Tiers) { $criteria[$tier] = $m.useTier.Replace('{0}',$tier) }
            $questions.tier = @{type='choice';instructions=$m.tier;criteria=$criteria}
            $questions.effort = @{type='choice';instructions=$m.effort;criteria=@{low=$m.simple;medium=$m.moderate;high=$m.complex}}
        } elseif ($Escalate) {
            $failure=[string]$FailNote
            $state.fail_note = $failure.Substring(0,[Math]::Min($failure.Length,1000))
            LimitState $state
            $questions.escalate = @{type='noul';instructions=$m.escalate;criteria=@{'true'=$m.raise;'false'=$m.keep}}
        } elseif ($NeedCritic) {
            $questions.irreversible = @{type='noul';instructions=$m.critic;criteria=@{'true'=$m.needCritic;'false'=$m.noCritic}}
        } else { throw 'missing_action' }
        $body = @{model=$config.jev.model;state=$state;questions=$questions}
    }
    $json = $body | ConvertTo-Json -Depth 20 -Compress
    if ($DryRun) { Write-Output $json; exit 0 }
    $key = [Environment]::GetEnvironmentVariable('TANDEM_JEV_API_KEY','Process')
    if (!$key) { $key = [Environment]::GetEnvironmentVariable('TANDEM_JEV_API_KEY','User') }
    if (!$key) { $key = [Environment]::GetEnvironmentVariable('OPENROUTER_API_KEY','Process') }
    if (!$key) { $key = [Environment]::GetEnvironmentVariable('OPENROUTER_API_KEY','User') }
    if (!$key) { Fallback 'no_key' $m.no_key; exit 0 }
    $statusPath = Join-Path $root 'tandem/.cache/jev-status.json'
    try {
        $response = Invoke-RestMethod -Uri $Endpoint -Method Post -Headers @{Authorization="Bearer $key"} -ContentType 'application/json' -Body ([Text.Encoding]::UTF8.GetBytes($json)) -TimeoutSec 30
    } catch {
        $httpResponse = $_.Exception.Response
        $statusCode = if ($httpResponse) { [int]$httpResponse.StatusCode } else { 0 }
        if ($statusCode -eq 401 -or $statusCode -eq 402) {
            $stream = $httpResponse.GetResponseStream()
            if ($stream) {
                $reader = New-Object IO.StreamReader($stream)
                try { $errorBody = $reader.ReadToEnd() } finally { $reader.Dispose() }
                try { $null = $errorBody | ConvertFrom-Json } catch {}
            }
            $reason = if ($statusCode -eq 402) { 'insufficient_credits' } else { 'invalid_key' }
            $notices = @{
                en = @{ insufficient_credits='Jev has insufficient OpenRouter credits. Using the routing table for decisions now. Add credits at https://openrouter.ai/settings/credits.'; invalid_key='The Jev OpenRouter key is invalid or inactive. Using the routing table for decisions now. Check or replace the key at https://openrouter.ai/settings/keys, then update the user environment variable TANDEM_JEV_API_KEY.' }
                ko = @{ insufficient_credits='Jev OpenRouter 크레딧이 부족합니다. 지금은 배치표로 대신 결정합니다. https://openrouter.ai/settings/credits 에서 크레딧을 충전하세요.'; invalid_key='Jev OpenRouter 키가 잘못되었거나 비활성 상태입니다. 지금은 배치표로 대신 결정합니다. https://openrouter.ai/settings/keys 에서 키를 확인하거나 재발급한 뒤 사용자 환경변수 TANDEM_JEV_API_KEY를 갱신하세요.' }
            }
            $statusDir = Split-Path $statusPath
            if (!(Test-Path -LiteralPath $statusDir)) { New-Item -ItemType Directory -Path $statusDir -Force | Out-Null }
            [IO.File]::WriteAllText($statusPath,(@{status=$reason;at=[datetime]::UtcNow.ToString('o')} | ConvertTo-Json -Compress),[Text.UTF8Encoding]::new($false))
            Write-Output (@{ok=$false;decided_by='table';reason=$reason;notice=$notices[$lang][$reason]} | ConvertTo-Json -Compress)
            exit 0
        }
        throw
    }
    if (Test-Path -LiteralPath $statusPath) { Remove-Item -LiteralPath $statusPath -Force }
    $questionObject=($body.questions | ConvertTo-Json -Depth 20) | ConvertFrom-Json
    $validation=ValidateAnswers $questionObject $response.answers ([double]$config.jev.min_confidence)
    if ($validation -eq 'invalid_answer') { Fallback 'invalid_answer' $m.invalid; exit 0 }
    $low=$validation -eq 'low_confidence'
    $result = @{ok=(!$low);decided_by=$(if ($low) {'table'} else {'jev'});answers=$response.answers;cost=$response.usage.cost}
    if ($low) { $result.reason='low_confidence'; $result.notice=$m.low }
    Write-Output ($result | ConvertTo-Json -Depth 20 -Compress)
} catch {
    $fallbackLang=if ($lang -in @('ko','en')) {$lang} elseif ((Get-UICulture).Name -like 'ko*') {'ko'} else {'en'}
    $notice=if ($messages -and $messages[$fallbackLang]) {$messages[$fallbackLang].error} elseif ($fallbackLang -eq 'ko') {'Jev 요청에 실패했습니다. 배치표로 결정합니다.'} else {'Jev request failed. Using the routing table.'}
    Fallback 'error' $notice
}
