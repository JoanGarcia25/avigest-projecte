# Fitxa de Decisió Tècnica — FD04: Estratègia de Còpies de Seguretat i Servidor Dedicat (PRD)

**Projecte:** AviGest S.L. — Sistema de gestió centralitzada de granges avícoles  
**Mòdul:** ASIX - Projecte (Requeriment 4.5)  
**Data:** Actualitzat a 26 d'octubre de 2026  
**Responsable:** Joan (Àrea d'Infraestructura, Xarxa i Seguretat)  

---

## 1. Descripció de la necessitat
Cal garantir la continuïtat de negoci i la protecció de les dades mitjançant:
- Còpies periòdiques automatitzades de la base de dades PostgreSQL i del directori OpenLDAP de `srv-serveis`.
- **Aïllament del servei de backup:** Executar les còpies des d'un servidor independent (`srv-backup`) per evitar que una incidència a `srv-serveis` afecti el repositori de recuperació.
- **Simulació d'emmagatzematge extern:** Emmagatzematge en un segon disc virtual independent muntat exclusivament per a les còpies de seguretat.
- Definició formal d'RTO/RPO i script de restauració validat.

---

## 2. Alternatives avaluades

### Alternativa 1: Servidor dedicat `srv-backup` amb scripts orquestrats per Cron (Escollida)
* **Descripció:** Màquina virtual dedicada a la LAN (`srv-backup`) que executa tasques programades mitjançant `cron` per abocar la BD PostgreSQL i l'arbre LDAP de `srv-serveis` a través de xarxa xifrada, i copiar-los a un segon disc virtual simulant la ubicació externa.
* **Pros:**
  - **Aïllament de fallades:** Si la màquina `srv-serveis` pateix una caiguda o un atac, les còpies estan físicament protegides a `srv-backup`.
  - **Suport independent (Model 3-2-1):** El segon disc virtual dedicat permet simular la ubicació externa/NAS.
  - **Simplicitat i màxim control:** Eines estàndard (`pg_dump`, `slapcat`/`ldapsearch`, `tar`, `gzip`, `cron`). Fàcilment auditable.
* **Contres:**
  - Requereix recursos per a una màquina virtual dedicada addicional.

### Alternativa 2: Execució de backups en local dins del propi `srv-serveis`
* **Descripció:** El mateix servidor de serveis executa el cron i guarda les còpies en el seu propi sistema de fitxers.
* **Pros:**
  - Estalvi d'una màquina virtual.
* **Contres:**
  - **Punt únic de fallada (*Single Point of Failure*):** Si cau el disc o la màquina `srv-serveis`, es perden simultàniament les dades de producció i les còpies de seguretat.

---

## 3. Decisió presa
**S'escull el servidor dedicat `srv-backup` amb segon disc virtual per a emmagatzematge simulat extern.**

### Justificació:
1. **Model 3-2-1 rigorós:**
   - 3 còpies (producció a `srv-serveis`, còpia local a `srv-backup`, i arxiu al segon disc virtual).
   - 2 suports diferents (disc de producció i disc secundari de còpies).
   - 1 ubicació aïllada (màquina independent `srv-backup`).
2. **Automatització amb Cron:** Execució nocturna desatesa a les 02:00 AM sense impacte en l'operativa de les granges.

---

## 4. Mètode de verificació
- **Execució del buidatge des de `srv-backup`:** Comprovació que `pg_dump` s'executa correctament sobre `srv-serveis:5432`.
- **Escriptura al segon disc:** Verificació de la creació del paquet `.tar.gz` al punt de muntatge del segon disc `/mnt/disc-extern-backup/`.
