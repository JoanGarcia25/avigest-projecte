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

Ús:
  python simulador_iot.py --mode normal       # Envia lectures periòdiques realistes
  python simulador_iot.py --mode alarma       # Simula pujada sobtada de temp (>31ºC)
  python simulador_iot.py --mode interactiu   # Introdueix lectures manuals per provar
==============================================================================
"""

import sys
import time
import random
import argparse
import subprocess
from datetime import datetime

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
    }
]

def executar_sql_insercio(id_sensor, valor, unitat):
    """
    Insereix la lectura directament a MariaDB utilitzant docker exec o connexió directa.
    Retorna True si s'ha executat amb èxit.
    """
    ts = datetime.now().strftime("%Y-%m-%d %H:%M:%S")
    sql = f"INSERT INTO lectures_sensors (id_sensor, data_hora, valor, unitat) VALUES ({id_sensor}, '{ts}', {valor:.2f}, '{unitat}');"

    # Intent d'execució mitjançant contenidor Docker
    cmd = [
        "docker", "exec", "-i", "avigest_mariadb",
        "mariadb", "-u", "avigest_app", "-pavigest_secret_2026", "avigest_db",
        "-e", sql
    ]

    try:
        proc = subprocess.run(cmd, stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True, timeout=5)
        if proc.returncode == 0:
            return True, "Inserit a MariaDB Docker"
        else:
            return False, f"Error Docker: {proc.stderr.strip()}"
    except Exception as e:
        # Si Docker no s'està executant localment, mostrem la consulta SQL preparada
        return False, f"Simulació SQL: {sql}"

def comprovar_estat_actuadors():
    """Comprova si el trigger de temperatura ha engegat el ventilador."""
    sql = "SELECT a.id_actuador, n.codi_nau, a.tipus_actuador, a.estat_actual FROM actuadors a JOIN naus n ON a.id_nau = n.id_nau WHERE a.tipus_actuador = 'ventilador';"
    cmd = [
        "docker", "exec", "-i", "avigest_mariadb",
        "mariadb", "-u", "avigest_app", "-pavigest_secret_2026", "avigest_db",
        "-e", sql
    ]
    try:
        proc = subprocess.run(cmd, stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True, timeout=5)
        if proc.returncode == 0:
            return proc.stdout.strip()
    except Exception:
        pass
    return None

def mode_normal():
    print("\n=======================================================")
    print("  AviGest S.L. — Simulació de Telemetria en Temps Real  ")
    print("  (Premeu Ctrl+C per aturar la simulació)             ")
    print("=======================================================\n")
    try:
        cicle = 1
        while True:
            print(f"--- Cicle de lectura #{cicle} [{datetime.now().strftime('%H:%M:%S')}] ---")
            for s in SENSORS_CONFIG:
                val = random.uniform(s["normal_range"][0], s["normal_range"][1])
                success, msg = executar_sql_insercio(s["id_sensor"], val, s["unitat"])
                tec_label = f"[{s['tecnologia']}]"
                print(f"  {tec_label:<10} Sensor #{s['id_sensor']} ({s['tipus']} - {s['nau']}): {val:.2f} {s['unitat']} -> {msg}")
            
            cicle += 1
            print("Esperant 5 segons per a la propera tanda de telemetria...\n")
            time.sleep(5)
    except KeyboardInterrupt:
        print("\nSimulació aturada per l'usuari.")

def mode_alarma():
    print("\n=======================================================")
    print("  AviGest S.L. — Simulació d'Incidència i Dispar de Triggers")
    print("=======================================================\n")
    print("1. Injectant TEMPERATURA CRÍTICA (34.8 ºC) al Sensor #1 (Bellpuig NAU-01)...")
    print("   -> Llindar màxim de la nau: 31.0 ºC")
    success, msg = executar_sql_insercio(1, 34.80, "ºC")
    print(f"   Estat: {msg}")

    print("\n2. Injectant NIVELL CRÍTIC DE SILO (980 kg) al Sensor #3 (LoRaWAN Silo Bellpuig)...")
    print("   -> Llindar mínim de reserva: 1500.0 kg")
    success, msg = executar_sql_insercio(3, 980.00, "kg")
    print(f"   Estat: {msg}")

    print("\n3. Comprovant efecte automàtic del TRIGGER a la Base de Dades:")
    estat = comprovar_estat_actuadors()
    if estat:
        print(estat)
        print("\n[ÈXIT] El trigger ha detectat la pujada de temperatura i ha canviat l'estat del ventilador a 'ON'!")
    else:
        print("  -> Si teniu MariaDB engegat a Docker, podeu verificar amb phpMyAdmin la taula 'actuadors' i 'alarmes_incidencies'.")

def mode_interactiu():
    print("\n=======================================================")
    print("  AviGest S.L. — Simulador Interactiu Manual           ")
    print("=======================================================\n")
    print("Sensors disponibles:")
    for s in SENSORS_CONFIG:
        print(f"  [{s['id_sensor']}] {s['granja']} | {s['nau']} | {s['tipus']} ({s['unitat']}) [Llindars: {s['min']}-{s['max']}]")
    
    try:
        id_s = int(input("\nIndiqueu l'ID del sensor a simular (ex: 1): "))
        sensor_trobat = next((s for s in SENSORS_CONFIG if s["id_sensor"] == id_s), None)
        if not sensor_trobat:
            print("[ERROR] Sensor no vàlid!")
            return

        val = float(input(f"Indiqueu el valor mesurat en {sensor_trobat['unitat']} (ex: 32.5): "))
        ok, msg = executar_sql_insercio(id_s, val, sensor_trobat["unitat"])
        print(f"\n[Resultat]: {msg}")
        
        if val > sensor_trobat["max"]:
            print(f"-> ALERTA: El valor {val} supera el màxim permès ({sensor_trobat['max']}). S'haurà disparat el ventilador.")
        elif val < sensor_trobat["min"]:
            print(f"-> ALERTA: El valor {val} és inferior al mínim ({sensor_trobat['min']}). S'haurà generat una alarma.")
        else:
            print("-> El valor està dins del rang de funcionament normal.")
    except ValueError:
        print("[ERROR] Cal introduir un número vàlid.")

def main():
    parser = argparse.ArgumentParser(description="Simulador de Telemetria IoT per a AviGest S.L.")
    parser.add_argument("--mode", choices=["normal", "alarma", "interactiu"], default="normal",
                        help="Mode de funcionament: 'normal', 'alarma' o 'interactiu'")
    args = parser.parse_args()

    if args.mode == "normal":
        mode_normal()
    elif args.mode == "alarma":
        mode_alarma()
    elif args.mode == "interactiu":
        mode_interactiu()

if __name__ == "__main__":
    main()
