$maxConcurrentJobs = 4
$priorityLevels = 4 # number of levels of priority
$priorityQueue = New-Object System.Collections.Generic.List[System.Object]

For (($i = 0); $i -lt $priorityLevels; $i++) {
    $p = New-Object System.Collections.Queue
    $priorityQueue.Add($p)
}

function Queue-Job {
    param(
        [Parameter(Mandatory=$true)]
        $ScriptBlock,
        $priority
    )
    if ($priority -eq $null) { # default priority
        $priority = 1
    } elseif ($priority -gt $priorityLevels) { # too high priority
        $priority = $priorityLevels
    } elseif ($priority -lt 0) { # too low priority
        $priority = 0
    }
    $priorityQueue[$priority].Enqueue("$ScriptBlock")
}

function Run-Job {
    For (($i = 0); $i -lt $priorityLevels; $i++) {
        $p = $priorityQueue[$i]
        if ($p.Count -gt 0) {
            $job = [Scriptblock]::Create($p.Dequeue())
            Start-Job -ScriptBlock $job
            return
        }
    }
}

function Count-JobsQueued {
    $count = 0
    For ($i = 0; $i -lt $priorityLevels; $i++) {
        $p = $priorityQueue[$i]
        $count += $p.Count
    }
    return $count
}

function Loop-Main {
    $run = $true
    $oldJobcount = 0;

    while ($run) {
        $queued = Count-JobsQueued
        while ((Count-JobsQueued) -gt 0) {
            $jobs = Get-Job -State Running
            while ($jobs.Count -lt $maxConcurrentJobs) {
                Run-Job
                $jobs = Get-Job -State Running
            }
        $queued = Count-JobsQueued
        if ($queued -ne $oldJobcount) {# only print if there is a change
            $oldJobcount = $queued
            write-host "Running jobs:" $jobs.Count
            write-host "Remaining jobs:" $queued
            }
        }
        Write-Host "No more jobs to run."
        $run = $false
    }
}

ForEach ($i in 1..100) { # add 100 jobs with default priority (1)
    Queue-Job -ScriptBlock { Start-Sleep -Seconds ( Get-Random -Minimum 1 -Maximum 5 ); Write-Host "$i is done." } 
}
ForEach ($i in 1..10) { # add 10 jobs with priority 0 (Highest priority)
    Queue-Job -ScriptBlock { Write-Host "H"; Start-Sleep -Seconds ( Get-Random -Minimum 1 -Maximum 5 ); Write-Host "Urgent: $i is done." } -Priority 0
}
ForEach ($i in 1..10) { # add 10 jobs with priority 2
    Queue-Job -ScriptBlock { Write-Host "L"; Start-Sleep -Seconds ( Get-Random -Minimum 1 -Maximum 5 ); Write-Host "Low Priority: $i is done." } -Priority 2
}

Loop-Main