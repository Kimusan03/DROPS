// HC-SR04 Test Code
const int trigPin = 8;
const int echoPin = 7;

void setup() {
  Serial.begin(9600);
  pinMode(trigPin, OUTPUT);
  pinMode(echoPin, INPUT);
}

void loop() {
  // Send a 10µs pulse to trigger
  digitalWrite(trigPin, LOW);
  delayMicroseconds(2);
  digitalWrite(trigPin, HIGH);
  delayMicroseconds(10);
  digitalWrite(trigPin, LOW);

  // Read the echo
  long duration = pulseIn(echoPin, HIGH);
  
  // Convert to cm
  float distance = duration * 0.034 / 2;

const int waterPin = A0
// Water Level Sensor
  ;int waterValue = analogRead(waterPin);
  String raining = (waterValue > 200) ? "Yes" : "No"; // Threshold = 500

// output
  Serial.print("Is it raining? ");
  Serial.print(raining);
  Serial.print(" | Flood Level: ");
  Serial.print(distance);
  Serial.println(" cm");

  delay(500); // Half-second delay
}
