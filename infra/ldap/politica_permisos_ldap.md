# Política de Permisos, Rols i Aïllament de Dades — LDAP AviGest

**Mòdul:** ASIX - Projecte (Requeriment 4.2 i Requeriments Funcionals R2, R3)  
**Base del Directori (Suffix / Base DN):** `dc=avigest,dc=cat`

---

## 1. Arbre del Directori (Directory Information Tree - DIT)

L'estructura jeràrquica d'AviGest separa clarament l'administració interna de la plataforma dels diferents clients contractants, garantint que cap empresa client pugui veure ni modificar dades d'altres empreses.

```text
dc=avigest,dc=cat
├── ou=groups
│   ├── cn=AdminsAviGest       (Rol: Administrador global de plataforma)
│   ├── cn=AdminsClient        (Rol: Administrador del compte de client - N granges)
│   ├── cn=GestorsGranja       (Rol: Responsable operatiu d'una granja concreta)
│   └── cn=UsuarisConsulta     (Rol: Només lectura - veterinaris, auditors)
└── ou=users
    ├── ou=avigest             (Personal intern d'AviGest S.L.)
    │   ├── uid=admin_avigest
    │   └── uid=tecnic_suport
    └── ou=clients             (Usuaris externs agrupats per client)
        ├── ou=client_agroponent
        │   ├── uid=jaume_admin          (Admin del Client 1: veu Bellpuig i Mollerussa)
        │   ├── uid=gestor_bellpuig      (Gestor exclusiu de la Granja Bellpuig)
        │   └── uid=veterinari_ponent    (Usuari consulta per a totes dues granges)
        └── ou=client_segria
            ├── uid=laura_admin          (Admin del Client 2: veu Alcarràs)
            └── uid=gestor_alcarras      (Gestor exclusiu de la Granja Alcarràs)
```

---

## 2. Matriu de Rols i Permisos (Requeriment R2)

| Operació / Recurs | 1. Admin AviGest | 2. Admin Client | 3. Gestor Granja | 4. Consulta |
| :--- | :---: | :---: | :---: | :---: |
| **Alta / Baixa de Clients** | SÍ | NO | NO | NO |
| **Alta / Baixa de Granges** | SÍ | Sol·licita | NO | NO |
| **Gestió d'usuaris interns AviGest** | SÍ | NO | NO | NO |
| **Gestió d'usuaris del seu client** | SÍ | SÍ (dels seus) | NO | NO |
| **Visualització dades de múltiples clients** | SÍ (Tots) | NO (Només el seu) | NO | NO |
| **Visualització de totes les granges del client** | SÍ | SÍ | NO (Només la seva) | SÍ (Assignades) |
| **Configuració de llindars de sensors** | SÍ | SÍ | SÍ | NO |
| **Accionament manual d'actuadors** | SÍ | SÍ | SÍ | NO |
| **Gestió de cicles/lots de pollastres (R6)** | SÍ | SÍ | SÍ | NO |
| **Visualització de lectures i alarmes (R4, R7)** | SÍ | SÍ | SÍ | SÍ |
| **Reconeixement i resolució d'alarmes** | SÍ | SÍ | SÍ | NO |

---

## 3. Política d'Aïllament de Dades entre Granges i Clients (Requeriment R3)

L'aïllament s'aplica en dues capes complementàries per garantir la seguretat per disseny (*defense in depth*):

### Capa 1: Aïllament d'Identitat al Directori (LDAP)
1. **Compartimentació per Unitats Organitzatives:** Cada client té la seva pròpia branca sota `ou=clients,ou=users,dc=avigest,dc=cat` (per exemple, `ou=client_agroponent`).
2. **Atributs d'assignació d'àmbit:**
   - Als usuaris de tipus *Admin Client* se'ls vincula el camp `businessCategory: CLIENT_<ID_CLIENT>` (per exemple `CLIENT_1`). L'aplicació web o API valida aquest camp i només retorna dades on `granges.id_client = 1`.
   - Als usuaris de tipus *Gestor Granja* se'ls vincula a més l'atribut `departmentNumber: GRANJA_<ID_GRANJA>` (per exemple `GRANJA_1`). D'aquesta manera, encara que el seu client tingui 5 granges, el gestor només té visibilitat de la granja `1`.

### Capa 2: Aïllament a la Base de Dades i l'API
- Quan un usuari inicia sessió, el servei d'autenticació obté els seus grups LDAP i els identificadors de client i granja.
- Totes les consultes SQL executades pel programari filtren obligatòriament amb `WHERE granges.id_client = :client_session` (i si és gestor, s'afegeix `AND granges.id_granja = :granja_session`).
- Els administradors globals (`cn=AdminsAviGest`) no tenen cap filtre aplicat i tenen visibilitat de suport tècnic global.
