#pragma once

#include <Arduino.h>

namespace vaya {

class StatusIndicators {
 public:
  void begin();
  void update(uint32_t nowMs, bool pairing, bool connected, bool standby,
              bool faultActive);

 private:
  bool pairingOutput_{false};
  uint32_t lastPairingToggleMs_{0};
};

}  // namespace vaya
