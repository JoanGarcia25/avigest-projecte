# Fitxa de Decisió Tècnica — FD01: Sistema Gestor de Base de Dades (SGBD)

**Projecte:** AviGest S.L. — Sistema de gestió centralitzada de granges avícoles  
**Mòdul:** ASIX - Projecte (Requeriment 4.3)  
**Data:** 19 d'octubre de 2026  
**Responsable:** Mariam / Joan  

---

## 1. Descripció de la necessitat
El sistema centralitzat d'AviGest requereix un SGBD relacional per emmagatzemar:
- Dades de múltiples clients i les seves granges (model multitenant).
- Dades estructurades de naus, lots de criança de pollastres, inventari de sensors i actuadors.
- Lectures de sensors IoT en temps real (sèries temporals de temperatura, humitat, nivell de silos).
- Regles automàtiques mitjançant triggers (activació de ventiladors/calefactors quan se superen llindars).
- Registre d'auditoria, actuacions i alarmes d'incidències.

---

## 2. Alternatives avaluades

### Alternativa 1: MariaDB (10.11 LTS) / MySQL
* **Descripció:** Sistema de gestió de bases de dades relacional de codi obert derivat de MySQL, estàndard en entorns Linux i administració de sistemes.
* **Pros:**
  - Desplegament senzillíssim i lleuger en contenidor Docker (`mariadb:10.11`).
  - Totalment compatible amb eines d'administració visual com **phpMyAdmin**, ideal per a demostracions i defensa en directe.
  - Curba d'aprenentatge molt baixa i domini previ assolit en el currículum del cicle ASIX.
  - Rendiment excel·lent per a operacions de lectura i escriptura transaccional estàndard.
  - Gran quantitat de documentació i facilitat per a còpies de seguretat amb `mariadb-dump`.
* **Contres:**
  - La sintaxi dels triggers i procediments emmagatzemats és més estricta i té menys opcions de llenguatge que PL/pgSQL.
  - No disposa de Row-Level Security (RLS) natiu directe com PostgreSQL; l'aïllament per granja/client s'implementa mitjançant vistes, procediments o consultes filtrades per `client_id` / `granja_id`.

### Alternativa 2: PostgreSQL (16)
* **Descripció:** SGBD objecte-relacional avançat amb suport natiu per a tipus complexos, JSON i extensions temporals.
* **Pros:**
  - Suport natiu de *Row-Level Security* (RLS) per a aïllament multitenant transparent.
  - Llenguatge de procediments (PL/pgSQL) molt ric per a triggers complexos.
* **Contres:**
  - Configuració d'usuaris, rols i permisos inicials més complexa (`pg_hba.conf`).
  - Eines web d'administració (pgAdmin4) més pesades en recursos i menys àgils per a la defensa en directe que phpMyAdmin.
  - Corba de depuració superior davant de fallades durant la presentació presencial.

### Alternativa 3: SQLite3 (Descartada)
* **Descripció:** Base de dades embeguda en fitxer local.
* **Motiu de descart:** No és un servei client-servidor adequat per a una seu central que rep connexions concurrents de múltiples granges, sensors IoT i usuaris simultanis.

---

## 3. Decisió presa
**S'escull MariaDB 10.11 LTS**.

### Justificació:
1. **Simplicitat operativa i fiabilitat:** Compleix el principi fonamental del projecte d'aconseguir una solució 100% funcional, fàcil d'entendre i fàcil de defensar davant del tribunal docent.
2. **Eines visuals integrades:** L'acompanyament amb un contenidor de **phpMyAdmin** permet als administradors i al tribunal visualitzar les dades en temps real, comprovar les alertes i verificar els triggers a l'instant.
3. **Optimització per a contenidors:** Estabilitat demostrada i arrencada immediata a través de Docker Compose.

---

## 4. Mètode de verificació
- **Prova realitzada:** Desplegament de la imatge oficial `mariadb:10.11` a l'orquestrador Docker local amb persistència de dades en volum.
- **Validació de triggers:** Execució d'un script SQL de prova (`02_triggers_procedures.sql`) verificant que la inserció d'una lectura de temperatura per sobre del llindar dispara automàticament la inserció a `registre_actuacions` i `alarmes_incidencies`.
- **Eines validades:** Connexió reeixida de `phpMyAdmin` sobre la xarxa interna de Docker.
