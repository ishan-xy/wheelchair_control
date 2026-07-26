#pragma once

#include <Arduino.h>
#include <NimBLEDevice.h>

#include "vaya/config.h"
#include "vaya/passkey_store.h"
#include "vaya/pairing_policy_store.h"

namespace vaya {

struct RxFrame {
  char data[config::kMaxFrameLength + 1]{};
};

class BleTransport {
 public:
  BleTransport(PasskeyStore& passkeyStore, PairingPolicyStore& pairingPolicy);
  bool begin();
  bool popFrame(RxFrame& frame);
  bool send(const char* data, size_t length);
  bool connected() const;
  bool consumeConnectedEvent();
  bool consumeDisconnectedEvent();
  bool consumeRxOverflowEvent();
  void scheduleCurrentBondRemoval(uint32_t nowMs);
  bool changePasskey(uint32_t passkey, uint32_t nowMs);
  bool setAllowNewDevices(bool allowed);
  void wake();
  bool openPairingWindow(uint32_t nowMs);
  bool allowNewDevices() const;
  bool pairingWindowOpen(uint32_t nowMs) const;
  uint8_t trustedDeviceCount() const;
  void update(uint32_t nowMs);
  uint32_t passkey() const;

  void handleIncomingConnection(const NimBLEConnInfo& connection);
  void handleConnect(const NimBLEConnInfo& connection);
  void handleDisconnect();
  void handleWrite(const uint8_t* data, size_t length);

 private:
  bool enqueue(const char* data, size_t length);

  PasskeyStore& passkeyStore_;
  PairingPolicyStore& pairingPolicy_;
  NimBLEServer* server_{nullptr};
  NimBLECharacteristic* tx_{nullptr};
  volatile bool connected_{false};
  volatile bool connectedEvent_{false};
  volatile bool disconnectedEvent_{false};
  volatile bool rxOverflowEvent_{false};
  bool bondRemovalPending_{false};
  bool disconnectAfterBondRemoval_{false};
  bool removeAllBondsPending_{false};
  uint32_t bondRemovalAtMs_{0};
  uint16_t connectionHandle_{BLE_HS_CONN_HANDLE_NONE};
  NimBLEAddress peerIdentityAddress_{};
  bool peerWasTrusted_{false};
  uint32_t pairingWindowUntilMs_{0};
  RxFrame queue_[config::kRxQueueDepth]{};
  volatile uint8_t head_{0};
  volatile uint8_t tail_{0};
  portMUX_TYPE queueMux_ = portMUX_INITIALIZER_UNLOCKED;
};

}  // namespace vaya
