#define WATER_PIN A0
#define TRIG 8
#define ECHO 7

void setup() {
  Serial.begin(9600);
  pinMode(TRIG, OUTPUT);
  pinMode(ECHO, INPUT);
}

void loop() {
  // ---- Water sensor ----
  int waterValue = analogRead(WATER_PIN);
  int raining = (waterValue > 200) ? 1 : 0;  // 1 = yes, 0 = no

  // ---- Ultrasonic ----
  digitalWrite(TRIG, LOW);
  delayMicroseconds(2);
  digitalWrite(TRIG, HIGH);
  delayMicroseconds(10);
  digitalWrite(TRIG, LOW);

  long duration = pulseIn(ECHO, HIGH, 30000);
  float distance = duration * 0.034 / 2.0;

  // ---- SERIAL OUTPUT (Python-friendly) ----
  // FORMAT: waterValue,raining,distance
  Serial.print(waterValue);
  Serial.print(",");
  Serial.print(raining);
  Serial.print(",");
  Serial.println(distance);

  delay(1000);
}
