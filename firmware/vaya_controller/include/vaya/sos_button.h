#pragma once

#include <Arduino.h>

namespace vaya {

class SosButton {
 public:
  void begin();
  void update(uint32_t nowMs);
  bool consumeSosEvent();

 private:
  bool enabled_{false};
  bool rawPressed_{false};
  bool stablePressed_{false};
  bool triggered_{false};
  bool sosEvent_{false};
  uint32_t rawChangedAtMs_{0};
  uint32_t pressedAtMs_{0};
};

}  // namespace vaya
