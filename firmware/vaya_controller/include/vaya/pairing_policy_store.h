#pragma once

#include <Arduino.h>
#include <Preferences.h>

namespace vaya {

class PairingPolicyStore {
 public:
  bool begin();
  bool setAllowNewDevices(bool allowed);
  bool explicitlyAllowsNewDevices() const;

 private:
  Preferences preferences_;
  bool allowNewDevices_{false};
};

}  // namespace vaya
