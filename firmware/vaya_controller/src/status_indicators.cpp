#include "vaya/status_indicators.h"

#include "vaya/config.h"

namespace vaya {

void StatusIndicators::begin() {
  if (config::kPairingLedEnabled) {
    pinMode(config::kPairingLedPin, OUTPUT);
    digitalWrite(config::kPairingLedPin, LOW);
  }
  if (config::kFaultLedEnabled) {
    pinMode(config::kFaultLedPin, OUTPUT);
    digitalWrite(config::kFaultLedPin, LOW);
  }
}

void StatusIndicators::update(uint32_t nowMs, bool pairing, bool connected,
                              bool standby, bool faultActive) {
  if (config::kPairingLedEnabled) {
    if (pairing && nowMs - lastPairingToggleMs_ >= config::kPairingLedPeriodMs) {
      lastPairingToggleMs_ = nowMs;
      pairingOutput_ = !pairingOutput_;
    }
    if (!pairing) pairingOutput_ = false;
    digitalWrite(config::kPairingLedPin,
                 pairing ? (pairingOutput_ ? HIGH : LOW)
                         : (connected && !standby ? HIGH : LOW));
  }
  if (config::kFaultLedEnabled) {
    digitalWrite(config::kFaultLedPin, faultActive ? HIGH : LOW);
  }
}

}  // namespace vaya
