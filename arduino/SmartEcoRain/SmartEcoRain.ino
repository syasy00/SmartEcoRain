#include <WiFi.h>
#include <EEPROM.h>
#include <DHT.h>
#include <Wire.h>
#include <Adafruit_GFX.h>
#include <Adafruit_SSD1306.h>
#include <DNSServer.h>
#include <HTTPClient.h>
#include <WebServer.h>

// ====== Pin and Device Definitions ======
#define SCREEN_WIDTH 128
#define SCREEN_HEIGHT 32
#define OLED_RESET -1
#define DHTPIN 4
#define DHTTYPE DHT11 // Relay module for pump control
#define RELAY_PIN 5
#define LED_PIN 2

#define TRIG_PIN 18 // Ultrasonic sensor (trigger)
#define ECHO_PIN 19 // Ultrasonic sensor (echo)
#define WATER_SENSOR_PIN 34  // Analog water (rain) sensor

// ====== EEPROM Addresses ======
#define EEPROM_SIZE 256
#define SSID_ADDR 0
#define PASS_ADDR 64
#define USER_ADDR 128

Adafruit_SSD1306 display(SCREEN_WIDTH, SCREEN_HEIGHT, &Wire, OLED_RESET);
DHT dht(DHTPIN, DHTTYPE);
WebServer server(80);
DNSServer dnsServer;

String ssid, pass, username;
float waterLevel = 0.0;
String pumpMode = "AUTO";   // Default: AUTO mode
String pumpStatus = "OFF";  // Default: Pump off
const float tankHeight = 7.0; // Height of tank in cm

void showOLED(String line1, String line2 = "", String line3 = "", String line4 = "") {
  display.clearDisplay();
  display.setTextSize(1);
  display.setTextColor(SSD1306_WHITE);
  display.setCursor(0, 0);
  display.println(line1);
  display.setCursor(0, 8);
  display.println(line2);
  display.setCursor(0, 16);
  display.println(line3);
  display.setCursor(0, 24);
  display.println(line4);
  display.display();
}

void writeToEEPROM(int addr, const String &data) {
  for (int i = 0; i < 64; i++) EEPROM.write(addr + i, i < data.length() ? data[i] : 0);
  EEPROM.commit();
}

String readFromEEPROM(int addr) {
  char buf[65];
  for (int i = 0; i < 64; i++) buf[i] = EEPROM.read(addr + i);
  buf[64] = '\0';
  return String(buf);
}

void blinkConnected() {
  for (int i = 0; i < 3; i++) {
    digitalWrite(LED_PIN, HIGH);
    delay(300);
    digitalWrite(LED_PIN, LOW);
    delay(300);
  }
}
// ====== Upload Sensor Data to Mobile App (flutter) ======
void sendToPHP(float temp, float hum, float waterLevel, int rainSensorValue, String relayStatus, String mode) {
  if (WiFi.status() == WL_CONNECTED) {
    HTTPClient http;
    http.begin("https://humancc.site/syasyaaina/sensor_SER/submit.php");
    http.addHeader("Content-Type", "application/json");
    String postData = "{\"temperature\":" + String(temp) +
                      ",\"humidity\":" + String(hum) +
                      ",\"water_level\":" + String(waterLevel) +
                      ",\"rain_sensor\":" + String(rainSensorValue) +
                      ",\"relay_status\":\"" + relayStatus + "\"" +
                      ",\"mode\":\"" + mode + "\"}";
    int responseCode = http.POST(postData);
    Serial.print("POST Response: ");
    Serial.println(responseCode);
    http.end();
  } else {
    Serial.println("WiFi not connected");
  }
}

// ====== Ultrasonic Water Level Measurement ======
float measureDistance() {
  // Triggers the ultrasonic sensor and returns distance in cm
  digitalWrite(TRIG_PIN, LOW);
  delayMicroseconds(2);
  digitalWrite(TRIG_PIN, HIGH);
  delayMicroseconds(10);
  digitalWrite(TRIG_PIN, LOW);

  long duration = pulseIn(ECHO_PIN, HIGH, 30000);
  float distance = duration * 0.0343 / 2;
  return distance;
}

