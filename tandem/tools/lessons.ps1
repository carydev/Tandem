param([string[]]$Tags,[int]$Top=3,[string]$Path)
try { [Console]::OutputEncoding = [Text.UTF8Encoding]::new($false) } catch {}  # UTF-8 stdout: PS 5.1 defaults to the OEM code page (cp949 on Korean Windows), which garbles non-ASCII output read by Bash/Claude
$ErrorActionPreference = 'Stop'
# Prints the lessons.md lines that match any of -Tags, highest hit count "(xN)" first, then newest date first, at most -Top lines.
# Nothing is printed when the file does not exist or nothing matches. Reads only; the card author edits lessons.md by hand.
try {
    $root = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..\..'))
    if (-not $Path) {
        $docs = 'docs/tandem'
        try { $saved = (Get-Content -LiteralPath (Join-Path $root 'tandem/config.json') -Raw -Encoding UTF8 | ConvertFrom-Json).docs_root; if ($saved) { $docs = [string]$saved } } catch {}
        $Path = Join-Path $docs 'lessons/lessons.md'
    }
    $full = if ([IO.Path]::IsPathRooted($Path)) { [IO.Path]::GetFullPath($Path) } else { [IO.Path]::GetFullPath((Join-Path $root $Path)) }
    if (-not (Test-Path -LiteralPath $full -PathType Leaf)) { exit 0 }
    $wanted = @($Tags | ForEach-Object { $_ -split ',' } | ForEach-Object { $_.Trim().ToLowerInvariant() } | Where-Object { $_ })
    $rows = @()
    foreach ($line in ([IO.File]::ReadAllText($full, [Text.Encoding]::UTF8) -split "`r?`n")) {
        $match = [regex]::Match($line, '^\s*-\s*(\d{4}-\d{2}-\d{2})\s*\[([^\]]*)\]')
        if (-not $match.Success) { continue }
        $lineTags = @($match.Groups[2].Value -split ',' | ForEach-Object { $_.Trim().ToLowerInvariant() } | Where-Object { $_ })
        if ($wanted.Count -gt 0 -and -not @($lineTags | Where-Object { $wanted -contains $_ }).Count) { continue }
        $hits = 1
        $count = [regex]::Match($line, '\(x(\d+)\)\s*$')
        if ($count.Success) { $hits = [int]$count.Groups[1].Value }
        $rows += [pscustomobject]@{ hits=$hits; date=$match.Groups[1].Value; line=$line.TrimEnd() }
    }
    $rows | Sort-Object @{Expression='hits';Descending=$true}, @{Expression='date';Descending=$true} | Select-Object -First ([Math]::Max(1,$Top)) | ForEach-Object { Write-Output $_.line }
} catch {}
exit 0
