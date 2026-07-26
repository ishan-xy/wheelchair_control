#pragma once

#include <Arduino.h>

namespace vaya {

class PairWakeButton {
 public:
  void begin();
  void update(uint32_t nowMs);
  bool consumeWakeEvent();
  bool consumePairingRequestEvent();

 private:
  bool enabled_{false};
  bool rawPressed_{false};
  bool stablePressed_{false};
  bool pairingRequested_{false};
  bool wakeEvent_{false};
  bool pairingRequestEvent_{false};
  uint32_t rawChangedAtMs_{0};
  uint32_t pressedAtMs_{0};
};

}  // namespace vaya
