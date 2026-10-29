param(
    [Parameter(Position=0)][string]$Command='list',
    [string[]]$Task,[string]$Title,[string]$Card,[string]$To,[string]$By,[string]$Note,[switch]$Quiet
)
# Kanban board: <docs>/board/board.json (+ board-data.js for board/index.html). Moves are one short call; viewing costs no tokens.
try { [Console]::OutputEncoding = [Text.UTF8Encoding]::new($false) } catch {}
$ErrorActionPreference = 'Stop'
$utf8 = [Text.UTF8Encoding]::new($false)
$inv = [Globalization.CultureInfo]::InvariantCulture
$columns = @('todo','doing','built','review','test','done','blocked')
$alias = @{ 'progress'='doing'; 'in-progress'='doing'; 'wip'='doing'; 'complete'='built'; 'completed'='built'; 'testing'='test'; 'stopped'='blocked' }
function Has($o,[string]$name) { return ($null -ne $o) -and ($o.PSObject.Properties[$name]) -and ($null -ne $o.$name) }
function Now { return [datetimeoffset]::Now.ToString('yyyy-MM-ddTHH:mm:sszzz',$inv) }
function Say([string]$text) { if (!$Quiet) { Write-Output $text } }
function WriteAtomic([string]$path,[string]$text) {
    $tmp = $path + '.tmp'
    [IO.File]::WriteAllText($tmp,$text,$utf8)
    if (Test-Path -LiteralPath $path) { [IO.File]::Replace($tmp,$path,[NullString]::Value) } else { [IO.File]::Move($tmp,$path) }
}
function TitleFromCard([string]$path,[string]$id) {
    if (!$path) { return '' }
    $full = if ([IO.Path]::IsPathRooted($path)) { $path } else { Join-Path $root $path }
    if (!(Test-Path -LiteralPath $full)) { return '' }
    $t = ([regex]::Match([IO.File]::ReadAllText($full,[Text.Encoding]::UTF8),'(?m)^#\s+(.+)$')).Groups[1].Value.Trim()
    if ($id -and $t.StartsWith($id)) { $t = $t.Substring($id.Length).TrimStart(' ',':','-',[char]0x2014,[char]0x00B7) }
    return $t
}
function RunStats($ids) {
    # Per-task totals from runs.jsonl so the page can show agent, model, time and tokens without reading the log itself.
    $stats = @{}
    $log = Join-Path $docs 'log/runs.jsonl'
    if (!(Test-Path -LiteralPath $log)) { return $stats }
    $want = @{}; foreach ($id in $ids) { $want[$id.ToLowerInvariant()] = $id }
    foreach ($line in [IO.File]::ReadLines($log,[Text.Encoding]::UTF8)) {
        if (!$line.Contains('"task"')) { continue }
        try { $r = $line | ConvertFrom-Json } catch { continue }
        $key = ([string]$r.task).ToLowerInvariant()
        if (!$want.ContainsKey($key)) { continue }
        $id = $want[$key]
        if (!$stats.ContainsKey($id)) { $stats[$id] = [ordered]@{runs=0;agent=$null;model=$null;round=$null;result=$null;duration_s=$null;tokens=$null} }
        $s = $stats[$id]; $s.runs++
        if (Has $r 'agent') { $s.agent = [string]$r.agent }
        if (Has $r 'model') { $s.model = [string]$r.model }
        $s.round = [string]$r.round; $s.result = [string]$r.result
        if (Has $r 'duration_s') { $s.duration_s = [long]$s.duration_s + [long]$r.duration_s }
        if (Has $r 'tokens') {
            $t = $r.tokens; $v = $null
            if (Has $t 'total') { $v = [double]$t.total } elseif ((Has $t 'input') -or (Has $t 'output')) { $v = 0.0; if (Has $t 'input') { $v += [double]$t.input }; if (Has $t 'output') { $v += [double]$t.output } }
            if ($null -ne $v) { $s.tokens = [double]$s.tokens + $v }
        }
    }
    return $stats
}
$lang = 'ko'
try {
    $root = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..\..'))
    $configPath = Join-Path $root 'tandem/config.json'
    $config = if (Test-Path $configPath) { Get-Content $configPath -Raw -Encoding UTF8 | ConvertFrom-Json } else { $null }
    $lang = if ($config -and $config.lang -eq 'en') { 'en' } elseif ($config) { 'ko' } elseif ((Get-UICulture).Name -like 'ko*') { 'ko' } else { 'en' }
    $docsRoot = if ($config -and $config.docs_root) { [string]$config.docs_root } else { 'docs/tandem' }
    $docs = Join-Path $root $docsRoot
    $dir = Join-Path $docs 'board'
    $jsonPath = Join-Path $dir 'board.json'; $jsPath = Join-Path $dir 'board-data.js'; $htmlPath = Join-Path $dir 'index.html'
    $msg = @{
        ko = @{ usage='사용법: board.ps1 add|move|note|remove|list|sync|open -Task <ID[,ID]> [-To todo|doing|built|review|test|done|blocked] [-Title ..] [-Card ..] [-By ..] [-Note ..]'
                task='-Task 가 필요합니다'; to='-To 값이 올바르지 않습니다: {0}'; nocard='보드에 없는 과제: {0}'; empty='보드가 비어 있습니다'; nohtml='보드 화면 파일이 없습니다: {0}'
                names=@{todo='할 일';doing='진행중';built='작업완료';review='리뷰';test='테스트';done='완료';blocked='막힘'} }
        en = @{ usage='Usage: board.ps1 add|move|note|remove|list|sync|open -Task <ID[,ID]> [-To todo|doing|built|review|test|done|blocked] [-Title ..] [-Card ..] [-By ..] [-Note ..]'
                task='-Task is required'; to='Invalid -To value: {0}'; nocard='Task not on the board: {0}'; empty='The board is empty'; nohtml='Board page not found: {0}'
                names=@{todo='To do';doing='In progress';built='Built';review='Review';test='Test';done='Done';blocked='Blocked'} }
    }[$lang]
    $Command = $Command.ToLowerInvariant()
    if ($Command -notin @('add','move','note','remove','list','sync','open')) { Write-Output $msg.usage; exit 0 }
    $ids = @($Task | ForEach-Object { ([string]$_).Split(',') } | ForEach-Object { $_.Trim() } | Where-Object { $_ })
    if ($Command -eq 'open') {
        if (Test-Path -LiteralPath $htmlPath) { Start-Process $htmlPath; Say $htmlPath } else { Say ($msg.nohtml -f $htmlPath) }
        exit 0
    }
    if ($Command -in @('add','move','note','remove') -and !$ids.Count) { Write-Output $msg.task; exit 0 }
    if ($Command -eq 'move') {
        $To = ([string]$To).ToLowerInvariant(); if ($alias.ContainsKey($To)) { $To = $alias[$To] }
        if ($To -notin $columns) { Write-Output ($msg.to -f $To); exit 0 }
    }
    [IO.Directory]::CreateDirectory($dir) | Out-Null
    $sha = [Security.Cryptography.SHA1]::Create()
    $lockName = 'Global\TANDEM-board-' + ([BitConverter]::ToString($sha.ComputeHash($utf8.GetBytes($jsonPath.ToLowerInvariant())))).Replace('-','').Substring(0,16)
    $mutex = New-Object Threading.Mutex($false,$lockName)
    $owned = $false
    try {
        try { $owned = $mutex.WaitOne(10000) } catch [Threading.AbandonedMutexException] { $owned = $true }
        $board = $null
        if (Test-Path -LiteralPath $jsonPath) { try { $board = [IO.File]::ReadAllText($jsonPath,[Text.Encoding]::UTF8) | ConvertFrom-Json } catch { $board = $null } }
        $cards = New-Object System.Collections.Generic.List[object]
        if ($board -and (Has $board 'cards')) { foreach ($c in @($board.cards)) { $cards.Add($c) } }
        $rev = if ($board -and (Has $board 'rev')) { [long]$board.rev } else { 0 }
        function Find([string]$id) { foreach ($c in $cards) { if ([string]$c.id -ieq $id) { return $c } }; return $null }
        function NewCard([string]$id,[string]$title) {
            $c = [pscustomobject][ordered]@{id=$id;title=$title;column='todo';by=$null;note=$null;created=(Now);updated=(Now);history=@();stats=$null}
            $cards.Add($c); return $c
        }
        function Push($c,[string]$col) {
            $h = @($c.history) + @([pscustomobject]@{to=$col;by=$(if ($By) {$By} else {$null});at=(Now)})
            if ($h.Count -gt 30) { $h = $h[($h.Count-30)..($h.Count-1)] }
            $c.history = $h
        }
        $changed = $false
        if ($Command -eq 'list') {
            $show = New-Object System.Collections.Generic.List[object]
            foreach ($c in $cards) { if (!$ids.Count -or ($ids -icontains [string]$c.id)) { $show.Add($c) } }
            if (!$show.Count) { Write-Output $msg.empty; exit 0 }
            foreach ($col in $columns) {
                $inCol = @($show | Where-Object { $_.column -eq $col }); if (!$inCol.Count) { continue }
                Write-Output ("$($msg.names[$col]) ($($inCol.Count))")
                foreach ($c in $inCol) { Write-Output (("- $($c.id) $($c.title)").TrimEnd() + $(if ($c.by) { " [$($c.by)]" } else { '' })) }
            }
            exit 0
        }
        foreach ($id in $ids) {
            $c = Find $id
            $title = if ($Title) { $Title } else { TitleFromCard $Card $id }
            switch ($Command) {
                'add' {
                    if (!$c) { $c = NewCard $id $title; Push $c 'todo' } elseif ($title) { $c.title = $title; $c.updated = (Now) }
                    if ($Note) { $c.note = $Note }
                    $changed = $true
                }
                'move' {
                    if (!$c) { $c = NewCard $id $title } elseif ($title -and !$c.title) { $c.title = $title }
                    if ($c.column -ne $To) { $c.column = $To; Push $c $To }
                    $c.by = $(if ($By) {$By} else {$null}); $c.updated = (Now)
                    if ($PSBoundParameters.ContainsKey('Note')) { $c.note = $(if ($Note) {$Note} else {$null}) }
                    $changed = $true
                }
                'note' {
                    if (!$c) { Say ($msg.nocard -f $id); continue }
                    $c.note = $(if ($Note) {$Note} else {$null}); $c.updated = (Now); $changed = $true
                }
                'remove' {
                    if ($c) { [void]$cards.Remove($c); $changed = $true } else { Say ($msg.nocard -f $id) }
                }
            }
        }
        if ($Command -eq 'sync') { $changed = $true }
        if ($changed) {
            $stats = RunStats @($cards | ForEach-Object { [string]$_.id })
            foreach ($c in $cards) { $c.stats = $(if ($stats.ContainsKey([string]$c.id)) { [pscustomobject]$stats[[string]$c.id] } else { $null }) }
            $project = Split-Path $root -Leaf
            $modeName = if ($config) { [string]$config.mode } else { '' }
            $stamp = Now; $nextRev = $rev + 1; $cardArray = $cards.ToArray()
            $out = [pscustomobject]@{version=1;project=$project;lang=$lang;mode=$modeName;updated=$stamp;rev=$nextRev;columns=$columns;cards=$cardArray}
            $json = $out | ConvertTo-Json -Depth 8 -Compress
            WriteAtomic $jsonPath $json
            WriteAtomic $jsPath ("window.TANDEM_BOARD=" + $json + ";`n")
            foreach ($id in $ids) { $c = Find $id; if ($c) { Say ("$($c.id) -> $($msg.names[[string]$c.column])") } }
            if ($Command -eq 'sync') { Say ("rev=" + ($rev+1)) }
        }
    } finally {
        if ($owned) { $mutex.ReleaseMutex() }
        $mutex.Dispose()
    }
} catch {
    if ($lang -eq 'en') { Write-Output "board failed: $($_.Exception.Message)" } else { Write-Output "보드 갱신 실패: $($_.Exception.Message)" }
}
exit 0