// ====== REMOTE PUMP CONTROL (AUTO/MANUAL) ======
void checkPumpStatus() {
  // Checks the remote pump status from server in MANUAL mode
  if (WiFi.status() == WL_CONNECTED) {
    HTTPClient http;
    http.begin("https://humancc.site/syasyaaina/sensor_SER/pump_control.php");
    int httpCode = http.GET();
    if (httpCode == 200) {
      String payload = http.getString();
      if (payload.indexOf("\"mode\":\"MANUAL\"") > 0) {
        pumpMode = "MANUAL";
        // Only set relay in MANUAL
        if (payload.indexOf("\"status\":\"ON\"") > 0) {
          digitalWrite(RELAY_PIN, HIGH);
          pumpStatus = "ON";
        } else {
          digitalWrite(RELAY_PIN, LOW);
          pumpStatus = "OFF";
        }
      } else {
        pumpMode = "AUTO";
        // In AUTO, relay is handled by sensor logic in loop
      }
    }
    http.end();
  }
}

void startCaptivePortal() {
  WiFi.disconnect(true);
  delay(100);
  WiFi.mode(WIFI_OFF);
  delay(100);
  WiFi.mode(WIFI_AP);
  delay(100);

  WiFi.softAP("ESP32_Config", "");
  delay(1000);

  IPAddress IP = WiFi.softAPIP();
  dnsServer.start(53, "*", IP);

  server.on("/", handleRoot);
  server.on("/generate_204", handleRoot);
  server.on("/redirect", handleRoot);
  server.on("/hotspot-detect.html", handleRoot);
  server.on("/ncsi.txt", handleRoot);
  server.on("/fwlink", handleRoot);
  server.on("/save", HTTP_POST, handleSave);
  server.on("/clear", HTTP_POST, handleClear);
  server.onNotFound([]() {
    server.sendHeader("Location", "/", true);
    server.send(302, "Redirecting...");
  });

  server.begin();
  showOLED("AP Mode Active", "ESP32_Config", IP.toString());
}

void handleRoot() {
  String currentSSID = readFromEEPROM(SSID_ADDR);
  String currentPass = readFromEEPROM(PASS_ADDR);
  String currentUser = readFromEEPROM(USER_ADDR);

  String html = R"rawliteral(
<!DOCTYPE html><html><head><meta charset='UTF-8'><title>WiFi Setup</title>
<meta name='viewport' content='width=device-width, initial-scale=1'>
<style>body{font-family:Segoe UI,sans-serif;background:#f4f6fa;display:flex;justify-content:center;align-items:center;height:100vh;margin:0}.card{background:white;padding:30px;border-radius:12px;box-shadow:0 6px 20px rgba(0,0,0,0.08);width:90%;max-width:360px}h2{text-align:center;margin-bottom:20px}label{display:block;margin-bottom:6px;font-weight:500;font-size:14px}input{width:100%;padding:10px;margin-bottom:14px;border:1px solid #ccc;border-radius:8px;font-size:14px}button{width:100%;padding:10px;margin-top:8px;background:#007BFF;color:white;border:none;border-radius:8px;font-size:15px;cursor:pointer}button:hover{background:#0056b3}.note{font-size:13px;color:#555;margin-top:20px;text-align:center}</style>
</head><body><div class='card'><h2>WiFi Setup</h2>
<form action='/save' method='POST'>
<label for='ssid'>WiFi SSID</label>
<input name='ssid' id='ssid' placeholder='SSID' value=")rawliteral"
                + currentSSID + R"rawliteral(" required>
<label for='pass'>WiFi Password (leave blank if open)</label>
<input name='pass' id='pass' type='password' placeholder='(Leave blank if open)' value=")rawliteral"
                + currentPass + R"rawliteral(">
<label for='user'>Username</label>
<input name='user' id='user' placeholder='Username' value=")rawliteral"
                + currentUser + R"rawliteral(" required>
<button type='submit'>🔒 Save & Connect</button>
</form>
<form action='/clear' method='POST'>
<button type='submit'>🧹 Reset</button>
</form>
<form action='/' method='GET'>
<button type='submit'>🔄 Reload</button>
</form>
<div class='note'>
Current SSID: <b>)rawliteral"
                + currentSSID + R"rawliteral(</b><br>
Username: <b>)rawliteral"
                + currentUser + R"rawliteral(</b>
</div></div></body></html>)rawliteral";

  server.send(200, "text/html", html);
}

void handleSave() {
  ssid = server.arg("ssid");
  pass = server.arg("pass");
  username = server.arg("user");

  writeToEEPROM(SSID_ADDR, ssid);
  writeToEEPROM(PASS_ADDR, pass);
  writeToEEPROM(USER_ADDR, username);

  showOLED("Saved!", "Restarting...", "");
  delay(1000);

  server.sendHeader("Location", "/", true);
  server.send(302, "text/plain", "Updated, rebooting...");
  delay(1000);
  ESP.restart();
}

