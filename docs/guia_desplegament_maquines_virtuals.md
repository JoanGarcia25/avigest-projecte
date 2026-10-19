# Guia de Desplegament Pas a Pas en Màquines Virtuals — AviGest S.L.

**Projecte:** Implantació d'un sistema informàtic de gestió de granges de pollastres  
**Destinada a:** Joan i Mariam (Execució del laboratori presencial i defensa oral)  
**Entorn recomanat:** VMware Workstation o VirtualBox (Linux Ubuntu Server 24.04 LTS o Debian 12)  

---

## 1. Preparació de l'Escenari a VMware / VirtualBox

Per simular la seu central i les granges remotes crearem **2 Màquines Virtuals (MVs)**:

| Màquina | Nom proposat | Sistema Operatiu | Memòria RAM | Rol en el Projecte |
| :--- | :--- | :--- | :---: | :--- |
| **MV 1** | `AviGest-Central` | Ubuntu Server 24.04 | 2 - 4 GB | **Seu Central:** MariaDB, OpenLDAP, phpMyAdmin, phpLDAPadmin, Backups i Tallafocs. |
| **MV 2** | `AviGest-Granja` | Ubuntu Server o Debian | 1 - 2 GB | **Gateway de Granja:** Simulador de sensors ESP32, telemetria RS485 i LoRaWAN. |

### Pas 0: Xarxa de VMware
1. A VMware Workstation, posa totes dues màquines en mode de xarxa **NAT** (o **Host-Only**).
2. Arrenca totes dues màquines i esbrina la IP que tenen amb la comanda:
   ```bash
   hostname -I
   ```
   *Exemple per a aquesta guia:*
   - **MV 1 (Central):** `192.168.100.10`
   - **MV 2 (Granja):** `192.168.100.20`
   - *(Substitueix aquestes IPs per les reals que et surtin a la teva pantalla).*

---

## 2. Pas a Pas a la MV 1: Seu Central d'AviGest (Comanda per comanda)

Inicia sessió a la terminal de la **MV 1** i executa exactament aquests passos en ordre:

### Pas 1: Actualització de paquets i eines necessàries
```bash
sudo apt update && sudo apt upgrade -y
sudo apt install -y curl git mariadb-client ufw netcat-traditional
```

### Pas 2: Copiar el projecte a la MV 1
Pots copiar la carpeta del projecte directament des del teu Windows amb `scp`, o clonar-la si la tens a GitHub.
*Opció A: Des del teu Windows PowerShell:*
```powershell
scp -r C:\Users\jgarcia1_insmollerus\Desktop\Projecte\avigest-projecte usuari@<IP_MV1>:~/
```
*Opció B: Des de la terminal de la MV 1 si clones des de Git:*
```bash
git clone <URL_DEL_TEU_REPOSITORI_GITHUB> ~/avigest-projecte
```

Ara moguem la carpeta a `/opt` i assignem permisos:
```bash
sudo mv ~/avigest-projecte /opt/avigest-projecte
sudo chown -R $USER:$USER /opt/avigest-projecte
cd /opt/avigest-projecte
```

### Pas 3: Instal·lar Docker i Docker Compose
Executa la comanda oficial d'instal·lació de Docker:
```bash
curl -fsSL https://get.docker.com -o get-docker.sh
sudo sh get-docker.sh
sudo usermod -aG docker $USER
newgrp docker
```
Verifica que Docker respon:
```bash
docker --version
docker compose version
```

### Pas 4: Arrencar tots els serveis centrals (MariaDB + LDAP)
Entra a la carpeta de Docker i aixeca la infraestructura:
```bash
cd /opt/avigest-projecte/docker
docker compose up -d
```
*Espera uns 15 segons mentre MariaDB i OpenLDAP s'inicialitzen i carreguen l'esquema SQL i els usuaris.*

Comprova que els 4 contenidors estan en estat `Up`:
```bash
docker compose ps
```

### Pas 5: Verificar que les dades s'han carregat correctament a MariaDB
Executa aquesta consulta des de la terminal de la MV 1:
```bash
docker exec -it avigest_mariadb mariadb -u avigest_app -pavigest_secret_2026 avigest_db -e "SHOW TABLES;"
```
*Hauries de veure les 9 taules (`clients`, `granges`, `naus`, `sensors`, `actuadors`, etc.).*

Ara comprova les granges de prova:
```bash
docker exec -it avigest_mariadb mariadb -u avigest_app -pavigest_secret_2026 avigest_db -e "SELECT id_granja, nom_granja, codi_explotacio, poblacio FROM granges;"
```
*Hauràs de veure: Granja Ponent Bellpuig, Granja Ponent Mollerussa i Granja Segrià Alcarràs.*

### Pas 6: Verificar OpenLDAP per línia de comandes
Executa una cerca LDAP:
```bash
docker exec -it avigest_openldap ldapsearch -x -b "dc=avigest,dc=cat" "(uid=admin_avigest)"
```
*Hauràs de veure l'administrador d'AviGest correctament retornat.*

### Pas 7: Comprovar els panells web des del teu Windows
Obre el navegador del teu ordinador físic (Chrome / Firefox) i entra a:
1. **phpMyAdmin:** `http://<IP_MV1>:8080`
   - Usuari: `avigest_app`
   - Contrasenya: `avigest_secret_2026`
2. **phpLDAPadmin:** `http://<IP_MV1>:8081`
   - Usuari (Login DN): `cn=admin,dc=avigest,dc=cat`
   - Contrasenya: `admin_ldap_pass_2026`

