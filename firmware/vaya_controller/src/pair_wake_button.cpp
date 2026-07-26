#include "vaya/pair_wake_button.h"

#include "vaya/config.h"

namespace vaya {

void PairWakeButton::begin() {
  enabled_ = config::kPairingButtonEnabled;
  if (!enabled_) return;
  pinMode(config::kPairWakeButtonPin,
          config::kPairWakeButtonActiveLow ? INPUT_PULLUP : INPUT_PULLDOWN);
  rawPressed_ = digitalRead(config::kPairWakeButtonPin) ==
                (config::kPairWakeButtonActiveLow ? LOW : HIGH);
  stablePressed_ = rawPressed_;
}

void PairWakeButton::update(uint32_t nowMs) {
  if (!enabled_) return;

  const bool rawPressed = digitalRead(config::kPairWakeButtonPin) ==
                          (config::kPairWakeButtonActiveLow ? LOW : HIGH);
  if (rawPressed != rawPressed_) {
    rawPressed_ = rawPressed;
    rawChangedAtMs_ = nowMs;
  }

  if (rawPressed_ != stablePressed_ &&
      nowMs - rawChangedAtMs_ >= config::kPairWakeButtonDebounceMs) {
    stablePressed_ = rawPressed_;
    if (stablePressed_) {
      pressedAtMs_ = nowMs;
      pairingRequested_ = false;
    } else if (!pairingRequested_) {
      wakeEvent_ = true;
    }
  }

  if (stablePressed_ && !pairingRequested_ &&
      nowMs - pressedAtMs_ >= config::kPairingButtonHoldMs) {
    pairingRequested_ = true;
    pairingRequestEvent_ = true;
  }
}

bool PairWakeButton::consumeWakeEvent() {
  const bool event = wakeEvent_;
  wakeEvent_ = false;
  return event;
}

bool PairWakeButton::consumePairingRequestEvent() {
  const bool event = pairingRequestEvent_;
  pairingRequestEvent_ = false;
  return event;
}

}  // namespace vaya
