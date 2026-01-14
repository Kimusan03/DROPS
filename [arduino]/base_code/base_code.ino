#define TRIG_PIN 9
#define ECHO_PIN 10
#define WATER_PIN A0

void setup() {
  Serial.begin(9600);

  pinMode(TRIG_PIN, OUTPUT);
  pinMode(ECHO_PIN, INPUT);
}

void loop() {
  // ---- Ultrasonic ----
  long duration;
  float distance;

  digitalWrite(TRIG_PIN, LOW);
  delayMicroseconds(2);
  digitalWrite(TRIG_PIN, HIGH);
  delayMicroseconds(10);
  digitalWrite(TRIG_PIN, LOW);

  duration = pulseIn(ECHO_PIN, HIGH, 30000);

  if (duration == 0) {
    distance = -1; // no reading
  } else {
   float distance = duration * 0.034 / 2;
  }

  // ---- Water level sensor ----
  int waterValue = analogRead(WATER_PIN);

  // ---- Output ----
  Serial.print("Ultrasonic: ");
  if (distance < 0) {
    Serial.print("No reading");
  } else {
    Serial.print(distance);
    Serial.print(" cm");
  }

  Serial.print(" | Water Sensor: ");
  Serial.println(waterValue);

  delay(1000);
}
