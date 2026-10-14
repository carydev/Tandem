param([Parameter(Mandatory=$true)][string]$Task,[string]$Out)
$ErrorActionPreference='Continue'
$utf8=[Text.UTF8Encoding]::new($false)
try { [Console]::OutputEncoding=$utf8 } catch {}
function GitNames([string]$arguments,[string]$workingDirectory) {
    $start=New-Object Diagnostics.ProcessStartInfo
    $start.FileName='git.exe'
    $start.Arguments=$arguments
    $start.WorkingDirectory=$workingDirectory
    $start.UseShellExecute=$false
    $start.RedirectStandardOutput=$true
    $start.RedirectStandardError=$true
    $proc=[Diagnostics.Process]::Start($start)
    $stream=New-Object IO.MemoryStream
    $proc.StandardOutput.BaseStream.CopyTo($stream)
    $proc.WaitForExit()
    if ($proc.ExitCode -ne 0) { throw 'git file listing failed' }
    return ,@($utf8.GetString($stream.ToArray()).TrimEnd([char]0) -split [char]0)
}
try {
    $root=(Get-Location).Path
    $docs='docs/tandem'
    $lang=if ((Get-UICulture).Name -like 'ko*') {'ko'} else {'en'}
    $config=Join-Path $root 'tandem/config.json'
    if (Test-Path -LiteralPath $config) {
        $saved=Get-Content -LiteralPath $config -Raw -Encoding UTF8 | ConvertFrom-Json
        if ($saved.docs_root) { $docs=[string]$saved.docs_root }
        if ($saved.lang -in @('ko','en')) { $lang=[string]$saved.lang }
    }
    $safe=$Task -replace '[^A-Za-z0-9_-]','_'
    if (!$Out) { $Out=Join-Path (Join-Path $root $docs) ('reports/review/'+$safe+'.diff') }
    $path=[IO.Path]::GetFullPath($Out)
    $parts=New-Object 'System.Collections.Generic.List[string]'
    $inside=& git rev-parse --is-inside-work-tree 2>$null
    if ($LASTEXITCODE -ne 0 -or $inside -ne 'true') {
        $parts.Add($(if ($lang -eq 'ko') {'Git 저장소가 아닙니다.'} else {'Not a Git repository.'}))
    } else {
        & git rev-parse --verify HEAD 1>$null 2>$null
        $base=if ($LASTEXITCODE -eq 0) {'HEAD'} else {''}
        $trackedNames=GitNames ('diff --name-only -z '+$base) $root
        foreach ($name in $trackedNames) {
            if (!$name) { continue }
            $full=Join-Path $root $name
            if ((Test-Path -LiteralPath $full -PathType Leaf) -and (Get-Item -LiteralPath $full).Length -gt 204800) {
                $parts.Add(($(if ($lang -eq 'ko') {'큰 변경 파일: {0} ({1} 바이트)'} else {'Large changed file: {0} ({1} bytes)'}) -f $name,(Get-Item -LiteralPath $full).Length))
                continue
            }
            $patch=if ($base) { @(& git -c core.quotepath=false diff --no-ext-diff HEAD -- $name) } else { @(& git -c core.quotepath=false diff --no-ext-diff -- $name) }
            if ($patch.Count) { $parts.Add(($patch -join "`n")) }
        }

        # -z preserves spaces and newlines in untracked file names.
        $names=GitNames 'ls-files --others --exclude-standard -z' $root
        foreach ($name in $names) {
            if (!$name) { continue }
            $full=Join-Path $root $name
            if ([IO.Path]::GetFullPath($full) -eq $path) { continue }
            if (!(Test-Path -LiteralPath $full -PathType Leaf)) { continue }
            $info=Get-Item -LiteralPath $full
            if ($info.Length -gt 204800) {
                $parts.Add(($(if ($lang -eq 'ko') {'큰 새 파일: {0} ({1} 바이트)'} else {'Large untracked file: {0} ({1} bytes)'}) -f $name,$info.Length))
                continue
            }
            $bytes=[IO.File]::ReadAllBytes($full)
            $binary=($bytes -contains [byte]0)
            if (!$binary) { try { [Text.UTF8Encoding]::new($false,$true).GetString($bytes) | Out-Null } catch { $binary=$true } }
            if ($binary) { $parts.Add(($(if ($lang -eq 'ko') {'바이너리 새 파일: '} else {'Binary untracked file: '})+$name)); continue }
            $patch=@(& git -c core.quotepath=false diff --no-index --no-ext-diff -- NUL $name 2>$null)
            if ($patch.Count) { $parts.Add(($patch -join "`n")) }
        }
    }
    [IO.Directory]::CreateDirectory((Split-Path -Parent $path)) | Out-Null
    [IO.File]::WriteAllText($path,($parts -join "`n"),$utf8)
    Write-Output $path
    exit 0
} catch {
    Write-Error $_
    exit 1
}
