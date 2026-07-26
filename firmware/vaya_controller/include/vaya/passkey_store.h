#pragma once

#include <Arduino.h>
#include <Preferences.h>

namespace vaya {

class PasskeyStore {
 public:
  bool begin(uint32_t initialPasskey);
  bool update(uint32_t passkey);
  uint32_t passkey() const;

 private:
  static bool valid(uint32_t passkey);

  Preferences preferences_;
  uint32_t passkey_{0};
};

}  // namespace vaya
