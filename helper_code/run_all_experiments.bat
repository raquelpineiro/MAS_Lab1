@echo off
setlocal EnableDelayedExpansion

:: ============================================================
:: MAS Lab1 - Run ALL experiment combinations
:: Saves raw output per run to results\logs\ directory
:: ============================================================

set JADE_LIB=C:\Users\david\Documents\JADE-all-4.6.0\JADE-bin-4.6.0\jade\lib\jade.jar
set NUM_REPS=10
set MAP_SIZE=10
set NUM_ITEMS=5
set NUM_ROUNDS=1000

:: Port counter to avoid JADE TIME_WAIT collisions
set /A PORT=3000

:: Create output directories
if not exist results mkdir results
if not exist results\logs mkdir results\logs

echo ============================================================
echo  MAS Lab1 - Running ALL experiment combinations
echo  %NUM_REPS% repetitions per configuration
echo  Output saved to results\logs\
echo ============================================================
echo.

:: ---- SCENARIO LOOP ----
for %%S in (1 2 3 4) do (
    if %%S==1 (
        set "S_NAME=3.1_fixed_no_traps"
        set S_TRAPS=0
        set S_REDIST=1000
    )
    if %%S==2 (
        set "S_NAME=3.2_fixed_10_traps"
        set S_TRAPS=10
        set S_REDIST=1000
    )
    if %%S==3 (
        set "S_NAME=3.3_dynamic_no_traps"
        set S_TRAPS=0
        set S_REDIST=10
    )
    if %%S==4 (
        set "S_NAME=3.4_dynamic_10_traps"
        set S_TRAPS=10
        set S_REDIST=10
    )

    echo.
    echo ************************************************************
    echo  SCENARIO !S_NAME!
    echo ************************************************************

    :: ---- SOLO AGENT RUNS (1 participant) ----
    for %%A in (RandomAgent AgentA AgentB) do (
        for %%C in (1 20) do (
            echo.
            echo --- %%A alone, commitment=%%C ---
            for /L %%R in (1,1,%NUM_REPS%) do (
                set /A PORT+=1
                set "LOGFILE=results\logs\!S_NAME!_%%A_solo_c%%C_rep%%R.log"
                echo   Rep %%R/%NUM_REPS% [port !PORT!]...
                java -cp "%JADE_LIB%;." jade.Boot -nomtp -port !PORT! -agents "sim:SimulatorAgent(%MAP_SIZE%,%NUM_ITEMS%,!S_TRAPS!,1,%NUM_ROUNDS%,!S_REDIST!);player:%%A(%%C)" > "!LOGFILE!" 2>&1
            )
        )
    )

    :: ---- ALL 3 AGENTS TOGETHER (3 participants) ----
    for %%C in (1 20) do (
        echo.
        echo --- All 3 together, commitment=%%C ---
        for /L %%R in (1,1,%NUM_REPS%) do (
            set /A PORT+=1
            set "LOGFILE=results\logs\!S_NAME!_all_together_c%%C_rep%%R.log"
            echo   Rep %%R/%NUM_REPS% [port !PORT!]...
            java -cp "%JADE_LIB%;." jade.Boot -nomtp -port !PORT! -agents "sim:SimulatorAgent(%MAP_SIZE%,%NUM_ITEMS%,!S_TRAPS!,3,%NUM_ROUNDS%,!S_REDIST!);rnd:RandomAgent(%%C);agA:AgentA(%%C);agB:AgentB(%%C)" > "!LOGFILE!" 2>&1
        )
    )
)

echo.
echo ============================================================
echo  ALL SIMULATIONS COMPLETE
echo  Raw logs saved in results\logs\
echo  Run extract_results.ps1 to generate CSV summary
echo ============================================================
pause
