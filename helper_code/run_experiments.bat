@echo off
set JADE_LIB="C:\Users\raque\Documents\MAS\jade\JADE-bin-4.6.0\jade\lib\jade.jar"
set TEMP_FILE=temp_raw.txt
set OUTPUT_FILE=random1_T2.txt

echo === EXPERIMENTOS EN CURSO (SOLO DATOS FINALES) ===
echo Listado de puntuaciones finales > %OUTPUT_FILE%

for /L %%i in (1,1,10) do (
   echo Running Repetition %%i of 10...
   
   taskkill /F /IM java.exe >nul 2>&1
   timeout /t 2 /nobreak >nul

   :: Ejecutamos JADE (Simulador + Agente) y guardamos la salida completa
   java -cp %JADE_LIB%;. jade.Boot -agents "sim:SimulatorAgent;jugador:RandomAgent(1)" > %TEMP_FILE% 2>&1

   echo ------------------------------------------ >> %OUTPUT_FILE%
   echo REPETICION %%i >> %OUTPUT_FILE%
   
   :: Extraemos el bloque usando tus nuevas etiquetas exactas
   powershell -Command "$p = Get-Content %TEMP_FILE%; $start = [array]::FindIndex($p, [Predicate[string]]{ $args[0].Trim() -eq 'FINAL SIMULATION STATE:' }); $end = [array]::FindIndex($p, [Predicate[string]]{ $args[0].Trim() -eq 'FINAL SIMULATION END' }); if($start -ge 0 -and $end -gt $start){ $p[$start..$end] | Out-File -Append %OUTPUT_FILE% }"
   
   echo Repetition %%i finished.
)

del %TEMP_FILE%
echo === PROCESO FINALIZADO ===
pause