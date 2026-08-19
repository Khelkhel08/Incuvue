// ESP32 Incubator — auto control + Firebase
// Board: ESP32 DevKit V1
// Temperature: heater + circulation fan (only when off setpoint)
// Humidity: ventilation fan (+ mist if too dry)
// Everything off when isActive is false
// Credentials: secrets.h in this folder
// DHT: Adafruit DHT sensor library + Adafruit Unified Sensor

#include <WiFi.h>
#include <WiFiClientSecure.h>
#include <HTTPClient.h>
#include <ArduinoJson.h>
#include "secrets.h"

#define DHT_PIN 4
#define WATER_PIN 34
#define RELAY_FAN_CIRC 26
#define RELAY_FAN_VENT 27
#define RELAY_HEATER 25
#define RELAY_MIST 33
#define MOTOR_ENA 32
#define MOTOR_IN1 18
#define MOTOR_IN2 19
static portMUX_TYPE dhtMux = portMUX_INITIALIZER_UNLOCKED;
#define RELAY_ON LOW
#define RELAY_OFF HIGH
#define TEMP_HYSTERESIS 0.3
#define HUM_HYSTERESIS 3.0
#define MOTOR_TILT_TIME 3000UL
#define MOTOR_PAUSE_TIME 5000UL
#define MOTOR_SETTLE_TIME 300UL
#define MOTOR_PWM 200
#define TEST_TURN_INTERVAL_SECONDS 0

const unsigned long SENSOR_INTERVAL = 2500;
const unsigned long FIREBASE_WRITE_INTERVAL = 2000;
const unsigned long FIREBASE_READ_INTERVAL = 800;
const unsigned long FIREBASE_AUTH_INTERVAL = 50UL * 60UL * 1000UL;

unsigned long lastSensorRead = 0;
unsigned long lastFirebaseWrite = 0;
unsigned long lastFirebaseRead = 0;
unsigned long lastFirebaseAuth = 0;
unsigned long lastMotorAction = 0;

String idToken = "";
bool wifiReady = false;
bool firebaseReady = false;
bool cmdIsActive = false;
bool cmdEggTurner = false;
bool cmdTurningActive = false;
bool cmdHeaterEnabled = true;
bool cmdFanCircEnabled = true;
bool cmdFanVentEnabled = true;
bool cmdManualMode = false;
float cmdTurningIntervalHours = 4.0;
int cmdTurnSeconds = 14400;
float cmdTargetTemp = 37.5;
float cmdTargetHum = 55.0;
int cmdCurrentDay = 0;
int cmdLockdownStartDay = 18;
bool heaterOn = false;
bool fanOn = false;
bool circOn = false;
bool ventOn = false;
bool mistOn = false;
float lastTemperature = NAN;
float lastHumidity = NAN;
float lastWaterPercent = 0;

enum MotorState {
  HOLD_CENTER,
  MOVE_RIGHT,
  HOLD_RIGHT,
  MOVE_CENTER_FROM_RIGHT,
  HOLD_CENTER_MID,
  MOVE_LEFT,
  HOLD_LEFT,
  MOVE_CENTER_FROM_LEFT
};
MotorState motorState = HOLD_CENTER;

void motorForward() {
  digitalWrite(MOTOR_IN1, HIGH);
  digitalWrite(MOTOR_IN2, LOW);
  analogWrite(MOTOR_ENA, MOTOR_PWM);
}

void motorBackward() {
  digitalWrite(MOTOR_IN1, LOW);
  digitalWrite(MOTOR_IN2, HIGH);
  analogWrite(MOTOR_ENA, MOTOR_PWM);
}

void motorStop() {
  digitalWrite(MOTOR_IN1, LOW);
  digitalWrite(MOTOR_IN2, LOW);
  analogWrite(MOTOR_ENA, 0);
}

void stopAllActuators() {
  digitalWrite(RELAY_HEATER, RELAY_OFF);
  digitalWrite(RELAY_FAN_CIRC, RELAY_OFF);
  digitalWrite(RELAY_FAN_VENT, RELAY_OFF);
  digitalWrite(RELAY_MIST, RELAY_OFF);
  heaterOn = false;
  fanOn = false;
  circOn = false;
  ventOn = false;
  mistOn = false;
  motorStop();
}

bool inLockdown() {
  return cmdCurrentDay >= cmdLockdownStartDay && cmdLockdownStartDay > 0;
}

