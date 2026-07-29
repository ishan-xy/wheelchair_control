#pragma once

#include <Arduino.h>

namespace vaya {

class AlertIndicator {
 public:
  void begin();
  void setSosActive(bool active);
  void update(uint32_t nowMs);

 private:
  bool enabled_{false};
  bool sosActive_{false};
  bool outputOn_{false};
  uint32_t lastToggleAtMs_{0};
};

}  // namespace vaya
