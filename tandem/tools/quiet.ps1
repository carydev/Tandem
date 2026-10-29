param(
    [Parameter(Position=0)][string]$Command,
    [string]$Name='run',
    [ValidateSet('cmd','powershell')][string]$Shell='cmd',
    [int]$Max=30,[int]$Tail=15,[string]$Pattern
)
# Runs a noisy command (build, test, install) with the full output saved to a log file.
# Prints only the exit code, matching problem lines and the last lines, so long output never enters the context.
try { [Console]::OutputEncoding = [Text.UTF8Encoding]::new($false) } catch {}
$ErrorActionPreference = 'Stop'
$lang = 'ko'
try {
    $root = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..\..'))
    $configPath = Join-Path $root 'tandem/config.json'
    $config = if (Test-Path $configPath) { Get-Content $configPath -Raw -Encoding UTF8 | ConvertFrom-Json } else { $null }
    $lang = if ($config -and $config.lang -eq 'en') { 'en' } elseif ($config) { 'ko' } elseif ((Get-UICulture).Name -like 'ko*') { 'ko' } else { 'en' }
    $m = @{
        ko = @{ usage='사용법: quiet.ps1 -Command "<명령>" [-Name <이름>] [-Shell cmd|powershell] [-Max 30] [-Tail 15] [-Pattern <정규식>]'; hits='--- 문제 줄 {0}/{1} ---'; tail='--- 끝 {0}줄 ---'; more='전체 로그에서 찾기: Select-String -Path {0} -Pattern <단어>' }
        en = @{ usage='Usage: quiet.ps1 -Command "<command>" [-Name <name>] [-Shell cmd|powershell] [-Max 30] [-Tail 15] [-Pattern <regex>]'; hits='--- problem lines {0}/{1} ---'; tail='--- last {0} lines ---'; more='Search the full log: Select-String -Path {0} -Pattern <word>' }
    }[$lang]
    if (!$Command) { Write-Output $m.usage; exit 0 }
    $logDir = Join-Path $root 'tandem/.cache/quiet'
    [IO.Directory]::CreateDirectory($logDir) | Out-Null
    $safe = [regex]::Replace($Name,'[^A-Za-z0-9._-]','_'); if (!$safe) { $safe = 'run' }
    $log = Join-Path $logDir ((Get-Date -Format 'yyyyMMdd-HHmmss') + '-' + $safe + '.log')
    $watch = [Diagnostics.Stopwatch]::StartNew()
    Push-Location $root
    try {
        if ($Shell -eq 'cmd') {
            & cmd.exe /d /s /c "`"$Command > `"$log`" 2>&1`""
            $code = $LASTEXITCODE
        } else {
            $script = "& { $Command } *>&1 | Out-File -LiteralPath '$($log.Replace("'","''"))' -Encoding utf8 -Width 4096; exit `$LASTEXITCODE"
            & powershell.exe -NoProfile -ExecutionPolicy Bypass -Command $script
            $code = $LASTEXITCODE
        }
    } finally { Pop-Location }
    $watch.Stop()
    $bytes = if (Test-Path -LiteralPath $log) { [IO.File]::ReadAllBytes($log) } else { [byte[]]@() }
    # Tools on Korean Windows often print cp949; fall back when the log is not valid UTF-8.
    try { $text = [Text.UTF8Encoding]::new($false,$true).GetString($bytes) } catch { $text = [Text.Encoding]::Default.GetString($bytes) }
    $text = $text.TrimStart([char]0xFEFF)
    $lines = @($text -split "`r?`n")
    if ($lines.Count -and $lines[-1] -eq '') { $lines = @($lines | Select-Object -SkipLast 1) }
    $rx = if ($Pattern) { $Pattern } else { '(?i)(\berror\b|\berrors?:|\bfail(ed|ure|s)?\b|exception|traceback|assert|panic|fatal|denied|cannot |unable to|not found|오류|실패|에러|예외)' }
    $hits = New-Object System.Collections.Generic.List[string]; $total = 0; $prev = $null; $repeat = 0
    foreach ($l in $lines) {
        if ($l -notmatch $rx) { continue }
        $total++
        $short = if ($l.Length -gt 300) { $l.Substring(0,300) + '...' } else { $l }
        if ($short -eq $prev) { $repeat++; continue }
        if ($repeat) { $hits.Add("  (x$($repeat+1))"); $repeat = 0 }
        if ($hits.Count -lt $Max) { $hits.Add($short) }
        $prev = $short
    }
    if ($repeat) { $hits.Add("  (x$($repeat+1))") }
    $relLog = $log.Substring($root.Length).TrimStart('\').Replace('\','/')
    Write-Output ("exit=$code lines=$($lines.Count) time={0:n1}s log=$relLog" -f $watch.Elapsed.TotalSeconds)
    if ($hits.Count) { Write-Output ($m.hits -f [Math]::Min($Max,$total),$total); $hits | ForEach-Object { Write-Output $_ } }
    $tailCount = if ($code -eq 0 -and !$hits.Count) { [Math]::Min(5,$Tail) } else { $Tail }
    if ($lines.Count) {
        Write-Output ($m.tail -f [Math]::Min($tailCount,$lines.Count))
        $lines | Select-Object -Last $tailCount | ForEach-Object { if ($_.Length -gt 300) { $_.Substring(0,300) + '...' } else { $_ } } | ForEach-Object { Write-Output $_ }
    }
    if ($code -ne 0 -or $total -gt $Max) { Write-Output ($m.more -f $relLog) }
    # Keep the cache small: newest 30 logs only.
    Get-ChildItem -LiteralPath $logDir -Filter '*.log' -File | Sort-Object LastWriteTime -Descending | Select-Object -Skip 30 | Remove-Item -Force -ErrorAction SilentlyContinue
    exit $(if ($code -is [int]) { $code } else { 0 })
} catch {
    if ($lang -eq 'en') { Write-Output "quiet failed: $($_.Exception.Message)" } else { Write-Output "quiet 실행 실패: $($_.Exception.Message)" }
    exit 1
}
