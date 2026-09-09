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
#include "vaya/status_indicators.h"
#include "vaya/topple_detector.h"

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
vaya::StatusIndicators statusIndicators;
vaya::ToppleDetector toppleDetector;

uint32_t telemetrySequence = 1;
uint32_t lastTelemetryMs = 0;
uint32_t lastJoystickMs = 0;
uint32_t joystickCalibrationX = 0;
uint32_t joystickCalibrationY = 0;
uint16_t joystickCalibrationCount = 0;
bool joystickWasEnabled = false;
int32_t joystickCenterX = vaya::config::kJoystickCenter;
int32_t joystickCenterY = vaya::config::kJoystickCenter;
bool emergencyAlarmActive() {
  const vaya::FaultCode fault = controller.fault();
  return fault == vaya::FaultCode::kToppleDetected ||
         fault == vaya::FaultCode::kSosRequested;
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

    vaya::ErrorCode result = command.type == vaya::CommandType::kResetEmergencyStop
                                 ? controller.resetSafetyEvent(command, toppleDetector.canReset())
                                 : controller.handle(command, nowMs);
    if (result == vaya::ErrorCode::kNone &&
        command.type == vaya::CommandType::kResetEmergencyStop) {
      toppleDetector.acknowledgeReset();
    }
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
      emergencyAlarmActive());
  if (length > 0) ble.send(frame, length);
}

int16_t readJoystickAxis(int8_t pin, int32_t center, int32_t minimum,
                         int32_t maximum, bool invert) {
  const int32_t delta = analogRead(pin) - center;
  if (abs(delta) <= vaya::config::kJoystickDeadZone) return 0;
  const int32_t span = delta > 0 ? maximum - center : center - minimum;
  const int32_t usableSpan = span - vaya::config::kJoystickDeadZone;
  const int32_t magnitude = abs(delta) - vaya::config::kJoystickDeadZone;
  int32_t output = constrain((magnitude * 1000) / usableSpan, 0, 1000);
  if (delta < 0) output = -output;
  return static_cast<int16_t>(invert ? -output : output);
}

void updatePhysicalJoystick(uint32_t nowMs) {
  if (!vaya::config::kPhysicalJoystickAvailable) return;
  if (!controller.physicalJoystickEnabled()) {
    joystickWasEnabled = false;
    joystickCalibrationCount = 0;
    joystickCalibrationX = 0;
    joystickCalibrationY = 0;
    return;
  }
  if (!joystickWasEnabled) {
    joystickWasEnabled = true;
    joystickCalibrationCount = 0;
    joystickCalibrationX = 0;
    joystickCalibrationY = 0;
  }
  if (joystickCalibrationCount < vaya::config::kJoystickCalibrationSamples) {
    joystickCalibrationX += analogRead(vaya::config::kJoystickXPin);
    joystickCalibrationY += analogRead(vaya::config::kJoystickYPin);
    ++joystickCalibrationCount;
    if (joystickCalibrationCount == vaya::config::kJoystickCalibrationSamples) {
      joystickCenterX = static_cast<int32_t>(
          joystickCalibrationX / joystickCalibrationCount);
      joystickCenterY = static_cast<int32_t>(
          joystickCalibrationY / joystickCalibrationCount);
      VAYA_LOG_INFO("JOYSTICK", "neutral calibrated X=%ld Y=%ld",
                    static_cast<long>(joystickCenterX),
                    static_cast<long>(joystickCenterY));
    }
    return;
  }
  if (nowMs - lastJoystickMs < vaya::config::kJoystickSampleMs) return;
  lastJoystickMs = nowMs;
  const int16_t axisX = readJoystickAxis(
      vaya::config::kJoystickXPin, joystickCenterX,
      vaya::config::kJoystickXMinimum, vaya::config::kJoystickXMaximum,
      vaya::config::kJoystickXInverted);
  const int16_t axisY = readJoystickAxis(
      vaya::config::kJoystickYPin, joystickCenterY,
      vaya::config::kJoystickYMinimum, vaya::config::kJoystickYMaximum,
      vaya::config::kJoystickYInverted);
  const int16_t appX = vaya::config::kJoystickAxesSwapped ? axisY : axisX;
  const int16_t appY = vaya::config::kJoystickAxesSwapped ? axisX : axisY;
  controller.handlePhysicalMove(appX, appY, nowMs);
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
  statusIndicators.begin();
  toppleDetector.begin();
  battery.begin();
  if (vaya::config::kPhysicalJoystickAvailable) {
    pinMode(vaya::config::kJoystickXPin, INPUT);
    pinMode(vaya::config::kJoystickYPin, INPUT);
  }
  if (!passkeyStore.begin(vaya::config::kInitialBlePasskey) ||
      !pairingPolicy.begin() || !ble.begin()) {
    controller.setStartupFault(vaya::FaultCode::kSecurityConfiguration);
  }
  controller.setSafetyStartupReady(toppleDetector.ready());
}

void loop() {
  const uint32_t nowMs = millis();

  charger.update(nowMs);
  controller.setCharging(charger.connected());
  toppleDetector.update(nowMs);
  controller.setSafetyStartupReady(toppleDetector.ready());
  if (toppleDetector.state() == vaya::SensorState::kFailed) {
    controller.setStartupFault(vaya::FaultCode::kImuUnavailable);
  }
  if (toppleDetector.consumeToppleEvent()) {
    controller.latchSafetyEvent(vaya::FaultCode::kToppleDetected);
    VAYA_LOG_WARNING("SAFETY", "topple detected; chair locked");
  }
  pairWakeButton.update(nowMs);
  if (pairWakeButton.consumeWakeEvent()) {
    standby.wake();
    ble.wake();
  }
  if (pairWakeButton.consumePairingRequestEvent()) {
    standby.wake();
    if (controller.canOpenPairingWindow() && ble.openPairingWindow(nowMs)) {
      alertIndicator.requestPairingFeedback(nowMs);
      VAYA_LOG_INFO("BLE", "pairing button accepted");
    } else {
      VAYA_LOG_WARNING("BLE", "pairing button rejected; chair must be locked, stopped, and allow new devices");
    }
  }
  sosButton.update(nowMs);
  if (sosButton.consumeSosEvent()) {
    controller.latchSafetyEvent(vaya::FaultCode::kSosRequested);
    standby.wake();
    ble.wake();
    VAYA_LOG_WARNING("SOS", "physical SOS requested; chair locked");
  }
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
  updatePhysicalJoystick(nowMs);
  motors.update(nowMs);
  controller.update(nowMs);
  battery.update(nowMs);
  standby.update(nowMs, controller.canEnterStandby() && !charger.connected());
  if (standby.inStandby()) ble.enterStandby();
  alertIndicator.setAlarmActive(emergencyAlarmActive());
  alertIndicator.update(nowMs);
  statusIndicators.update(nowMs, ble.pairingWindowOpen(nowMs), ble.connected(),
                          standby.inStandby(),
                          controller.fault() != vaya::FaultCode::kNone ||
                              controller.emergencyStopActive());
  sendTelemetry(nowMs);
  ble.update(nowMs);
  vaya::Logger::flush();
  taskYIELD();
}
#include "vaya/charger_sensor.h"
