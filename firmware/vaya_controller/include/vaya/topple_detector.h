#pragma once

#include <Arduino.h>

#include "vaya/types.h"

namespace vaya {

class ToppleDetector {
 public:
  void begin();
  void update(uint32_t nowMs);
  bool consumeToppleEvent();
  void acknowledgeReset();
  bool ready() const;
  bool canReset() const;
  SensorState state() const;

 private:
  bool readSample(float& roll, float& pitch, float& gyroMagnitude);
  void fail();

  SensorState state_{SensorState::kNotConfigured};
  bool toppleEvent_{false};
  bool toppled_{false};
  float referenceRoll_{0};
  float referencePitch_{0};
  float rollSum_{0};
  float pitchSum_{0};
  uint16_t calibrationSamples_{0};
  uint32_t calibrationStartedMs_{0};
  uint32_t lastSampleMs_{0};
  uint32_t toppleStartedMs_{0};
  uint32_t uprightStartedMs_{0};
};

}  // namespace vaya
