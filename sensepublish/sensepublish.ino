#include <ESP8266WiFi.h>
#include <WiFiManager.h>
#include <PubSubClient.h>

WiFiClient espClient;
PubSubClient client(espClient);

int active = 0;
int changed = 0;

void setup() {
  IPAddress ip;
  IPAddress subnet;
  IPAddress gateway;
  IPAddress dns;
  Serial.begin(115200, SERIAL_8N1);
  Serial.println(ESP.getResetReason());
  WiFi.hostname("SENSEPUBLISH");
  WiFi.mode(WIFI_STA);
  ip = IPAddress(192,168,127,61);
  subnet = IPAddress(255,255,255,0);
  gateway = IPAddress(192,168,127,1);
  dns = IPAddress(192,168,127,1);
  WiFi.config(ip, dns, gateway, subnet);
  WiFiManager wifiManager;
  wifiManager.autoConnect("AutoConnectAP");
  client.setServer("192.168.127.1", 1883);
}

void reconnect() {
  while (!client.connected()) {
    Serial.print("Attempting MQTT connection...");
    String clientId = "SENSEPOST-" + String(ESP.getChipId(), HEX);
    if (client.connect(clientId.c_str(), NULL, NULL, "sense", 0, true, "disconnected")) {
      client.publish("sense", "connected", true);
      Serial.println("connected");
    } else {
      Serial.print("failed, rc=");
      Serial.print(client.state());
      Serial.println(" try again in 5 seconds");
      delay(5000);
    }
  }
}

void loop() {
  changed = 0;
  if (!client.connected()) {
    reconnect();
  }
  client.loop();
  if (active == 0 && analogRead(A0) == 1024) {
    active = 1;
    changed = 1;
  }
  if (changed == 0 && active == 1 && analogRead(A0) < 1024) {
    active = 0;
    changed = 1;
  }
  if (changed == 1 && active == 1) {
    client.publish("sense", "active");
    Serial.println("dingdong");  
  } else if (changed == 1 && active == 0) {
    client.publish("sense", "inactive");
  }
  delay(10);
}
