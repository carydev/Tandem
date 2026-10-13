param([switch]$Rehash,[switch]$Status)
$ErrorActionPreference = 'Stop'
try {
    $root = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..\..'))
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
        Write-Output ("Rehashed {0} files" -f $manifest.files.Count)
    }
    if ($Status) {
        foreach ($relative in ($manifest.files.Keys | Sort-Object)) {
            $path = Join-Path $root $relative
            if (!(Test-Path -LiteralPath $path -PathType Leaf)) { Write-Output "missing $relative"; continue }
            $hash = (Get-FileHash -LiteralPath $path -Algorithm SHA256).Hash
            if ($hash -ne $manifest.files[$relative]) { Write-Output "modified $relative" }
        }
    }
} catch { Write-Error $_ }
