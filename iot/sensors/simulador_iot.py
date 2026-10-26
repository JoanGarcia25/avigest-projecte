#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
==============================================================================
AviGest S.L. — Simulador de Sensors IoT per a granja1-sim
Fitxer: iot/sensors/simulador_iot.py
Mòdul: ASIX - Projecte (Requeriments 4.8, R4, R5, R7)
Responsable: Mariam (Base de Dades, IoT i Automatització)

Descripció:
Aquest script s'executa a la màquina 'granja1-sim' (10.1.1.20) i simula:
  - Microcontroladors ESP32 llegint sensors ambientals per RS485 (Modbus RTU).
  - Cèl·lules de pesatge de silos transmetent per LoRaWAN (ChirpStack).

Opcions d'enviament:
  1. MQTT (recomanat): Envia trames JSON al broker local de granja1-srv (10.1.1.10)
     o directament al broker central de srv-serveis (10.0.20.10:1883).
  2. SQL Directe: Prova d'inserció directa a PostgreSQL 16 (srv-serveis: 10.0.20.10)
     per validar el funcionament dels triggers PL/pgSQL i l'activació de ventiladors.

Ús:
  python3 simulador_iot.py --mode normal
  python3 simulador_iot.py --mode alarma
  python3 simulador_iot.py --mode mqtt --broker 10.1.1.10
