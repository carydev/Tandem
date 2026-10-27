param([ValidateSet('claude','codex')][string]$Agent='codex')
try { [Console]::OutputEncoding = [Text.UTF8Encoding]::new($false) } catch {}  # UTF-8 stdout: PS 5.1 defaults to the OEM code page (cp949 on Korean Windows), which garbles non-ASCII output read by Bash/Claude
$ErrorActionPreference = 'Stop'
if ($env:TANDEM_HOOK_OFF -eq '1') { exit 0 }  # kill switch: no notices, no network
try {
    $root = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..\..'))
    $config = Get-Content -LiteralPath (Join-Path $root 'tandem/config.json') -Raw -Encoding UTF8 | ConvertFrom-Json
    if ($config.PSObject.Properties['hook'] -and $config.hook.PSObject.Properties['enabled'] -and $config.hook.enabled -eq $false) { exit 0 }
    $maxChars = 800  # cap on the session-start message; env TANDEM_HOOK_MAX_CHARS overrides config hook.max_chars
    if ($config.PSObject.Properties['hook'] -and $config.hook.PSObject.Properties['max_chars'] -and [int]$config.hook.max_chars -gt 0) { $maxChars = [int]$config.hook.max_chars }
    $envMax = 0
    if ([int]::TryParse([string]$env:TANDEM_HOOK_MAX_CHARS, [ref]$envMax) -and $envMax -gt 0) { $maxChars = $envMax }
    $lang = if ($config.lang -eq 'en') { 'en' } else { 'ko' }
    $messages = @{
        en = @{ update='TANDEM update available'; key='Jev key missing. Set TANDEM_JEV_API_KEY in your user environment.' }
        ko = @{ update='TANDEM 업데이트가 있습니다'; key='Jev 키가 없습니다. 사용자 환경 변수 TANDEM_JEV_API_KEY를 설정하세요.' }
    }
    $notices = New-Object 'System.Collections.Generic.List[string]'
    $cachePath = Join-Path $root 'tandem/.cache/update.json'
    $remote = $null
    $checkedToday = $false
    if (Test-Path $cachePath) {
        try {
            $cache = Get-Content $cachePath -Raw -Encoding UTF8 | ConvertFrom-Json
            if (([datetime]::UtcNow - [datetime]$cache.checked).TotalHours -lt 24) { $remote = $cache.version; $checkedToday = $true }
        } catch {}
    }
    if (!$checkedToday -and $config.update.notify -and $config.update.repo -and $config.update.ref) {
        try {
            $url = 'https://raw.githubusercontent.com/{0}/{1}/VERSION' -f $config.update.repo,$config.update.ref
            $web = Invoke-WebRequest -Uri $url -UseBasicParsing -TimeoutSec 3
            $remote = $web.Content.Trim()
            $cacheDir = Split-Path $cachePath
            if (!(Test-Path $cacheDir)) { New-Item -ItemType Directory -Path $cacheDir -Force | Out-Null }
            [IO.File]::WriteAllText($cachePath,(@{checked=[datetime]::UtcNow.ToString('o');version=$remote} | ConvertTo-Json -Compress),[Text.UTF8Encoding]::new($false))
        } catch {
            try {
                $cacheDir = Split-Path $cachePath
                if (!(Test-Path $cacheDir)) { New-Item -ItemType Directory -Path $cacheDir -Force | Out-Null }
                [IO.File]::WriteAllText($cachePath,(@{checked=[datetime]::UtcNow.ToString('o');version=''} | ConvertTo-Json -Compress),[Text.UTF8Encoding]::new($false))
            } catch {}
        }
    }
    if ($config.update.notify -and $remote -and $config.version) {
        try {
            $local = [string]$config.version
            if ([version]$remote -gt [version]$local) { $notices.Add($messages[$lang].update + ": $local -> $remote") }
        } catch {}
    }
    $jevEnabled = -not ($config.jev.PSObject.Properties['enabled'] -and $config.jev.enabled -eq $false)
    if ($jevEnabled -and $config.jev.notify_missing_key) {
        $found = $false
        foreach ($name in @('TANDEM_JEV_API_KEY','OPENROUTER_API_KEY')) {
            if ([Environment]::GetEnvironmentVariable($name,'Process') -or [Environment]::GetEnvironmentVariable($name,'User')) { $found = $true; break }
        }
        if (!$found) { $notices.Add($messages[$lang].key) }
    }
    $jevStatusPath = Join-Path $root 'tandem/.cache/jev-status.json'
    if ($jevEnabled -and (Test-Path -LiteralPath $jevStatusPath)) {
        try {
            $jevStatus = Get-Content -LiteralPath $jevStatusPath -Raw -Encoding UTF8 | ConvertFrom-Json
            $statusNotices = @{
                en = @{ insufficient_credits='Jev has insufficient OpenRouter credits. Using the routing table for decisions now. Add credits at https://openrouter.ai/settings/credits.'; invalid_key='The Jev OpenRouter key is invalid or inactive. Using the routing table for decisions now. Check or replace the key at https://openrouter.ai/settings/keys, then update the user environment variable TANDEM_JEV_API_KEY.' }
                ko = @{ insufficient_credits='Jev OpenRouter 크레딧이 부족합니다. 지금은 배치표로 대신 결정합니다. https://openrouter.ai/settings/credits 에서 크레딧을 충전하세요.'; invalid_key='Jev OpenRouter 키가 잘못되었거나 비활성 상태입니다. 지금은 배치표로 대신 결정합니다. https://openrouter.ai/settings/keys 에서 키를 확인하거나 재발급한 뒤 사용자 환경변수 TANDEM_JEV_API_KEY를 갱신하세요.' }
            }
            if ($statusNotices[$lang].ContainsKey([string]$jevStatus.status)) { $notices.Add($statusNotices[$lang][[string]$jevStatus.status]) }
        } catch {}
    }
    if ($notices.Count) {
        $message = $notices -join ' '
        if ($message.Length -gt $maxChars) { $message = $message.Substring(0, [Math]::Max(0, $maxChars - 3)) + '...' }
        $json = @{systemMessage=$message} | ConvertTo-Json -Compress
        $ascii = [regex]::Replace($json,'[^\x00-\x7F]',{param($m) '\u{0:x4}' -f [int][char]$m.Value[0]})
        [Console]::Out.WriteLine($ascii)
    }
} catch {}
exit 0