bool turnerEnabled() {
  if (!cmdIsActive || inLockdown()) {
    return false;
  }
  return cmdEggTurner;
}

unsigned long cyclePauseMs() {
  if (TEST_TURN_INTERVAL_SECONDS > 0) {
    return (unsigned long)TEST_TURN_INTERVAL_SECONDS * 1000UL;
  }
  int seconds = cmdTurnSeconds;
  if (seconds < 1) {
    seconds = 1;
  }
  return (unsigned long)seconds * 1000UL;
}

void controlEggTurner() {
  if (!turnerEnabled()) {
    motorStop();
    motorState = HOLD_CENTER;
    lastMotorAction = millis();
    return;
  }
  unsigned long now = millis();
  switch (motorState) {
    case HOLD_CENTER:
      motorStop();
      if (now - lastMotorAction >= cyclePauseMs()) {
        lastMotorAction = now;
        motorState = MOVE_RIGHT;
        motorForward();
        Serial.println("[Motor] 0 -> RIGHT 45");
      }
      break;
    case MOVE_RIGHT:
      if (now - lastMotorAction >= MOTOR_TILT_TIME) {
        lastMotorAction = now;
        motorStop();
        motorState = HOLD_RIGHT;
        Serial.println("[Motor] Hold RIGHT 45");
      }
      break;
    case HOLD_RIGHT:
      motorStop();
      if (now - lastMotorAction >= cyclePauseMs()) {
        lastMotorAction = now;
        motorState = MOVE_CENTER_FROM_RIGHT;
        motorBackward();
        Serial.println("[Motor] RIGHT -> 0");
      }
      break;
    case MOVE_CENTER_FROM_RIGHT:
      if (now - lastMotorAction >= MOTOR_TILT_TIME) {
        lastMotorAction = now;
        motorStop();
        motorState = HOLD_CENTER_MID;
        Serial.println("[Motor] Hold 0");
      }
      break;
    case HOLD_CENTER_MID:
      motorStop();
      if (now - lastMotorAction >= cyclePauseMs()) {
        lastMotorAction = now;
        motorState = MOVE_LEFT;
        motorBackward();
        Serial.println("[Motor] 0 -> LEFT 45");
      }
      break;
    case MOVE_LEFT:
      if (now - lastMotorAction >= MOTOR_TILT_TIME) {
        lastMotorAction = now;
        motorStop();
        motorState = HOLD_LEFT;
        Serial.println("[Motor] Hold LEFT 45");
      }
      break;
    case HOLD_LEFT:
      motorStop();
      if (now - lastMotorAction >= cyclePauseMs()) {
        lastMotorAction = now;
        motorState = MOVE_CENTER_FROM_LEFT;
        motorForward();
        Serial.println("[Motor] LEFT -> 0");
      }
      break;
    case MOVE_CENTER_FROM_LEFT:
      if (now - lastMotorAction >= MOTOR_TILT_TIME) {
        lastMotorAction = now;
        motorStop();
        motorState = HOLD_CENTER;
        Serial.println("[Motor] Hold 0 (cycle restart)");
      }
      break;
  }
}

void prepareHttps(WiFiClientSecure& client, HTTPClient& http) {
  client.setInsecure();
  client.setTimeout(20000);
  http.setTimeout(20000);
  http.useHTTP10(true);
}

static bool dhtWaitPin(uint8_t pin, uint8_t level, uint32_t timeoutCycles) {
  uint32_t start = ESP.getCycleCount();
  while (digitalRead(pin) != level) {
    if ((ESP.getCycleCount() - start) > timeoutCycles) {
      return false;
    }
  }
  return true;
}

bool decodeDht(const uint8_t data[5], float& temperature, float& humidity) {
  if (data[1] == 0 && data[3] == 0 && data[0] <= 100) {
    humidity = data[0];
    temperature = data[2];
  } else {
    humidity = ((data[0] << 8) | data[1]) * 0.1f;
    int16_t rawT = (int16_t)((data[2] << 8) | data[3]);
    if (rawT & 0x8000) {
      temperature = -0.1f * (rawT & 0x7FFF);
    } else {
      temperature = 0.1f * rawT;
    }
  }
  return humidity >= 0 && humidity <= 100 && temperature > -40 && temperature < 85;
}

