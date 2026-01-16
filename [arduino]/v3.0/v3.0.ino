/*
  DROPS Arduino Code
  Wiring:
  - Ultrasonic: Trig (8), Echo (7)
  - Water Sensor: Signal (A0)
*/

#define WATER_PIN A0
#define TRIG 8
#define ECHO 7

void setup() {
  Serial.begin(9600);
  pinMode(TRIG, OUTPUT);
  pinMode(ECHO, INPUT);
}

void loop() {
  // 1. Read Water Level Sensor (Analog)
  // This gives a value between 0 (dry) and 1023 (wet)
  int waterValue = analogRead(WATER_PIN);

  // 2. Read Ultrasonic Sensor (Distance)
  digitalWrite(TRIG, LOW);
  delayMicroseconds(2);
  digitalWrite(TRIG, HIGH);
  delayMicroseconds(10);
  digitalWrite(TRIG, LOW);

  long duration = pulseIn(ECHO, HIGH, 30000); // 30ms timeout
  float distance = duration * 0.034 / 2.0;

  // 3. Error Handling for Ultrasonic
  // If the sensor reads 0 or out of range, we send a recognizable error value
  if (distance <= 0 || distance > 400) {
    distance = 0.0; 
  }

  // 4. SERIAL OUTPUT (Formatted for Python Regex)
  // IMPORTANT: Python expects "Distance, WaterValue"
  // We don't need to send 'raining' (1/0) because the App calculates that!
  
  Serial.print(distance);    // First number: distance_cm
  Serial.print(",");
  Serial.println(waterValue); // Second number: water_level_raw

  // 1-second delay matches the 800ms-1s polling in Flutter
  delay(1000);
}
