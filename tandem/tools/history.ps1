param(
    [Parameter(Position=0)][string]$Command='index',
    [Parameter(Position=1)][string]$Query,
    [string]$Topic,[string]$Did,[string]$Next,[string]$Decision,[string[]]$Files,[string]$Blocked,[string[]]$Task,
    [string]$Goal,[string]$By,[string]$Line,[int]$Entry=0,[int]$Last=2,[switch]$New,[switch]$Quiet
)
# Topic history: <docs>/history/<topic>.md (summary card + numbered entries), archive/, INDEX.md, .state.json.
# Reading cost stays flat: INDEX at session start, then one topic's card and latest entries; older entries rotate to archive/.
try { [Console]::OutputEncoding = [Text.UTF8Encoding]::new($false) } catch {}
$ErrorActionPreference = 'Stop'
$utf8 = [Text.UTF8Encoding]::new($false)
$inv = [Globalization.CultureInfo]::InvariantCulture
function Has($o,[string]$name) { return ($null -ne $o) -and ($o.PSObject.Properties[$name]) -and ($null -ne $o.$name) }
function Now { return [datetimeoffset]::Now }
function Stamp($t) { return $t.ToString('yyyy-MM-dd HH:mm',$inv) }
function Say([string]$text) { if (!$Quiet) { Write-Output $text } }
function Clip([string]$t,[int]$n) { $t = ([string]$t).Replace("`r",' ').Replace("`n",' ').Trim(); if ($t.Length -gt $n) { return $t.Substring(0,$n-1) + [char]0x2026 }; return $t }
function WriteAtomic([string]$path,[string]$text) {
    $tmp = $path + '.tmp'
    [IO.File]::WriteAllText($tmp,$text,$utf8)
    if (Test-Path -LiteralPath $path) { [IO.File]::Replace($tmp,$path,[NullString]::Value) } else { [IO.File]::Move($tmp,$path) }
}
function Slug([string]$name) { $s = [regex]::Replace($name.Trim(),'[\\/:*?"<>|\s]+','-').Trim('-','.'); if (!$s) { $s = 'topic' }; return $s }
function Distance([string]$a,[string]$b) {
    $a = $a.ToLowerInvariant(); $b = $b.ToLowerInvariant()
    $prev = New-Object 'int[]' ($b.Length+1); $cur = New-Object 'int[]' ($b.Length+1)
    for ($j=0; $j -le $b.Length; $j++) { $prev[$j] = $j }
    for ($i=1; $i -le $a.Length; $i++) {
        $cur[0] = $i
        for ($j=1; $j -le $b.Length; $j++) {
            $cost = 1; if ($a[$i-1] -eq $b[$j-1]) { $cost = 0 }
            $best = $prev[$j] + 1
            if ($cur[$j-1] + 1 -lt $best) { $best = $cur[$j-1] + 1 }
            if ($prev[$j-1] + $cost -lt $best) { $best = $prev[$j-1] + $cost }
            $cur[$j] = $best
        }
        $tmp = $prev; $prev = $cur; $cur = $tmp
    }
    return $prev[$b.Length]
}
function Ago($iso) {
    $t = [datetimeoffset]::MinValue
    if (![datetimeoffset]::TryParse([string]$iso,$inv,[Globalization.DateTimeStyles]::None,[ref]$t)) { return '' }
    $s = ((Now) - $t).TotalSeconds
    if ($s -lt 3600) { return ($m.min -f [Math]::Max(1,[int]($s/60))) }
    if ($s -lt 86400) { return ($m.hour -f [int]($s/3600)) }
    return ($m.day -f [int]($s/86400))
}
function RunGit([string[]]$gitArgs) {
    try { $out = & git -C $root @gitArgs 2>$null; if ($LASTEXITCODE -ne 0) { return @() }; return @($out) } catch { return @() }
}
function SplitEntries([string]$text) {
    # Entries start with '### #<n>'. Returns list of @{n; text}.
    $list = New-Object System.Collections.Generic.List[object]
    $matches2 = [regex]::Matches($text,'(?m)^### #(\d+)[^\r\n]*')
    for ($i=0; $i -lt $matches2.Count; $i++) {
        $start = $matches2[$i].Index
        $end = if ($i+1 -lt $matches2.Count) { $matches2[$i+1].Index } else { $text.Length }
        $list.Add([pscustomobject]@{n=[int]$matches2[$i].Groups[1].Value; text=$text.Substring($start,$end-$start).TrimEnd()})
    }
    return ,$list
}
function FindTopic([string]$name) {
    foreach ($p in $state.topics.PSObject.Properties) { if ($p.Name -ieq $name.Trim()) { return $p.Name } }
    return $null
}
function TopicPath([string]$name) { return Join-Path $dir ($state.topics.$name.slug + '.md') }
function SummaryLines([string]$name) {
    $t = $state.topics.$name; $o = New-Object System.Collections.Generic.List[string]
    if (Has $t 'goal') { $o.Add("- $($m.goal): $($t.goal)") }
    if (Has $t 'last') { $o.Add("- $($m.now): #$($t.last.n) · $($t.last.at) · $($t.last.did)") }
    if (Has $t 'next') { $o.Add("- $($m.next): $($t.next)") }
    if (Has $t 'blocked') { $o.Add("- $($m.blocked): $($t.blocked)") }
    if (@($t.decisions).Count) { $o.Add("- $($m.decisions): " + (@($t.decisions) -join ' / ')) }
    if (@($t.files).Count) { $o.Add("- $($m.files): " + (@($t.files) -join ', ')) }
    if (@($t.tasks).Count) { $o.Add("- $($m.tasks): " + (@($t.tasks) -join ', ')) }
    if (@($t.runs).Count) { $o.Add("- $($m.runs): " + (@($t.runs) -join ' / ')) }
    foreach ($a in @($t.archived)) { $o.Add("- $($m.archive): archive/$($a.file) (#$($a.from)-#$($a.to))") }
    return ,$o
}
function RenderTopic([string]$name,[string]$entriesText) {
    $body = "# $name`n`n<!-- summary:start -->`n" + ((SummaryLines $name) -join "`n") + "`n<!-- summary:end -->`n`n## $($m.log)`n"
    if ($entriesText.Trim()) { $body += "`n" + $entriesText.Trim() + "`n" }
    return $body
}
function EntriesOf([string]$path) {
    if (!(Test-Path -LiteralPath $path)) { return '' }
    $text = [IO.File]::ReadAllText($path,[Text.Encoding]::UTF8)
    $at = $text.IndexOf("`n## $($m.log)")
    if ($at -lt 0) { $at = [regex]::Match($text,'(?m)^## (기록|Log)\s*$').Index }
    $first = [regex]::Match($text,'(?m)^### #\d+')
    if (!$first.Success) { return '' }
    return $text.Substring($first.Index)
}
function BuildIndex {
    $o = New-Object System.Collections.Generic.List[string]
    $names = @($state.topics.PSObject.Properties | ForEach-Object { $_.Name })
    if (!$names.Count) { return '' }
    $sorted = @($names | Sort-Object { [datetimeoffset]::Parse([string]$state.topics.$_.updated,$inv) } -Descending)
    $cut = (Now).AddDays(-$activeDays)
    $active = New-Object System.Collections.Generic.List[string]; $rest = New-Object System.Collections.Generic.List[string]
    foreach ($n in $sorted) {
        $u = [datetimeoffset]::Parse([string]$state.topics.$n.updated,$inv)
        if ($u -ge $cut -and $active.Count -lt $activeMax) { $active.Add($n) } else { $rest.Add($n) }
    }
    $o.Add($m.indexHead)
    foreach ($n in $active) {
        $t = $state.topics.$n
        $lineText = "- $n #$($t.count) · $(Ago $t.updated)"
        if (Has $t 'next') { $lineText += " · $($m.next): $(Clip $t.next 70)" }
        if (Has $t 'blocked') { $lineText += " · $($m.blocked): $(Clip $t.blocked 50)" }
        $o.Add($lineText)
    }
    if ($rest.Count) { $o.Add(($m.dormant -f $rest.Count) + ' ' + (Clip ($rest -join ', ') 200)) }
    $o.Add($m.howTo)
    return ($o -join "`n")
}
function SaveAll([string[]]$touched) {
    foreach ($name in $touched) { $p = TopicPath $name; WriteAtomic $p (RenderTopic $name (EntriesOf $p)) }
    $state.updated = (Now).ToString('o')
    WriteAtomic $statePath ($state | ConvertTo-Json -Depth 8)
    $index = BuildIndex
    WriteAtomic $indexPath ("# $($m.indexTitle)`n`n" + $index + "`n")
}
$lang = 'ko'
try {
    $root = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..\..'))
    $configPath = Join-Path $root 'tandem/config.json'
    $config = if (Test-Path $configPath) { Get-Content $configPath -Raw -Encoding UTF8 | ConvertFrom-Json } else { $null }
    $lang = if ($config -and $config.lang -eq 'en') { 'en' } elseif ($config) { 'ko' } elseif ((Get-UICulture).Name -like 'ko*') { 'ko' } else { 'en' }
    $hc = if ($config -and (Has $config 'history')) { $config.history } else { $null }
    $maxChars = if ($hc -and (Has $hc 'max_chars')) { [int]$hc.max_chars } else { 1500 }
    $maxEntries = if ($hc -and (Has $hc 'max_entries')) { [int]$hc.max_entries } else { 20 }
    $keep = if ($hc -and (Has $hc 'keep')) { [int]$hc.keep } else { 10 }
    $activeDays = if ($hc -and (Has $hc 'active_days')) { [int]$hc.active_days } else { 30 }
    $activeMax = if ($hc -and (Has $hc 'active_max')) { [int]$hc.active_max } else { 15 }
    $docsRoot = if ($config -and $config.docs_root) { [string]$config.docs_root } else { 'docs/tandem' }
    $docsRel = $docsRoot.Replace('\','/').TrimEnd('/')
    $dir = Join-Path (Join-Path $root $docsRoot) 'history'
    $archiveDir = Join-Path $dir 'archive'
    $statePath = Join-Path $dir '.state.json'; $indexPath = Join-Path $dir 'INDEX.md'
    $m = @{
        ko = @{ goal='목표'; now='현재'; next='다음'; blocked='막힘'; decisions='결정'; files='파일'; tasks='과제'; runs='최근 실행'; archive='보관'; log='기록'; did='한 일'
                indexTitle='작업 히스토리 목차'; indexHead='작업 히스토리 (주제 #최근번호 · 마지막 기록 · 다음 할 일):'
                howTo="요청이 위 주제면 먼저 ``powershell -NoProfile -ExecutionPolicy Bypass -File tandem/tools/history.ps1 show -Topic <주제>`` 로 요약과 최신 기록만 읽고 이어간다. 히스토리 파일 전체를 읽지 않는다. 지난 내용은 ``history.ps1 search <단어>``."
                dormant='보관 주제 {0}개:'; min='{0}분 전'; hour='{0}시간 전'; day='{0}일 전'
                usage='사용법: history.ps1 add|show|search|index|brief|run  (add -Topic <주제> -Did <한 일> -Next <다음> -Decision <결정 또는 없음> [-Files a,b] [-Blocked ..] [-Task T-1] [-Goal ..] [-New])'
                need='-Topic, -Did, -Next, -Decision 이 필요합니다 (결정이 없으면 -Decision 없음)'; similar='비슷한 주제가 있습니다: {0}. 같은 주제면 그 이름으로, 새 주제면 -New 를 붙이세요.'
                none='주제 없음: {0}'; noentry='기록 없음: #{0}'; nohits='찾은 기록 없음'; changed='주의: #{0} 이후 바뀐 파일 - {1}'; dirty='주의: 커밋 안 된 변경 - {1}'; other='주의: {0} #{1} ({2})가 같은 파일을 다룸 - {3}'
                added='{0} #{1} 기록, 목차 갱신'; rotated='{0} 오래된 기록 #{1}-#{2} 를 archive/{3} 로 옮김' }
        en = @{ goal='Goal'; now='Now'; next='Next'; blocked='Blocked'; decisions='Decisions'; files='Files'; tasks='Tasks'; runs='Recent runs'; archive='Archive'; log='Log'; did='Did'
                indexTitle='Work history index'; indexHead='Work history (topic #latest · last entry · next step):'
                howTo="If the request matches a topic above, first run ``powershell -NoProfile -ExecutionPolicy Bypass -File tandem/tools/history.ps1 show -Topic <topic>`` to read only its summary and latest entries, then continue. Never read whole history files. For older details use ``history.ps1 search <words>``."
                dormant='{0} dormant topics:'; min='{0}m ago'; hour='{0}h ago'; day='{0}d ago'
                usage='Usage: history.ps1 add|show|search|index|brief|run  (add -Topic <topic> -Did <done> -Next <next> -Decision <decision or none> [-Files a,b] [-Blocked ..] [-Task T-1] [-Goal ..] [-New])'
                need='-Topic, -Did, -Next and -Decision are required (use -Decision none when there is none)'; similar='Similar topic exists: {0}. Use that name for the same topic, or add -New for a new one.'
                none='No such topic: {0}'; noentry='No entry: #{0}'; nohits='No matching entries'; changed='Note: files changed since #{0} - {1}'; dirty='Note: uncommitted changes - {1}'; other='Note: {0} #{1} ({2}) touched the same files - {3}'
                added='{0} #{1} recorded, index updated'; rotated='{0}: moved old entries #{1}-#{2} to archive/{3}' }
    }[$lang]
    $Command = $Command.ToLowerInvariant()
    if ($Command -notin @('add','show','search','index','brief','run')) { Write-Output $m.usage; exit 0 }
    if ($Command -eq 'brief') {
        # SessionStart hook (startup/resume/clear/compact). Prints nothing when off or empty, so it costs nothing until used.
        if ($env:TANDEM_HOOK_OFF -eq '1') { exit 0 }
        if ($hc -and (Has $hc 'inject') -and $hc.inject -eq $false) { exit 0 }
        if (!(Test-Path -LiteralPath $statePath)) { exit 0 }
    }
    $state = $null
    if (Test-Path -LiteralPath $statePath) { try { $state = [IO.File]::ReadAllText($statePath,[Text.Encoding]::UTF8) | ConvertFrom-Json } catch { $state = $null } }
    if (!$state) { $state = [pscustomobject]@{version=1; updated=$null; topics=[pscustomobject]@{}} }
    if (!(Has $state 'topics')) { $state | Add-Member -NotePropertyName topics -NotePropertyValue ([pscustomobject]@{}) -Force }

    if ($Command -eq 'brief') {
        $text = BuildIndex
        if (!$text) { exit 0 }
        if ($text.Length -gt $maxChars) { $text = $text.Substring(0,[Math]::Max(0,$maxChars-3)) + '...' }
        $json = @{hookSpecificOutput=@{hookEventName='SessionStart';additionalContext=$text}} | ConvertTo-Json -Compress -Depth 4
        $ascii = [regex]::Replace($json,'[^\x00-\x7F]',{param($c) '\u{0:x4}' -f [int][char]$c.Value[0]})
        [Console]::Out.WriteLine($ascii)
        exit 0
    }
    if ($Command -eq 'index') { $text = BuildIndex; if ($text) { Write-Output $text }; exit 0 }
    if ($Command -eq 'search') {
        $words = @(([string]$Query).Split(' ',[StringSplitOptions]::RemoveEmptyEntries))
        if (!$words.Count -or !(Test-Path -LiteralPath $dir)) { Write-Output $m.nohits; exit 0 }
        $hits = New-Object System.Collections.Generic.List[object]
        $mdFiles = @(@(Get-ChildItem -LiteralPath $dir -Filter '*.md' -File) + @(if (Test-Path -LiteralPath $archiveDir) { Get-ChildItem -LiteralPath $archiveDir -Filter '*.md' -File }) | Where-Object { $_ })
        foreach ($f in $mdFiles) {
            if ($f.Name -eq 'INDEX.md' -or $f.Name -eq 'README.md') { continue }
            $topicName = ([regex]::Match([IO.File]::ReadAllText($f.FullName,[Text.Encoding]::UTF8),'(?m)^# (.+)$')).Groups[1].Value.Trim()
            if ($Topic -and $topicName -ine $Topic.Trim()) { continue }
            foreach ($e in (SplitEntries ([IO.File]::ReadAllText($f.FullName,[Text.Encoding]::UTF8)))) {
                $ok = $true; foreach ($w in $words) { if ($e.text.IndexOf($w,[StringComparison]::OrdinalIgnoreCase) -lt 0) { $ok = $false; break } }
                if (!$ok) { continue }
                $head = ($e.text -split "`n")[0]; $didLine = ([regex]::Match($e.text,'(?m)^- (한 일|Did): (.+)$')).Groups[2].Value
                $when = ([regex]::Match($head,'\d{4}-\d{2}-\d{2} \d{2}:\d{2}')).Value
                $where = if ($f.DirectoryName -eq $archiveDir) { " [archive/$($f.Name)]" } else { '' }
                $hits.Add([pscustomobject]@{when=$when; text=("$topicName #$($e.n) · $when · " + (Clip $didLine 80) + $where)})
            }
        }
        if (!$hits.Count) { Write-Output $m.nohits; exit 0 }
        $hits | Sort-Object when -Descending | Select-Object -First 10 | ForEach-Object { Write-Output $_.text }
        if ($hits.Count -gt 10) { Write-Output "(+$($hits.Count-10))" }
        exit 0
    }
    if ($Command -eq 'show') {
        $name = if ($Topic) { FindTopic $Topic } else { $null }
        if (!$name) { Write-Output ($m.none -f $Topic); $i = BuildIndex; if ($i) { Write-Output $i }; exit 0 }
        $t = $state.topics.$name
        Write-Output "# $name"
        (SummaryLines $name) | ForEach-Object { Write-Output $_ }
        $path = TopicPath $name
        if ($Entry -gt 0) {
            $found = $null
            foreach ($e in (SplitEntries (EntriesOf $path))) { if ($e.n -eq $Entry) { $found = $e } }
            if (!$found -and (Test-Path -LiteralPath $archiveDir)) {
                foreach ($a in @($t.archived)) { if ($Entry -ge [int]$a.from -and $Entry -le [int]$a.to) { foreach ($e in (SplitEntries ([IO.File]::ReadAllText((Join-Path $archiveDir $a.file),[Text.Encoding]::UTF8)))) { if ($e.n -eq $Entry) { $found = $e } } } }
            }
            Write-Output ''
            if ($found) { Write-Output $found.text } else { Write-Output ($m.noentry -f $Entry) }
            exit 0
        }
        $entries = SplitEntries (EntriesOf $path)
        $take = [Math]::Max(1,$Last)
        $from = [Math]::Max(0,$entries.Count-$take)
        for ($i=$from; $i -lt $entries.Count; $i++) { Write-Output ''; Write-Output $entries[$i].text }
        # Is it safe to continue? Compare the files of the latest entry with what changed since.
        if ((Has $t 'last') -and @($t.files).Count) {
            $fileList = @($t.files)
            if (Has $t.last 'commit') {
                $changed = @(RunGit (@('diff','--name-only',[string]$t.last.commit,'HEAD','--') + $fileList))
                if ($changed.Count) { Write-Output ''; Write-Output ($m.changed -f $t.last.n,(($changed | Select-Object -First 8) -join ', ')) }
            }
            $dirty = @(RunGit (@('status','--porcelain','--') + $fileList) | ForEach-Object { $_.Substring([Math]::Min(3,$_.Length)) })
            if ($dirty.Count) { Write-Output ($m.dirty -f $null,(($dirty | Select-Object -First 8) -join ', ')) }
            $mine = [datetimeoffset]::Parse([string]$t.updated,$inv)
            foreach ($p in $state.topics.PSObject.Properties) {
                if ($p.Name -eq $name) { continue }
                $o = $p.Value; if (!(Has $o 'last')) { continue }
                if ([datetimeoffset]::Parse([string]$o.updated,$inv) -le $mine) { continue }
                $shared = @(@($o.last.files) | Where-Object { $fileList -icontains $_ })
                if ($shared.Count) { Write-Output ($m.other -f $p.Name,$o.last.n,(Ago $o.updated),($shared -join ', ')) }
            }
        }
        exit 0
    }

    [IO.Directory]::CreateDirectory($dir) | Out-Null
    $sha = [Security.Cryptography.SHA1]::Create()
    $lockName = 'Global\TANDEM-history-' + ([BitConverter]::ToString($sha.ComputeHash($utf8.GetBytes($dir.ToLowerInvariant())))).Replace('-','').Substring(0,16)
    $mutex = New-Object Threading.Mutex($false,$lockName); $owned = $false
    try {
        try { $owned = $mutex.WaitOne(10000) } catch [Threading.AbandonedMutexException] { $owned = $true }
        if ($owned -and (Test-Path -LiteralPath $statePath)) { try { $state = [IO.File]::ReadAllText($statePath,[Text.Encoding]::UTF8) | ConvertFrom-Json } catch {} }
        if ($Command -eq 'run') {
            # Wrapper hook: attach a one-line run note to the topic that owns this task. Silent when unmapped.
            $ids = @($Task | ForEach-Object { ([string]$_).Split(',') } | ForEach-Object { $_.Trim() } | Where-Object { $_ })
            foreach ($p in $state.topics.PSObject.Properties) {
                $tp = $p.Value
                if (!(@($tp.tasks) | Where-Object { $ids -icontains $_ })) { continue }
                $runs = @(@($tp.runs) + @(Clip $Line 90)); if ($runs.Count -gt 5) { $runs = $runs[($runs.Count-5)..($runs.Count-1)] }
                $tp.runs = $runs; $tp.updated = (Now).ToString('o')
                SaveAll @($p.Name)
            }
            exit 0
        }
        # add
        if (!$Topic -or !$Did -or !$Next -or !$Decision) { Write-Output $m.need; exit 0 }
        $noDecision = @('-','none','n/a','없음','없다') -contains $Decision.Trim().ToLowerInvariant()
        $name = FindTopic $Topic
        if (!$name) {
            if (!$New) {
                $near = @($state.topics.PSObject.Properties | ForEach-Object { $_.Name } | Where-Object {
                    $a = $_.ToLowerInvariant(); $b = $Topic.Trim().ToLowerInvariant()
                    $a.Contains($b) -or $b.Contains($a) -or ((Distance $a $b) -le [Math]::Max(1,[int]([Math]::Min($a.Length,$b.Length)/4)))
                })
                if ($near.Count) { Write-Output ($m.similar -f ($near -join ', ')); exit 0 }
            }
            $name = $Topic.Trim()
            $slug = Slug $name; $taken = @($state.topics.PSObject.Properties | ForEach-Object { $_.Value.slug })
            $k = 2; $base = $slug; while ($taken -icontains $slug) { $slug = "$base-$k"; $k++ }
            $state.topics | Add-Member -NotePropertyName $name -NotePropertyValue ([pscustomobject]@{slug=$slug;goal=$null;created=(Now).ToString('o');updated=(Now).ToString('o');count=0;next=$null;blocked=$null;decisions=@();files=@();tasks=@();runs=@();archived=@();last=$null})
        }
        $t = $state.topics.$name
        $n = [int]$t.count + 1
        $stampNow = Stamp (Now)
        $commit = @(RunGit @('rev-parse','--short','HEAD')) | Select-Object -First 1
        $fileList = @($Files | ForEach-Object { ([string]$_).Split(',') } | ForEach-Object { $_.Trim().Replace('\','/') } | Where-Object { $_ })
        $taskList = @($Task | ForEach-Object { ([string]$_).Split(',') } | ForEach-Object { $_.Trim() } | Where-Object { $_ })
        $head = "### #$n · $stampNow" + $(if ($By) { " · $By" } else { '' }) + $(if ($commit) { " · $commit" } else { '' })
        $body = New-Object System.Collections.Generic.List[string]
        $body.Add($head); $body.Add("- $($m.did): $(Clip $Did 400)")
        if (!$noDecision) { $body.Add("- $($m.decisions): $(Clip $Decision 300)") }
        if ($fileList.Count) { $body.Add("- $($m.files): " + ($fileList -join ', ')) }
        $body.Add("- $($m.next): $(Clip $Next 300)")
        if ($Blocked) { $body.Add("- $($m.blocked): $(Clip $Blocked 200)") }
        if ($taskList.Count) { $body.Add("- $($m.tasks): " + ($taskList -join ', ')) }
        $path = Join-Path $dir ($t.slug + '.md')
        $entriesText = (EntriesOf $path).TrimEnd()
        $entriesText = ($entriesText + "`n`n" + ($body -join "`n")).Trim()
        # Rotation: keep the topic file small; old entries move to archive/ unchanged.
        $entries = SplitEntries $entriesText
        if ($entries.Count -gt $maxEntries) {
            $moveCount = $entries.Count - $keep
            $moving = @(); for ($i=0; $i -lt $moveCount; $i++) { $moving += $entries[$i] }
            [IO.Directory]::CreateDirectory($archiveDir) | Out-Null
            $part = @($t.archived).Count + 1; $archiveName = "$($t.slug)-$part.md"
            $archiveText = "# $name`n`n## $($m.log) (#$($moving[0].n)-#$($moving[-1].n))`n`n" + (($moving | ForEach-Object { $_.text }) -join "`n`n") + "`n"
            WriteAtomic (Join-Path $archiveDir $archiveName) $archiveText
            $t.archived = @(@($t.archived) + @([pscustomobject]@{file=$archiveName;from=$moving[0].n;to=$moving[-1].n}))
            $restText = New-Object System.Collections.Generic.List[string]; for ($i=$moveCount; $i -lt $entries.Count; $i++) { $restText.Add($entries[$i].text) }
            $entriesText = $restText -join "`n`n"
            Say ($m.rotated -f $name,$moving[0].n,$moving[-1].n,$archiveName)
        }
        $t.count = $n; $t.updated = (Now).ToString('o'); $t.next = (Clip $Next 300)
        $t.blocked = $(if ($Blocked) { Clip $Blocked 200 } else { $null })
        if ($Goal) { $t.goal = (Clip $Goal 200) }
        if (!$noDecision) { $dec = @(@($t.decisions) + @("#$n $(Clip $Decision 120)")); if ($dec.Count -gt 8) { $dec = $dec[($dec.Count-8)..($dec.Count-1)] }; $t.decisions = $dec }
        if ($fileList.Count) { $fl = @($fileList + @(@($t.files) | Where-Object { $fileList -notcontains $_ })); if ($fl.Count -gt 8) { $fl = $fl[0..7] }; $t.files = $fl }
        if ($taskList.Count) { $t.tasks = @(@($t.tasks) + @($taskList | Where-Object { @($t.tasks) -notcontains $_ })) }
        $t.last = [pscustomobject]@{n=$n;at=$stampNow;by=$(if ($By) {$By} else {$null});commit=$(if ($commit) {[string]$commit} else {$null});did=(Clip $Did 120);files=$fileList}
        WriteAtomic $path (RenderTopic $name $entriesText)
        SaveAll @()
        Say ($m.added -f $name,$n)
    } finally {
        if ($owned) { $mutex.ReleaseMutex() }
        $mutex.Dispose()
    }
} catch {
    if ($Command -eq 'brief') { exit 0 }
    if ($lang -eq 'en') { Write-Output "history failed: $($_.Exception.Message)" } else { Write-Output "히스토리 처리 실패: $($_.Exception.Message)" }
}
exit 0