void handleClear() {
  writeToEEPROM(SSID_ADDR, "");
  writeToEEPROM(PASS_ADDR, "");
  writeToEEPROM(USER_ADDR, "");

  ssid = pass = username = "";

  WiFi.disconnect(true, true);
  delay(500);

  showOLED("WiFi Cleared", "Restarting AP...", "");
  delay(1000);
  startCaptivePortal();
}

void setup() {
  Serial.begin(115200);
  EEPROM.begin(EEPROM_SIZE);
  display.begin(SSD1306_SWITCHCAPVCC, 0x3C);
  pinMode(LED_PIN, OUTPUT);
  dht.begin(); // Start DHT11 sensor
  pinMode(RELAY_PIN, OUTPUT); // Relay for pump
  digitalWrite(RELAY_PIN, LOW); // Pump off at startup

  pinMode(TRIG_PIN, OUTPUT);
  pinMode(ECHO_PIN, INPUT);
  pinMode(WATER_SENSOR_PIN, INPUT);

  ssid = readFromEEPROM(SSID_ADDR);
  pass = readFromEEPROM(PASS_ADDR);
  username = readFromEEPROM(USER_ADDR);

  WiFi.mode(WIFI_AP_STA);
  WiFi.softAP("ESP32_Config", "");
  delay(1000);

  IPAddress IP = WiFi.softAPIP();
  dnsServer.start(53, "*", IP);

  server.on("/", handleRoot);
  server.on("/save", HTTP_POST, handleSave);
  server.on("/clear", HTTP_POST, handleClear);
  server.begin();

  if (ssid.length() > 0) {
    showOLED("Connecting WiFi...", ssid);

    if (pass.length() > 0) {
      WiFi.begin(ssid.c_str(), pass.c_str());
    } else {
      WiFi.begin(ssid.c_str());
    }

    int retries = 0;
    while (WiFi.status() != WL_CONNECTED && retries < 20) {
      delay(500);
      retries++;
    }

    if (WiFi.status() == WL_CONNECTED) {
      blinkConnected();
      showOLED("WiFi Connected", "Welcome " + username);
    } else {
      showOLED("WiFi Failed", "Check Credentials", "");
      delay(2000);
    }
  } else {
    showOLED("AP Mode", "SSID: ESP32_Config", IP.toString());
  }
}

void loop() {
  server.handleClient();

  static unsigned long lastUpdate = 0;
  static unsigned long lastPumpCheck = 0;

  // Check pump mode/status every 1 second
  if (millis() - lastPumpCheck > 1000) {
    lastPumpCheck = millis();
    checkPumpStatus();
  }

  // Read sensors, upload, and update display every 5 seconds
  if (millis() - lastUpdate > 5000) {
    lastUpdate = millis();

 // === Ultrasonic Water Level ===
    float distance = measureDistance();
    Serial.print("Distance: ");
    Serial.println(distance);

    // Water level logic using tankHeight
    float waterHeight = tankHeight - distance;
    if (waterHeight < 0) waterHeight = 0;
    if (waterHeight > tankHeight) waterHeight = tankHeight;
    float percentFull = (waterHeight / tankHeight) * 100.0;
    waterLevel = percentFull; // global

// === DHT11 Temperature & Humidity ===
    float temp = dht.readTemperature();
    float hum = dht.readHumidity();

    if (isnan(temp) || isnan(hum)) {
      showOLED("DHT11 Error", "Check wiring", "", "");
      return;
    }

// === Water/Rain Sensor ===
    int rainSensorValue = analogRead(WATER_SENSOR_PIN);
    String rainwaterStatus = (rainSensorValue > 1000) ? "Yes" : "No";

// === Relay Control Logic (AUTO Mode) ===
    if (pumpMode == "AUTO") {
      
      if (waterLevel <= 30.0 && rainSensorValue < 1000) {
        digitalWrite(RELAY_PIN, HIGH);
        pumpStatus = "ON";
      } else {
        digitalWrite(RELAY_PIN, LOW);
        pumpStatus = "OFF";
      }
    }

// === OLED Display ===
    showOLED(
      "T: " + String(temp, 1) + "C H: " + String(hum, 0) + "%",
      "Tank: " + String(waterLevel, 1) + "%",
      "Dist: " + String(distance, 1) + "cm",
      "Rain: " + rainwaterStatus
    );

// === Data Upload ===
    sendToPHP(temp, hum, waterLevel, rainSensorValue, pumpStatus, pumpMode);
  }
}
