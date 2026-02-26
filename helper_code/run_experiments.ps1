# ============================================================
# MAS Lab1 - Automated Experiment Runner (PowerShell)
# Runs all 4 scenarios x agent configs x 2 commitments x 10 reps
# ============================================================
# Usage: powershell -ExecutionPolicy Bypass -File run_experiments.ps1
# ============================================================

$JADE_LIB = "..\..\jade.jar"
$TEMP_FILE = "temp_raw.txt"
$RESULTS_DIR = "results"
$NUM_REPS = 10

# Map params (fixed for all scenarios per enunciado)
$MAP_SIZE = 10
$NUM_ITEMS = 5
$NUM_ROUNDS = 1000

# Create results directory
if (-not (Test-Path $RESULTS_DIR)) { New-Item -ItemType Directory -Path $RESULTS_DIR | Out-Null }

Write-Host "============================================================" -ForegroundColor Cyan
Write-Host " MAS Lab1 - Experiment Automation" -ForegroundColor Cyan
Write-Host " $NUM_REPS repetitions per configuration" -ForegroundColor Cyan
Write-Host "============================================================" -ForegroundColor Cyan

# ---- SCENARIO DEFINITIONS ----
$scenarios = @(
    @{ Name="3.1_fixed_no_traps";    Traps=0;  ReDist=1000 },
    @{ Name="3.2_fixed_10_traps";    Traps=10; ReDist=1000 },
    @{ Name="3.3_dynamic_no_traps";  Traps=0;  ReDist=10   },
    @{ Name="3.4_dynamic_10_traps";  Traps=10; ReDist=10   }
)

# ---- FUNCTION: Extract scores from JADE output file ----
function Extract-FinalScores {
    param([string]$FilePath)

    $content = Get-Content $FilePath -Encoding UTF8 -ErrorAction SilentlyContinue
    if (-not $content) {
        $content = Get-Content $FilePath -ErrorAction SilentlyContinue
    }

    $inFinal = $false
    $agents = @()
    $currentAgent = @{}

    foreach ($line in $content) {
        if ($line -match "FINAL SIMULATION STATE") {
            $inFinal = $true
            $agents = @()
            $currentAgent = @{}
        }
        if ($inFinal) {
            if ($line -match "^Name:\s*(.+)$") {
                if ($currentAgent.Count -gt 0) { $agents += $currentAgent }
                $currentAgent = @{ Name = $Matches[1].Trim(); Score = 0; Traps = 0 }
            }
            if ($line -match "^Score:\s*(\d+)") {
                $currentAgent.Score = [int]$Matches[1]
            }
            if ($line -match "^NumTraps:\s*(\d+)") {
                $currentAgent.Traps = [int]$Matches[1]
            }
        }
        if ($line -match "FINAL SIMULATION END") {
            if ($currentAgent.Count -gt 0) { $agents += $currentAgent }
        }
    }

    return $agents
}

# ---- FUNCTION: Run a single JADE experiment ----
function Run-Experiment {
    param(
        [string]$AgentString,
        [int]$NumParticipants,
        [int]$NumTraps,
        [int]$ReDist
    )

    # Kill any lingering java processes
    Get-Process java -ErrorAction SilentlyContinue | Stop-Process -Force -ErrorAction SilentlyContinue
    Start-Sleep -Seconds 1

    $simArgs = "$MAP_SIZE,$NUM_ITEMS,$NumTraps,$NumParticipants,$NUM_ROUNDS,$ReDist"
    $fullAgents = "sim:SimulatorAgent($simArgs);$AgentString"

    $javaCmd = "java -cp `"$JADE_LIB;.`" jade.Boot -agents `"$fullAgents`""

    # Run and capture output
    $process = Start-Process -FilePath "java" -ArgumentList "-cp", "$JADE_LIB;.", "jade.Boot", "-agents", $fullAgents -RedirectStandardOutput $TEMP_FILE -RedirectStandardError "temp_err.txt" -NoNewWindow -PassThru -Wait

    return Extract-FinalScores $TEMP_FILE
}

# ============================================================
# MAIN EXPERIMENT LOOP
# ============================================================
$totalExperiments = 4 * 8  # 4 scenarios x (6 solo + 2 together)
$currentExp = 0