==============================================================================
"""

import sys
import os
import time
import json
import shutil
import random
import argparse
import subprocess
from datetime import datetime

# Configuració per defecte cap a srv-serveis (PostgreSQL 16)
CONFIG_CONN = {
    "host": os.getenv("PGHOST", "10.0.20.10"),
    "port": os.getenv("PGPORT", "5432"),
    "user": os.getenv("PGUSER", "avigest_app"),
    "password": os.getenv("PGPASSWORD", "avigest_secret_2026"),
    "database": os.getenv("PGDATABASE", "avigest_db")
}

# Sensors configurats al sistema
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
        "tipus": "pes_silo",
        "tecnologia": "LoRaWAN",
        "unitat": "kg",
        "min": 1000.0,
        "max": 15000.0,
        "normal_range": (7000.0, 9500.0)
    },
    {
        "id_sensor": 4,
        "granja": "Granja Ponent Bellpuig",
        "nau": "NAU-01",
        "tipus": "co2",
        "tecnologia": "RS485",
        "unitat": "ppm",
        "min": 400.0,
        "max": 2500.0,
        "normal_range": (800.0, 1400.0)
    }
]

def executar_sql_postgres(sql):
    """Executa una ordre SQL contra PostgreSQL (directament o via docker)."""
    host = CONFIG_CONN["host"]
    user = CONFIG_CONN["user"]
    pwd = CONFIG_CONN["password"]
    db = CONFIG_CONN["database"]
    port = CONFIG_CONN["port"]

    # 1. Client psql si està disponible
    psql_bin = shutil.which("psql")
    if psql_bin:
        env = os.environ.copy()
        env["PGPASSWORD"] = pwd
        cmd = [psql_bin, "-h", host, "-p", str(port), "-U", user, "-d", db, "-c", sql]
        try:
            res = subprocess.run(cmd, env=env, stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True, timeout=5)
            if res.returncode == 0:
                return True, res.stdout.strip()
            return False, res.stderr.strip()
        except Exception as e:
            return False, str(e)

    # 2. Docker local si s'executa a srv-serveis
    docker_bin = shutil.which("docker")
    if docker_bin:
        cmd = ["docker", "exec", "-i", "avigest_postgres", "psql", "-U", user, "-d", db, "-c", sql]
        try:
            res = subprocess.run(cmd, stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True, timeout=5)
            if res.returncode == 0:
                return True, res.stdout.strip()
            return False, res.stderr.strip()
        except Exception as e:
            return False, str(e)

    return False, f"SQL preparat: {sql}"

def enviar_telemetria_mqtt(broker_ip, sensor_id, tipus, valor, unitat):
    """Envia una trama JSON via MQTT mitjançant mosquitto_pub."""
    payload = json.dumps({
        "id_sensor": sensor_id,
        "tipus": tipus,
        "valor": round(valor, 2),
        "unitat": unitat,
        "timestamp": datetime.now().isoformat()
    })
    topic = f"avigest/granja1/telemetria/{tipus}"

    pub_bin = shutil.which("mosquitto_pub")
    if pub_bin:
        cmd = [pub_bin, "-h", broker_ip, "-p", "1883", "-t", topic, "-m", payload]
        try:
            subprocess.run(cmd, timeout=3)
            return True, payload
        except Exception as e:
            return False, str(e)
    return False, payload

def comprovar_estat_actuadors():
    sql = "SELECT a.id_actuador, n.codi_nau, a.tipus_actuador, a.estat_actual FROM actuadors a JOIN naus n ON a.id_nau = n.id_nau WHERE a.tipus_actuador = 'ventilador';"
    ok, out = executar_sql_postgres(sql)
    if ok:
        print("\n--- Estat Actual dels Actuadors (PostgreSQL) ---")
        print(out)
        print("------------------------------------------------")

def comprovar_alarmes_recents():
    sql = "SELECT id_alarma, id_nau, nivell_gravetat, missatge, data_generacio FROM alarmes_incidencies ORDER BY data_generacio DESC LIMIT 3;"
    ok, out = executar_sql_postgres(sql)
    if ok and out:
        print("\n--- Darreres Alarmes Generades per Triggers ---")
        print(out)
        print("-------------------------------------------------")

def main():
    parser = argparse.ArgumentParser(description="Simulador IoT AviGest (ESP32 / Modbus / LoRaWAN)")
    parser.add_argument("--mode", choices=["normal", "alarma", "mqtt", "interactiu"], default="normal",
                        help="Mode de simulació: normal, alarma (>31ºC), mqtt, interactiu")
    parser.add_argument("--host", default=CONFIG_CONN["host"], help="Adreça de srv-serveis")
    parser.add_argument("--broker", default="10.1.1.10", help="Broker MQTT (granja1-srv o srv-serveis)")
    args = parser.parse_args()

    CONFIG_CONN["host"] = args.host

    print("======================================================================")
    print("  AviGest S.L. — Simulador IoT (granja1-sim -> granja1-srv / seu)     ")
    print(f"  Mode seleccionat: {args.mode.upper()}")
    print("======================================================================")

    if args.mode == "normal":
        print("[INFO] Generant lectures ambientals normals (22ºC - 25ºC)...")
        for s in SENSORS_CONFIG:
            v_min, v_max = s["normal_range"]
            val = random.uniform(v_min, v_max)
            sql = f"INSERT INTO lectures_sensors (id_sensor, valor) VALUES ({s['id_sensor']}, {val:.2f});"
            ok, out = executar_sql_postgres(sql)
            print(f"  -> [{s['tecnologia']}] {s['granja']} ({s['nau']}) {s['tipus']}: {val:.2f} {s['unitat']} | PG: {'OK' if ok else 'Simulat'}")
            time.sleep(0.5)

    elif args.mode == "alarma":
        print("[CRÍTIC] Simulant cop de calor extrem a NAU-01 (> 31 ºC)...")
        temp_perillosa = 33.80
        sql = f"INSERT INTO lectures_sensors (id_sensor, valor) VALUES (1, {temp_perillosa:.2f});"
        ok, out = executar_sql_postgres(sql)
        print(f"  -> INJECTADA LECTURA: 33.80 ºC al Sensor #1 (Llindar màxim: 31.00 ºC)")
        time.sleep(1)
        comprovar_estat_actuadors()
        comprovar_alarmes_recents()

    elif args.mode == "mqtt":
        print(f"[INFO] Publicant telemetria al Broker MQTT {args.broker}:1883...")
        for s in SENSORS_CONFIG:
            v_min, v_max = s["normal_range"]
            val = random.uniform(v_min, v_max)
            ok, payload = enviar_telemetria_mqtt(args.broker, s["id_sensor"], s["tipus"], val, s["unitat"])
            print(f"  -> MQTT: {payload} | Enviat: {'OK' if ok else 'Pendent Broker'}")
            time.sleep(0.5)

if __name__ == "__main__":
    main()
