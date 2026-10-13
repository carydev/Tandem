param([ValidateSet('claude','codex')][string]$Agent='codex')
$ErrorActionPreference = 'Stop'
try {
    $root = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..\..'))
    $config = Get-Content -LiteralPath (Join-Path $root 'tandem/config.json') -Raw -Encoding UTF8 | ConvertFrom-Json
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
    if ($config.jev.notify_missing_key) {
        $found = $false
        foreach ($name in @('TANDEM_JEV_API_KEY','OPENROUTER_API_KEY')) {
            if ([Environment]::GetEnvironmentVariable($name,'Process') -or [Environment]::GetEnvironmentVariable($name,'User')) { $found = $true; break }
        }
        if (!$found) { $notices.Add($messages[$lang].key) }
    }
    if ($notices.Count) {
        $json = @{systemMessage=($notices -join ' ')} | ConvertTo-Json -Compress
        $ascii = [regex]::Replace($json,'[^\x00-\x7F]',{param($m) '\u{0:x4}' -f [int][char]$m.Value[0]})
        [Console]::Out.WriteLine($ascii)
    }
} catch {}
exit 0