foreach ($scenario in $scenarios) {
    $scenarioName = $scenario.Name
    $numTraps = $scenario.Traps
    $reDist = $scenario.ReDist

    Write-Host ""
    Write-Host "************************************************************" -ForegroundColor Yellow
    Write-Host " SCENARIO $scenarioName" -ForegroundColor Yellow
    Write-Host " Traps=$numTraps, ReDist=$reDist" -ForegroundColor Yellow
    Write-Host "************************************************************" -ForegroundColor Yellow

    $csvFile = "$RESULTS_DIR\$scenarioName.csv"
    "Config,Commitment,Rep,AgentName,Score,Traps" | Out-File -FilePath $csvFile -Encoding UTF8

    # ---- SOLO AGENT RUNS ----
    $soloConfigs = @(
        @{ ConfigName="random_solo"; AgentClass="RandomAgent"; AgentLabel="random" },
        @{ ConfigName="agentA_solo"; AgentClass="AgentA";      AgentLabel="agentA" },
        @{ ConfigName="agentB_solo"; AgentClass="AgentB";      AgentLabel="agentB" }
    )

    foreach ($config in $soloConfigs) {
        foreach ($commitment in @(1, 20)) {
            $currentExp++
            Write-Host ""
            Write-Host "--- $($config.ConfigName), commitment=$commitment ---" -ForegroundColor Green

            for ($rep = 1; $rep -le $NUM_REPS; $rep++) {
                Write-Host "  Rep $rep/$NUM_REPS..." -NoNewline

                $agentStr = "player:$($config.AgentClass)($commitment)"
                $results = Run-Experiment -AgentString $agentStr -NumParticipants 1 -NumTraps $numTraps -ReDist $reDist

                if ($results -and $results.Count -gt 0) {
                    $r = $results[0]
                    "$($config.ConfigName),$commitment,$rep,$($config.AgentLabel),$($r.Score),$($r.Traps)" | Out-File -FilePath $csvFile -Append -Encoding UTF8
                    Write-Host " Score=$($r.Score), Traps=$($r.Traps)" -ForegroundColor White
                } else {
                    "$($config.ConfigName),$commitment,$rep,$($config.AgentLabel),ERROR,ERROR" | Out-File -FilePath $csvFile -Append -Encoding UTF8
                    Write-Host " ERROR extracting results" -ForegroundColor Red
                }
            }
        }
    }

    # ---- ALL 3 AGENTS TOGETHER ----
    foreach ($commitment in @(1, 20)) {
        $currentExp++
        Write-Host ""
        Write-Host "--- All 3 together, commitment=$commitment ---" -ForegroundColor Green

        for ($rep = 1; $rep -le $NUM_REPS; $rep++) {
            Write-Host "  Rep $rep/$NUM_REPS..." -NoNewline

            $agentStr = "rnd:RandomAgent($commitment);agA:AgentA($commitment);agB:AgentB($commitment)"
            $results = Run-Experiment -AgentString $agentStr -NumParticipants 3 -NumTraps $numTraps -ReDist $reDist

            if ($results -and $results.Count -ge 3) {
                foreach ($r in $results) {
                    # Map JADE agent names to our labels
                    $label = switch ($r.Name) {
                        "rnd"  { "random" }
                        "agA"  { "agentA" }
                        "agB"  { "agentB" }
                        default { $r.Name }
                    }
                    "all_together,$commitment,$rep,$label,$($r.Score),$($r.Traps)" | Out-File -FilePath $csvFile -Append -Encoding UTF8
                }
                $scoreStr = ($results | ForEach-Object { "$($_.Name)=$($_.Score)" }) -join ", "
                Write-Host " $scoreStr" -ForegroundColor White
            } else {
                "all_together,$commitment,$rep,ERROR,ERROR,ERROR" | Out-File -FilePath $csvFile -Append -Encoding UTF8
                Write-Host " ERROR extracting results" -ForegroundColor Red
            }
        }
    }
}

# ============================================================
# GENERATE SUMMARY
# ============================================================
Write-Host ""
Write-Host "============================================================" -ForegroundColor Cyan
Write-Host " GENERATING SUMMARY" -ForegroundColor Cyan
Write-Host "============================================================" -ForegroundColor Cyan

$summaryFile = "$RESULTS_DIR\summary.txt"
"MAS Lab1 - EXPERIMENT RESULTS SUMMARY" | Out-File -FilePath $summaryFile -Encoding UTF8
"Generated: $(Get-Date)" | Out-File -FilePath $summaryFile -Append -Encoding UTF8
"" | Out-File -FilePath $summaryFile -Append -Encoding UTF8

foreach ($scenario in $scenarios) {
    $csvFile = "$RESULTS_DIR\$($scenario.Name).csv"
    if (Test-Path $csvFile) {
        "===== $($scenario.Name) =====" | Out-File -FilePath $summaryFile -Append -Encoding UTF8

        $data = Import-Csv $csvFile
        $groups = $data | Where-Object { $_.Score -ne "ERROR" } | Group-Object Config, Commitment, AgentName

        foreach ($g in $groups) {
            $avgScore = ($g.Group | ForEach-Object { [int]$_.Score } | Measure-Object -Average).Average
            $avgTraps = ($g.Group | ForEach-Object { [int]$_.Traps } | Measure-Object -Average).Average
            "{0,-40} | AvgScore={1,6:F1} | AvgTraps={2,5:F1}" -f $g.Name, $avgScore, $avgTraps | Out-File -FilePath $summaryFile -Append -Encoding UTF8
        }
        "" | Out-File -FilePath $summaryFile -Append -Encoding UTF8
    }
}

Write-Host ""
Get-Content $summaryFile
Write-Host ""
Write-Host "============================================================" -ForegroundColor Cyan
Write-Host " ALL EXPERIMENTS COMPLETE" -ForegroundColor Cyan
Write-Host " Results in: $RESULTS_DIR\" -ForegroundColor Cyan
Write-Host "============================================================" -ForegroundColor Cyan

# Cleanup temp files
Remove-Item $TEMP_FILE -ErrorAction SilentlyContinue
Remove-Item "temp_err.txt" -ErrorAction SilentlyContinue
