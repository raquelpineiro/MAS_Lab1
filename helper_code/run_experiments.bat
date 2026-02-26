@echo off
setlocal EnableDelayedExpansion

:: ============================================================
:: MAS Lab1 - Automated Experiment Runner
:: Runs all 4 scenarios x agent configs x 2 commitments x 10 reps
:: ============================================================

set JADE_LIB="..\..\jade.jar"
set TEMP_FILE=temp_raw.txt
set RESULTS_DIR=results
set NUM_REPS=10

:: Map params (fixed for all scenarios)
set MAP_SIZE=10
set NUM_ITEMS=5
set NUM_ROUNDS=1000

:: Create results directory
if not exist %RESULTS_DIR% mkdir %RESULTS_DIR%

echo ============================================================
echo  MAS Lab1 - Experiment Automation
echo  %NUM_REPS% repetitions per configuration
echo ============================================================
echo.

:: ---- SCENARIO DEFINITIONS ----
:: Scenario 3.1: Fixed world, no traps
:: Scenario 3.2: Fixed world, 10 traps
:: Scenario 3.3: Dynamic world, no traps
:: Scenario 3.4: Dynamic world, 10 traps

:: Loop through scenarios
for %%S in (1 2 3 4) do (
    if %%S==1 (
        set "SCENARIO_NAME=3.1_fixed_no_traps"
        set NUM_TRAPS=0
        set REDIST=1000
    )
    if %%S==2 (
        set "SCENARIO_NAME=3.2_fixed_10_traps"
        set NUM_TRAPS=10
        set REDIST=1000
    )
    if %%S==3 (
        set "SCENARIO_NAME=3.3_dynamic_no_traps"
        set NUM_TRAPS=0
        set REDIST=10
    )
    if %%S==4 (
        set "SCENARIO_NAME=3.4_dynamic_10_traps"
        set NUM_TRAPS=10
        set REDIST=10
    )

    echo.
    echo ************************************************************
    echo  SCENARIO !SCENARIO_NAME!
    echo  Traps=!NUM_TRAPS!, ReDist=!REDIST!
    echo ************************************************************

    set "SCENARIO_FILE=%RESULTS_DIR%\!SCENARIO_NAME!.csv"
    echo Config,Commitment,Rep,AgentName,Score,Traps > "!SCENARIO_FILE!"

    :: ---- SOLO AGENT RUNS (numParticipants=1) ----
    for %%C in (1 20) do (
        :: Random agent alone
        call :run_solo "random" "RandomAgent" %%C "!SCENARIO_FILE!" !NUM_TRAPS! !REDIST!

        :: Agent A alone
        call :run_solo "agentA" "AgentA" %%C "!SCENARIO_FILE!" !NUM_TRAPS! !REDIST!

        :: Agent B alone
        call :run_solo "agentB" "AgentB" %%C "!SCENARIO_FILE!" !NUM_TRAPS! !REDIST!
    )

    :: ---- ALL 3 AGENTS TOGETHER (numParticipants=3) ----
    for %%C in (1 20) do (
        call :run_together %%C "!SCENARIO_FILE!" !NUM_TRAPS! !REDIST!
    )
)

echo.
echo ============================================================
echo  ALL EXPERIMENTS COMPLETE
echo  Results saved in %RESULTS_DIR%\ directory
echo ============================================================
echo.

:: Generate summary
call :generate_summary

pause
goto :eof

:: ============================================================
:: SUBROUTINE: Run a single agent alone
:: Args: %1=configName %2=agentClass %3=commitment %4=outputFile %5=numTraps %6=reDist
:: ============================================================
:run_solo
set CONFIG_NAME=%~1
set AGENT_CLASS=%~2
set COMMIT=%~3
set OUT_FILE=%~4
set S_TRAPS=%~5
set S_REDIST=%~6

echo.
echo --- %CONFIG_NAME% alone, commitment=%COMMIT% ---

