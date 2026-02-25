@echo off
setlocal EnableDelayedExpansion

:: ============================================================
:: MAS Lab1 - Run one simulation example "in one go"
:: ============================================================
::
:: Usage:
::   run_simulation.bat [SCENARIO] [AGENT_MODE] [COMMITMENT]
::
:: SCENARIO (optional, default=1):
::   1 = Fixed world, no traps
::   2 = Fixed world, 10 traps
::   3 = Dynamic world, no traps
::   4 = Dynamic world, 10 traps
::
:: AGENT_MODE (optional, default=all):
::   all    = All 3 agents together (RandomAgent + AgentA + AgentB)
::   random = RandomAgent alone
::   agentA = AgentA alone
::   agentB = AgentB alone
::
:: COMMITMENT (optional, default=1):
::   Integer value for agent commitment parameter
::
:: Examples:
::   run_simulation.bat                    (scenario 1, all agents, commitment 1)
::   run_simulation.bat 2                  (scenario 2, all agents, commitment 1)
::   run_simulation.bat 3 agentA 20        (scenario 3, AgentA alone, commitment 20)
::   run_simulation.bat 4 all 1            (scenario 4, all agents, commitment 1)
::
:: ============================================================

set JADE_LIB=C:\Users\david\Documents\JADE-all-4.6.0\JADE-bin-4.6.0\jade\lib\jade.jar

:: Fixed map parameters (as per enunciado: 10x10 map, 5 items, 1000 rounds)
set MAP_SIZE=10
set NUM_ITEMS=5
set NUM_ROUNDS=1000

:: Parse arguments with defaults
set SCENARIO=%~1
if "%SCENARIO%"=="" set SCENARIO=1

set AGENT_MODE=%~2
if "%AGENT_MODE%"=="" set AGENT_MODE=all

set COMMITMENT=%~3
if "%COMMITMENT%"=="" set COMMITMENT=1

:: Set scenario parameters
if "%SCENARIO%"=="1" (
    set NUM_TRAPS=0
    set REDIST=1000
    set SCENARIO_DESC=Fixed world, no traps
)
if "%SCENARIO%"=="2" (
    set NUM_TRAPS=10
    set REDIST=1000
    set SCENARIO_DESC=Fixed world, 10 traps
)
if "%SCENARIO%"=="3" (
    set NUM_TRAPS=0
    set REDIST=10
    set SCENARIO_DESC=Dynamic world, no traps
)
if "%SCENARIO%"=="4" (
    set NUM_TRAPS=10
    set REDIST=10
    set SCENARIO_DESC=Dynamic world, 10 traps
)

:: Set agent configuration
if /I "%AGENT_MODE%"=="all" (
    set NUM_PARTICIPANTS=3
    set AGENTS=rnd:RandomAgent(%COMMITMENT%);agA:AgentA(%COMMITMENT%);agB:AgentB(%COMMITMENT%)
    set AGENT_DESC=All 3 agents together
)
if /I "%AGENT_MODE%"=="random" (
    set NUM_PARTICIPANTS=1
    set AGENTS=player:RandomAgent(%COMMITMENT%)
    set AGENT_DESC=RandomAgent alone
)
if /I "%AGENT_MODE%"=="agentA" (
    set NUM_PARTICIPANTS=1
    set AGENTS=player:AgentA(%COMMITMENT%)
    set AGENT_DESC=AgentA alone
)
if /I "%AGENT_MODE%"=="agentB" (
    set NUM_PARTICIPANTS=1
    set AGENTS=player:AgentB(%COMMITMENT%)
    set AGENT_DESC=AgentB alone
)

:: Build SimulatorAgent arguments
set SIM_ARGS=%MAP_SIZE%,%NUM_ITEMS%,%NUM_TRAPS%,%NUM_PARTICIPANTS%,%NUM_ROUNDS%,%REDIST%

echo ============================================================
echo  MAS Lab1 - Simulation
echo  Scenario %SCENARIO%: !SCENARIO_DESC!
echo  Agent: !AGENT_DESC!
echo  Commitment: %COMMITMENT%
echo  Map: %MAP_SIZE%x%MAP_SIZE%, Items=%NUM_ITEMS%, Traps=!NUM_TRAPS!, ReDist=!REDIST!
echo  Rounds: %NUM_ROUNDS%
echo ============================================================
echo.

java -cp "%JADE_LIB%;." jade.Boot -agents "sim:SimulatorAgent(%SIM_ARGS%);!AGENTS!"

echo.
echo ============================================================
echo  Simulation finished.
echo ============================================================
pause
