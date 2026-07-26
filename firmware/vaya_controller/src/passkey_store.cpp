#include "vaya/passkey_store.h"

#include "vaya/logger.h"

namespace vaya {
namespace {

constexpr char kNamespace[] = "vaya_security";
constexpr char kPasskeyKey[] = "ble_passkey";

}  // namespace

bool PasskeyStore::begin(uint32_t initialPasskey) {
  if (!valid(initialPasskey)) {
    VAYA_LOG_ERROR("SECURITY", "initial passkey is not a valid six-digit key");
    return false;
  }
  if (!preferences_.begin(kNamespace, false)) {
    VAYA_LOG_ERROR("SECURITY", "NVS security store unavailable");
    return false;
  }

  const uint32_t stored = preferences_.getUInt(kPasskeyKey, 0);
  if (valid(stored)) {
    passkey_ = stored;
    return true;
  }
  return update(initialPasskey);
}

bool PasskeyStore::update(uint32_t passkey) {
  if (!valid(passkey)) return false;
  if (preferences_.putUInt(kPasskeyKey, passkey) != sizeof(passkey)) {
    VAYA_LOG_ERROR("SECURITY", "could not persist replacement passkey");
    return false;
  }
  passkey_ = passkey;
  VAYA_LOG_INFO("SECURITY", "BLE passkey updated");
  return true;
}

uint32_t PasskeyStore::passkey() const { return passkey_; }

bool PasskeyStore::valid(uint32_t passkey) {
  return passkey >= 100000 && passkey <= 999999;
}

}  // namespace vaya
