#include "vaya/reset_button.h"

#include "vaya/config.h"

namespace vaya {

void ResetButton::begin() {
  enabled_ = config::kResetButtonEnabled;
  if (!enabled_) return;
  pinMode(config::kResetButtonPin,
          config::kResetButtonActiveLow ? INPUT_PULLUP : INPUT_PULLDOWN);
  rawPressed_ = digitalRead(config::kResetButtonPin) ==
                (config::kResetButtonActiveLow ? LOW : HIGH);
  stablePressed_ = rawPressed_;
}

void ResetButton::update(uint32_t nowMs) {
  if (!enabled_) return;
  const bool rawPressed = digitalRead(config::kResetButtonPin) ==
                          (config::kResetButtonActiveLow ? LOW : HIGH);
  if (rawPressed != rawPressed_) {
    rawPressed_ = rawPressed;
    rawChangedAtMs_ = nowMs;
  }
  if (rawPressed_ != stablePressed_ &&
      nowMs - rawChangedAtMs_ >= config::kResetButtonDebounceMs) {
    stablePressed_ = rawPressed_;
    if (stablePressed_) {
      pressedAtMs_ = nowMs;
      triggered_ = false;
    }
  }
  if (stablePressed_ && !triggered_ &&
      nowMs - pressedAtMs_ >= config::kResetButtonHoldMs) {
    triggered_ = true;
    resetEvent_ = true;
  }
}

bool ResetButton::consumeResetEvent() {
  const bool event = resetEvent_;
  resetEvent_ = false;
  return event;
}

}  // namespace vaya
