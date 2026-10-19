# Arquitectura del Flux de Dades IoT: Del Sensor a la Base de Dades Central

**Mòdul:** ASIX - Projecte (Requeriment 4.8)  
**Responsable:** Mariam (Base de Dades, IoT i Automatització)  

---

## 1. Visió General del Flux d'Ingesta de Dades

El sistema d'AviGest garanteix la recollida contínua de les mètriques ambientals de les naus i dels dipòsits de gra des de les explotacions remotes fins a la seu central.

```mermaid
flowchart TD
    subgraph Granja["1 & 2. Granja Remota (Camp & Gateway)"]
        direction TB
        S_RS485["Sensors Temp/Humitat (RS485 Modbus)"] -->|Bus cablejat| ESP_Nau["ESP32 Mestre de Nau"]
        Actuador["Relés Ventiladors / Calefacció"] <--|Modbus RTU| ESP_Nau
        S_LoRa["Sensors de Silo (Pes/Nivell)"] -->|Ràdio LoRaWAN 868MHz| GwLoRa["Gateway LoRaWAN Granja"]
        ESP_Nau -->|Ethernet local| GatewayGranja["Gateway Industrial Fanless<br/>(Buffer Store-and-Forward)"]
        GwLoRa -->|Ethernet local| GatewayGranja
    end

    subgraph WAN_Internet["3. Xarxa WAN / Internet Segura"]
        GatewayGranja ==>|Payloads JSON xifrats sobre TLS/HTTPS| DMZ_Ingesta["Proxy Nginx / API d'Ingesta (DMZ)"]
    end

    subgraph Central["4. Seu Central AviGest (LAN Interna)"]
        DMZ_Ingesta ==>|Inserció transaccional| MariaDB["MariaDB (Taula lectures_sensors)"]
        MariaDB -->|Trigger AFTER INSERT| Trigger["tg_control_llindars_sensor"]
        Trigger -->|Si > 31ºC| AutoVent["Actualitza estat actuador a ON<br/>+ Escriu a registre_actuacions"]
        Trigger -->|Si crític| AutoAlarm["Insereix a alarmes_incidencies"]
    end
```

---

## 2. Descripció de les 4 Etapes del Flux de Dades

### Etapa 1: Captura de Dades a Camp (ESP32)
* **Dins de la nau:** Els sensors ambientals (temperatura, humitat) estan connectats a un bus RS485 diferencial amb un transceptor MAX485 o transceiver industrial aïllat galvànicament. L'ESP32 llegeix les trames Modbus periòdicament (cada 30 segons).
* **Als silos exteriors:** La cèl·lula de pesatge del silo transmet una trama LoRaWAN cap al gateway de la granja (cada 30-60 minuts).

### Etapa 2: Concentració i Processament a la Vora (Edge Computing a la Granja)
* El **Gateway Industrial de la Granja** recull totes les trames de la instal·lació.
* **Seguretat local de suport a la vida (Life-Safety):**
  - Si es perd la connexió a Internet amb la seu central, la nau **no queda indefensa**.
  - L'ESP32 local conté un bucle de control bàsic autònom: si la temperatura mesurada supera el llindar crític de 31 ºC, el relé de sortida commuta directament els ventiladors de forma d'emergència.
* **Mecanisme Store-and-Forward:** Si la connexió WAN cau, el gateway desa les lectures en una base de dades local de cua (SQLite o búfer en memòria cau). Quan el router 4G/fibra es restableix, envia totes les lectures acumulades amb la seva marca horària original (*timestamp*), evitant forats en les gràfiques d'històric.

### Etapa 3: Transport Segur fins a la Seu Central
* Les lectures s'empaqueten en trames lleugeres en format **JSON**:
  ```json
  {
    "codi_granja": "ES250480001",
    "codi_nau": "NAU-01",
    "sensor_id": 1,
    "tipus": "temperatura",
    "valor": 32.40,
    "unitat": "ºC",
    "timestamp": "2026-10-19T10:15:30Z"
  }
  ```
* El transport es realitza a través d'una connexió segura (HTTPS POST cap a l'endpoint de la DMZ o broker MQTT sobre TLS `port 8883`). Només els gateways de les granges autoritzades poden enviar informació (filtratge per certificat de client o token d'autenticació API).

### Etapa 4: Ingesta, Triggers i Automatismes a MariaDB
* El servei d'ingesta de la seu central valida la informació i executa la inserció SQL a la taula transaccional:
  ```sql
  INSERT INTO lectures_sensors (id_sensor, data_hora, valor, unitat)
  VALUES (1, '2026-10-19 10:15:30', 32.40, 'ºC');
  ```
* En el mateix mil·lisegon d'inserció, es dispara el trigger **`tg_control_llindars_sensor`**:
  1. Comprova que `32.40 > 31.00` (llindar màxim).
  2. Actualitza automàticament la taula `actuadors` posant el ventilador a `ON`.
  3. Apunta l'activació a la taula d'auditoria `registre_actuacions` amb el motiu del sobreescalfament.
  4. Genera una entrada crítica a `alarmes_incidencies` per avisar el gestor de la granja.
