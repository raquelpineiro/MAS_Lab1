import jade.core.Agent;
import jade.core.AID;
import jade.core.behaviours.*;
import jade.lang.acl.ACLMessage;
import jade.lang.acl.MessageTemplate;
import jade.domain.DFService;
import jade.domain.FIPAException;
import jade.domain.FIPAAgentManagement.DFAgentDescription;
import jade.domain.FIPAAgentManagement.ServiceDescription;
import java.util.LinkedList;
import java.util.Queue;
import java.util.HashSet;
import java.util.HashMap;
import java.util.Random;

public class AgentB extends Agent {
    
    private SimulationState myState;
    private MapNavigator navigator;
    private AID simulatorAID;
    private int commitment;

    protected void setup() {
        System.out.println("Agent B (BFS) " + getLocalName() + " initialize...");
        Object[] args = getArguments();
        if (args != null && args.length > 0) {
            commitment = Integer.parseInt((String) args[0]);
        } else {
            commitment = 1; 
        }
        navigator = new MapNavigator();
        joinSimulation();
    } 

    private void joinSimulation() {
        DFAgentDescription template = new DFAgentDescription();
        ServiceDescription sd = new ServiceDescription();
        sd.setType("SimulatorService");
        template.addServices(sd);

        try {
            int tries = 0;
            while (simulatorAID == null && tries < 10) {
                DFAgentDescription[] result = DFService.search(this, template);
                
                if (result.length > 0) {
                    simulatorAID = result[0].getName();
                    System.out.println("Simulator found: " + simulatorAID.getLocalName());
                } else {
                    System.out.println("Simulator not found, retry in 1 second...");
                    doWait(1000);
                    tries++;
                }
            }

            if (simulatorAID != null) {
                ACLMessage joinMsg = new ACLMessage(ACLMessage.REQUEST);
                joinMsg.addReceiver(simulatorAID);
                joinMsg.setConversationId("join-simulation-request");
                joinMsg.setContent(String.valueOf(commitment)); 
                send(joinMsg);
                
                MessageTemplate mt = MessageTemplate.MatchConversationId("join-simulation-request");
                ACLMessage reply = blockingReceive(mt);
                
                if (reply != null && reply.getPerformative() == ACLMessage.AGREE) {
                    System.out.println("Request accepted. Initialize state...");
                    try {
                        myState = (SimulationState) reply.getContentObject();
                        addBehaviour(new PlayGameBehaviour());
                    } catch (Exception e) {
                        e.printStackTrace();
                    }
                } else {
                    System.out.println("Request denied.");
                    doDelete();
                }
            } else {
                System.out.println("ERROR: Simulator not found after retries.");
                doDelete();
            }
        } catch (Exception e) {
            e.printStackTrace();
        }
    }

    // --- BFS PATHFINDING BEHAVIOUR ---
    private class PlayGameBehaviour extends CyclicBehaviour {
        public void action() {
            ACLMessage msg = myAgent.receive();

            if (msg != null) {
                String conversationId = msg.getConversationId();

                if ("request-action".equals(conversationId) && msg.getPerformative() == ACLMessage.REQUEST) {
                    try {
                        Position currentPos = myState.getPosition();
                        Position nextMove = bfsDecision(currentPos, myState.getMap());

                        ACLMessage proposal = msg.createReply();
                        proposal.setPerformative(ACLMessage.PROPOSE);
                        proposal.setContentObject(nextMove);
                        myAgent.send(proposal);

                    } catch (Exception e) { e.printStackTrace(); }
                } 
                else if ("update-state".equals(conversationId)) {
                    try { myState = (SimulationState) msg.getContentObject(); } catch (Exception e) {}
                }
                else if ("simulation-complete".equals(conversationId)) {
                    System.out.println(getLocalName() + ": End. BFS agent finished.");
                    myAgent.doDelete();
                }
            } else {
                block();
            }
        }

        /**
         * BFS-based decision function:
         * 1. BFS from currentPos avoiding traps → find shortest path to nearest item
         * 2. If no safe path exists, BFS allowing traps
         * 3. If no items reachable at all, pick a random safe adjacent position
         * 4. Return the FIRST STEP of the path (not the destination)
         */
        private Position bfsDecision(Position currentPos, Map map) {
            // Try BFS avoiding traps first
            Position firstStep = bfsToNearestItem(currentPos, map, true);
            
            if (firstStep != null) {
                return firstStep;
            }

            // If no safe path, try BFS allowing traps
            firstStep = bfsToNearestItem(currentPos, map, false);
            
            if (firstStep != null) {
                return firstStep;
            }

            // No items reachable: pick a random safe adjacent position (exploration)
            LinkedList<Position> candidates = navigator.getNextPossiblePositions(map, currentPos);
            LinkedList<Position> safeCandidates = new LinkedList<>();
            for (Position p : candidates) {
                if (!map.isTrapPosition(p)) {
                    safeCandidates.add(p);
                }
            }

            LinkedList<Position> finalCandidates = safeCandidates.isEmpty() ? candidates : safeCandidates;
            if (!finalCandidates.isEmpty()) {
                Random rand = new Random();
                return finalCandidates.get(rand.nextInt(finalCandidates.size()));
            }

            return currentPos; // Stay in place (should not happen)
        }

        /**
         * BFS from startPos. Expands adjacent positions (up/down/left/right).
         * If avoidTraps=true, does not expand through trap positions.
         * Returns the FIRST STEP toward the nearest item found, or null if none reachable.
         */
        private Position bfsToNearestItem(Position startPos, Map map, boolean avoidTraps) {
            // Queue stores positions to visit
            Queue<Position> queue = new LinkedList<>();
            // Track visited positions (using "x,y" string as key)
            HashSet<String> visited = new HashSet<>();
            // Parent map to reconstruct path: child -> parent
            HashMap<String, Position> parent = new HashMap<>();

            String startKey = posKey(startPos);
            queue.add(startPos);
            visited.add(startKey);
            parent.put(startKey, null); // start has no parent

            while (!queue.isEmpty()) {
                Position current = queue.poll();

                // Check if current position has an item (skip start position)
                if (!current.equals(startPos) && map.isItemPosition(current)) {
                    // Reconstruct path back to start and return the first step
                    return reconstructFirstStep(current, startPos, parent);
                }

                // Expand neighbors
                LinkedList<Position> neighbors = navigator.getNextPossiblePositions(map, current);
                for (Position neighbor : neighbors) {
                    String key = posKey(neighbor);
                    if (!visited.contains(key)) {
                        // Skip traps if avoidTraps is enabled
                        if (avoidTraps && map.isTrapPosition(neighbor)) {
                            continue;
                        }
                        visited.add(key);
                        parent.put(key, current);
                        queue.add(neighbor);
                    }
                }
            }

            return null; // No item reachable
        }

        /**
         * Given a target position found by BFS, walk back through parent pointers
         * to find the very first step from startPos toward the target.
         */
        private Position reconstructFirstStep(Position target, Position start, HashMap<String, Position> parent) {
            Position current = target;
            Position previous = parent.get(posKey(current));

            // Walk back until previous == start
            while (previous != null && !previous.equals(start)) {
                current = previous;
                previous = parent.get(posKey(current));
            }

            return current; // This is the first step from start toward target
        }

        /** Helper to create a unique string key for a Position */
        private String posKey(Position p) {
            return p.x + "," + p.y;
        }
    }
}