int dhtCapture(uint8_t pin, uint32_t startLowMs, uint8_t data[5]) {
  uint32_t mhz = getCpuFrequencyMhz();
  if (mhz < 80) {
    mhz = 240;
  }
  uint32_t us = mhz;
  pinMode(pin, OUTPUT);
  digitalWrite(pin, LOW);
  delay(startLowMs);

  portENTER_CRITICAL(&dhtMux);
  digitalWrite(pin, HIGH);
  delayMicroseconds(40);
  pinMode(pin, INPUT_PULLUP);

  if (!dhtWaitPin(pin, LOW, 250 * us)) {
    portEXIT_CRITICAL(&dhtMux);
    return 1;
  }
  if (!dhtWaitPin(pin, HIGH, 250 * us)) {
    portEXIT_CRITICAL(&dhtMux);
    return 2;
  }
  if (!dhtWaitPin(pin, LOW, 250 * us)) {
    portEXIT_CRITICAL(&dhtMux);
    return 3;
  }

  for (int i = 0; i < 40; i++) {
    if (!dhtWaitPin(pin, HIGH, 150 * us)) {
      portEXIT_CRITICAL(&dhtMux);
      return 4;
    }
    uint32_t highStart = ESP.getCycleCount();
    if (!dhtWaitPin(pin, LOW, 200 * us)) {
      portEXIT_CRITICAL(&dhtMux);
      return 5;
    }
    data[i / 8] <<= 1;
    if ((ESP.getCycleCount() - highStart) > (40 * us)) {
      data[i / 8] |= 1;
    }
  }
  portEXIT_CRITICAL(&dhtMux);
  pinMode(pin, INPUT_PULLUP);

  if (((data[0] + data[1] + data[2] + data[3]) & 0xFF) != data[4]) {
    return 6;
  }
  return 0;
}

bool readClimate() {
  uint8_t data[5] = {0};
  int err = dhtCapture(DHT_PIN, 2, data);
  if (err != 0) {
    delay(80);
    memset(data, 0, 5);
    err = dhtCapture(DHT_PIN, 18, data);
  }
  if (err != 0) {
    Serial.print("[DHT] err ");
    Serial.println(err);
    return false;
  }
  if (!decodeDht(data, lastTemperature, lastHumidity)) {
    Serial.println("[DHT] err 7");
    return false;
  }
  return true;
}

String firestoreDocUrl() {
  return String("https://firestore.googleapis.com/v1/projects/")
         + FIREBASE_PROJECT_ID
         + "/databases/(default)/documents/incubators/incubator_1";
}

void printNearbyWifi() {
  Serial.println("[WiFi] Scanning...");
  int n = WiFi.scanNetworks();
  if (n <= 0) {
    Serial.println("[WiFi] No networks found");
    return;
  }
  for (int i = 0; i < n; i++) {
    Serial.print("  ");
    Serial.print(WiFi.SSID(i));
    Serial.print("  ch=");
    Serial.println(WiFi.channel(i));
  }
}

bool connectWiFi() {
  if (WiFi.status() == WL_CONNECTED) {
    wifiReady = true;
    return true;
  }
  Serial.print("[WiFi] Connecting to SSID: ");
  Serial.println(WIFI_SSID);
  WiFi.persistent(false);
  WiFi.mode(WIFI_STA);
  WiFi.setSleep(false);
  WiFi.disconnect();
  delay(300);
  WiFi.begin(WIFI_SSID, WIFI_PASSWORD);
  unsigned long start = millis();
  while (WiFi.status() != WL_CONNECTED && millis() - start < 25000) {
    delay(400);
    Serial.print(".");
  }
  Serial.println();
  if (WiFi.status() != WL_CONNECTED) {
    wifiReady = false;
    Serial.println("[WiFi] FAILED");
    printNearbyWifi();
    return false;
  }
  wifiReady = true;
  Serial.print("[WiFi] OK ");
  Serial.println(WiFi.localIP());
  return true;
}

