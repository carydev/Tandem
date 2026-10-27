param([Parameter(Mandatory=$true)][string]$Review,[string]$Response,[int]$MinFindings=3)
try { [Console]::OutputEncoding = [Text.UTF8Encoding]::new($false) } catch {}  # UTF-8 stdout: PS 5.1 defaults to the OEM code page (cp949 on Korean Windows), which garbles non-ASCII output read by Bash/Claude
$ErrorActionPreference = 'Stop'
# Checks an R2 review file against the verdict schema (confirmed / needs_validation / rejected) and,
# with -Response, checks that an R3 response answers every finding ID. Always exits 0; the first output line is
# "status=ok|warn|fail findings=N confirmed=N needs_validation=N rejected=N" followed by one line per issue.
try {
    $root = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..\..'))
    function Resolve([string]$p) { if ([IO.Path]::IsPathRooted($p)) { return [IO.Path]::GetFullPath($p) }; return [IO.Path]::GetFullPath((Join-Path $root $p)) }
    $lang = 'en'
    try { $saved = (Get-Content -LiteralPath (Join-Path $root 'tandem/config.json') -Raw -Encoding UTF8 | ConvertFrom-Json).lang; if ($saved -in @('ko','en')) { $lang = $saved } }
    catch { if ((Get-UICulture).Name -like 'ko*') { $lang = 'ko' } }
    $messages = @{
        ko = @{ missing='검토 파일이 없습니다'; none='판정 줄(F1 [confirmed|needs_validation|rejected] ...)이 없습니다'; dup='ID 중복'; order='ID 번호가 1부터 이어지지 않습니다'
                severity='confirmed 는 심각도 [높음|중간|낮음] 가 필요합니다'; evidence='confirmed 는 근거= 가 필요합니다. 근거가 없으면 needs_validation 으로 내립니다'
                nvSeverity='needs_validation 에는 심각도를 붙이지 않습니다'; unknown='needs_validation 은 미확인= 으로 어떤 사실이 미확인인지 적습니다'; reason='rejected 는 이유= 가 필요합니다'
                few='confirmed+needs_validation 이 {0}개 미만입니다. 동의만 하는 답으로 간주합니다'; noResponse='R3 응답 파일이 없습니다'; unanswered='R3 응답 없음'; badAnswer='R3 응답은 fixed|disputed|deferred 중 하나여야 합니다' }
        en = @{ missing='Review file not found'; none='No verdict lines (F1 [confirmed|needs_validation|rejected] ...)'; dup='Duplicate ID'; order='IDs do not run from 1 in order'
                severity='confirmed needs a severity [high|medium|low]'; evidence='confirmed needs evidence=; without evidence, downgrade to needs_validation'
                nvSeverity='needs_validation must not carry a severity'; unknown='needs_validation needs unknown= stating which fact is unverified'; reason='rejected needs reason='
                few='Fewer than {0} confirmed+needs_validation findings; treated as agreement only'; noResponse='R3 response file not found'; unanswered='No R3 answer'; badAnswer='R3 answer must be fixed|disputed|deferred' }
    }
    $m = $messages[$lang]
    $issues = New-Object 'System.Collections.Generic.List[string]'
    $reviewPath = Resolve $Review
    if (-not (Test-Path -LiteralPath $reviewPath -PathType Leaf)) { Write-Output "status=fail findings=0 confirmed=0 needs_validation=0 rejected=0"; Write-Output "- $($m.missing): $Review"; exit 0 }
    $text = [IO.File]::ReadAllText($reviewPath, [Text.Encoding]::UTF8)
    $pattern = '^\s*-?\s*(F\d+)\s*\[(confirmed|needs_validation|rejected)\]\s*(?:\[(높음|중간|낮음|high|medium|low)\])?\s*(.*)$'
    $findings = @()
    foreach ($line in ($text -split "`r?`n")) {
        $match = [regex]::Match($line, $pattern, 'IgnoreCase')
        if ($match.Success) { $findings += [pscustomobject]@{ id=$match.Groups[1].Value.ToUpperInvariant(); verdict=$match.Groups[2].Value.ToLowerInvariant(); severity=$match.Groups[3].Value; rest=$match.Groups[4].Value } }
    }
    $counts = @{ confirmed=0; needs_validation=0; rejected=0 }
    foreach ($f in $findings) { $counts[$f.verdict]++ }
    $status = 'ok'
    if ($findings.Count -eq 0) { $status = 'fail'; $issues.Add("- $($m.none)") }
    else {
        $ids = @($findings | ForEach-Object { $_.id })
        $seen = New-Object 'System.Collections.Generic.HashSet[string]'
        foreach ($id in $ids) { if (-not $seen.Add($id)) { $issues.Add("- $($id): $($m.dup)") } }
        $expected = 1..$findings.Count | ForEach-Object { "F$_" }
        if (($ids -join ',') -ne ($expected -join ',') -and $seen.Count -eq $ids.Count) { $issues.Add("- $($m.order)") }
        foreach ($f in $findings) {
            $hasEvidence = $f.rest -match '(근거|evidence)\s*='
            $hasUnknown = $f.rest -match '(미확인|unknown)\s*='
            $hasReason = $f.rest -match '(이유|reason)\s*='
            switch ($f.verdict) {
                'confirmed' { if (-not $f.severity) { $issues.Add("- $($f.id): $($m.severity)") }; if (-not $hasEvidence) { $issues.Add("- $($f.id): $($m.evidence)") } }
                'needs_validation' { if ($f.severity) { $issues.Add("- $($f.id): $($m.nvSeverity)") }; if (-not $hasUnknown) { $issues.Add("- $($f.id): $($m.unknown)") } }
                'rejected' { if (-not $hasReason) { $issues.Add("- $($f.id): $($m.reason)") } }
            }
        }
        if (($counts.confirmed + $counts.needs_validation) -lt $MinFindings) { $issues.Add('- ' + ($m.few -f $MinFindings)) }
        if ($Response) {
            $responsePath = Resolve $Response
            if (-not (Test-Path -LiteralPath $responsePath -PathType Leaf)) { $issues.Add("- $($m.noResponse): $Response") }
            else {
                $answers = @{}
                foreach ($line in ([IO.File]::ReadAllText($responsePath, [Text.Encoding]::UTF8) -split "`r?`n")) {
                    $a = [regex]::Match($line, '^\s*-?\s*(F\d+)\s*\[?\s*([A-Za-z_]+)\s*\]?', 'IgnoreCase')
                    if ($a.Success -and -not $answers.ContainsKey($a.Groups[1].Value.ToUpperInvariant())) { $answers[$a.Groups[1].Value.ToUpperInvariant()] = $a.Groups[2].Value.ToLowerInvariant() }
                }
                foreach ($f in $findings | Where-Object { $_.verdict -ne 'rejected' }) {
                    if (-not $answers.ContainsKey($f.id)) { $issues.Add("- $($f.id): $($m.unanswered)") }
                    elseif ($answers[$f.id] -notin @('fixed','disputed','deferred')) { $issues.Add("- $($f.id): $($m.badAnswer) ($($answers[$f.id]))") }
                }
            }
        }
        if ($issues.Count -gt 0) { $status = 'warn' }
    }
    Write-Output "status=$status findings=$($findings.Count) confirmed=$($counts.confirmed) needs_validation=$($counts.needs_validation) rejected=$($counts.rejected)"
    foreach ($issue in $issues) { Write-Output $issue }
} catch { Write-Output 'status=fail findings=0 confirmed=0 needs_validation=0 rejected=0'; Write-Output "- $($_.Exception.Message)" }
exit 0
