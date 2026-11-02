#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
Servei d'ingesta MQTT → PostgreSQL (Requeriment 4.8).
S'executa a srv-serveis, subscriu avigest/+/telemetria/# i INSERT a lectures_sensors
amb el rol avigest_iot. El trigger de llindars s'executa via SECURITY DEFINER.
"""
import json
import os
import sys
import time

import paho.mqtt.client as mqtt
import psycopg2

PG = {
    "host": os.getenv("PGHOST", "postgres"),
    "port": int(os.getenv("PGPORT", "5432")),
    "user": os.getenv("PGUSER", "avigest_iot"),
    "password": os.getenv("PGPASSWORD", "iot_ingest_pass_2026"),
    "dbname": os.getenv("PGDATABASE", "avigest_db"),
}
MQTT_HOST = os.getenv("MQTT_HOST", "mosquitto")
MQTT_PORT = int(os.getenv("MQTT_PORT", "1883"))
MQTT_TOPIC = os.getenv("MQTT_TOPIC", "avigest/+/telemetria/#")


def connectar_pg():
    while True:
        try:
            conn = psycopg2.connect(**PG)
            conn.autocommit = True
            print(f"[ingest] PostgreSQL a {PG['host']}:{PG['port']} OK", flush=True)
            return conn
        except Exception as exc:
            print(f"[ingest] Esperant PostgreSQL: {exc}", flush=True)
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
    conn = connectar_pg()

    def on_connect(client, userdata, flags, rc):
        print(f"[ingest] MQTT {MQTT_HOST}:{MQTT_PORT} rc={rc}", flush=True)
        client.subscribe(MQTT_TOPIC)

    def on_message(client, userdata, msg):
        nonlocal conn
        try:
            if conn.closed:
                conn = connectar_pg()
            inserir_lectura(conn, msg.payload.decode("utf-8"))
        except Exception as exc:
            print(f"[ingest] Error: {exc} payload={msg.payload!r}", flush=True)
            try:
                conn.close()
            except Exception:
                pass
            conn = connectar_pg()

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
