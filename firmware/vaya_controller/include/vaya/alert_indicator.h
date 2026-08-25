#pragma once

#include <Arduino.h>

namespace vaya {

class AlertIndicator {
 public:
  void begin();
  void setAlarmActive(bool active);
  void requestPairingFeedback(uint32_t nowMs);
  void update(uint32_t nowMs);

 private:
  bool enabled_{false};
  bool alarmActive_{false};
  bool outputOn_{false};
  uint32_t lastToggleAtMs_{0};
  uint32_t pairingFeedbackUntilMs_{0};
};

}  // namespace vaya
