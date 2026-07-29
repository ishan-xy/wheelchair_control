#include "vaya/sos_button.h"

#include "vaya/config.h"

namespace vaya {

void SosButton::begin() {
  enabled_ = config::kSosButtonEnabled;
  if (!enabled_) return;
  pinMode(config::kSosButtonPin,
          config::kSosButtonActiveLow ? INPUT_PULLUP : INPUT_PULLDOWN);
  rawPressed_ = digitalRead(config::kSosButtonPin) ==
                (config::kSosButtonActiveLow ? LOW : HIGH);
  stablePressed_ = rawPressed_;
}

void SosButton::update(uint32_t nowMs) {
  if (!enabled_) return;
  const bool rawPressed = digitalRead(config::kSosButtonPin) ==
                          (config::kSosButtonActiveLow ? LOW : HIGH);
  if (rawPressed != rawPressed_) {
    rawPressed_ = rawPressed;
    rawChangedAtMs_ = nowMs;
  }
  if (rawPressed_ != stablePressed_ &&
      nowMs - rawChangedAtMs_ >= config::kSosButtonDebounceMs) {
    stablePressed_ = rawPressed_;
    if (stablePressed_) {
      pressedAtMs_ = nowMs;
      triggered_ = false;
    }
  }
  if (stablePressed_ && !triggered_ &&
      nowMs - pressedAtMs_ >= config::kSosButtonHoldMs) {
    triggered_ = true;
    sosEvent_ = true;
  }
}

bool SosButton::consumeSosEvent() {
  const bool event = sosEvent_;
  sosEvent_ = false;
  return event;
}

}  // namespace vaya
