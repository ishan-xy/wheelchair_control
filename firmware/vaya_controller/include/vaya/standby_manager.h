#pragma once

#include <Arduino.h>

namespace vaya {

class StandbyManager {
 public:
  void update(uint32_t nowMs, bool eligible);
  void wake();
  bool inStandby() const;

 private:
  bool inStandby_{false};
  uint32_t eligibleSinceMs_{0};
};

}  // namespace vaya