bool firebaseSignIn() {
  if (!connectWiFi()) {
    return false;
  }
  WiFiClientSecure client;
  HTTPClient http;
  prepareHttps(client, http);
  String url = String("https://identitytoolkit.googleapis.com/v1/accounts:signInWithPassword?key=")
               + FIREBASE_API_KEY;
  JsonDocument bodyDoc;
  bodyDoc["email"] = DEVICE_EMAIL;
  bodyDoc["password"] = DEVICE_PASSWORD;
  bodyDoc["returnSecureToken"] = true;
  String body;
  serializeJson(bodyDoc, body);
  http.begin(client, url);
  http.addHeader("Content-Type", "application/json");
  int code = http.POST(body);
  String response = http.getString();
  http.end();
  if (code != 200) {
    firebaseReady = false;
    idToken = "";
    Serial.print("[Firebase] Auth HTTP ");
    Serial.println(code);
    return false;
  }
  JsonDocument parsed;
  DeserializationError err = deserializeJson(parsed, response);
  if (err || parsed["idToken"].isNull()) {
    firebaseReady = false;
    Serial.println("[Firebase] Auth parse failed");
    return false;
  }
  idToken = parsed["idToken"].as<String>();
  firebaseReady = true;
  lastFirebaseAuth = millis();
  Serial.println("[Firebase] Signed in");
  return true;
}

bool ensureFirebaseAuth() {
  if (idToken.length() == 0 || millis() - lastFirebaseAuth > FIREBASE_AUTH_INTERVAL) {
    return firebaseSignIn();
  }
  return firebaseReady;
}

float firestoreNumber(JsonObjectConst fields, const char* name, float fallback) {
  if (fields[name]["doubleValue"].is<float>() || fields[name]["doubleValue"].is<double>()) {
    return fields[name]["doubleValue"].as<float>();
  }
  if (!fields[name]["integerValue"].isNull()) {
    return fields[name]["integerValue"].as<String>().toFloat();
  }
  return fallback;
}

bool firestoreBool(JsonObjectConst fields, const char* name, bool fallback) {
  if (fields[name]["booleanValue"].is<bool>()) {
    return fields[name]["booleanValue"].as<bool>();
  }
  return fallback;
}

int firestoreInt(JsonObjectConst fields, const char* name, int fallback) {
  if (!fields[name]["integerValue"].isNull()) {
    return fields[name]["integerValue"].as<String>().toInt();
  }
  if (fields[name]["doubleValue"].is<float>() || fields[name]["doubleValue"].is<double>()) {
    return (int)fields[name]["doubleValue"].as<float>();
  }
  return fallback;
}

String firestoreString(JsonObjectConst fields, const char* name, const String& fallback) {
  if (!fields[name]["stringValue"].isNull()) {
    return fields[name]["stringValue"].as<String>();
  }
  return fallback;
}

void firebaseReadCommands() {
  if (!ensureFirebaseAuth()) {
    return;
  }
  WiFiClientSecure client;
  HTTPClient http;
  prepareHttps(client, http);
  String url = firestoreDocUrl()
               + "?mask.fieldPaths=isActive"
               + "&mask.fieldPaths=eggTurner"
               + "&mask.fieldPaths=turningActive"
               + "&mask.fieldPaths=turningInterval"
               + "&mask.fieldPaths=heaterEnabled"
               + "&mask.fieldPaths=fanCircEnabled"
               + "&mask.fieldPaths=fanVentEnabled"
               + "&mask.fieldPaths=fanEnabled"
               + "&mask.fieldPaths=targetTemperature"
               + "&mask.fieldPaths=targetHumidity"
               + "&mask.fieldPaths=currentDay"
               + "&mask.fieldPaths=lockdownStartDay"
               + "&mask.fieldPaths=controlMode"
               + "&mask.fieldPaths=turningIntervalMinutes"
               + "&mask.fieldPaths=turningIntervalSeconds";
  http.begin(client, url);
  http.addHeader("Authorization", String("Bearer ") + idToken);
  int code = http.GET();
  String response = http.getString();
  http.end();
  if (code == 401 || code == 403) {
    idToken = "";
    firebaseSignIn();
    return;
  }
  if (code != 200) {
    Serial.print("[Firebase] Read HTTP ");
    Serial.println(code);
    return;
  }
  JsonDocument parsed;
  if (deserializeJson(parsed, response)) {
    return;
  }
  JsonObjectConst fields = parsed["fields"].as<JsonObjectConst>();
  cmdIsActive = firestoreBool(fields, "isActive", cmdIsActive);
  cmdEggTurner = firestoreBool(fields, "eggTurner", cmdEggTurner);
  cmdTurningActive = firestoreBool(fields, "turningActive", cmdTurningActive);
  cmdHeaterEnabled = firestoreBool(fields, "heaterEnabled", cmdHeaterEnabled);
  cmdFanCircEnabled = firestoreBool(fields, "fanCircEnabled", cmdFanCircEnabled);
  cmdFanVentEnabled = firestoreBool(fields, "fanVentEnabled", cmdFanVentEnabled);
  if (fields["fanCircEnabled"].isNull() && fields["fanVentEnabled"].isNull()) {
    bool legacyFan = firestoreBool(fields, "fanEnabled", true);
    cmdFanCircEnabled = legacyFan;
    cmdFanVentEnabled = legacyFan;
  }
  cmdTurningIntervalHours = firestoreNumber(fields, "turningInterval", cmdTurningIntervalHours);
  int secondsField = firestoreInt(fields, "turningIntervalSeconds", 0);
  int minutesField = firestoreInt(fields, "turningIntervalMinutes", 0);
  if (secondsField > 0) {
    cmdTurnSeconds = secondsField;
  } else if (minutesField > 0) {
    cmdTurnSeconds = minutesField * 60;
  } else {
    int fromHours = (int)(cmdTurningIntervalHours * 3600.0 + 0.5);
    cmdTurnSeconds = fromHours > 0 ? fromHours : 1;
  }
  cmdManualMode = firestoreString(fields, "controlMode", "auto") == "manual";
  cmdTargetTemp = firestoreNumber(fields, "targetTemperature", cmdTargetTemp);
  cmdTargetHum = firestoreNumber(fields, "targetHumidity", cmdTargetHum);
  cmdCurrentDay = firestoreInt(fields, "currentDay", cmdCurrentDay);
  cmdLockdownStartDay = firestoreInt(fields, "lockdownStartDay", cmdLockdownStartDay);
}

