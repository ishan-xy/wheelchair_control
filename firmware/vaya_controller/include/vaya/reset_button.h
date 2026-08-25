#pragma once

#include <Arduino.h>

namespace vaya {

class ResetButton {
 public:
  void begin();
  void update(uint32_t nowMs);
  bool consumeResetEvent();

 private:
  bool enabled_{false};
  bool rawPressed_{false};
  bool stablePressed_{false};
  bool triggered_{false};
  bool resetEvent_{false};
  uint32_t rawChangedAtMs_{0};
  uint32_t pressedAtMs_{0};
};

}  // namespace vaya
