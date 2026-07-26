#include "vaya/ble_transport.h"

#include <cstring>

#include "vaya/logger.h"

namespace vaya {
namespace {

class ServerCallbacks final : public NimBLEServerCallbacks {
 public:
  explicit ServerCallbacks(BleTransport& transport) : transport_(transport) {}

  void onConnect(NimBLEServer*, NimBLEConnInfo& connection) override {
    transport_.handleIncomingConnection(connection);
  }

  void onDisconnect(NimBLEServer*, NimBLEConnInfo&, int) override {
    transport_.handleDisconnect();
    NimBLEDevice::startAdvertising();
  }

  uint32_t onPassKeyDisplay() override { return transport_.passkey(); }

  void onAuthenticationComplete(NimBLEConnInfo& connection) override {
    if (connection.isEncrypted() && connection.isAuthenticated()) {
      transport_.handleConnect(connection);
      return;
    }
    NimBLEServer* server = NimBLEDevice::getServer();
    if (server != nullptr) server->disconnect(connection);
  }

 private:
  BleTransport& transport_;
};

class RxCallbacks final : public NimBLECharacteristicCallbacks {
 public:
  explicit RxCallbacks(BleTransport& transport) : transport_(transport) {}

  void onWrite(NimBLECharacteristic* characteristic,
               NimBLEConnInfo&) override {
    const NimBLEAttValue value = characteristic->getValue();
    if (value.size() > 0) {
      transport_.handleWrite(
          reinterpret_cast<const uint8_t*>(value.data()), value.size());
    }
  }

