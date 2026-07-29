#include "vaya/standby_manager.h"

#include "vaya/config.h"

namespace vaya {

void StandbyManager::update(uint32_t nowMs, bool eligible) {
  if (!config::kAutoStandbyEnabled || inStandby_) return;
  if (!eligible) {
    eligibleSinceMs_ = 0;
    return;
  }
  if (eligibleSinceMs_ == 0) {
    eligibleSinceMs_ = nowMs;
    return;
  }
  if (nowMs - eligibleSinceMs_ >= config::kAutoStandbyDelayMs) {
    inStandby_ = true;
  }
}

void StandbyManager::wake() {
  inStandby_ = false;
  eligibleSinceMs_ = 0;
}

bool StandbyManager::inStandby() const { return inStandby_; }

}  // namespace vaya
