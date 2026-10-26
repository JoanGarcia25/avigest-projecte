# Fitxa de Decisió Tècnica — FD05: Comunicacions IoT, Simulació i Arquitectura Edge

**Projecte:** AviGest S.L. — Sistema de gestió centralitzada de granges avícoles  
**Mòdul:** ASIX - Projecte (Requeriment 4.8)  
**Data:** Actualitzat a 26 d'octubre de 2026  
**Responsable:** Mariam (Àrea de Base de Dades, IoT i Automatització)  

---

## 1. Descripció de la necessitat
Segons l'enunciat:
- A cada granja hi ha sensors IoT (temperatura, humitat, CO2, silos de gra) i actuadors (ventiladors, calefactors).
- S'ha de justificar la tria **LoRaWAN vs RS485** segons distància, consum, volum de dades i entorn.
- S'ha de definir com viatgen les dades des dels sensors fins a la base de dades central de la seu, amb suport per a funcionament autònom davant caigudes de connectivitat.

---

## 2. Alternatives avaluades i Disseny en Dues Màquines a la Granja

Per aïllar correctament la simulació de maquinari del control de la granja, es divideix la instal·lació de Granja 1 (`10.1.1.0/24`) en dos equips:

### Màquina 1: `granja1-sim` (Dispositius de camp)
- **RS485 amb protocol Modbus RTU:**
  * **Ubicació:** Dins de les naus per a sensors de temperatura, humitat i actuadors (ventiladors).
  * **Justificació:** Alta immunitat a les interferències de grans motors elèctrics, alimentació permanent per cable trenat apantallat i resposta immediata de mil·lisegons.
- **LoRaWAN (amb ChirpStack):**
  * **Ubicació:** Silos de gra exteriors i dipòsits aïllats.
  * **Justificació:** Abast de quilòmetres sense necessitat de rases perilloses per a tractors; baixíssim consum (funciona amb bateries en *Deep Sleep*).

### Màquina 2: `granja1-srv` (Gateway Edge Computing de Granja)
- **Client VPN:** S'autentica contra `fw-seu` (xarxa `10.0.100.0/24`).
- **Broker MQTT local:** Recull la telemetria provinent de `granja1-sim`.
- **Regles d'actuació locals (*Edge Computing*):** Executa les regles automàtiques immediates (si T > 31ºC, activa ventilador) de forma autònoma, sense esperar resposta de la central.
- **Búfer de dades (*Store-and-Forward*):** Si la VPN o Internet cau, emmagatzema les lectures localment i les reenvia quan es restableix el túnel cap a la seu central.

---

## 3. Decisió presa
**S'adopta l'arquitectura híbrida RS485 + LoRaWAN a `granja1-sim`, transmetent cap a `granja1-srv` mitjançant MQTT local, i d'allí per la VPN fins a `srv-serveis`.**

---

## 4. Mètode de verificació
- **Simulació a `granja1-sim`:** Generació de trames Modbus i paquets LoRa cap a `granja1-srv`.
- **Comprovació de regles locals:** Validació que `granja1-srv` activa el relé del ventilador fins i tot si es desconnecta la interfície de xarxa cap a la seu central.
- **Ingesta central:** Verificació a `srv-serveis` que les lectures arriben al broker MQTT i es guarden a la taula corresponent de PostgreSQL.