for /L %%i in (1,1,%NUM_REPS%) do (
    echo   Rep %%i/%NUM_REPS%...

    taskkill /F /IM java.exe >nul 2>&1
    timeout /t 2 /nobreak >nul

    java -cp %JADE_LIB%;. jade.Boot -agents "sim:SimulatorAgent(%MAP_SIZE%,%NUM_ITEMS%,%S_TRAPS%,1,%NUM_ROUNDS%,%S_REDIST%);player:%AGENT_CLASS%(%COMMIT%)" > %TEMP_FILE% 2>&1

    :: Extract score and traps from the FINAL block
    for /f "tokens=2 delims=:" %%a in ('findstr /C:"Score:" %TEMP_FILE% ^| findstr /n . ^| findstr "^" ^| more') do (
        set "LAST_SCORE=%%a"
    )
    for /f "tokens=2 delims=:" %%a in ('findstr /C:"NumTraps:" %TEMP_FILE% ^| findstr /n . ^| findstr "^" ^| more') do (
        set "LAST_TRAPS=%%a"
    )

    :: Use powershell for reliable extraction of last occurrence
    for /f %%a in ('powershell -Command "$c = Get-Content '%TEMP_FILE%'; $scores = $c | Select-String 'Score: (\d+)' | ForEach-Object { $_.Matches.Groups[1].Value }; if($scores){ $scores[-1] } else { '0' }"') do set LAST_SCORE=%%a
    for /f %%a in ('powershell -Command "$c = Get-Content '%TEMP_FILE%'; $traps = $c | Select-String 'NumTraps: (\d+)' | ForEach-Object { $_.Matches.Groups[1].Value }; if($traps){ $traps[-1] } else { '0' }"') do set LAST_TRAPS=%%a

    echo %CONFIG_NAME%_solo,%COMMIT%,%%i,%CONFIG_NAME%,!LAST_SCORE!,!LAST_TRAPS! >> "%OUT_FILE%"
)
goto :eof

:: ============================================================
:: SUBROUTINE: Run all 3 agents together
:: Args: %1=commitment %2=outputFile %3=numTraps %4=reDist
:: ============================================================
:run_together
set COMMIT=%~1
set OUT_FILE=%~2
set S_TRAPS=%~3
set S_REDIST=%~4

echo.
echo --- All 3 agents together, commitment=%COMMIT% ---

for /L %%i in (1,1,%NUM_REPS%) do (
    echo   Rep %%i/%NUM_REPS%...

    taskkill /F /IM java.exe >nul 2>&1
    timeout /t 2 /nobreak >nul

    java -cp %JADE_LIB%;. jade.Boot -agents "sim:SimulatorAgent(%MAP_SIZE%,%NUM_ITEMS%,%S_TRAPS%,3,%NUM_ROUNDS%,%S_REDIST%);rnd:RandomAgent(%COMMIT%);agA:AgentA(%COMMIT%);agB:AgentB(%COMMIT%)" > %TEMP_FILE% 2>&1

    :: Extract scores for each agent using powershell (3 participants = 3 Name/Score blocks in FINAL)
    :: The output in the FINAL block lists participants in order: rnd, agA, agB
    for /f "usebackq tokens=1,2,3 delims=," %%a in (`powershell -Command "$c = Get-Content '%TEMP_FILE%'; $final = $false; $names = @(); $scores = @(); $traps = @(); foreach($line in $c){ if($line -match 'FINAL SIMULATION STATE'){ $final = $true; $names = @(); $scores = @(); $traps = @() } if($final){ if($line -match '^Name: (.+)$'){ $names += $Matches[1].Trim() } if($line -match '^Score: (\d+)'){ $scores += $Matches[1] } if($line -match '^NumTraps: (\d+)'){ $traps += $Matches[1] } } }; for($i=0; $i -lt $names.Count; $i++){ Write-Output ('{0},{1},{2}' -f $names[$i],$scores[$i],$traps[$i]) }"`) do (
        echo all_together,%COMMIT%,%%i,%%a,%%b,%%c >> "%OUT_FILE%"
    )
)
goto :eof

:: ============================================================
:: SUBROUTINE: Generate summary from CSV files
:: ============================================================
:generate_summary
set SUMMARY_FILE=%RESULTS_DIR%\summary.txt

echo. > "%SUMMARY_FILE%"
echo ============================================================ >> "%SUMMARY_FILE%"
echo  MAS Lab1 - EXPERIMENT RESULTS SUMMARY >> "%SUMMARY_FILE%"
echo ============================================================ >> "%SUMMARY_FILE%"

for %%F in (%RESULTS_DIR%\3.*.csv) do (
    echo. >> "%SUMMARY_FILE%"
    echo ---- %%~nF ---- >> "%SUMMARY_FILE%"

    powershell -Command ^
        "$data = Import-Csv '%%F';" ^
        "$groups = $data | Group-Object Config,Commitment,AgentName;" ^
        "foreach($g in $groups){" ^
        "  $avg = ($g.Group | ForEach-Object { [int]$_.Score } | Measure-Object -Average).Average;" ^
        "  $avgTraps = ($g.Group | ForEach-Object { [int]$_.Traps } | Measure-Object -Average).Average;" ^
        "  Write-Output ('{0} | AvgScore={1:F1} | AvgTraps={2:F1}' -f $g.Name, $avg, $avgTraps)" ^
        "}" >> "%SUMMARY_FILE%"
)

echo.
echo Summary saved to %SUMMARY_FILE%
type "%SUMMARY_FILE%"
goto :eof