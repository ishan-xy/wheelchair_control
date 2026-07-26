#pragma once

#include <Arduino.h>

#include "vaya/types.h"

namespace vaya {

class BatterySensor {
 public:
  void begin();
  void update(uint32_t nowMs);
  const BatteryReading& reading() const;

 private:
  void finishReading(uint32_t nowMs);
  int16_t estimatePercentage(uint32_t voltageMv) const;

  BatteryReading reading_{};
  uint32_t accumulator_{0};
  uint32_t lastSampleMs_{0};
  uint8_t sampleCount_{0};
};

}  // namespace vaya
