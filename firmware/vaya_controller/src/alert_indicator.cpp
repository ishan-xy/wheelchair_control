#include "vaya/alert_indicator.h"

#include "vaya/config.h"

namespace vaya {

void AlertIndicator::begin() {
  enabled_ = config::kAlertIndicatorEnabled;
  if (!enabled_) return;
  pinMode(config::kAlertIndicatorPin, OUTPUT);
  digitalWrite(config::kAlertIndicatorPin,
               config::kAlertIndicatorActiveHigh ? LOW : HIGH);
}

void AlertIndicator::setAlarmActive(bool active) {
  alarmActive_ = active;
}

void AlertIndicator::requestPairingFeedback(uint32_t nowMs) {
  pairingFeedbackUntilMs_ = nowMs + 120;
}

void AlertIndicator::update(uint32_t nowMs) {
  if (!enabled_) return;
  if (!alarmActive_ && static_cast<int32_t>(pairingFeedbackUntilMs_ - nowMs) <= 0) {
    outputOn_ = false;
  } else if (nowMs - lastToggleAtMs_ >= config::kAlertIndicatorPeriodMs) {
    lastToggleAtMs_ = nowMs;
    outputOn_ = !outputOn_;
  }
  const bool outputLevel = config::kAlertIndicatorActiveHigh ? outputOn_ : !outputOn_;
  digitalWrite(config::kAlertIndicatorPin, outputLevel ? HIGH : LOW);
}

}  // namespace vaya
