// HW-504 joystick input test for ESP32.
// Wiring: GND -> GND, VCC -> 3V3, VRx -> GPIO32, VRy -> GPIO33.
// Do not connect 5 V joystick outputs directly to ESP32 ADC pins.

constexpr int kVrxPin = 32;
constexpr int kVryPin = 33;
constexpr int kChangeThreshold = 4;

int lastVrx = -1;
int lastVry = -1;

void setup() {
  Serial.begin(115200);
  pinMode(kVrxPin, INPUT);
  pinMode(kVryPin, INPUT);
  analogReadResolution(12);
  Serial.println("HW-504 input test: center, then move front/back/left/right.");
}

void loop() {
  const int vrx = analogRead(kVrxPin);
  const int vry = analogRead(kVryPin);

  if (abs(vrx - lastVrx) >= kChangeThreshold ||
      abs(vry - lastVry) >= kChangeThreshold) {
    Serial.printf("VRx=%d  VRy=%d\n", vrx, vry);
    lastVrx = vrx;
    lastVry = vry;
  }

  delay(50);
}
