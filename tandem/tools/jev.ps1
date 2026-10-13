param([switch]$Route,[switch]$Escalate,[switch]$NeedCritic,[string]$Card,[string]$FailNote,[string[]]$Tiers=@('top','mid','light'),[string]$Request,[switch]$DryRun)
$ErrorActionPreference = 'Stop'
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
    if ($Request) { $body = Get-Content -LiteralPath $Request -Raw -Encoding UTF8 | ConvertFrom-Json }
    else {
        if (!$Card -or !(Test-Path -LiteralPath $Card)) { throw 'Card is required' }
        $text = Get-Content -LiteralPath $Card -Raw -Encoding UTF8
        $parts = [regex]::Matches($text,'(?ims)^##\s*(목표|목적|제약(?:사항)?|완료\s*조건|성공\s*조건|goal|objectives?|constraints?|requirements?|done\s*when|completion(?:\s*criteria)?|acceptance\s*criteria)[^\r\n]*\r?\n(.*?)(?=^##\s|\z)')
        $state = @{}
        foreach ($part in $parts) {
            $name=$part.Groups[1].Value; $state[$name]=$part.Groups[2].Value.Trim()
            LimitState $state
            if (($state | ConvertTo-Json -Compress -Depth 10).Length -ge 6000) { break }
        }
        if ($state.Count -eq 0) { Write-Output '{"ok":false,"decided_by":"table","reason":"no_card_sections"}'; exit 0 }
        $questions = @{}
        if ($Route) {
            $criteria = @{}; foreach ($tier in $Tiers) { $criteria[$tier] = "Use $tier model" }
            $questions.tier = @{type='choice';instructions='Choose the least capable sufficient tier';criteria=$criteria}
            $questions.effort = @{type='choice';instructions='Choose the least sufficient effort';criteria=@{low='Simple';medium='Moderate';high='Complex'}}
        } elseif ($Escalate) {
            $failure=[string]$FailNote
            $state.fail_note = $failure.Substring(0,[Math]::Min($failure.Length,1000))
            LimitState $state
            $questions.escalate = @{type='noul';instructions='Does the failure require escalation?';criteria=@{'true'='Escalate';'false'='Keep tier'}}
        } elseif ($NeedCritic) {
            $questions.irreversible = @{type='noul';instructions='Is this decision hard to reverse?';criteria=@{'true'='Needs critic';'false'='No critic'}}
        } else { throw 'Specify Route, Escalate, NeedCritic, or Request' }
        $body = @{model=$config.jev.model;state=$state;questions=$questions}
    }
    $json = $body | ConvertTo-Json -Depth 20 -Compress
    if ($DryRun) { Write-Output $json; exit 0 }
    $key = [Environment]::GetEnvironmentVariable('TANDEM_JEV_API_KEY','Process')
    if (!$key) { $key = [Environment]::GetEnvironmentVariable('TANDEM_JEV_API_KEY','User') }
    if (!$key) { $key = [Environment]::GetEnvironmentVariable('OPENROUTER_API_KEY','Process') }
    if (!$key) { $key = [Environment]::GetEnvironmentVariable('OPENROUTER_API_KEY','User') }
    if (!$key) { Write-Output '{"ok":false,"decided_by":"table","reason":"no_key"}'; exit 0 }
    $response = Invoke-RestMethod -Uri 'https://openrouter.ai/api/alpha/decisions' -Method Post -Headers @{Authorization="Bearer $key"} -ContentType 'application/json' -Body ([Text.Encoding]::UTF8.GetBytes($json)) -TimeoutSec 30
    $questionObject=($body.questions | ConvertTo-Json -Depth 20) | ConvertFrom-Json
    $validation=ValidateAnswers $questionObject $response.answers ([double]$config.jev.min_confidence)
    if ($validation -eq 'invalid_answer') { Write-Output '{"ok":false,"decided_by":"table","reason":"invalid_answer"}'; exit 0 }
    $low=$validation -eq 'low_confidence'
    $result = @{ok=(!$low);decided_by=$(if ($low) {'table'} else {'jev'});answers=$response.answers;cost=$response.usage.cost}
    if ($low) { $result.reason='low_confidence' }
    Write-Output ($result | ConvertTo-Json -Depth 20 -Compress)
} catch { Write-Output '{"ok":false,"decided_by":"table","reason":"error"}' }
