param([string]$Task,[ValidateSet('R1','R2','R3','single')][string]$Round='single',[string]$Card,[string]$Out,[string]$Model,[string]$Effort='low',[ValidateSet('workspace-write','read-only')][string]$Sandbox='workspace-write',[string]$DecidedBy='table',[string]$Prompt,[string]$Wait,[int]$WaitSeconds=540,[string]$RunnerState)
$ErrorActionPreference='Stop'
$utf8=[Text.UTF8Encoding]::new($false)
function Quote([string]$s) { '"'+$s.Replace('"','\"')+'"' }
function Relative([string]$path,[string]$root) { $prefix=$root.TrimEnd('\','/')+'\'; if ($path.StartsWith($prefix,[StringComparison]::OrdinalIgnoreCase)) { return $path.Substring($prefix.Length).Replace('\','/') }; return $path }
function Summary($state) {
    $done=$state+'.done.json'
    if (!(Test-Path -LiteralPath $done)) { Write-Output ('RUNNING '+[IO.Path]::GetFileName($state).Replace('.state.json','')); return }
    $s=Get-Content -LiteralPath $done -Raw -Encoding UTF8 | ConvertFrom-Json
    Write-Output "status=$($s.result) exit=$($s.exit) out=$($s.out_exists)"
    if ($s.summary) { $s.summary -split "`r?`n" | Select-Object -Last 5 | ForEach-Object { Write-Output $_ } }
    Write-Output "session=$($s.session) tokens=$($s.tokens.input)/$($s.tokens.cached)/$($s.tokens.output)"
}
function WaitDone([string]$path,[int]$seconds) {
    $until=[datetime]::UtcNow.AddSeconds([Math]::Max(0,[Math]::Min(540,$seconds)))
    while (!(Test-Path -LiteralPath ($path+'.done.json')) -and [datetime]::UtcNow -lt $until) { Start-Sleep -Milliseconds 500 }
    Summary $path
}
try {
    $root=[IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..\..'))
    $stateDir=Join-Path $root '.codex-last'
    if ($RunnerState) {
        $s=Get-Content -LiteralPath $RunnerState -Raw -Encoding UTF8 | ConvertFrom-Json
        $exit=1; $session=''; $tokens=@{input=0;cached=0;output=0}; $note=''
        try {
            $exe=(Get-Command codex.cmd -ErrorAction Stop).Source
            $args=@('exec','--json','-o',(Quote $s.last),'-m',(Quote $s.model),'-c',('model_reasoning_effort='+$s.effort),'--sandbox',$s.sandbox,'-') -join ' '
            $p=Start-Process -FilePath $exe -ArgumentList $args -WorkingDirectory $root -RedirectStandardInput $s.prompt -RedirectStandardOutput $s.jsonl -RedirectStandardError $s.err -PassThru -Wait -WindowStyle Hidden
            $exit=$p.ExitCode
            if (Test-Path -LiteralPath $s.jsonl) {
                foreach ($line in [IO.File]::ReadLines($s.jsonl)) {
                    if ($line.Contains('"thread.started"')) { try { $session=($line | ConvertFrom-Json).thread_id } catch {} }
                    if ($line.Contains('"turn.completed"')) { try { $u=($line | ConvertFrom-Json).usage; $tokens=@{input=[long]$u.input_tokens;cached=[long]$u.cached_input_tokens;output=[long]$u.output_tokens} } catch {} }
                }
            }
            if ($s.sandbox -eq 'read-only' -and $exit -eq 0 -and (Test-Path -LiteralPath $s.last)) { [IO.File]::WriteAllText($s.out,[IO.File]::ReadAllText($s.last,[Text.Encoding]::UTF8),$utf8) }
        } catch { $note=$_.Exception.Message }
        $exists=Test-Path -LiteralPath $s.out -PathType Leaf
        $result=if ($exit -eq 0 -and $exists) {'ok'} else {'fail'}
        $last=if (Test-Path -LiteralPath $s.last) {[IO.File]::ReadAllText($s.last,[Text.Encoding]::UTF8)} else {''}
        if (!$note -and $result -eq 'fail' -and (Test-Path -LiteralPath $s.err)) { $note=([IO.File]::ReadAllText($s.err,[Text.Encoding]::UTF8) -split "`r?`n" | Select-Object -First 2) -join ' ' }
        $record=@{ts=[datetime]::Now.ToString('o');task=$s.task;round=$s.round;model=$s.model;effort=$s.effort;result=$result;escalated_from=$null;workers=$null;out=(Relative $s.out $root);session=$session;tokens=$tokens;decided_by=$s.decided_by;note=$note}
        $log=Join-Path $s.docs 'log/runs.jsonl'; [IO.Directory]::CreateDirectory((Split-Path $log)) | Out-Null
        [IO.File]::AppendAllText($log,($record | ConvertTo-Json -Compress -Depth 8)+"`n",$utf8)
        $done=@{result=$result;exit=$exit;out_exists=$exists;summary=($last -split "`r?`n" | Where-Object { $_ } | Select-Object -Last 5) -join "`n";session=$session;tokens=$tokens}
        [IO.File]::WriteAllText($RunnerState+'.done.json',($done | ConvertTo-Json -Compress -Depth 8),$utf8)
        exit 0
    }
    if ($Wait) { WaitDone (Join-Path $stateDir ($Wait+'.state.json')) $WaitSeconds; exit 0 }
    if (!$Task -or !$Card -or !$Out -or !$Model) { throw 'Task, Card, Out, and Model are required' }
    [IO.Directory]::CreateDirectory($stateDir) | Out-Null
    $safe=(($Task+'-'+$Round) -replace '[^A-Za-z0-9_-]','_')
    $mutex=[Threading.Mutex]::new($false,'Local\Tandem-codex-'+[Convert]::ToBase64String([Security.Cryptography.SHA256]::Create().ComputeHash([Text.Encoding]::UTF8.GetBytes($root+'|'+$safe))).Substring(0,32).Replace('/','_'))
    $null=$mutex.WaitOne()
    try {
        foreach ($file in (Get-ChildItem $stateDir -Filter '*.state.json' -File)) {
            try { $old=Get-Content $file.FullName -Raw -Encoding UTF8 | ConvertFrom-Json; if ($old.key -eq $safe -and !(Test-Path ($file.FullName+'.done.json'))) { Write-Output ('RUNNING '+$old.id); exit 0 } } catch {}
        }
        $id=$safe+'-'+(Get-Date -Format yyyyMMddHHmmss)+'-'+([guid]::NewGuid().ToString('N').Substring(0,4))
        $cardFull=[IO.Path]::GetFullPath((Join-Path $root $Card)); $outFull=[IO.Path]::GetFullPath((Join-Path $root $Out))
        $cardText=Get-Content -LiteralPath $cardFull -Raw -Encoding UTF8
        $scope=([regex]::Match($cardText,'(?ms)^##\s*(쓰기 범위|Write scope)[^\r\n]*\r?\n(.*?)(?=^##\s|\z)')).Groups[2].Value.Trim()
        $instruction="Read task card $cardFull and follow it. Output artifact: $outFull. Write scope: $scope. $Prompt`nTask card (UTF-8):`n$cardText"
        if ($Sandbox -eq 'read-only') { $instruction+=' Return the full result in your final message; the wrapper saves it to Out. Do not edit files.' } else { $instruction+=' Last message: summary only, at most five lines.' }
        $stem=Join-Path $stateDir $id; $statePath=$stem+'.state.json'
        [IO.File]::WriteAllText($stem+'.prompt',$instruction,$utf8)
        $config=Get-Content (Join-Path $root 'tandem/config.json') -Raw -Encoding UTF8 | ConvertFrom-Json
        $s=@{id=$id;key=$safe;task=$Task;round=$Round;model=$Model;effort=$Effort;sandbox=$Sandbox;decided_by=$DecidedBy;out=$outFull;docs=(Join-Path $root $config.docs_root);prompt=$stem+'.prompt';last=$stem+'.txt';jsonl=$stem+'.jsonl';err=$stem+'.err'}
        [IO.File]::WriteAllText($statePath,($s | ConvertTo-Json -Compress),$utf8)
        $runner=Start-Process -FilePath 'powershell.exe' -ArgumentList @('-NoProfile','-ExecutionPolicy','Bypass','-File',(Quote $PSCommandPath),'-RunnerState',(Quote $statePath)) -WorkingDirectory $root -PassThru -WindowStyle Hidden
    } finally { $mutex.ReleaseMutex(); $mutex.Dispose() }
    WaitDone $statePath $WaitSeconds
} catch { Write-Output "status=fail $($_.Exception.Message)" }
