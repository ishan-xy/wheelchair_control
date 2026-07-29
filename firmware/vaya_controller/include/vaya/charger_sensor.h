#pragma once

#include <Arduino.h>

namespace vaya {

class ChargerSensor {
 public:
  void begin();
  void update(uint32_t nowMs);
  bool available() const;
  bool connected() const;

 private:
  bool enabled_{false};
  bool rawConnected_{false};
  bool connected_{false};
  uint32_t rawChangedAtMs_{0};
};

}  // namespace vaya