void firebaseWriteSensors() {
  if (!ensureFirebaseAuth() || isnan(lastTemperature) || isnan(lastHumidity)) {
    return;
  }
  WiFiClientSecure client;
  HTTPClient http;
  prepareHttps(client, http);
  String url = firestoreDocUrl()
               + "?updateMask.fieldPaths=temperature"
               + "&updateMask.fieldPaths=humidity"
               + "&updateMask.fieldPaths=waterLevel"
               + "&updateMask.fieldPaths=heater"
               + "&updateMask.fieldPaths=fan"
               + "&updateMask.fieldPaths=fanCirc"
               + "&updateMask.fieldPaths=fanVent"
               + "&updateMask.fieldPaths=deviceOnline";
  JsonDocument bodyDoc;
  JsonObject fields = bodyDoc["fields"].to<JsonObject>();
  fields["temperature"]["doubleValue"] = lastTemperature;
  fields["humidity"]["doubleValue"] = lastHumidity;
  fields["waterLevel"]["doubleValue"] = lastWaterPercent;
  fields["heater"]["booleanValue"] = heaterOn;
  fields["fan"]["booleanValue"] = fanOn;
  fields["fanCirc"]["booleanValue"] = circOn;
  fields["fanVent"]["booleanValue"] = ventOn;
  fields["deviceOnline"]["booleanValue"] = true;
  String body;
  serializeJson(bodyDoc, body);
  http.begin(client, url);
  http.addHeader("Authorization", String("Bearer ") + idToken);
  http.addHeader("Content-Type", "application/json");
  int code = http.PATCH(body);
  http.end();
  if (code == 401 || code == 403) {
    idToken = "";
    firebaseSignIn();
    return;
  }
  if (code != 200) {
    Serial.print("[Firebase] Write HTTP ");
    Serial.println(code);
    return;
  }
  Serial.println("[Firebase] Sensors written");
}

