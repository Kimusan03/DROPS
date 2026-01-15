#include <SoftwareSerial.h>

SoftwareSerial espSerial(2, 3); // RX, TX

void setup() {
  Serial.begin(9600);       // Serial monitor
  espSerial.begin(115200);  // ESP-01 default baud rate
  Serial.println("ESP-01 Test Start");
}

void loop() {
  // send AT command to ESP-01
  espSerial.println("AT");
  delay(1000);

  // read response
  while (espSerial.available()) {
    char c = espSerial.read();
    Serial.write(c);
  }
  delay(2000);
}
