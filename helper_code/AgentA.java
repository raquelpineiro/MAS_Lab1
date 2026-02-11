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
import java.util.Random;

public class AgentA extends Agent {
    
    private SimulationState myState;
    private MapNavigator navigator;
    private AID simulatorAID;
    private int commitment;

    protected void setup() {
        System.out.println("Agent A " + getLocalName() + " initialize...");
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
            // Try to find the simulator agent with retries
            while (simulatorAID == null && tries < 10) {
                DFAgentDescription[] result = DFService.search(this, template);
                
                if (result.length > 0) {
                    simulatorAID = result[0].getName();
                    System.out.println("Simulator found: " + simulatorAID.getLocalName());
                } else {
                    System.out.println("Simulator not found, retry in 1 second...");
                    doWait(1000); // Wait 1 second
                    tries++;
                }
            }

            if (simulatorAID != null) {
                // Send join request
                ACLMessage joinMsg = new ACLMessage(ACLMessage.REQUEST);
                joinMsg.addReceiver(simulatorAID);
                joinMsg.setConversationId("join-simulation-request");
                joinMsg.setContent(String.valueOf(commitment)); 
                send(joinMsg);
                
                // Wait for response
                MessageTemplate mt = MessageTemplate.MatchConversationId("join-simulation-request");
                ACLMessage reply = blockingReceive(mt);
                
                if (reply != null && reply.getPerformative() == ACLMessage.AGREE) {
                    System.out.println("Request accepted. Initialize state...");
                    try {
                        myState = (SimulationState) reply.getContentObject();
                        // Ones we have the initial state, we can start the main behavior
                        addBehaviour(new PlayGameBehaviour());
                    } catch (Exception e) {
                        e.printStackTrace();
                    }
                } else {
                    System.out.println("Request negate.");
                    doDelete();
                }
            } else {
                System.out.println("ERROR: Simulator not found after few tries.");
                doDelete();
            }
        } catch (Exception e) {
            e.printStackTrace();
        }
    }

    // --- INTELLIGENT BEHAVIOUR (GREEDY) ---
    private class PlayGameBehaviour extends CyclicBehaviour {
        public void action() {
            ACLMessage msg = myAgent.receive();

            if (msg != null) {
                String conversationId = msg.getConversationId();

                if ("request-action".equals(conversationId) && msg.getPerformative() == ACLMessage.REQUEST) {
                    try {
                        Position currentPos = myState.getPosition();
                        LinkedList<Position> candidates = navigator.getNextPossiblePositions(myState.getMap(), currentPos);
                        
                        // --- STRATEGY AGENT A ---
                        Position nextMove = null;
                        
                        // 1. Obtain list of items in the map
                        LinkedList<Position> items = myState.getMap().getItemPositions();
                        
                        // 2. Filter candidates to avoid traps (if possible)
                        LinkedList<Position> safeCandidates = new LinkedList<>();
                        for (Position p : candidates) {
                            if (!myState.getMap().isTrapPosition(p)) {
                                safeCandidates.add(p);
                            }
                        }
                        
                        // If we have safe candidates, we will consider them. If not, we will consider all candidates (even if they have traps) to avoid being stuck.
                        LinkedList<Position> finalCandidates = safeCandidates.isEmpty() ? candidates : safeCandidates;

                        if (!items.isEmpty()) {
                            // 3. If there are items, choose the one closest to me
                            Position bestItem = null;
                            int minDistance = Integer.MAX_VALUE;
                            
                            for (Position item : items) {
                                int dist = Math.abs(item.x - currentPos.x) + Math.abs(item.y - currentPos.y);
                                if (dist < minDistance) {
                                    minDistance = dist;
                                    bestItem = item;
                                }
                            }
                            
                            // 4. Choose the candidate move that brings me closer to that item
                            int currentDist = Math.abs(bestItem.x - currentPos.x) + Math.abs(bestItem.y - currentPos.y);
                            
                            for (Position move : finalCandidates) {
                                int newDist = Math.abs(bestItem.x - move.x) + Math.abs(bestItem.y - move.y);
                                if (newDist < currentDist) {
                                    nextMove = move;
                                    currentDist = newDist; // Update currentDist to ensure we pick the best move towards the item
                                }
                            }
                        }
                        
                        // 5. If no move brings me closer to an item, pick a random safe move (or any move if no safe moves)
                        if (nextMove == null && !finalCandidates.isEmpty()) {
                            Random rand = new Random();
                            nextMove = finalCandidates.get(rand.nextInt(finalCandidates.size()));
                        } else if (nextMove == null) {
                            nextMove = currentPos; // Stay in place if no moves available (should not happen since we should have at least the current position as candidate)
                        }

                        // Send the chosen move as a proposal
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
                    System.out.println(getLocalName() + ": End. I have finish.");
                    myAgent.doDelete();
                }
            } else {
                block();
            }
        }
    }
}
