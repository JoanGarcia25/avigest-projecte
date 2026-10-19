/*
 * =============================================================================
 * AviGest S.L. — Firmware de Referència per a Microcontrolador ESP32
 * Fitxer: iot/sensors/codi_esp32_referencia.ino
 * Mòdul: ASIX - Projecte (Requeriments 4.8 i 2. Context Tecnològic)
 *
 * Descripció:
 * Codi en C++ / Arduino Framework per a la placa ESP32 instal·lada a la nau.
 * Llegeix els sensors ambientals connectats mitjançant bus industrial RS485
 * (pins RX2/TX2 amb xip transceptor MAX485), controla el relé del ventilador
 * de seguretat local (Life-Safety Edge) i transmet la telemetria en JSON
 * cap al Gateway industrial de la granja.
 * =============================================================================
 */

#include <WiFi.h>
#include <HTTPClient.h>
#include <ArduinoJson.h>

// Definició de pins de l'ESP32
#define PIN_RELE_VENTILADOR 23   // Sortida a relé d'actuador (Ventilador)
#define PIN_RX2 16               // Port sèrie RS485 RX
#define PIN_TX2 17               // Port sèrie RS485 TX
#define PIN_RS485_DIR 4          // Control de direcció Transmissió/Recepció MAX485

// Configuració de la xarxa local de la granja
const char* WIFI_SSID = "AviGest_Granja_LAN";
const char* WIFI_PASS = "ClauSeguraGranja2026";
const char* GATEWAY_URL = "http://192.168.1.10:8000/api/telemetria";

// Paràmetres de la instal·lació
const int ID_GRANJA = 1;
const int ID_NAU = 1;
const int ID_SENSOR_TEMP = 1;
const float LLINDAR_MAX_TEMP = 31.0; // ºC

unsigned long darrera_lectura = 0;
const long INTERVAL_LECTURA = 30000; // Cada 30 segons

void setup() {
  Serial.begin(115200);
  Serial2.begin(9600, SERIAL_8N1, PIN_RX2, PIN_TX2);

  pinMode(PIN_RELE_VENTILADOR, OUTPUT);
  pinMode(PIN_RS485_DIR, OUTPUT);
  digitalWrite(PIN_RELE_VENTILADOR, LOW); // Ventilador apagat inicialment
  digitalWrite(PIN_RS485_DIR, LOW);       // Mode recepció RS485

  Serial.println("[ESP32] Inicialitzant mòdul AviGest...");
  conectarWiFi();
}

void loop() {
  unsigned long ara = millis();

  if (ara - darrera_lectura >= INTERVAL_LECTURA) {
    darrera_lectura = ara;

    // 1. Lectura del sensor de temperatura i humitat via RS485 / Modbus
    float temperatura = llegirSensorRS485_Temperatura();
    float humitat = llegirSensorRS485_Humitat();

    Serial.printf("[TELEMETRIA] Temp: %.2f ºC | Humitat: %.2f %%\n", temperatura, humitat);

    // 2. Control de Seguretat Local a la Vora (Edge Computing)
    // Si la temperatura supera el llindar crític, s'activa el ventilador immediatament
    // sense dependre de la connexió a Internet
    if (temperatura > LLINDAR_MAX_TEMP) {
      digitalWrite(PIN_RELE_VENTILADOR, HIGH);
      Serial.println("[LOCAL EDGE] ALERTA: Sobreescalfament! Ventilador ACTIVAT localment.");
    } else {
      digitalWrite(PIN_RELE_VENTILADOR, LOW);
    }

    // 3. Enviament de telemetria al Gateway de granja
    enviarLecturaGateway(ID_SENSOR_TEMP, "temperatura", temperatura, "ºC");
  }
}

void conectarWiFi() {
  Serial.printf("[WIFI] Connectant a %s...\n", WIFI_SSID);
  WiFi.begin(WIFI_SSID, WIFI_PASS);
  int intents = 0;
  while (WiFi.status() != WL_CONNECTED && intents < 20) {
    delay(500);
    Serial.print(".");
    intents++;
  }
  if (WiFi.status() == WL_CONNECTED) {
    Serial.println("\n[WIFI] Connectat amb èxit. IP: " + WiFi.localIP().toString());
  } else {
    Serial.println("\n[WIFI] Advertència: Sense connexió WiFi. Operant en mode autònom local.");
  }
}

float llegirSensorRS485_Temperatura() {
  // En entorn real: envia trama Modbus RTU 01 03 00 00 00 01 84 0A pel Serial2
  // Per a demostració: valor simulat realista entre 23 i 28 ºC
  return 24.5 + (random(-20, 20) / 10.0);
}

float llegirSensorRS485_Humitat() {
  return 60.0 + (random(-50, 50) / 10.0);
}

void enviarLecturaGateway(int id_sensor, const char* tipus, float valor, const char* unitat) {
  if (WiFi.status() != WL_CONNECTED) return;

  HTTPClient http;
  http.begin(GATEWAY_URL);
  http.addHeader("Content-Type", "application/json");

  StaticJsonDocument<256> doc;
  doc["id_granja"] = ID_GRANJA;
  doc["id_nau"] = ID_NAU;
  doc["id_sensor"] = id_sensor;
  doc["tipus"] = tipus;
  doc["valor"] = valor;
  doc["unitat"] = unitat;

  String requestBody;
  serializeJson(doc, requestBody);

  int httpResponseCode = http.POST(requestBody);
  if (httpResponseCode > 0) {
    Serial.printf("[HTTP] Lectura enviada correctament (Codi %d)\n", httpResponseCode);
  } else {
    Serial.printf("[HTTP] Error d'enviament: %s\n", http.errorToString(httpResponseCode).c_str());
  }
  http.end();
}
