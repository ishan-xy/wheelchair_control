#include "vaya/pairing_policy_store.h"

namespace vaya {
namespace {

constexpr char kNamespace[] = "vaya_pair";
constexpr char kAllowNewDevicesKey[] = "allow_new";

}  // namespace

bool PairingPolicyStore::begin() {
  if (!preferences_.begin(kNamespace, false)) return false;
  allowNewDevices_ = preferences_.getBool(kAllowNewDevicesKey, false);
  return true;
}

bool PairingPolicyStore::setAllowNewDevices(bool allowed) {
  if (preferences_.putBool(kAllowNewDevicesKey, allowed) != 1) return false;
  allowNewDevices_ = allowed;
  return true;
}

bool PairingPolicyStore::explicitlyAllowsNewDevices() const {
  return allowNewDevices_;
}

}  // namespace vaya
