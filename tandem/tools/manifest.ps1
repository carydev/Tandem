param([switch]$Rehash,[switch]$Status)
$ErrorActionPreference = 'Stop'
try {
    $root = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..\..'))
    $configPath = Join-Path $root 'tandem/config.json'
    $lang = if (Test-Path -LiteralPath $configPath) { try { (Get-Content -LiteralPath $configPath -Raw -Encoding UTF8 | ConvertFrom-Json).lang } catch { '' } } else { '' }
    if ($lang -notin @('ko','en')) { $lang = if ((Get-UICulture).Name -like 'ko*') { 'ko' } else { 'en' } }
    $messages = @{
        ko = @{ rehashed='개 파일의 해시를 다시 계산했습니다'; missing='파일 없음'; modified='파일 변경됨' }
        en = @{ rehashed='files'; missing='missing'; modified='modified' }
    }
    $manifestPath = Join-Path $root 'tandem/manifest.json'
    $manifest = @{ version = '1.1'; files = @{} }
    if (Test-Path $manifestPath) {
        $old = Get-Content -LiteralPath $manifestPath -Raw -Encoding UTF8 | ConvertFrom-Json
        $manifest.version = $old.version
        foreach ($p in $old.files.PSObject.Properties) { $manifest.files[$p.Name] = $p.Value }
    }
    if ($Rehash) {
        foreach ($relative in @($manifest.files.Keys)) {
            $path = Join-Path $root $relative
            if (Test-Path -LiteralPath $path -PathType Leaf) {
                $manifest.files[$relative] = (Get-FileHash -LiteralPath $path -Algorithm SHA256).Hash.ToLowerInvariant()
            }
        }
        $dir = Split-Path $manifestPath
        if (!(Test-Path $dir)) { New-Item -ItemType Directory -Path $dir -Force | Out-Null }
        $json = $manifest | ConvertTo-Json -Depth 10
        [IO.File]::WriteAllText($manifestPath,$json + "`n",[Text.UTF8Encoding]::new($false))
        Write-Output $(if ($lang -eq 'ko') { "$($manifest.files.Count)$($messages.ko.rehashed)" } else { "Rehashed $($manifest.files.Count) $($messages.en.rehashed)" })
    }
    if ($Status) {
        foreach ($relative in ($manifest.files.Keys | Sort-Object)) {
            $path = Join-Path $root $relative
            if (!(Test-Path -LiteralPath $path -PathType Leaf)) { Write-Output "$($messages[$lang].missing) $relative"; continue }
            $hash = (Get-FileHash -LiteralPath $path -Algorithm SHA256).Hash
            if ($hash -ne $manifest.files[$relative]) { Write-Output "$($messages[$lang].modified) $relative" }
        }
    }
} catch {
    if ($lang -eq 'ko') { Write-Error 'manifest를 확인하지 못했습니다.' } else { Write-Error 'Could not inspect manifest.' }
}
