#include <Arduino.h>

#include "vaya/alert_indicator.h"
#include "vaya/battery_sensor.h"
#include "vaya/ble_transport.h"
#include "vaya/config.h"
#include "vaya/charger_sensor.h"
#include "vaya/device_controller.h"
#include "vaya/logger.h"
#include "vaya/motor_controller.h"
#include "vaya/passkey_store.h"
#include "vaya/pair_wake_button.h"
#include "vaya/pairing_policy_store.h"
#include "vaya/protocol.h"
#include "vaya/sos_button.h"
#include "vaya/standby_manager.h"

namespace {

vaya::MotorController motors;
vaya::BatterySensor battery;
vaya::PasskeyStore passkeyStore;
vaya::PairingPolicyStore pairingPolicy;
vaya::BleTransport ble(passkeyStore, pairingPolicy);
vaya::DeviceController controller(motors);
vaya::PairWakeButton pairWakeButton;
vaya::ChargerSensor charger;
vaya::SosButton sosButton;
vaya::AlertIndicator alertIndicator;
vaya::StandbyManager standby;

uint32_t telemetrySequence = 1;
uint32_t lastTelemetryMs = 0;
uint32_t sosActiveUntilMs = 0;

bool sosActive(uint32_t nowMs) {
  return sosActiveUntilMs != 0 &&
         static_cast<int32_t>(sosActiveUntilMs - nowMs) > 0;
}

void sendAck(uint32_t sequence, vaya::ErrorCode error) {
  char frame[vaya::config::kMaxFrameLength + 1]{};
  const size_t length = vaya::Protocol::encodeAck(
      frame, sizeof(frame), sequence, error, controller.state());
  if (length > 0) ble.send(frame, length);
}

void processCommands(uint32_t nowMs) {
  vaya::RxFrame rx;
  for (uint8_t processed = 0; processed < 4 && ble.popFrame(rx); ++processed) {
    vaya::Command command;
    const vaya::ErrorCode parseResult =
        vaya::Protocol::parse(rx.data, command);
    if (parseResult != vaya::ErrorCode::kNone) {
      VAYA_LOG_WARNING("PROTOCOL", "rejected frame: %s",
                       vaya::toString(parseResult));
      sendAck(command.sequence, parseResult);
      continue;
    }

    vaya::ErrorCode result = controller.handle(command, nowMs);
    if (result == vaya::ErrorCode::kNone &&
        command.type == vaya::CommandType::kChangePasskey &&
        !ble.changePasskey(static_cast<uint32_t>(command.valueA), nowMs)) {
      result = vaya::ErrorCode::kSecurityStorageFailed;
    }
    if (result == vaya::ErrorCode::kNone &&
        command.type == vaya::CommandType::kSetNewDevicePairing &&
        !ble.setAllowNewDevices(command.valueA != 0)) {
      result = vaya::ErrorCode::kSecurityStorageFailed;
    }
    sendAck(command.sequence, result);
    if (result == vaya::ErrorCode::kNone &&
        command.type == vaya::CommandType::kForgetBond) {
      ble.scheduleCurrentBondRemoval(nowMs);
    }
    if (result != vaya::ErrorCode::kNone) {
      VAYA_LOG_WARNING("COMMAND", "seq=%lu rejected: %s",
                       static_cast<unsigned long>(command.sequence),
                       vaya::toString(result));
    }
  }
}

void sendTelemetry(uint32_t nowMs) {
  if (!ble.connected() ||
      nowMs - lastTelemetryMs < vaya::config::kTelemetryPeriodMs) {
    return;
  }
  lastTelemetryMs = nowMs;
  char frame[vaya::config::kMaxFrameLength + 1]{};
  const size_t length = vaya::Protocol::encodeTelemetry(
      frame, sizeof(frame), telemetrySequence++, nowMs, controller.state(),
      battery.reading(), motors.snapshot(), controller.fault(),
      controller.locked(), controller.emergencyStopActive(),
      ble.allowNewDevices(), ble.trustedDeviceCount(),
      ble.pairingWindowOpen(nowMs), charger.available(), charger.connected(),
      sosActive(nowMs));
  if (length > 0) ble.send(frame, length);
}

}  // namespace

void setup() {
  vaya::Logger::begin(115200);
  vaya::Logger::setLevel(vaya::LogLevel::kInfo);
  VAYA_LOG_INFO("BOOT", "VAYA controller %s starting",
                vaya::config::kFirmwareVersion);

  motors.begin();
  controller.begin();
  pairWakeButton.begin();
  charger.begin();
  sosButton.begin();
  alertIndicator.begin();
  battery.begin();
  if (!passkeyStore.begin(vaya::config::kInitialBlePasskey) ||
      !pairingPolicy.begin() || !ble.begin()) {
    controller.setStartupFault(vaya::FaultCode::kSecurityConfiguration);
  }
}

void loop() {
  const uint32_t nowMs = millis();

  charger.update(nowMs);
  controller.setCharging(charger.connected());
  pairWakeButton.update(nowMs);
  if (pairWakeButton.consumeWakeEvent()) {
    standby.wake();
    ble.wake();
  }
  if (pairWakeButton.consumePairingRequestEvent()) {
    standby.wake();
    if (controller.canOpenPairingWindow() && ble.openPairingWindow(nowMs)) {
      VAYA_LOG_INFO("BLE", "pairing button accepted");
    } else {
      VAYA_LOG_WARNING("BLE", "pairing button rejected; chair must be locked, stopped, and allow new devices");
    }
  }
  sosButton.update(nowMs);
  if (sosButton.consumeSosEvent()) {
    sosActiveUntilMs = nowMs + vaya::config::kSosActiveMs;
    standby.wake();
    ble.wake();
    VAYA_LOG_WARNING("SOS", "physical SOS requested");
  }
  alertIndicator.setSosActive(sosActive(nowMs));

  if (ble.consumeDisconnectedEvent()) {
    controller.onDisconnected();
    VAYA_LOG_WARNING("BLE", "disconnected; motors stopped");
  }
  if (ble.consumeConnectedEvent()) {
    controller.onConnected(nowMs);
    VAYA_LOG_INFO("BLE", "caregiver connected");
  }
  if (ble.consumeRxOverflowEvent()) {
    controller.raiseFault(vaya::FaultCode::kRxOverflow);
    VAYA_LOG_ERROR("SAFETY", "RX queue overflow; motors stopped");
  }

  // Safety is evaluated before lower-priority parsing and telemetry work.
  controller.update(nowMs);
  processCommands(nowMs);
  motors.update(nowMs);
  controller.update(nowMs);
  battery.update(nowMs);
  standby.update(nowMs, controller.canEnterStandby() && !charger.connected());
  if (standby.inStandby()) ble.enterStandby();
  alertIndicator.update(nowMs);
  sendTelemetry(nowMs);
  ble.update(nowMs);
  vaya::Logger::flush();
  taskYIELD();
}
#include "vaya/charger_sensor.h"
