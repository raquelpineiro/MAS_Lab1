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

public class RandomAgent extends Agent {
    
    private SimulationState myState;
    private MapNavigator navigator;
    private AID simulatorAID;
    private int commitment;

    // --- MÉTODO SETUP ---
    protected void setup() {
        System.out.println("Agente " + getLocalName() + " iniciando...");

        // 1. Leer argumentos
        Object[] args = getArguments();
        if (args != null && args.length > 0) {
            commitment = Integer.parseInt((String) args[0]);
        } else {
            commitment = 1; 
        }

        // 2. Inicializar herramientas
        navigator = new MapNavigator();

        // 3. Llamar a la función para unirse
        joinSimulation();
    } 

    // --- MÉTODO JOIN SIMULATION CON REINTENTOS ---
    private void joinSimulation() {
        DFAgentDescription template = new DFAgentDescription();
        ServiceDescription sd = new ServiceDescription();
        sd.setType("SimulatorService");
        template.addServices(sd);

        try {
            int intentos = 0;
            // Intentamos buscar hasta 10 veces (esperando 1 seg entre intentos)
            while (simulatorAID == null && intentos < 10) {
                DFAgentDescription[] result = DFService.search(this, template);
                
                if (result.length > 0) {
                    simulatorAID = result[0].getName();
                    System.out.println("Simulador encontrado: " + simulatorAID.getLocalName());
                } else {
                    System.out.println("Simulador no encontrado, reintentando en 1 seg...");
                    doWait(1000); // Esperar 1 segundo (método de JADE)
                    intentos++;
                }
            }

            if (simulatorAID != null) {
                // Enviar solicitud de unión
                ACLMessage joinMsg = new ACLMessage(ACLMessage.REQUEST);
                joinMsg.addReceiver(simulatorAID);
                joinMsg.setConversationId("join-simulation-request");
                joinMsg.setContent(String.valueOf(commitment)); 
                send(joinMsg);
                
                // Esperar respuesta bloqueante
                MessageTemplate mt = MessageTemplate.MatchConversationId("join-simulation-request");
                ACLMessage reply = blockingReceive(mt);
                
                if (reply != null && reply.getPerformative() == ACLMessage.AGREE) {
                    System.out.println("Solicitud aceptada. Inicializando estado...");
                    try {
                        myState = (SimulationState) reply.getContentObject();
                        // Una vez aceptados, añadimos el comportamiento de juego
                        addBehaviour(new PlayGameBehaviour());
                    } catch (Exception e) {
                        e.printStackTrace();
                    }
                } else {
                    System.out.println("Solicitud rechazada.");
                    doDelete();
                }
            } else {
                System.out.println("ERROR: No se encontró el simulador tras varios intentos.");
                doDelete();
            }
        } catch (Exception e) {
            e.printStackTrace();
        }
    }

    // --- CLASE INTERNA DEL COMPORTAMIENTO ---
    private class PlayGameBehaviour extends CyclicBehaviour {
        public void action() {
            ACLMessage msg = myAgent.receive();

            if (msg != null) {
                String conversationId = msg.getConversationId();

                // CASO 1: Petición de movimiento
                if ("request-action".equals(conversationId) && msg.getPerformative() == ACLMessage.REQUEST) {
                    try {
                        Position currentPos = myState.getPosition();
                        LinkedList<Position> candidates = navigator.getNextPossiblePositions(myState.getMap(), currentPos);
                        
                        Random rand = new Random();
                        Position nextMove = currentPos; 
                        
                        if (!candidates.isEmpty()) {
                            int index = rand.nextInt(candidates.size());
                            nextMove = candidates.get(index);
                        }

                        ACLMessage proposal = msg.createReply();
                        proposal.setPerformative(ACLMessage.PROPOSE);
                        proposal.setContentObject(nextMove);
                        myAgent.send(proposal);
                        
                        System.out.println(getLocalName() + ": Moviendo a " + nextMove);

                    } catch (Exception e) {
                        e.printStackTrace();
                    }
                } 
                // CASO 2: Actualización de estado
                else if ("update-state".equals(conversationId) && msg.getPerformative() == ACLMessage.INFORM) {
                    try {
                        myState = (SimulationState) msg.getContentObject();
                    } catch (Exception e) {
                        e.printStackTrace();
                    }
                }
                // CASO 3: Fin de la simulación
                else if ("simulation-complete".equals(conversationId)) {
                    System.out.println(getLocalName() + ": Fin de la partida.");
                    myAgent.doDelete();
                }
            } else {
                block();
            }
        }
    }
}