# Fitxa de Decisió Tècnica — FD05: Comunicacions IoT (LoRaWAN vs RS485)

**Projecte:** AviGest S.L. — Sistema de gestió centralitzada de granges avícoles  
**Mòdul:** ASIX - Projecte (Requeriment 4.8 i Context Tecnològic)  
**Data:** 19 d'octubre de 2026  
**Responsable:** Mariam (Àrea de Base de Dades, IoT i Automatització)  

---

## 1. Descripció de la necessitat
Segons l'enunciat:
- A cada granja hi ha instal·lats sensors IoT controlats amb microcontroladors **ESP32** (temperatura, humitat, nivell de silos, consum d'aigua/aliment).
- S'han de connectar actuadors (ventiladors, calefactors, alarmes) amb reacció automàtica segons lectures de sensors.
- L'enunciat exigeix literalment: **"haureu de decidir quina tecnologia utilitzeu per a cada tipus de necessitat (LoRaWAN vs RS485) i justificar-ho segons distància, consum, volum de dades i entorn"**.
- Cal definir la canalització d'aquestes dades des dels dispositius de camp fins a la base de dades central de la seu d'AviGest.

---

## 2. Alternatives avaluades i Anàlisi Comparativa

### Tecnologia A: Bus Industrial Cablejat RS485 (Protocol Modbus RTU)
* **Descripció:** Estàndard de comunicació sèrie diferencial per cable de parell trenat apantallat (STP).
* **Paràmetres clau:**
  - **Distància:** Fins a 1.200 metres de longitud total de bus, amb múltiples dispositius (*daisy chain*).
  - **Consum energètic:** Mitjà/Alt (requereix alimentació per cable de 12V/24V DC). No apte per a sensors aïllats que funcionin amb petites piles.
  - **Volum i freqüència de dades:** Alta velocitat (fins a 115.200 bps o 10 Mbps). Permet mostrejos d'alta freqüència en temps real (cada pocs segons) i comunicació bidireccional determinista de baixa latència (< 20 ms).
  - **Resistència a l'entorn:** Immunitat electromagnètica màxima gràcies a la transmissió diferencial balanced-line. Resisteix les interferències de grans motors inductius (extractors de ventilació de 2 CV, bombes i variadors).

### Tecnologia B: Xarxa sense fils d'àrea àmplia LoRaWAN (868 MHz)
* **Descripció:** Protocol de comunicació per ràdio de llarg abast i baixíssim consum de dades (banda lliure ISM europea).
* **Paràmetres clau:**
  - **Distància:** De 2 a 10 km de cobertura rural directa (*Line of Sight*), travessant parets d'edificis exteriors.
  - **Consum energètic:** Ultra-baix (*Ultra Low Power*). Els dispositius romanen en mode *Deep Sleep* el 99% del temps, permetent una autonomia de 3 a 5 anys amb una senzilla bateria de liti LiFeS2 (sense necessitat de fil elèctric).
  - **Volum i freqüència de dades:** Molt reduït (paquets de 10 a 50 bytes) i amb limitació legal de cicle de treball (*Duty Cycle* de l'1% a Europa). No apte per a telemetria cada 2 segons ni per al control ràpid d'actuadors electromecànics crítics.
  - **Resistència a l'entorn:** Totalment immune a problemes mecànics de cables (no hi ha risc de tall de cables per tractors o rases de construcció).

---

## 3. Decisió presa: Model Híbrid Especialitzat per Necessitat

S'adopta una **arquitectura híbrida complementària**, assignant la tecnologia òptima a cada element de la granja:

| Element / Dispositiu | Ubicació | Tecnologia Escollida | Justificació Tècnica (Distància, Consum, Volum, Entorn) |
| :--- | :--- | :---: | :--- |
| **Sensors de Temperatura i Humitat** | Interior de la nau | **RS485 (Modbus)** | Requereixen lectures freqüents (cada 30-60 segons) per reaccionar ràpidament abans que pugi la calor. L'entorn té grans interferències de motors, i l'alimentació elèctrica és accessible al sostre/façana de la nau. |
| **Actuadors (Ventiladors i Calefactors)** | Interior / façana nau | **RS485 (Modbus)** | Requereixen ordre immediata i bidireccional fiable (confirmació d'engegada en mil·lisegons). No es pot assumir la latència ni les restriccions d'emissió de ràdio de LoRaWAN per a una ventilació crítica. |
| **Sensors de Silos de Gra / Pinso** | Exterior de la granja (aïllats) | **LoRaWAN (868 MHz)** | Els silos estan a l'exterior, a desenes de metres de les naus i patis transitats per camions. Passar cables soterrats seria molt costós i vulnerable a trencaments. El nivell de gra només cal enviar-lo un cop cada 30-60 minuts (volum mínim de dades) i funciona anys amb bateria. |
| **Sensors de Dipòsit d'Aigua General** | Exterior perimetral | **LoRaWAN (868 MHz)** | Mateixa justificació: ubicació exterior remota sense accés fàcil a línia elèctrica per cable. |

---

## 4. Mètode de verificació
- **Simulador de dades:** Verificació mitjançant el script `simulador_iot.py`, comprovant que les lectures etiquetades com a `RS485` arriben amb freqüència regular i les de `LoRaWAN` simulen el paquet periòdic de pes del silo.
- **Validació de trigger:** Comprovació que una lectura crítica procedent del bus RS485 activa immediatament l'actuador ventilador associat a la mateixa nau en menys d'un segon a la base de dades.
