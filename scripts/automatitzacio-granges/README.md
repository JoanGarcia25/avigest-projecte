# Automatització d'Alta de Noves Granges — AviGest S.L.

**Mòdul:** ASIX - Projecte (Requeriments 4.7 i Prova Pràctica d'Avaluació Presencial)  
**Script Principal:** `alta_granja.sh`  

---

## 1. Objectiu de l'Automatització i Variació Presencial (Granja 2)

Segons el requeriment 4.7 i el punt 7 d'Avaluació Presencial:
> *"Per afegir la Granja 2 (la variació que us demanaran), clonareu `granja1-srv` i `granja1-sim` en una xarxa nova (`10.1.2.0/24`). L'script del 4.7 ha de crear l'usuari a LDAP, l'esquema a la BD i la regla al firewall."*

Aquest script automatitza completament el procés en pocs segons.

---

## 2. Què fa l'Script amb una sola ordre?

Quan s'executa `./alta_granja.sh`:
1. **Base de Dades PostgreSQL 16 (`srv-serveis`):** Invoca la funció `sp_alta_granja_completa` que:
   - Insereix el registre de la nova granja a la taula `granges`.
   - Crea les naus sol·licitades (ex: `NAU-01`, `NAU-02`).
   - Provisiona els sensors per defecte a cada nau:
     - Sensor de temperatura (RS485 Modbus) amb llindars 20 ºC - 31 ºC.
     - Sensor d'humitat (RS485 Modbus) amb llindars 45% - 70%.
     - Sensor de silo de gra exterior (LoRaWAN) amb llindar mínim de 1000 kg.
     - Sensor de CO2 (RS485 Modbus).
   - Provisiona els actuadors industrials (ventilador, calefactor, il·luminació).
2. **Directori Centralitzat OpenLDAP (`srv-serveis`):**
   - Crea el compte d'usuari per al responsable de la granja (`uid=gestor_<granja>`).
   - Assigna els atributs `businessCategory: CLIENT_<ID>` i `departmentNumber: GRANJA_<ID>` per aplicar l'**aïllament multitenant (R3)**.
3. **Regla de Tallafocs a `fw-seu` (OPNsense / iptables):**
   - Genera la regla d'accés per a la IP VPN `10.0.100.<10+id_granja>` amb pas exclusiu cap a MQTT `10.0.20.10:1883`.
   - Afegeix l'usuari al grup `cn=GestorsGranja` (no amaga errors d'LDAP).
4. **Gateway Local i Buffer:**
   - Genera l'estructura de carpetes per al gateway local clonat (`/var/avigest/granges/<codi_explotacio>/telemetria`, `logs`, `config`).
   - Crea el fitxer de variables d'entorn `gateway.env`.

---

## 3. Instruccions d'Ús

### Mode 1: Execució Ràpida per Línia de Comandes (Recomanat per a la prova en directe)
```bash
./alta_granja.sh -c 1 -n "Granja 2 Urgell" -e "ES252170099" -a "Camí Vell s/n" -p "Bellpuig" -s 2 -u "gestor_granja2" -r "10.1.2.0/24"
```
Contrasenya de laboratori del gestor: `avigest2026` (la mateixa que els usuaris LDIF). El codi d'explotació ha de ser **únic** (`ES252170004` ja el fa servir Tàrrega a les dades de prova).

### Mode 2: Assistent Interactiu per Consola
```bash
./alta_granja.sh
```