void applyClimateControl(bool printStatus) {
  if (!cmdIsActive) {
    return;
  }

  if (cmdManualMode) {
    digitalWrite(RELAY_HEATER, cmdHeaterEnabled ? RELAY_ON : RELAY_OFF);
    heaterOn = cmdHeaterEnabled;
    digitalWrite(RELAY_FAN_CIRC, cmdFanCircEnabled ? RELAY_ON : RELAY_OFF);
    circOn = cmdFanCircEnabled;
    digitalWrite(RELAY_FAN_VENT, cmdFanVentEnabled ? RELAY_ON : RELAY_OFF);
    ventOn = cmdFanVentEnabled;
  } else if (!isnan(lastTemperature) && !isnan(lastHumidity)) {
    bool tooCold = lastTemperature < cmdTargetTemp - TEMP_HYSTERESIS;
    bool tooHot = lastTemperature > cmdTargetTemp + TEMP_HYSTERESIS;
    bool tooHumid = lastHumidity > cmdTargetHum + HUM_HYSTERESIS;
    if (cmdHeaterEnabled && tooCold) {
      digitalWrite(RELAY_HEATER, RELAY_ON);
      heaterOn = true;
    } else {
      digitalWrite(RELAY_HEATER, RELAY_OFF);
      heaterOn = false;
    }
    bool wantVent = cmdFanVentEnabled && tooHumid;
    bool wantCirc = cmdFanCircEnabled && (tooCold || tooHot);
    digitalWrite(RELAY_FAN_VENT, wantVent ? RELAY_ON : RELAY_OFF);
    ventOn = wantVent;
    digitalWrite(RELAY_FAN_CIRC, wantCirc ? RELAY_ON : RELAY_OFF);
    circOn = wantCirc;
  }

  if (!isnan(lastHumidity)) {
    bool tooDry = lastHumidity < cmdTargetHum - HUM_HYSTERESIS;
    bool waterLow = lastWaterPercent < 5.0;
    if (!waterLow && tooDry) {
      digitalWrite(RELAY_MIST, RELAY_ON);
      mistOn = true;
    } else {
      digitalWrite(RELAY_MIST, RELAY_OFF);
      mistOn = false;
    }
  }
  fanOn = circOn || ventOn;

  if (!printStatus) {
    return;
  }
  Serial.print("[CTRL] ");
  Serial.print(cmdManualMode ? "manual" : "auto");
  Serial.print(" heater=");
  Serial.print(heaterOn ? "ON" : "off");
  Serial.print(" circ=");
  Serial.print(circOn ? "ON" : "off");
  Serial.print(" vent=");
  Serial.print(ventOn ? "ON" : "off");
  Serial.print(" mist=");
  Serial.print(mistOn ? "ON" : "off");
  Serial.print(" egg=");
  Serial.println(cmdEggTurner ? "allow" : "off");
}

void setup() {
  Serial.begin(115200);
  Serial.println("ESP32 Incubator auto + Firebase");
  pinMode(RELAY_FAN_CIRC, OUTPUT);
  digitalWrite(RELAY_FAN_CIRC, RELAY_OFF);
  pinMode(RELAY_FAN_VENT, OUTPUT);
  digitalWrite(RELAY_FAN_VENT, RELAY_OFF);
  pinMode(RELAY_HEATER, OUTPUT);
  digitalWrite(RELAY_HEATER, RELAY_OFF);
  pinMode(RELAY_MIST, OUTPUT);
  digitalWrite(RELAY_MIST, RELAY_OFF);
  pinMode(MOTOR_ENA, OUTPUT);
  pinMode(MOTOR_IN1, OUTPUT);
  pinMode(MOTOR_IN2, OUTPUT);
  motorStop();
  pinMode(WATER_PIN, INPUT);
  pinMode(DHT_PIN, INPUT_PULLUP);
  lastMotorAction = millis();
  connectWiFi();
  firebaseSignIn();
}

void loop() {
  unsigned long now = millis();
  if (now - lastFirebaseRead >= FIREBASE_READ_INTERVAL) {
    lastFirebaseRead = now;
    firebaseReadCommands();
    if (cmdIsActive) {
      applyClimateControl(true);
    }
  }
  if (!cmdIsActive) {
    stopAllActuators();
  } else {
    controlEggTurner();
  }
  if (now - lastSensorRead >= SENSOR_INTERVAL) {
    lastSensorRead = now;
    bool dhtOk = readClimate();
    int waterRaw = analogRead(WATER_PIN);
    lastWaterPercent = (waterRaw / 4095.0) * 100.0;
    if (!dhtOk) {
      Serial.print("[DHT22] Read FAILED (incubation ");
      Serial.print(cmdIsActive ? "ON" : "OFF");
      Serial.println(" — batch does not block DHT)");
      if (cmdIsActive) {
        applyClimateControl(true);
      }
    } else {
      Serial.print("[DHT22] Temp ");
      Serial.print(lastTemperature, 1);
      Serial.print("/");
      Serial.print(cmdTargetTemp, 1);
      Serial.print(" Hum ");
      Serial.print(lastHumidity, 1);
      Serial.print("/");
      Serial.print(cmdTargetHum, 0);
      if (!cmdIsActive) {
        Serial.println("  (idle — start batch in app for relays)");
      } else {
        Serial.println();
        applyClimateControl(true);
      }
    }
  }
  if (now - lastFirebaseWrite >= FIREBASE_WRITE_INTERVAL) {
    lastFirebaseWrite = now;
    firebaseWriteSensors();
  }
}