### Pas 8: Configurar i provar les Còpies de Seguretat (Requeriment 4.5)
Dona permisos als scripts de backup:
```bash
chmod +x /opt/avigest-projecte/infra/backups-prd/*.sh
sudo mkdir -p /var/backups/avigest
```
Executa un backup manual per verificar-ne el funcionament:
```bash
sudo /opt/avigest-projecte/infra/backups-prd/backup_avigest.sh
```
Comprova que ha generat el fitxer `.tar.gz` i el fitxer de comprovació `.sha256`:
```bash
ls -la /var/backups/avigest
```
Instal·la la tasca programada nocturna al crontab:
```bash
sudo crontab /opt/avigest-projecte/infra/backups-prd/crontab.txt
sudo crontab -l
```

---

## 3. Pas a Pas a la MV 2: Gateway de Granja (IoT)

Aquesta màquina representa el Gateway Fanless de la granja remota que llegeix els sensors.

Inicia sessió a la terminal de la **MV 2**:

### Pas 1: Instal·lar paquets bàsics
```bash
sudo apt update
sudo apt install -y python3 python3-pip mariadb-client netcat-traditional
```

### Pas 2: Copiar el projecte a la MV 2
*Des del teu Windows PowerShell:*
```powershell
scp -r C:\Users\jgarcia1_insmollerus\Desktop\Projecte\avigest-projecte usuari@<IP_MV2>:~/
```
A la MV 2, mou-te a la carpeta dels sensors:
```bash
cd ~/avigest-projecte/iot/sensors
```

### Pas 3: Provar connectivitat amb la Seu Central (MV 1)
Comprova que la MV 2 arriba a la MV 1 per xarxa:
```bash
ping -c 3 <IP_MV1>
```
Comprova que el port de MariaDB (3306) està obert i accessible des de la granja:
```bash
nc -zv <IP_MV1> 3306
```
*(Hauria de dir: `Connection to <IP_MV1> 3306 port [tcp/mysql] succeeded!`)*

Fes una consulta de prova directament a la base de dades central des de la MV 2:
```bash
mariadb -h <IP_MV1> -u avigest_app -pavigest_secret_2026 avigest_db -e "SELECT nom_granja FROM granges;"
```

---

## 4. Com Realitzar la Demostració en Directe davant del Professor

Segueix aquest ordre durant la teva defensa oral per mostrar totes les funcionalitats:

### Prova 1: Telemetria Normal en Temps Real
A la **MV 2** (Gateway de Granja), engega el simulador:
```bash
python3 ~/avigest-projecte/iot/sensors/simulador_iot.py --host <IP_MV1> --mode normal
```
*Veuràs com cada 5 segons s'envien les lectures de temperatura, humitat i nivell de silo cap a la seu central.*

### Prova 2: Simulació d'Alarma i Disparament del Trigger (La més important!)
1. Obre **phpMyAdmin** des del teu navegador (`http://<IP_MV1>:8080`), ves a la taula `actuadors` i comprova que el ventilador de la Nau 1 està a **`OFF`**.
2. A la **MV 2**, atura el mode normal (amb `Ctrl+C`) i executa el **mode alarma**:
   ```bash
   python3 ~/avigest-projecte/iot/sensors/simulador_iot.py --host <IP_MV1> --mode alarma
   ```
3. Observa la sortida per pantalla:
   - S'injecta una temperatura de **34.8 ºC** (supera el límit de 31 ºC).
   - El trigger `tg_control_llindars_sensor` actua automàticament.
4. Torna al navegador web a phpMyAdmin i refresca:
   - Taula `actuadors`: L'estat del ventilador ha canviat automàticament a **`ON`**.
   - Taula `registre_actuacions`: S'ha creat una fila indicant `ACTIVAR` i el motiu ("Temperatura crítica: 34.8 ºC").
   - Taula `alarmes_incidencies`: S'ha generat l'alarma de sobreescalfament per alertar el granger.

### Prova 3: La Prova Presencial del Professor (Alta d'una Granja Nova)
Quan el professor et digui: *"Afegiu-me una granja nova que es diu Granja Urgell Tàrrega amb 2 naus per al client 1"*:

Ves a la **MV 1** (Seu Central) i executa l'script:
```bash
cd /opt/avigest-projecte/scripts/automatitzacio-granges
chmod +x alta_granja.sh
./alta_granja.sh -c 1 -n "Granja Urgell Tàrrega" -e "ES252170004" -a "Camí de Verdú s/n" -p "Tàrrega" -s 2 -u "gestor_tarrega"
```
En **2 segons**:
- S'haurà creat la granja a MariaDB amb les seves 2 naus i sensors provisionats.
- S'haurà creat l'usuari `gestor_tarrega` a OpenLDAP vinculat a la granja.
- S'haurà generat l'estructura de carpetes per al nou gateway.
- Ensenya el resultat a phpMyAdmin i a phpLDAPadmin per mostrar que tot ha quedat configurat automàticament.

### Prova 4: Simulacre de Restauració davant Desastres (PRD)
A la **MV 1**, demostra la recuperació del sistema:
```bash
# 1. Comprova quin és l'últim backup generat
ls -la /var/backups/avigest/*.tar.gz

# 2. Executa la restauració automàtica
sudo /opt/avigest-projecte/infra/backups-prd/restaurar_avigest.sh /var/backups/avigest/<NOM_DEL_FITXER_BACKUP>.tar.gz
```
*En menys d'un minut el script descomprimeix el paquet, verifica el hash SHA-256 i restaura tant MariaDB com OpenLDAP.*
