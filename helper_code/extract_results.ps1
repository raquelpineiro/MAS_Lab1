# ============================================================
# MAS Lab1 - Extract results from raw log files
# Run after run_all_experiments.bat completes
# Usage: powershell -ExecutionPolicy Bypass -File extract_results.ps1
# ============================================================

$LOGS_DIR = "results\logs"
$CSV_FILE = "results\all_results.csv"

# CSV header
"Scenario,Config,AgentName,Commitment,Rep,Score,NumTraps" | Out-File -FilePath $CSV_FILE -Encoding UTF8

$logFiles = Get-ChildItem "$LOGS_DIR\*.log" | Sort-Object Name
$total = $logFiles.Count
$current = 0

foreach ($file in $logFiles) {
    $current++
    $baseName = $file.BaseName  # e.g. "3.1_fixed_no_traps_AgentA_solo_c1_rep3"

    # Parse filename into components
    # Filenames look like: 3.1_fixed_no_traps_AgentA_solo_c1_rep3
    #                       3.4_dynamic_10_traps_all_together_c20_rep5
    # Strategy: extract commitment and rep from the end, then split scenario vs config
    if ($baseName -match '^(.+)_c(\d+)_rep(\d+)$') {
        $prefix = $Matches[1]
        $commitment = $Matches[2]
        $rep = $Matches[3]
    } else {
        Write-Host "  SKIP: Could not parse filename $baseName" -ForegroundColor Yellow
        continue
    }

    # Split prefix into scenario and config
    # Scenario always starts with 3.X_ and ends before the agent config
    # Known configs: AgentA_solo, AgentB_solo, RandomAgent_solo, all_together
    if ($prefix -match '^(3\.\d_.+?)_(AgentA_solo|AgentB_solo|RandomAgent_solo|all_together)$') {
        $scenario = $Matches[1]
        $configRaw = $Matches[2]
    } else {
        Write-Host "  SKIP: Could not split scenario/config from $prefix" -ForegroundColor Yellow
        continue
    }

    # Read file content and strip ANSI codes
    $content = Get-Content $file.FullName -ErrorAction SilentlyContinue
    if (-not $content) {
        Write-Host "  SKIP: Empty file $baseName" -ForegroundColor Yellow
        continue
    }

    # Find FINAL SIMULATION STATE block and extract scores
    $inFinal = $false
    $names = @()
    $scores = @()
    $traps = @()

    foreach ($line in $content) {
        $line = $line -replace '\e\[[0-9;]*[a-zA-Z]', ''
        $line = $line.Trim()

        if ($line -match 'FINAL SIMULATION STATE') {
            $inFinal = $true
            $names = @(); $scores = @(); $traps = @()
        }
        if ($inFinal) {
            if ($line -match '^Name:\s*(.+)$') { $names += $Matches[1].Trim() }
            if ($line -match '^Score:\s*(-?\d+)') { $scores += $Matches[1] }
            if ($line -match '^NumTraps:\s*(\d+)') { $traps += $Matches[1] }
        }
    }

    if ($names.Count -eq 0) {
        Write-Host "  [$current/$total] FAIL: No FINAL block in $baseName" -ForegroundColor Red
        # Write error line
        if ($configRaw -eq "all_together") {
            foreach ($agent in @("rnd","agA","agB")) {
                "$scenario,all_together,$agent,$commitment,$rep,ERROR,ERROR" | Out-File -FilePath $CSV_FILE -Append -Encoding UTF8
            }
        } else {
            "$scenario,$configRaw,player,$commitment,$rep,ERROR,ERROR" | Out-File -FilePath $CSV_FILE -Append -Encoding UTF8
        }
        continue
    }

    # Write results
    for ($i = 0; $i -lt $names.Count; $i++) {
        $config = if ($configRaw -eq "all_together") { "all_together" } else { $configRaw }
        "$scenario,$config,$($names[$i]),$commitment,$rep,$($scores[$i]),$($traps[$i])" | Out-File -FilePath $CSV_FILE -Append -Encoding UTF8
    }
    Write-Host "  [$current/$total] OK: $baseName" -ForegroundColor Green
}

# ============================================================
# Generate summary with averages per config
# ============================================================
Write-Host ""
Write-Host "============================================================" -ForegroundColor Cyan
Write-Host " GENERATING SUMMARY" -ForegroundColor Cyan
Write-Host "============================================================" -ForegroundColor Cyan

$SUMMARY_FILE = "results\summary.txt"
$data = Import-Csv $CSV_FILE

"MAS Lab1 - EXPERIMENT RESULTS SUMMARY" | Out-File -FilePath $SUMMARY_FILE -Encoding UTF8
"Generated: $(Get-Date)" | Out-File -FilePath $SUMMARY_FILE -Append -Encoding UTF8
"" | Out-File -FilePath $SUMMARY_FILE -Append -Encoding UTF8

$scenarioGroups = $data | Where-Object { $_.Score -ne "ERROR" } | Group-Object Scenario

foreach ($sg in $scenarioGroups) {
    "" | Out-File -FilePath $SUMMARY_FILE -Append -Encoding UTF8
    "===== $($sg.Name) =====" | Out-File -FilePath $SUMMARY_FILE -Append -Encoding UTF8

    $configGroups = $sg.Group | Group-Object Config, AgentName, Commitment
    foreach ($cg in $configGroups) {
        $avgScore = ($cg.Group | ForEach-Object { [int]$_.Score } | Measure-Object -Average).Average
        $avgTraps = ($cg.Group | ForEach-Object { [int]$_.NumTraps } | Measure-Object -Average).Average
        $count = $cg.Group.Count
        "{0,-55} | AvgScore={1,7:F1} | AvgTraps={2,5:F1} | N={3}" -f $cg.Name, $avgScore, $avgTraps, $count | Out-File -FilePath $SUMMARY_FILE -Append -Encoding UTF8
    }
}

Write-Host ""
Get-Content $SUMMARY_FILE
Write-Host ""
Write-Host "============================================================" -ForegroundColor Cyan
Write-Host " Results CSV: $CSV_FILE" -ForegroundColor Cyan
Write-Host " Summary:     $SUMMARY_FILE" -ForegroundColor Cyan
Write-Host "============================================================" -ForegroundColor Cyan
