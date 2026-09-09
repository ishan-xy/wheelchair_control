#pragma once

#include <Arduino.h>

#ifndef VAYA_BLE_PASSKEY
#define VAYA_BLE_PASSKEY 0
#endif

#ifndef VAYA_FEATURE_PAIRING_BUTTON
#define VAYA_FEATURE_PAIRING_BUTTON 0
#endif

#ifndef VAYA_PAIR_WAKE_BUTTON_PIN
#define VAYA_PAIR_WAKE_BUTTON_PIN -1
#endif

#ifndef VAYA_FEATURE_AUTO_STANDBY
#define VAYA_FEATURE_AUTO_STANDBY 0
#endif

#ifndef VAYA_FEATURE_SOS_BUTTON
#define VAYA_FEATURE_SOS_BUTTON 0
#endif

#ifndef VAYA_SOS_BUTTON_PIN
#define VAYA_SOS_BUTTON_PIN -1
#endif

#ifndef VAYA_FEATURE_ALERT_INDICATOR
#define VAYA_FEATURE_ALERT_INDICATOR 0
#endif

#ifndef VAYA_ALERT_INDICATOR_PIN
#define VAYA_ALERT_INDICATOR_PIN -1
#endif

#ifndef VAYA_FEATURE_PAIRING_LED
#define VAYA_FEATURE_PAIRING_LED 0
#endif

#ifndef VAYA_PAIRING_LED_PIN
#define VAYA_PAIRING_LED_PIN -1
#endif

#ifndef VAYA_FEATURE_FAULT_LED
#define VAYA_FEATURE_FAULT_LED 0
#endif

#ifndef VAYA_FAULT_LED_PIN
#define VAYA_FAULT_LED_PIN -1
#endif

#ifndef VAYA_FEATURE_TOPPLE_DETECTION
#define VAYA_FEATURE_TOPPLE_DETECTION 0
#endif

#ifndef VAYA_FEATURE_CHARGER_DETECTION
#define VAYA_FEATURE_CHARGER_DETECTION 0
#endif

#ifndef VAYA_FEATURE_PHYSICAL_JOYSTICK
#define VAYA_FEATURE_PHYSICAL_JOYSTICK 1
#endif

#ifndef VAYA_JOYSTICK_X_PIN
#define VAYA_JOYSTICK_X_PIN 32
#endif

#ifndef VAYA_JOYSTICK_Y_PIN
#define VAYA_JOYSTICK_Y_PIN 33
#endif

#ifndef VAYA_CHARGER_DETECT_PIN
#define VAYA_CHARGER_DETECT_PIN -1
#endif

