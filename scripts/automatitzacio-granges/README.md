# Automatització d'Alta de Noves Granges — AviGest S.L.

**Mòdul:** ASIX - Projecte (Requeriments 4.7 i Prova Pràctica d'Avaluació Presencial)  
**Script Principal:** `alta_granja.sh`

---

## 1. Objectiu de l'Automatització
Segons el requeriment 4.7 de l'enunciat:
> *"Scripts de shell que automatitzin la creació d'una nova granja dins del sistema: alta de l'estructura de directoris/comptes/serveis corresponents, de manera que donar d'alta una granja nova sigui un procés ràpid i repetible."*

A més, en el punt **7. Sistema d'avaluació**, l'enunciat adverteix:
> *"Cada equip rebrà durant la fase d'execució una petita variació del requeriment (p. ex. una granja addicional amb característiques concretes) que haurà d'implementar en una sessió presencial."*

Aquest script permet respondre a la petició del professor en qüestió de **segons**, demostrant un nivell de preparació i professionalitat excel·lent.

---

## 2. Què fa l'Script amb una sola ordre?
Quan s'executa `./alta_granja.sh`:
1. **Base de Dades MariaDB:** Invoca el procediment emmagatzemat `sp_alta_granja_completa` que:
   - Insereix el registre de la nova granja a la taula `granges`.
   - Crea automàticament les naus sol·licitades (ex: `NAU-01`, `NAU-02`).
   - Provisiona els sensors per defecte a cada nau:
     - Sensor de temperatura (RS485 Modbus) amb llindars 20 ºC - 31 ºC.
     - Sensor d'humitat (RS485 Modbus) amb llindars 45% - 70%.
     - Sensor de silo de gra exterior (LoRaWAN) amb llindar mínim de 1500 kg.
   - Provisiona els actuadors industrials (ventilador d'extracció i calefactor).
2. **Directori Centralitzat OpenLDAP:**
   - Crea el compte d'usuari per al responsable de la granja (`uid=gestor_<granja>`).
   - Assigna els atributs `businessCategory: CLIENT_<ID>` i `departmentNumber: GRANJA_<ID>` per aplicar l'**aïllament multitenant (R3)**.
   - Afegeix l'usuari al grup `cn=GestorsGranja,ou=groups,dc=avigest,dc=cat`.
3. **Sistema de Fitxers Local:**
   - Genera l'estructura de carpetes per al gateway local de la granja (`/var/avigest/granges/<codi_explotacio>/telemetria`, `logs`, `config`).
   - Crea el fitxer de variables d'entorn `gateway.env`.

---

## 3. Instruccions d'Ús

### Mode 1: Execució Ràpida per Línia de Comandes (Recomanat per a la prova en directe)
```bash
./alta_granja.sh -c 1 -n "Granja Urgell Tàrrega" -e "ES252170004" -a "Camí Vell s/n" -p "Tàrrega" -s 3 -u "gestor_tarrega"
```

### Mode 2: Assistent Interactiu per Consola
Si s'executa sense paràmetres, l'script demana les dades pas a pas:
```bash
./alta_granja.sh
```
Sortida de l'assistent:
```text
ID del Client propietari (ex: 1): 1
Nom comercial de la granja: Granja Urgell Tàrrega
Codi oficial d'explotació (ex: ES252170004): ES252170004
Adreça física: Camí de Verdú s/n
Població: Tàrrega
Nombre de naus a crear (1-10) [2]: 3
Nom d'usuari per al Gestor de la granja: gestor_tarrega
```
