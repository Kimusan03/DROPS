#define WATER_PIN A0
#define TRIG_PIN 8
#define ECHO_PIN 7

long duration;
float distanceCm;
int waterValue;
float waterLevelCm;

float sensorHeightCm = 100; // adjust as your setup
float waterMax = 1023.0;

void setup() {
  Serial.begin(9600);
  pinMode(TRIG_PIN, OUTPUT);
  pinMode(ECHO_PIN, INPUT);
}

float readDistance() {
  digitalWrite(TRIG_PIN, LOW);
  delayMicroseconds(2);
  digitalWrite(TRIG_PIN, HIGH);
  delayMicroseconds(10);
  digitalWrite(TRIG_PIN, LOW);

  long duration = pulseIn(ECHO_PIN, HIGH, 60000);
  if (duration == 0) return -1;
  return (duration * 0.034) / 2.0;
}

float readWaterLevel() {
  waterValue = analogRead(WATER_PIN);
  waterLevelCm = (waterValue / waterMax) * sensorHeightCm;
  return waterLevelCm;
}

void loop() {
  distanceCm = readDistance();
  waterLevelCm = readWaterLevel();

  Serial.print(distanceCm);
  Serial.print(",");
  Serial.println(waterLevelCm);

  delay(1000);
}
