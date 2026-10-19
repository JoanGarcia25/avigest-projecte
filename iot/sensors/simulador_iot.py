#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
==============================================================================
AviGest S.L. — Simulador de Sensors IoT (ESP32 / RS485 / LoRaWAN)
Fitxer: iot/sensors/simulador_iot.py
Mòdul: ASIX - Projecte (Requeriments 4.8, R4, R5, R7)
Responsable: Mariam (Base de Dades, IoT i Automatització)

Descripció:
Aquest script simula la telemetria enviada pels microcontroladors ESP32
de les granges cap a la seu central. Permet provar en directe el funcionament
dels triggers de MariaDB (activació automàtica de ventiladors i alarmes).
Suporta connexió tant local com a través de xarxa cap a la MV1 (Seu Central).

Ús:
  python3 simulador_iot.py --mode normal --host 192.168.100.10
  python3 simulador_iot.py --mode alarma --host 192.168.100.10
  python3 simulador_iot.py --mode interactiu
==============================================================================
"""

import sys
import time
import shutil
import random
import argparse
import subprocess
from datetime import datetime

# Configuració per defecte de connexió a la BD
# Nota: Per a ingesta real de camp (mode normal), l'usuari recomanat és
# 'avigest_iot' amb permisos mínims (només INSERT a lectures_sensors).
# Es fa servir 'avigest_app' per defecte perquè els modes 'alarma' i
# 'interactiu' necessiten consultar actuadors i alarmes per verificar.
CONFIG_CONN = {
    "host": "127.0.0.1",
    "port": 3306,
    "user": "avigest_app",
    "password": "avigest_secret_2026",
    "database": "avigest_db"
}

# Definició dels sensors reals del sistema (conforme a 03_dades_prova.sql)
SENSORS_CONFIG = [
    {
        "id_sensor": 1,
        "granja": "Granja Ponent Bellpuig",
        "nau": "NAU-01",
        "tipus": "temperatura",
        "tecnologia": "RS485",
        "unitat": "ºC",
        "min": 20.0,
        "max": 31.0,
        "normal_range": (22.0, 26.5)
    },
    {
        "id_sensor": 2,
        "granja": "Granja Ponent Bellpuig",
        "nau": "NAU-01",
        "tipus": "humitat",
        "tecnologia": "RS485",
        "unitat": "%",
        "min": 45.0,
        "max": 70.0,
        "normal_range": (52.0, 64.0)
    },
    {
        "id_sensor": 3,
        "granja": "Granja Ponent Bellpuig",
        "nau": "NAU-01",
        "tipus": "silo_gra",
        "tecnologia": "LoRaWAN",
        "unitat": "kg",
        "min": 1500.0,
        "max": 15000.0,
        "normal_range": (7000.0, 9500.0)
    },
    {
        "id_sensor": 5,
        "granja": "Granja Ponent Bellpuig",
        "nau": "NAU-02",
        "tipus": "temperatura",
        "tecnologia": "RS485",
        "unitat": "ºC",
        "min": 26.0,
        "max": 33.0,
        "normal_range": (28.0, 31.0)
    },
    {
        "id_sensor": 8,
        "granja": "Granja Ponent Mollerussa",
        "nau": "NAU-01",
        "tipus": "temperatura",
        "tecnologia": "RS485",
        "unitat": "ºC",
        "min": 19.0,
        "max": 30.0,
        "normal_range": (21.0, 24.5)
    },
    {
        "id_sensor": 11,
        "granja": "Granja Ponent Bellpuig",
        "nau": "NAU-01",
        "tipus": "co2",
        "tecnologia": "RS485",
        "unitat": "ppm",
        "min": 400.0,
        "max": 3000.0,
        "normal_range": (600.0, 1800.0)
    },
    {
        "id_sensor": 12,
        "granja": "Granja Ponent Mollerussa",
        "nau": "NAU-01",
        "tipus": "co2",
        "tecnologia": "RS485",
        "unitat": "ppm",
        "min": 400.0,
        "max": 3000.0,
        "normal_range": (550.0, 1600.0)
    },
    {
        "id_sensor": 13,
        "granja": "Granja Segrià Alcarràs",
        "nau": "NAU-01",
        "tipus": "temperatura",
        "tecnologia": "RS485",
        "unitat": "ºC",
        "min": 20.0,
        "max": 31.0,
        "normal_range": (23.0, 27.0)
    },
    {
        "id_sensor": 14,
        "granja": "Granja Segrià Alcarràs",
        "nau": "NAU-01",
        "tipus": "humitat",
        "tecnologia": "RS485",
        "unitat": "%",
        "min": 45.0,
        "max": 70.0,
        "normal_range": (50.0, 65.0)
    },
    {
        "id_sensor": 15,
        "granja": "Granja Segrià Alcarràs",
        "nau": "NAU-01",
        "tipus": "silo_gra",
        "tecnologia": "LoRaWAN",
        "unitat": "kg",
        "min": 1500.0,
        "max": 15000.0,
        "normal_range": (6000.0, 11000.0)
    },
    {
        "id_sensor": 16,
        "granja": "Granja Segrià Alcarràs",
        "nau": "NAU-01",
        "tipus": "co2",
        "tecnologia": "RS485",
        "unitat": "ppm",
        "min": 400.0,
        "max": 3000.0,
        "normal_range": (650.0, 1900.0)
    }
]

def executar_sql(sql):
    """
    Executa una consulta SQL provant diverses vies:
    1. Client natiu mariadb/mysql a través de la xarxa cap a CONFIG_CONN['host']
    2. Contenidor Docker local avigest_mariadb
    """
    host = CONFIG_CONN["host"]
    user = CONFIG_CONN["user"]
    pwd = CONFIG_CONN["password"]
    db = CONFIG_CONN["database"]

    # Via 1: Si mariadb o mysql està instal·lat al sistema
    client_bin = shutil.which("mariadb") or shutil.which("mysql")
    if client_bin:
        cmd = [
            client_bin,
            f"-h{host}",
            f"-u{user}",
            f"-p{pwd}",
            db,
            "-e", sql
        ]
        try:
            res = subprocess.run(cmd, stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True, timeout=5)
            if res.returncode == 0:
                return True, res.stdout.strip()
            else:
                return False, res.stderr.strip()
        except Exception as e:
            pass

    # Via 2: Si estem a la màquina central i tenim Docker
    docker_bin = shutil.which("docker")
    if docker_bin and host in ["127.0.0.1", "localhost"]:
        cmd = [
            "docker", "exec", "-i", "avigest_mariadb",
            "mariadb", f"-u{user}", f"-p{pwd}", db,
            "-e", sql
        ]
        try:
            res = subprocess.run(cmd, stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True, timeout=5)
            if res.returncode == 0:
                return True, res.stdout.strip()
            else:
                return False, res.stderr.strip()
        except Exception:
            pass

    return False, f"SQL preparat: {sql}"

def executar_sql_insercio(id_sensor, valor, unitat):
    # NOTA DE SEGURETAT: En un entorn de producció real, s'hauria d'utilitzar
    # un connector Python (mysql-connector o PyMySQL) amb prepared statements
    # per evitar riscos d'injecció SQL. En aquest projecte didàctic els valors
    # provenen exclusivament del codi intern del simulador, no de l'usuari extern.
    ts = datetime.now().strftime("%Y-%m-%d %H:%M:%S")
    sql = f"INSERT INTO lectures_sensors (id_sensor, data_hora, valor, unitat) VALUES ({id_sensor}, '{ts}', {valor:.2f}, '{unitat}');"
    ok, out = executar_sql(sql)
    if ok:
        return True, f"Enviat a MariaDB ({CONFIG_CONN['host']})"
    else:
        return False, out

def comprovar_estat_actuadors():
    sql = "SELECT a.id_actuador, n.codi_nau, a.tipus_actuador, a.estat_actual FROM actuadors a JOIN naus n ON a.id_nau = n.id_nau WHERE a.tipus_actuador = 'ventilador';"
    ok, out = executar_sql(sql)
    if ok and out:
        return out
    return None

def comprovar_ultimes_alarmes():
    sql = "SELECT id_alarma, titol, data_hora, resolta FROM alarmes_incidencies ORDER BY id_alarma DESC LIMIT 2;"
    ok, out = executar_sql(sql)
    if ok and out:
        return out
    return None

def test_connexio():
    """Verifica la connexió a MariaDB abans de començar la simulació."""
    print(f"  Verificant connexió a MariaDB ({CONFIG_CONN['host']}:{CONFIG_CONN['port']})...")
    ok, out = executar_sql("SELECT 1;")
    if ok:
        print(f"  ✔ Connexió establerta correctament amb usuari '{CONFIG_CONN['user']}'.\n")
        return True
    else:
        print(f"  ✘ ERROR: No s'ha pogut connectar a MariaDB.")
        print(f"    Detall: {out}")
        print(f"    Comproveu que el contenidor 'avigest_mariadb' estigui actiu")
        print(f"    o que MariaDB accepti connexions a {CONFIG_CONN['host']}:{CONFIG_CONN['port']}.\n")
        return False

def mode_normal():
    print("\n=======================================================")
    print(f"  AviGest S.L. — Telemetria en Temps Real -> {CONFIG_CONN['host']}")
    print("  (Premeu Ctrl+C per aturar la simulació)             ")
    print("=======================================================\n")
    if not test_connexio():
        sys.exit(1)
    try:
        cicle = 1
        while True:
            print(f"--- Cicle #{cicle} [{datetime.now().strftime('%H:%M:%S')}] ---")
            for s in SENSORS_CONFIG:
                val = random.uniform(s["normal_range"][0], s["normal_range"][1])
                success, msg = executar_sql_insercio(s["id_sensor"], val, s["unitat"])
                tec_label = f"[{s['tecnologia']}]"
                print(f"  {tec_label:<10} Sensor #{s['id_sensor']} ({s['tipus']} - {s['nau']}): {val:.2f} {s['unitat']} -> {msg}")
            
            cicle += 1
            print("Esperant 5 segons per a la propera tanda...\n")
            time.sleep(5)
    except KeyboardInterrupt:
        print("\nSimulació aturada.")

def mode_alarma():
    print("\n=======================================================")
    print(f"  AviGest S.L. — Simulació d'Incidència -> {CONFIG_CONN['host']}")
    print("=======================================================\n")
    if not test_connexio():
        sys.exit(1)

    print("1. Injectant TEMPERATURA CRÍTICA (34.8 ºC) al Sensor #1 (Bellpuig NAU-01)...")
    print("   -> Llindar màxim de la nau: 31.0 ºC")
    success, msg = executar_sql_insercio(1, 34.80, "ºC")
    print(f"   Estat: {msg}")

    print("\n2. Injectant NIVELL CRÍTIC DE SILO (980 kg) al Sensor #3 (LoRaWAN Silo Bellpuig)...")
    print("   -> Llindar mínim de reserva: 1500.0 kg")
    success, msg = executar_sql_insercio(3, 980.00, "kg")
    print(f"   Estat: {msg}")

    print("\n3. Injectant CO2 PERILLÓS (3500 ppm) al Sensor #11 (CO2 Bellpuig NAU-01)...")
    print("   -> Llindar màxim: 3000.0 ppm")
    success, msg = executar_sql_insercio(11, 3500.00, "ppm")
    print(f"   Estat: {msg}")

    print("\n4. Comprovant efecte del TRIGGER a MariaDB (Taula Actuadors):")
    estat = comprovar_estat_actuadors()
    if estat:
        print(estat)
        print("\n[ÈXIT] El trigger ha engegat el ventilador a 'ON' automàticament!")
    else:
        print("  -> Comproveu la taula 'actuadors' a phpMyAdmin per veure l'estat 'ON'.")

    print("\n5. Comprovant efecte del TRIGGER a MariaDB (Taula Alarmes):")
    alarmes = comprovar_ultimes_alarmes()
    if alarmes:
        print(alarmes)

def mode_interactiu():
    print("\n=======================================================")
    print(f"  AviGest S.L. — Simulador Interactiu -> {CONFIG_CONN['host']}")
    print("=======================================================\n")
    if not test_connexio():
        sys.exit(1)

    for s in SENSORS_CONFIG:
        print(f"  [{s['id_sensor']}] {s['granja']} | {s['nau']} | {s['tipus']} ({s['unitat']}) [Llindars: {s['min']}-{s['max']}]")
    
    try:
        id_s = int(input("\nIndiqueu l'ID del sensor (ex: 1): "))
        sensor_trobat = next((s for s in SENSORS_CONFIG if s["id_sensor"] == id_s), None)
        if not sensor_trobat:
            print("[ERROR] Sensor no vàlid!")
            return

        val = float(input(f"Indiqueu el valor mesurat en {sensor_trobat['unitat']}: "))
        ok, msg = executar_sql_insercio(id_s, val, sensor_trobat["unitat"])
        print(f"\n[Resultat]: {msg}")
    except ValueError:
        print("[ERROR] Número no vàlid.")

def main():
    parser = argparse.ArgumentParser(description="Simulador IoT per a AviGest S.L.")
    parser.add_argument("--mode", choices=["normal", "alarma", "interactiu"], default="normal",
                        help="Mode d'execució: normal (telemetria contínua), alarma (injecció d'incidències), interactiu (manual)")
    parser.add_argument("--host", default="127.0.0.1", help="Adreça IP de la MV1 (Seu Central)")
    parser.add_argument("--port", type=int, default=3306, help="Port de MariaDB")
    parser.add_argument("--user", default="avigest_app",
                        help="Usuari de MariaDB (per a ingesta real de camp usar 'avigest_iot')")
    parser.add_argument("--password", default="avigest_secret_2026", help="Contrasenya de MariaDB")
    parser.add_argument("--database", default="avigest_db", help="Base de dades")
    args = parser.parse_args()

    CONFIG_CONN["host"] = args.host
    CONFIG_CONN["port"] = args.port
    CONFIG_CONN["user"] = args.user
    CONFIG_CONN["password"] = args.password
    CONFIG_CONN["database"] = args.database

    if args.mode == "normal":
        mode_normal()
    elif args.mode == "alarma":
        mode_alarma()
    elif args.mode == "interactiu":
        mode_interactiu()

if __name__ == "__main__":
    main()
