#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
==============================================================================
AviGest S.L. — Servei d'ingesta MQTT → MariaDB (Requeriment 4.8)
Fitxer: iot/ingestio/mqtt_a_mariadb.py
Mòdul: ASIX - Projecte
Responsable: Mariam (Base de Dades, IoT i Automatització)

Descripció:
S'executa a srv-serveis (contenidor avigest_mqtt_ingest).
Subscriu el topic avigest/+/telemetria/# i fa INSERT a lectures_sensors
amb l'usuari dedicat avigest_iot.
El trigger trg_control_llindars_sensor s'activa automàticament a MariaDB.
==============================================================================
"""
import json
import os
import sys
import time

import paho.mqtt.client as mqtt
import pymysql

DB_CONFIG = {
    "host": os.getenv("DB_HOST", "mariadb"),
    "port": int(os.getenv("DB_PORT", "3306")),
    "user": os.getenv("DB_USER", "avigest_iot"),
    "password": os.getenv("DB_PASSWORD", "iot_ingest_pass_2026"),
    "database": os.getenv("DB_NAME", "avigest_db"),
    "autocommit": True,
}
MQTT_HOST = os.getenv("MQTT_HOST", "mosquitto")
MQTT_PORT = int(os.getenv("MQTT_PORT", "1883"))
MQTT_TOPIC = os.getenv("MQTT_TOPIC", "avigest/+/telemetria/#")


def connectar_db():
    while True:
        try:
            conn = pymysql.connect(**DB_CONFIG)
            print(f"[ingest] MariaDB a {DB_CONFIG['host']}:{DB_CONFIG['port']} OK", flush=True)
            return conn
        except Exception as exc:
            print(f"[ingest] Esperant MariaDB ({DB_CONFIG['host']}:{DB_CONFIG['port']}): {exc}", flush=True)
            time.sleep(3)


def inserir_lectura(conn, payload):
    data = json.loads(payload)
    sensor_id = int(data["id_sensor"])
    valor = float(data["valor"])
    with conn.cursor() as cur:
        cur.execute(
            "INSERT INTO lectures_sensors (id_sensor, valor) VALUES (%s, %s)",
            (sensor_id, valor),
        )
    print(f"[ingest] INSERT sensor={sensor_id} valor={valor}", flush=True)


def main():
    conn = connectar_db()

    def on_connect(client, userdata, flags, rc):
        print(f"[ingest] MQTT {MQTT_HOST}:{MQTT_PORT} rc={rc}", flush=True)
        client.subscribe(MQTT_TOPIC)

    def on_message(client, userdata, msg):
        nonlocal conn
        try:
            conn.ping(reconnect=True)
            inserir_lectura(conn, msg.payload.decode("utf-8"))
        except Exception as exc:
            print(f"[ingest] Error: {exc} payload={msg.payload!r}", flush=True)
            try:
                conn.close()
            except Exception:
                pass
            conn = connectar_db()

    client = mqtt.Client(mqtt.CallbackAPIVersion.VERSION1, client_id="avigest-mqtt-ingest")
    client.on_connect = on_connect
    client.on_message = on_message

    while True:
        try:
            client.connect(MQTT_HOST, MQTT_PORT, 60)
            client.loop_forever()
        except Exception as exc:
            print(f"[ingest] MQTT desconnectat: {exc}", flush=True)
            time.sleep(5)


if __name__ == "__main__":
    try:
        main()
    except KeyboardInterrupt:
        sys.exit(0)

