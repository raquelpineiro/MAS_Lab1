# MAS Lab 1 — Item World Simulation (JADE)

This folder contains the source code for the Multi-Agent Systems lab: **Item World** simulation with one Simulator Agent and three types of participant agents (Random, Type A — Greedy, Type B — BFS). All agents are implemented in JADE.

---

## Prerequisites

- **Java JDK** (8 or later), with `java` and `javac` on the `PATH`.
- **JADE** (Java Agent DEvelopment Framework).  
  Download from the [JADE website](https://jade.tilab.com/) and note the path to `jade.jar` (typically inside the `lib` folder of the JADE distribution).

---

## Configuration: JADE library path

Set the path to `jade.jar` in one of these ways:

- **Environment variable (recommended):**  
  `JADE_JAR` = full path to `jade.jar`  
  Example (Windows):  
  `set JADE_JAR=C:\path\to\JADE\lib\jade.jar`  
  Example (Linux/macOS):  
  `export JADE_JAR=/path/to/JADE/lib/jade.jar`

- **Or** edit the scripts that use it: `run_simulation.bat` and `run_all_experiments.bat`. At the top of each, set the variable that points to `jade.jar` (e.g. `JADE_LIB`) to your actual path.

---

## Compilation

From the folder that contains all `.java` files (this `helper_code` folder), run:

**Windows (cmd):**
```cmd
javac -cp "%JADE_JAR%;." *.java
```

**Windows (PowerShell):**
```powershell
javac -cp "$env:JADE_JAR;." *.java
```

**Linux / macOS:**
```bash
javac -cp "$JADE_JAR:." *.java
```

If you did not set `JADE_JAR`, replace `%JADE_JAR%` / `$env:JADE_JAR` / `$JADE_JAR` with the full path to `jade.jar`, for example:
```cmd
javac -cp "C:\JADE\lib\jade.jar;." *.java
```

This produces the `.class` files needed to run the simulation.

---

## Running a single simulation (one go)

You must start **one Simulator Agent** and **one or more participant agents** in the same JADE container. The Simulator waits until the required number of participants has joined, then runs the simulation for the configured number of rounds.

### Using `run_simulation.bat` (recommended for quick runs)

The script `run_simulation.bat` runs one simulation with configurable scenario, agent mode, and commitment. Set `JADE_LIB` at the top of the script to your `jade.jar` path, then:

```cmd
run_simulation.bat [SCENARIO] [AGENT_MODE] [COMMITMENT]
```

| Argument    | Optional | Values | Default | Description |
|------------|----------|--------|---------|-------------|
| SCENARIO   | Yes      | 1–4    | 1       | 1 = fixed, no traps; 2 = fixed, 10 traps; 3 = dynamic, no traps; 4 = dynamic, 10 traps |
| AGENT_MODE | Yes      | `all`, `random`, `agentA`, `agentB` | `all` | `all` = three agents together; others = one agent alone |
| COMMITMENT | Yes      | integer (e.g. 1–20) | 1 | Commitment parameter for participant(s) |

**Examples:**
```cmd
run_simulation.bat
run_simulation.bat 2
run_simulation.bat 3 agentA 20
run_simulation.bat 4 all 1
```

The script uses a 10×10 map, 5 items, and 1000 rounds; scenario controls traps and redistribution step.

### Simulator agent arguments

`SimulatorAgent` takes **6 arguments** (in order):

| # | Parameter           | Meaning                          | Example |
|---|---------------------|----------------------------------|---------|
| 1 | map size (rows/cols)| Grid dimension (e.g. 10 → 10×10) | 10      |
| 2 | number of items     | Items on the map                 | 5       |
| 3 | number of traps     | Trap cells                        | 0 or 10 |
| 4 | number of participants | How many agents must join     | 1 or 3  |
| 5 | simulation rounds   | Rounds per run                    | 1000    |
| 6 | redistribution step| Rounds between map rescheduling (e.g. 1000 = fixed) | 1000 or 10 |

Example: `SimulatorAgent(10,5,0,1,1000,1000)` → 10×10 map, 5 items, 0 traps, 1 participant, 1000 rounds, fixed map.

### Participant agent arguments

Each participant agent takes a single argument: **commitment** (integer, typically 1–20).  
Example: `RandomAgent(1)` or `AgentA(20)`.

### Example: one simulation in one command

**One agent alone (e.g. Random, commitment 1):**

**Windows (cmd):**
```cmd
java -cp "%JADE_JAR%;." jade.Boot -agents "sim:SimulatorAgent(10,5,0,1,1000,1000);player:RandomAgent(1)"
```

**Linux / macOS:**
```bash
java -cp "$JADE_JAR:." jade.Boot -agents "sim:SimulatorAgent(10,5,0,1,1000,1000);player:RandomAgent(1)"
```

**All three agents together (commitment 1):**

**Windows (cmd):**
```cmd
java -cp "%JADE_JAR%;." jade.Boot -agents "sim:SimulatorAgent(10,5,5,3,1000,1000);rnd:RandomAgent(1);agA:AgentA(1);agB:AgentB(1)"
```

Again, replace `%JADE_JAR%` or `$JADE_JAR` with your actual `jade.jar` path if you did not set the environment variable.

---

## Instantiating each agent type from the command line

As required, every participant agent can be started directly from the command line via `jade.Boot -agents ...`.

- **Random agent:**  
  `RandomAgent(commitment)`  
  Example: `player:RandomAgent(1)` or `player:RandomAgent(20)`.

- **Agent Type A (Greedy):**  
  `AgentA(commitment)`  
  Example: `agA:AgentA(1)`.

- **Agent Type B (BFS):**  
  `AgentB(commitment)`  
  Example: `agB:AgentB(20)`.

The name before the colon is the JADE local name (e.g. `player`, `rnd`, `agA`, `agB`); you can choose any valid name. The number in parentheses is the commitment value.

Full example with one of each type and the simulator:
```text
java -cp "<path-to-jade.jar>;." jade.Boot -agents "sim:SimulatorAgent(10,5,10,3,1000,1000);agent1:RandomAgent(1);agent2:AgentA(1);agent3:AgentB(1)"
```

---

## Running the experiment scripts (many runs in one go)

To run the full set of experiments (4 scenarios × various agent configurations × 2 commitments × 10 repetitions):

1. **Set the JADE path** in `run_all_experiments.bat` (variable `JADE_LIB` at the top).

2. **Compile** all sources as in “Compilation” above.

3. **Run all simulations** (raw output is saved per run):
   ```cmd
   run_all_experiments.bat
   ```
   This creates `results\logs\` and writes one `.log` file per run (e.g. `3.1_fixed_no_traps_AgentA_solo_c1_rep3.log`). Each JADE run uses a different port to avoid collisions.

4. **Extract results and generate summary:**
   ```cmd
   powershell -ExecutionPolicy Bypass -File extract_results.ps1
   ```
   This script reads all `.log` files in `results\logs\`, parses the “FINAL SIMULATION STATE” block from each, and produces:
   - **`results\all_results.csv`** — one row per agent/run (Scenario, Config, AgentName, Commitment, Rep, Score, NumTraps).
   - **`results\summary.txt`** — averages per scenario/config/agent/commitment.

---“Compilation” above.

---

## File overview

| File / folder   | Description |
|-----------------|-------------|
| `SimulatorAgent.java` | Simulator; manages map, rounds, and participant protocol. |
| `SimulationManagerBehaviour.java` | Core simulation loop (do not modify for evaluation). |
| `RegisterParticipantsBehaviour.java` | Handles join requests and commitment. |
| `RandomAgent.java` | Participant: random move selection. |
| `AgentA.java` | Participant: greedy (nearest item, avoid traps). |
| `AgentB.java` | Participant: BFS to nearest item. |
| `Map.java`, `MapNavigator.java`, `Position.java`, … | Map, navigation, and simulation state. |
| `run_simulation.bat` | Run one simulation with optional scenario, agent mode, and commitment. |
| `run_all_experiments.bat` | Run all experiment combinations; saves raw output to `results\logs\`. |
| `extract_results.ps1` | Parse logs in `results\logs\` and generate `results\all_results.csv` and `results\summary.txt`. |

---

## Troubleshooting

- **“Simulator not found”:** Start the Simulator in the same `jade.Boot` command as the participants (as in the examples above). All agents must run in the same JADE platform for this lab.
- **Compilation errors:** Ensure `jade.jar` is in the classpath and all `.java` files from this folder are compiled together.
- **Scripts fail:** Check that `JADE_LIB` in `run_simulation.bat` and `run_all_experiments.bat` points to the correct `jade.jar` path (no spaces issues; use quotes if the path contains spaces).
- **extract_results.ps1** expects log files in `results\logs\` with names produced by `run_all_experiments.bat` (e.g. `3.1_fixed_no_traps_AgentA_solo_c1_rep3.log`). Run it from the `helper_code` folder after `run_all_experiments.bat` has finished. If some logs show “No FINAL block”, that run did not complete correctly; the script will still write `ERROR` rows to the CSV for those runs.
