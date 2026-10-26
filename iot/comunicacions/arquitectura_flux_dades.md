# Arquitectura del Flux de Dades IoT: Del Sensor a la Base de Dades Central

**Mòdul:** ASIX - Projecte (Requeriment 4.8)  
**Responsable:** Mariam (Base de Dades, IoT i Automatització)  
**Entorn:** Topologia de 7 Màquines Virtuals interconnectades  

---

## 1. Visió General del Flux d'Ingesta de Dades

El sistema d'AviGest garanteix la recollida contínua de les lectures ambientals de les naus i dipòsits de gra des de les explotacions remotes fins a la seu central, seguint el recorregut estricte definit en la nova arquitectura de màquines virtuals:

```mermaid
flowchart TD
    subgraph Granja["Granja 1 (10.1.1.0/24)"]
        direction LR
        Sim["granja1-sim<br/>• ESP32 simulats (RS485 Modbus)<br/>• Silos LoRaWAN (ChirpStack)"]
        -->|Trames Modbus / LoRa|
        Srv["granja1-srv (Edge)<br/>• MQTT local<br/>• Regles locals (Ventilador >31ºC)<br/>• Buffer Store-and-Forward<br/>• Client VPN (10.0.100.10)"]
    end

    subgraph Perimetre["fw-seu (OPNsense)"]
        VPN_In["Punt d'Entrada VPN (10.0.100.1)<br/>Regles 4.4: Només permet pas<br/>al port MQTT 1883/8883 de la LAN"]
    end

    subgraph Nucli["LAN seu (10.0.20.0/24)"]
        MQTT_Central["srv-serveis (10.0.20.10)<br/>Broker MQTT Mosquitto"]
        -->|Ingesta de lectures|
        PG["PostgreSQL 16 (avigest_db)<br/>+ Rèplica de BD"]
        PG -->|Trigger PL/pgSQL| Triggers["fn_control_llindars_sensor()<br/>• Actualitza actuador a ON<br/>• Insereix registre_actuacions<br/>• Insereix alarmes_incidencies"]
    end

    Srv ==>|Túnel xifrat VPN| VPN_In
    VPN_In ==>|NOMÉS MQTT:1883| MQTT_Central
```

---

## 2. Recorregut Detallat Pas a Pas d'una Lectura

### Pas 1: `granja1-sim` (Simulació de camp)
* Simula els microcontroladors ESP32 llegint sensors ambientals per bus sèrie **RS485 (Modbus RTU)** i les cèl·lules de pesatge dels silos exteriors per xarxa **LoRaWAN (ChirpStack)**.
* Publica les lectures en format JSON cap al servei local de `granja1-srv`.

### Pas 2: `granja1-srv` (Edge Computing i Buffer Local)
* Rep la lectura al broker MQTT local de la granja.
* **Execució de regles locals (Seguretat de suport a la vida / Life-Safety):**
  - Si la temperatura mesurada supera el llindar crític (> 31 ºC), activa immediatament el ventilador localment sense dependre d'Internet ni de la seu central.
* **Store-and-Forward:** Desa la lectura al búfer d'històrics local per si hi ha talls de xarxa rurals.
* Transmet el missatge telemètric pel túnel xifrat VPN cap a la seu central.

### Pas 3: `fw-seu` (Tallafocs OPNsense)
* És l'únic punt d'entrada des de la VPN (`10.0.100.0/24`).
* Aplica les regles de tallafocs documentades (4.4):
  - **Filtre estricte:** Només deixa passar el tràfic provinent de la granja amb destí al port del Broker MQTT de `srv-serveis` (`10.0.20.10:1883/8883`).
  - Qualsevol intent d'accedir directament a PostgreSQL (5432) o LDAP (389) és descartat immediatament (`DROP`).

### Pas 4: `srv-serveis` (Broker MQTT, PostgreSQL 16 i Rèplica)
* El broker **Eclipse Mosquitto** rep la lectura.
* El servei d'ingesta desa el valor a la taula `lectures_sensors` de **PostgreSQL 16**.
* Es dispara el trigger PL/pgSQL **`tg_control_llindars_sensor`**, auditant actuacions i generant alarmes si és procedent.
* La instància secundària de rèplica manté el registre duplicat per a alta disponibilitat d'aplicació.

### Pas 5: `srv-backup` (Còpies de seguretat)
* Cada nit a les 02:00 AM, `srv-backup` extreu els buidatges transaccionals i els desa al segon disc virtual extern.

### Pas 6: `dmz-web` (Accés client)
* El client (`pc-client`) consulta el portal web passant pel tallafocs i el proxy invers Nginx de la DMZ (`10.0.10.10`).