namespace vaya::config {

inline constexpr char kDeviceName[] = "VAYA One";
inline constexpr char kFirmwareVersion[] = "2.1.0";
// Used only for first-time provisioning. The active passkey is persisted in
// NVS and can be rotated by an authenticated caregiver session.
inline constexpr uint32_t kInitialBlePasskey = VAYA_BLE_PASSKEY;
// Development builds without the physical button can explicitly allow setup
// pairing. Production builds must set this to 1 and open a physical window.
inline constexpr bool kPairingButtonEnabled = VAYA_FEATURE_PAIRING_BUTTON != 0;
inline constexpr int8_t kPairWakeButtonPin = VAYA_PAIR_WAKE_BUTTON_PIN;
inline constexpr bool kPairWakeButtonActiveLow = true;
inline constexpr uint16_t kPairWakeButtonDebounceMs = 35;
inline constexpr uint32_t kPairingButtonHoldMs = 5000;
inline constexpr uint32_t kPairingWindowMs = 120000;
inline constexpr bool kAutoStandbyEnabled = VAYA_FEATURE_AUTO_STANDBY != 0;
inline constexpr uint32_t kAutoStandbyDelayMs = 600000;
inline constexpr bool kSosButtonEnabled = VAYA_FEATURE_SOS_BUTTON != 0;
inline constexpr int8_t kSosButtonPin = VAYA_SOS_BUTTON_PIN;
inline constexpr bool kSosButtonActiveLow = true;
inline constexpr uint16_t kSosButtonDebounceMs = 35;
inline constexpr uint32_t kSosButtonHoldMs = 2000;
inline constexpr uint32_t kSosActiveMs = 120000;
inline constexpr bool kAlertIndicatorEnabled = VAYA_FEATURE_ALERT_INDICATOR != 0;
inline constexpr int8_t kAlertIndicatorPin = VAYA_ALERT_INDICATOR_PIN;
inline constexpr bool kAlertIndicatorActiveHigh = true;
inline constexpr uint16_t kAlertIndicatorPeriodMs = 250;
inline constexpr bool kPairingLedEnabled = VAYA_FEATURE_PAIRING_LED != 0;
inline constexpr int8_t kPairingLedPin = VAYA_PAIRING_LED_PIN;
inline constexpr bool kFaultLedEnabled = VAYA_FEATURE_FAULT_LED != 0;
inline constexpr int8_t kFaultLedPin = VAYA_FAULT_LED_PIN;
inline constexpr uint16_t kPairingLedPeriodMs = 300;
inline constexpr bool kToppleDetectionEnabled = VAYA_FEATURE_TOPPLE_DETECTION != 0;
inline constexpr uint8_t kMpu6050Address = 0x68;
inline constexpr uint8_t kMpu6050SdaPin = 21;
inline constexpr uint8_t kMpu6050SclPin = 22;
inline constexpr uint16_t kImuSamplePeriodMs = 10;
inline constexpr uint16_t kImuCalibrationMs = 1500;
inline constexpr int16_t kToppleThresholdDegrees = 35;
inline constexpr int16_t kToppleResetThresholdDegrees = 10;
inline constexpr uint16_t kToppleTriggerMs = 250;
inline constexpr uint16_t kToppleResetStableMs = 2000;
inline constexpr bool kChargerDetectionEnabled =
    VAYA_FEATURE_CHARGER_DETECTION != 0;
inline constexpr int8_t kChargerDetectPin = VAYA_CHARGER_DETECT_PIN;
inline constexpr bool kChargerDetectActiveLow = true;
inline constexpr uint16_t kChargerDebounceMs = 100;
inline constexpr bool kPhysicalJoystickAvailable =
    VAYA_FEATURE_PHYSICAL_JOYSTICK != 0;
inline constexpr int8_t kJoystickXPin = VAYA_JOYSTICK_X_PIN;
inline constexpr int8_t kJoystickYPin = VAYA_JOYSTICK_Y_PIN;
inline constexpr uint16_t kJoystickSampleMs = 20;
inline constexpr uint16_t kJoystickCenter = 2048;
inline constexpr uint16_t kJoystickDeadZone = 140;
inline constexpr uint16_t kJoystickCalibrationSamples = 50;
// Measured HW-504 ranges in its installed orientation. VRx is travel and VRy
// is steering; the neutral point is calibrated when physical mode is enabled.
inline constexpr uint16_t kJoystickXMinimum = 0;
inline constexpr uint16_t kJoystickXMaximum = 4000;
inline constexpr uint16_t kJoystickYMinimum = 0;
inline constexpr uint16_t kJoystickYMaximum = 4000;
inline constexpr bool kJoystickAxesSwapped = true;
// Higher VRx means front; higher VRy means right.
inline constexpr bool kJoystickXInverted = false;
inline constexpr bool kJoystickYInverted = false;
inline constexpr char kServiceUuid[] = "6E400001-B5A3-F393-E0A9-E50E24DCCA9E";
inline constexpr char kRxUuid[] = "6E400002-B5A3-F393-E0A9-E50E24DCCA9E";
inline constexpr char kTxUuid[] = "6E400003-B5A3-F393-E0A9-E50E24DCCA9E";

// Verified RMCS-2305 wiring: SLEEP is active low; PWM and DIR control each channel.
inline constexpr uint8_t kLeftSleep = 18;
inline constexpr uint8_t kLeftDirection = 25;
inline constexpr uint8_t kLeftPwm = 26;
inline constexpr bool kLeftForwardDirectionHigh = true;
inline constexpr uint8_t kRightSleep = 19;
inline constexpr uint8_t kRightDirection = 14;
inline constexpr uint8_t kRightPwm = 27;
inline constexpr bool kRightForwardDirectionHigh = false;
inline constexpr uint8_t kBatteryAdcPin = 34;

inline constexpr uint32_t kPwmFrequencyHz = 20000;
inline constexpr uint8_t kPwmResolutionBits = 8;
inline constexpr uint8_t kLeftPwmChannel = 0;
inline constexpr uint8_t kRightPwmChannel = 1;
inline constexpr int16_t kIndoorPwmLimit = 125;
inline constexpr int16_t kOutdoorPwmLimit = 255;
inline constexpr int16_t kDefaultPwmLimit = kIndoorPwmLimit;
inline constexpr int16_t kInputDeadZoneMilli = 60;
inline constexpr uint16_t kMotorUpdateMs = 10;
inline constexpr uint16_t kMotorOutputLogPeriodMs = 100;
inline constexpr uint16_t kDirectionDeadTimeMs = 60;
inline constexpr uint16_t kPwmRampPerSecond = 300;

// Mobile BLE scheduling can briefly jitter even while the link is healthy.
// Disconnect events still stop immediately; this bounds stale motion commands.
inline constexpr uint16_t kMotionWatchdogMs = 500;
inline constexpr uint16_t kControlLeaseMs = 2000;
inline constexpr uint16_t kTelemetryPeriodMs = 250;
inline constexpr uint16_t kBatterySamplePeriodMs = 20;
inline constexpr uint8_t kBatterySamplesPerReading = 16;
inline constexpr uint16_t kMaxFrameLength = 180;
inline constexpr uint8_t kRxQueueDepth = 8;

struct BatteryCalibration {
  bool enabled;
  uint16_t adcMax;
  uint16_t adcReferenceMv;
  uint32_t dividerNumerator;
  uint32_t dividerDenominator;
  int16_t offsetMv;
  uint16_t disconnectedBelowRaw;
  uint16_t packEmptyMv;
  uint16_t packFullMv;
};

// Disabled until measured values for the production board and battery pack are
// supplied. Disabled telemetry is reported as SENSOR_NOT_CONFIGURED.
inline constexpr BatteryCalibration kBattery{
    false, 4095, 3300, 1, 1, 0, 8, 0, 0};

static_assert(kMotionWatchdogMs < kControlLeaseMs);
static_assert(kDefaultPwmLimit <= 255);
static_assert(kIndoorPwmLimit <= 255);
static_assert(kOutdoorPwmLimit <= 255);
static_assert(!kPairingButtonEnabled || kPairWakeButtonPin >= 0,
              "Set VAYA_PAIR_WAKE_BUTTON_PIN when enabling the Pair / Wake button.");
static_assert(!kAutoStandbyEnabled || kPairingButtonEnabled,
              "Auto standby requires the physical Pair / Wake button.");
static_assert(!kSosButtonEnabled || kSosButtonPin >= 0,
              "Set VAYA_SOS_BUTTON_PIN when enabling the SOS button.");
static_assert(!kAlertIndicatorEnabled || kAlertIndicatorPin >= 0,
              "Set VAYA_ALERT_INDICATOR_PIN when enabling the alert indicator.");
static_assert(!kPairingLedEnabled || kPairingLedPin >= 0,
              "Set VAYA_PAIRING_LED_PIN when enabling the pairing LED.");
static_assert(!kFaultLedEnabled || kFaultLedPin >= 0,
              "Set VAYA_FAULT_LED_PIN when enabling the fault LED.");
static_assert(!kChargerDetectionEnabled || kChargerDetectPin >= 0,
              "Set VAYA_CHARGER_DETECT_PIN when enabling charger detection.");
static_assert(!kPhysicalJoystickAvailable ||
                  (kJoystickXPin >= 0 && kJoystickYPin >= 0),
              "Set both joystick ADC pins when enabling the physical joystick.");
static_assert(kJoystickXMinimum < kJoystickCenter &&
                  kJoystickCenter < kJoystickXMaximum &&
                  kJoystickYMinimum < kJoystickCenter &&
                  kJoystickCenter < kJoystickYMaximum,
              "Joystick neutral must be inside each configured ADC range.");

}  // namespace vaya::config
