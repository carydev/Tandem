param([string]$Task,[ValidateSet('R1','R2','R3','single')][string]$Round='single',[string]$Card,[string]$Out,[string]$Model,[string]$Effort='low',[ValidateSet('workspace-write','read-only')][string]$Sandbox='workspace-write',[string]$DecidedBy='table',[string]$Prompt,[string]$Wait,[int]$WaitSeconds=540,[string]$RunnerState)
try { [Console]::OutputEncoding = [Text.UTF8Encoding]::new($false) } catch {}  # UTF-8 stdout: PS 5.1 defaults to the OEM code page (cp949 on Korean Windows), which garbles non-ASCII output read by Bash/Claude
$ErrorActionPreference='Stop'
$utf8=[Text.UTF8Encoding]::new($false)
function Messages([string]$root) {
    $lang=if ((Get-UICulture).Name -like 'ko*') {'ko'} else {'en'}
    try { $saved=(Get-Content -LiteralPath (Join-Path $root 'tandem/config.json') -Raw -Encoding UTF8 | ConvertFrom-Json).lang; if ($saved -in @('ko','en')) { $lang=$saved } } catch {}
    $table=@{
        ko=@{task='Task, Card, Out, Model이 필요합니다'; fail='실행에 실패했습니다'; instruction='작업 카드 {0}을 읽고 따르세요. 결과 파일: {1}. 쓰기 범위: {2}. {3}`n작업 카드(UTF-8):`n{4}'; readonly=' 전체 결과를 마지막 메시지에 작성하세요. 래퍼가 Out에 저장합니다. 파일을 수정하지 마세요.'; writable=' 마지막 메시지는 5줄 이내 요약만 작성하세요.'}
        en=@{task='Task, Card, Out, and Model are required'; fail='Run failed'; instruction='Read task card {0} and follow it. Output artifact: {1}. Write scope: {2}. {3}`nTask card (UTF-8):`n{4}'; readonly=' Return the full result in your final message; the wrapper saves it to Out. Do not edit files.'; writable=' Last message: summary only, at most five lines.'}
    }
    $table.ko.model='Model 값이 올바르지 않습니다'
    $table.en.model='Invalid Model value'
    $table.ko.effort='Effort 값이 올바르지 않습니다'
    $table.en.effort='Invalid Effort value'
    $table.ko.path='경로에 큰따옴표를 사용할 수 없습니다'
    $table.en.path='A path contains a double quote'
    $table.ko.diff='변경분: '
    $table.en.diff='Changes: '
    $table.ko.noDiff='변경분 없음'
    $table.en.noDiff='Changes unavailable'
    return $table[$lang]
}
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
    $m=Messages $root
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
        $last=if (Test-Path -LiteralPath $s.last) {[IO.File]::ReadAllText($s.last,[Text.Encoding]::UTF8)} else {''}
        $lines=@($last -split "`r?`n" | Where-Object { $_.Trim() })
        $stopped=$lines.Count -gt 0 -and $lines[0] -cmatch '^STOPPED:'
        $result=if ($stopped) {'stopped'} elseif ($exit -eq 0 -and $exists) {'ok'} else {'fail'}
        $summary=if ($stopped) { (@($lines[0]) + @(@($lines | Select-Object -Skip 1) | Select-Object -Last 4)) -join "`n" } else { (@($lines | Select-Object -Last 5)) -join "`n" }
        if (!$note -and $result -eq 'fail' -and (Test-Path -LiteralPath $s.err)) { $note=([IO.File]::ReadAllText($s.err,[Text.Encoding]::UTF8) -split "`r?`n" | Select-Object -First 2) -join ' ' }
        $record=@{ts=[datetime]::Now.ToString('o');task=$s.task;round=$s.round;model=$s.model;effort=$s.effort;result=$result;escalated_from=$null;workers=$null;out=(Relative $s.out $root);session=$session;tokens=$tokens;decided_by=$s.decided_by;note=$note}
        $log=Join-Path $s.docs 'log/runs.jsonl'; [IO.Directory]::CreateDirectory((Split-Path $log)) | Out-Null
        [IO.File]::AppendAllText($log,($record | ConvertTo-Json -Compress -Depth 8)+"`n",$utf8)
        $done=@{result=$result;exit=$exit;out_exists=$exists;summary=$summary;session=$session;tokens=$tokens}
        [IO.File]::WriteAllText($RunnerState+'.done.json',($done | ConvertTo-Json -Compress -Depth 8),$utf8)
        exit 0
    }
    if ($Wait) { WaitDone (Join-Path $stateDir ($Wait+'.state.json')) $WaitSeconds; exit 0 }
    if (!$Task -or !$Card -or !$Out -or !$Model) { Write-Output "status=fail $($m.task)"; exit 0 }
    if ($Model -cnotmatch '^[A-Za-z0-9._:/-]+$') { Write-Output "status=fail $($m.model)"; exit 0 }
    if ($Effort -cnotmatch '^[a-z]+$') { Write-Output "status=fail $($m.effort)"; exit 0 }
    if (@($root,$Card,$Out) | Where-Object { $_.Contains('"') }) { Write-Output "status=fail $($m.path)"; exit 0 }
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
        $instruction=$m.instruction.Replace('{0}',$cardFull).Replace('{1}',$outFull).Replace('{2}',$scope).Replace('{3}',[string]$Prompt).Replace('{4}',$cardText).Replace('`n',"`n")
        if ($Round -eq 'R2') {
            $diffPath=''
            try {
                Push-Location $root
                try { $candidate=& (Join-Path $PSScriptRoot 'diff.ps1') -Task $Task 2>$null; if ($LASTEXITCODE -ne 0) { throw 'diff failed' }; $diffPath=[string]($candidate | Select-Object -Last 1); if (!(Test-Path -LiteralPath $diffPath -PathType Leaf)) { throw 'diff missing' } }
                finally { Pop-Location }
            } catch { $diffPath='' }
            $instruction+="`n"+$(if ($diffPath) { $m.diff+$diffPath } else { $m.noDiff })+"`n"
        }
        if ($Sandbox -eq 'read-only') { $instruction+=$m.readonly } else { $instruction+=$m.writable }
        $stem=Join-Path $stateDir $id; $statePath=$stem+'.state.json'
        [IO.File]::WriteAllText($stem+'.prompt',$instruction,$utf8)
        $config=Get-Content (Join-Path $root 'tandem/config.json') -Raw -Encoding UTF8 | ConvertFrom-Json
        $s=@{id=$id;key=$safe;task=$Task;round=$Round;model=$Model;effort=$Effort;sandbox=$Sandbox;decided_by=$DecidedBy;out=$outFull;docs=(Join-Path $root $config.docs_root);prompt=$stem+'.prompt';last=$stem+'.txt';jsonl=$stem+'.jsonl';err=$stem+'.err'}
        [IO.File]::WriteAllText($statePath,($s | ConvertTo-Json -Compress),$utf8)
        $runner=Start-Process -FilePath 'powershell.exe' -ArgumentList @('-NoProfile','-ExecutionPolicy','Bypass','-File',(Quote $PSCommandPath),'-RunnerState',(Quote $statePath)) -WorkingDirectory $root -PassThru -WindowStyle Hidden
    } finally { $mutex.ReleaseMutex(); $mutex.Dispose() }
    WaitDone $statePath $WaitSeconds
} catch { Write-Output "status=fail $($m.fail)" }
