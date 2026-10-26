# Fitxa de Decisió Tècnica — FD01: Sistema Gestor de Base de Dades (SGBD)

**Projecte:** AviGest S.L. — Sistema de gestió centralitzada de granges avícoles  
**Mòdul:** ASIX - Projecte (Requeriment 4.3 i 4.6)  
**Data:** Actualitzat a 26 d'octubre de 2026  
**Responsable:** Mariam / Joan  

---

## 1. Descripció de la necessitat
El sistema centralitzat d'AviGest a `srv-serveis` requereix un SGBD relacional robust per emmagatzemar:
- Dades estructurades de clients, granges, naus i cicles de criança (model multitenant).
- Sèries temporals de lectures IoT d'alta freqüència (temperatura, humitat, CO2, nivell de silos).
- Triggers procedimentals per a control automàtic d'actuadors i generació d'alarmes.
- Suport natiu de **rèplica de dades** per garantir la redundància i alta disponibilitat (Requeriment 4.6).

---

## 2. Alternatives avaluades

### Alternativa 1: PostgreSQL 16 (Escollida)
* **Descripció:** SGBD relacional i d'objectes avançat de codi obert, de referència en entorns empresarials i projectes IoT.
* **Pros:**
  - **Llenguatge procedural avançat (PL/pgSQL):** Permet escriure triggers rics i procediments d'automatització i auditoria d'accessos sense limitacions.
  - **Suport excel·lent per a telemetria:** Extensions natives com TimescaleDB per a sèries temporals de sensors i tipus de dades JSON/JSONB.
  - **Seguretat a nivell de fila (Row-Level Security - RLS):** Aïllament natiu multitenant per motor de dades, ideal per separar granges i clients.
  - **Mecanisme de rèplica nadiu (Streaming Replication):** Permet configurar rèpliques calentes (*Hot Standby*) amb sincronització basada en fitxers WAL (*Write-Ahead Logging*).
* **Contres:**
  - Administració de configuració inicial més estricta (`pg_hba.conf`, `postgresql.conf`).

### Alternativa 2: MariaDB (10.11 LTS) / MySQL
* **Descripció:** SGBD relacional clàssic derivat de MySQL.
* **Pros:**
  - Desplegament ràpid i eina web senzilla (phpMyAdmin).
* **Contres:**
  - Menor potència en procediments emmagatzemats i triggers complexos en comparació amb PL/pgSQL.
  - No disposa de Row-Level Security natiu directe; l'aïllament requereix vistes manuals.

### Alternativa 3: SQLite3 (Descartada)
* **Descripció:** Base de dades embeguda en fitxer local.
* **Motiu de descart:** Inadequada per a la seu central amb múltiples connexions concurrents d'ingesta IoT i usuaris de consulta.

---

## 3. Decisió presa
**S'escull PostgreSQL 16 amb suport de rèplica.**

### Justificació:
1. **Lògica de negoci potent:** PL/pgSQL permet implementar la lògica d'actuació automàtica i validació de llindars de forma elegant i segura.
2. **Capacitat d'ingesta IoT:** Estructura òptima per rebre les lectures del broker MQTT a `srv-serveis`.
3. **Redundància i Rèplica (Fitxa de Decisió / Avaluació):**
   > **Nota d'arquitectura sobre la Rèplica de Base de Dades:**  
   > En el desplegament del laboratori acadèmic, la rèplica de PostgreSQL està allotjada com a contenidor secundari dins de la mateixa màquina virtual `srv-serveis`.  
   > **Limitació de disseny documentada i defensada davant del tribunal:** Som plenament conscients que tenir la rèplica en un contenidor dins de la mateixa VM **no és una redundància real de maquinari si cau la VM sencera o si falla el disc virtual de `srv-serveis`**. En aquesta topologia de laboratori, la rèplica serveix per protegir el servei davant de fallades del procés PostgreSQL, errors de memòria cau o corrupcions de dades de l'aplicació, i per demostrar la configuració de *Streaming Replication*.  
   > Si cau la VM `srv-serveis` per complet, la continuïtat del servei està garantida per la màquina virtual dedicada independent **`srv-backup`** (`10.0.20.20`), la qual fa còpies transaccionals diàries i les emmagatzema en un segon disc virtual extern (RTO < 30 minuts). En una arquitectura de producció empresarial amb recursos de maquinari suficients, la rèplica de la BD s'allotjaria en una VM pròpia o en un servidor físic separat en un altre rack/CPD.

---

## 4. Mètode de verificació
- **Desplegament en Docker:** Contenidor `postgres:16-alpine` a la màquina `srv-serveis` (LAN: `10.0.20.0/24`).
- **Validació de triggers:** Execució de lectures de temperatura disparant l'activació de l'actuador i la inserció d'alarma.
- **Rèplica:** Verificació de l'estat de connexió del procés `walreceiver` i comprovació de lectura a la instància standby.
