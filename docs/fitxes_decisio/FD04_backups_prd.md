# Fitxa de Decisió Tècnica — FD04: Estratègia de Còpies de Seguretat i PRD

**Projecte:** AviGest S.L. — Sistema de gestió centralitzada de granges avícoles  
**Mòdul:** ASIX - Projecte (Requeriment 4.5)  
**Data:** 19 d'octubre de 2026  
**Responsable:** Joan (Àrea d'Infraestructura, Xarxa i Seguretat)  

---

## 1. Descripció de la necessitat
La seu central d'AviGest conté informació d'alta criticitat:
- Transaccions històriques de consum, creixement i pes de milers de pollastres de diferents explotacions.
- Registre d'incidències, alertes i auditoria d'activació d'actuadors.
- Base d'usuaris, claus i estructura organitzativa a OpenLDAP.

Cal garantir la continuïtat de negoci mitjançant:
- Una estratègia definida de còpies de seguretat (tipus, periodicitat, retenció i ubicació).
- Un Pla de Recuperació davant de Desastres (**PRD**) amb objectius temporals formalment definits (**RTO / RPO**).
- Automatització sense intervenció humana mitjançant tasques programades (`crontab`).
- Un procediment provat i documentat de restauració davant de caiguda total.

---

## 2. Alternatives avaluades

### Alternativa 1: Scripts d'automatització natius en Bash (`mariadb-dump` + `slapcat` + `gzip` + `rsync`) (Escollida)
* **Descripció:** Automatització mitjançant scripts de Bash que invoquen de forma coherent les eines natives de buidatge transaccional de MariaDB i d'OpenLDAP, comprimint els paquets amb suma de verificació SHA256 i sincronitzant-los fora del servidor amb `rsync`.
* **Pros:**
  - **Simplicitat i màxima compatibilitat:** No depèn de serveis o dimonis de tercers que puguin fallar.
  - **Transparència:** Els fitxers generats són fitxers SQL i LDIF estàndard, llegibles i restaurables des de qualsevol màquina amb una comanda senzilla.
  - **Consistència transaccional:** L'ús de la bandera `--single-transaction` a `mariadb-dump` garanteix la consistència de les lectures dels sensors sense bloquejar les taules durant la còpia.
  - **Molt fàcil de defensar:** El codi del script és 100% comprensible per a l'alumne i per al tribunal docent d'ASIX.
* **Contres:**
  - No aplica deduplicació avançada de blocs (tot i que la compressió `gzip` és més que suficient per al volum de dades del projecte).

### Alternativa 2: Eina de còpia especialitzada (BorgBackup / Restic)
* **Descripció:** Eines modernes de còpia de fitxers basades en repositoris amb deduplicació i xifratge del costat del client.
* **Pros:**
  - Estalvi d'espai per deduplicació i velocitat en còpies incrementals freqüents.
* **Contres:**
  - Per a bases de dades com MariaDB o directoris LDAP, igualment requereix un pas previ de generació de *dump* a disc abans de poder deduplicar.
  - Si es corromp el repositori de Borg, es perd l'accés directe a les còpies sense eines especials.

### Alternativa 3: Plataforma centralitzada empresarial (Bacula / Bareos)
* **Descripció:** Suite client-servidor de còpies de seguretat empresarials per a grans centres de dades.
* **Motiu de descart:** Complexitat excessiva d'instal·lació (requereix la seva pròpia base de dades, múltiples serveis `director`, `storage-daemon` i `file-daemon`), desproporcionada per a l'abast del projecte.

---

## 3. Decisió presa
**S'escull l'estratègia basada en scripts modulars de Bash (`backup_avigest.sh` i `restaurar_avigest.sh`) orquestrats mitjançant el `crontab` del sistema.**

### Justificació:
1. **Model 3-2-1 aplicat:** 3 còpies de la informació (producció, disc de backup local i servidor/NAS remot via `rsync`), en 2 suports diferents (SSD en RAID 10 i disc secundari/xarxa), i 1 còpia fora de la màquina principal.
2. **Robustesa:** L'script genera fitxers comprimits independents datats (`backup_avigest_YYYYMMDD_HHMMSS.tar.gz`) que contenen tant la base de dades com el directori LDAP de forma atòmica.
3. **Facilitat de restauració:** Permet validar el temps de recuperació (**RTO**) en menys de 10 minuts en una màquina nova buida.

---

## 4. Mètode de verificació
- **Execució de prova:** Llançament manual del script `backup_avigest.sh` comprovant la creació del paquet comprimit i el registre al fitxer `backup.log`.
- **Simulacre de desastre i restauració:** Eliminació controlada de la base de dades `avigest_db` i comprovació que el script `restaurar_avigest.sh` recupera el 100% de les dades, triggers i procediments sense errors.