 private:
  BleTransport& transport_;
};

}  // namespace

BleTransport::BleTransport(PasskeyStore& passkeyStore,
                           PairingPolicyStore& pairingPolicy)
    : passkeyStore_(passkeyStore), pairingPolicy_(pairingPolicy) {}

bool BleTransport::begin() {
  if (passkeyStore_.passkey() < 100000 || passkeyStore_.passkey() > 999999) {
    VAYA_LOG_ERROR("BLE", "no provisioned six-digit BLE passkey is available");
    return false;
  }

  NimBLEDevice::init(config::kDeviceName);
  NimBLEDevice::setMTU(185);
  NimBLEDevice::setSecurityAuth(true, true, true);
  NimBLEDevice::setSecurityIOCap(BLE_HS_IO_DISPLAY_ONLY);
  NimBLEDevice::setSecurityPasskey(passkeyStore_.passkey());

  server_ = NimBLEDevice::createServer();
  server_->setCallbacks(new ServerCallbacks(*this), true);
  NimBLEService* service = server_->createService(config::kServiceUuid);
  tx_ = service->createCharacteristic(
      config::kTxUuid, NIMBLE_PROPERTY::NOTIFY | NIMBLE_PROPERTY::READ |
                           NIMBLE_PROPERTY::READ_ENC);
  NimBLECharacteristic* rx = service->createCharacteristic(
      config::kRxUuid,
      NIMBLE_PROPERTY::WRITE | NIMBLE_PROPERTY::WRITE_NR |
          NIMBLE_PROPERTY::WRITE_ENC);
  rx->setCallbacks(new RxCallbacks(*this));
  if (!server_->start()) {
    VAYA_LOG_ERROR("BLE", "GATT server start failed");
    return false;
  }

  NimBLEAdvertising* advertising = NimBLEDevice::getAdvertising();
  advertising->addServiceUUID(config::kServiceUuid);
  advertising->enableScanResponse(true);
  advertising->setName(config::kDeviceName);
  if (!advertising->start()) {
    VAYA_LOG_ERROR("BLE", "advertising failed");
    return false;
  }
  VAYA_LOG_INFO("BLE", "advertising securely");
  return true;
}

bool BleTransport::popFrame(RxFrame& frame) {
  portENTER_CRITICAL(&queueMux_);
  if (tail_ == head_) {
    portEXIT_CRITICAL(&queueMux_);
    return false;
  }
  frame = queue_[tail_];
  tail_ = (tail_ + 1U) % config::kRxQueueDepth;
  portEXIT_CRITICAL(&queueMux_);
  return true;
}

bool BleTransport::send(const char* data, size_t length) {
  if (!connected_ || tx_ == nullptr || data == nullptr || length == 0) {
    return false;
  }
  tx_->setValue(reinterpret_cast<const uint8_t*>(data), length);
  return tx_->notify();
}

bool BleTransport::connected() const { return connected_; }

bool BleTransport::consumeConnectedEvent() {
  const bool value = connectedEvent_;
  connectedEvent_ = false;
  return value;
}

bool BleTransport::consumeDisconnectedEvent() {
  const bool value = disconnectedEvent_;
  disconnectedEvent_ = false;
  return value;
}

bool BleTransport::consumeRxOverflowEvent() {
  const bool value = rxOverflowEvent_;
  rxOverflowEvent_ = false;
  return value;
}

void BleTransport::scheduleCurrentBondRemoval(uint32_t nowMs) {
  bondRemovalPending_ = true;
  disconnectAfterBondRemoval_ = true;
  removeAllBondsPending_ = false;
  bondRemovalAtMs_ = nowMs + 200;
}

bool BleTransport::changePasskey(uint32_t passkey, uint32_t nowMs) {
  if (!passkeyStore_.update(passkey)) return false;
  NimBLEDevice::setSecurityPasskey(passkeyStore_.passkey());
  bondRemovalPending_ = true;
  disconnectAfterBondRemoval_ = true;
  // A new passkey must invalidate every prior bonding key, including keys
  // belonging to a different caregiver phone.
  removeAllBondsPending_ = true;
  bondRemovalAtMs_ = nowMs + 200;
  return true;
}

bool BleTransport::setAllowNewDevices(bool allowed) {
  if (!pairingPolicy_.setAllowNewDevices(allowed)) return false;
  VAYA_LOG_INFO("BLE", "new caregiver devices %s",
                allowNewDevices() ? "allowed" : "blocked");
  return true;
}

void BleTransport::wake() {
  if (!connected_) NimBLEDevice::startAdvertising();
  VAYA_LOG_INFO("BLE", "wake requested");
}

bool BleTransport::openPairingWindow(uint32_t nowMs) {
  if (!config::kPairingButtonEnabled || !allowNewDevices()) return false;
  pairingWindowUntilMs_ = nowMs + config::kPairingWindowMs;
  VAYA_LOG_INFO("BLE", "physical pairing window opened");
  if (server_ != nullptr && connectionHandle_ != BLE_HS_CONN_HANDLE_NONE) {
    server_->disconnect(connectionHandle_);
  } else {
    NimBLEDevice::startAdvertising();
  }
  return true;
}

bool BleTransport::allowNewDevices() const {
  // A chair with no trusted bond must remain recoverable through first-time
  // setup. Once any bond exists, only an explicit caregiver choice permits a
  // new device (and, in production, a physical pairing window).
  return trustedDeviceCount() == 0 || pairingPolicy_.explicitlyAllowsNewDevices();
}

bool BleTransport::pairingWindowOpen(uint32_t nowMs) const {
  return config::kPairingButtonEnabled && pairingWindowUntilMs_ != 0 &&
         static_cast<int32_t>(pairingWindowUntilMs_ - nowMs) > 0;
}

uint8_t BleTransport::trustedDeviceCount() const {
  const int count = NimBLEDevice::getNumBonds();
  return count <= 0 ? 0 : static_cast<uint8_t>(count > 255 ? 255 : count);
}

uint32_t BleTransport::passkey() const { return passkeyStore_.passkey(); }

void BleTransport::update(uint32_t nowMs) {
  if (pairingWindowUntilMs_ != 0 &&
      static_cast<int32_t>(nowMs - pairingWindowUntilMs_) >= 0) {
    pairingWindowUntilMs_ = 0;
    VAYA_LOG_INFO("BLE", "physical pairing window closed");
  }
  if (!bondRemovalPending_ ||
      static_cast<int32_t>(nowMs - bondRemovalAtMs_) < 0) {
    return;
  }
  bondRemovalPending_ = false;

  const bool removed = removeAllBondsPending_
                           ? NimBLEDevice::deleteAllBonds()
                           : !peerIdentityAddress_.isNull() &&
                                 NimBLEDevice::deleteBond(peerIdentityAddress_);
  removeAllBondsPending_ = false;
  if (removed) {
    VAYA_LOG_INFO("BLE", "caregiver bond removed");
    if (disconnectAfterBondRemoval_ && server_ != nullptr &&
        connectionHandle_ != BLE_HS_CONN_HANDLE_NONE) {
      server_->disconnect(connectionHandle_);
    }
    disconnectAfterBondRemoval_ = false;
    return;
  }

  VAYA_LOG_ERROR("BLE", "caregiver bond removal failed");
  disconnectAfterBondRemoval_ = false;
  if (server_ != nullptr && connectionHandle_ != BLE_HS_CONN_HANDLE_NONE) {
    server_->disconnect(connectionHandle_);
  }
}

void BleTransport::handleConnect(const NimBLEConnInfo& connection) {
  if (!peerWasTrusted_ &&
      (!allowNewDevices() ||
       (config::kPairingButtonEnabled && !pairingWindowOpen(millis())))) {
    peerIdentityAddress_ = connection.getIdAddress();
    connectionHandle_ = connection.getConnHandle();
    VAYA_LOG_WARNING("BLE", "new caregiver device rejected by trust policy");
    NimBLEDevice::deleteBond(peerIdentityAddress_);
    if (server_ != nullptr) server_->disconnect(connection);
    return;
  }
  peerIdentityAddress_ = connection.getIdAddress();
  connectionHandle_ = connection.getConnHandle();
  connected_ = true;
  connectedEvent_ = true;
}

void BleTransport::handleIncomingConnection(const NimBLEConnInfo& connection) {
  peerIdentityAddress_ = connection.getIdAddress();
  peerWasTrusted_ = NimBLEDevice::isBonded(peerIdentityAddress_);
}

void BleTransport::handleDisconnect() {
  const bool wasAuthenticated = connected_;
  connected_ = false;
  connectionHandle_ = BLE_HS_CONN_HANDLE_NONE;
  peerWasTrusted_ = false;
  if (wasAuthenticated) disconnectedEvent_ = true;
  portENTER_CRITICAL(&queueMux_);
  head_ = 0;
  tail_ = 0;
  portEXIT_CRITICAL(&queueMux_);
}

void BleTransport::handleWrite(const uint8_t* data, size_t length) {
  if (data == nullptr || length == 0) return;
  size_t start = 0;
  for (size_t i = 0; i <= length; ++i) {
    if (i != length && data[i] != '\n') continue;
    size_t frameLength = i - start;
    if (frameLength > 0 && data[start + frameLength - 1] == '\r') {
      --frameLength;
    }
    if (frameLength > 0 &&
        !enqueue(reinterpret_cast<const char*>(data + start), frameLength)) {
      rxOverflowEvent_ = true;
    }
    start = i + 1;
  }
}

bool BleTransport::enqueue(const char* data, size_t length) {
  if (length == 0 || length > config::kMaxFrameLength) return false;
  portENTER_CRITICAL(&queueMux_);
  const uint8_t next = (head_ + 1U) % config::kRxQueueDepth;
  if (next == tail_) {
    portEXIT_CRITICAL(&queueMux_);
    return false;
  }
  memcpy(queue_[head_].data, data, length);
  queue_[head_].data[length] = '\0';
  head_ = next;
  portEXIT_CRITICAL(&queueMux_);
  return true;
}

}  // namespace vaya
