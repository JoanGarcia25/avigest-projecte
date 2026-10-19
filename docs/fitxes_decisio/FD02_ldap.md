# Fitxa de Decisió Tècnica — FD02: Servidor d'Usuaris Centralitzat (LDAP)

**Projecte:** AviGest S.L. — Sistema de gestió centralitzada de granges avícoles  
**Mòdul:** ASIX - Projecte (Requeriment 4.2 i Requeriments Funcionals R2, R3)  
**Data:** 19 d'octubre de 2026  
**Responsable:** Joan (Àrea d'Infraestructura i Seguretat)  

---

## 1. Descripció de la necessitat
El sistema AviGest requereix un servei d'identitat i autenticació centralitzat capaç de:
- Autenticar els usuaris tant de la seu central com de les granges remotes.
- Donar suport a **quatre rols diferenciats** segons l'enunciat:
  1. *Administrador de plataforma (AviGest)*: Accés global a tota la infraestructura i dades.
  2. *Administrador de client*: Visualitza i gestiona totes les granges contractades pel seu compte empresarial.
  3. *Gestor de granja*: Accés exclusiu a una granja física concreta.
  4. *Usuari de consulta*: Accés de només lectura (veterinaris, inspectors o auditors).
- Garantir l'aïllament de seguretat entre clients diferents.
- Executar-se de manera aïllada i reproducible mitjançant contenidors Docker.

---

## 2. Alternatives avaluades

### Alternativa 1: OpenLDAP (`osixia/openldap`) + phpLDAPadmin (Escollida)
* **Descripció:** Servidor de directori de codi obert lleuger i estàndard de la indústria, acompanyat d'una consola web d'administració.
* **Pros:**
  - Extremadament lleuger: consumeix menys de 80 MB de memòria RAM.
  - Gran maduresa i compliment estricte dels estàndards de directori X.500 / LDAPv3.
  - Imatge Docker (`osixia/openldap`) molt estesa que admet la inicialització automatitzada mitjançant fitxers `.ldif` muntats en un volum.
  - phpLDAPadmin ofereix una interfície gràfica web neta i intuïtiva per visualitzar l'arbre davant del professor durant la defensa del projecte.
  - És la tecnologia de referència estudiada en el currículum oficial d'ASIX (M06/M08).
* **Contres:**
  - La sintaxi dels fitxers LDIF requereix precisió en els espais i l'estructura del Distinguished Name (DN).

### Alternativa 2: Samba 4 Active Directory Domain Controller (AD DC)
* **Descripció:** Emulació d'un controlador de domini de Microsoft Active Directory basat en Samba sobre Linux.
* **Pros:**
  - Integració nativa amb eines RSAT de Windows i polítiques de grup (GPO).
* **Contres:**
  - Configuració molt més feixuga i susceptible a fallades en contenidors Docker (requereix Kerberos natiu, resolució DNS pròpia obligatòria i modificació de permisos de xarxa privilegiats).
  - Sobrecàrrega innecessària de complexitat per al nostre cas d'ús (aplicació de granges avícoles).

### Alternativa 3: FreeIPA (RedHat Identity Management)
* **Descripció:** Suite d'identitat completa que combina 389 Directory Server, Kerberos, DNS i interfície web moderna.
* **Pros:**
  - Interfície web d'administració molt potent i moderna.
* **Contres:**
  - Requisits de maquinari molt elevats (> 2 GB de RAM dedicats només a la identitat).
  - Problemes d'execució habituals en entorns Docker Desktop sobre Windows a causa de la dependència directa de `systemd`.

---

## 3. Decisió presa
**S'escull OpenLDAP (`osixia/openldap`) acompanyat de phpLDAPadmin.**

### Justificació:
1. **Fiabilitat i simplicitat:** S'alinea directament amb el requisit de tenir una arquitectura robusta, simple i fàcil d'explicar en la defensa oral.
2. **Modularitat en Docker:** Permet afegir els usuaris inicials i l'estructura organitzativa mitjançant scripts LDIF sense intervenció manual.
3. **Traçabilitat:** El model d'unitats organitzatives (`ou=clients`, `ou=groups`, `ou=avigest`) permet reflectir de forma visual l'aïllament entre empreses clients.

---

## 4. Mètode de verificació
- **Prova en contenidor:** Desplegament del servei OpenLDAP amb el domini `dc=avigest,dc=cat`.
- **Importació LDIF:** Càrrega satisfactòria dels fitxers de definició de branques i usuaris de prova dels 4 rols.
- **Validació de consultes:** Comprovació mitjançant la comanda `ldapsearch` i navegació interactiva des de phpLDAPadmin al port `8081`.
