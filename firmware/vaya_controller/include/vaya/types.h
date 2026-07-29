#pragma once

#include <Arduino.h>

namespace vaya {

enum class DeviceState : uint8_t {
  kBooting,
  kDisconnected,
  kConnectedLocked,
  kConnectedIdle,
  kMoving,
  kStopping,
  kFault,
  kEmergencyStop,
};

enum class CommandType : uint8_t {
  kInvalid,
  kHello,
  kAcquireControl,
  kMove,
  kStop,
  kEmergencyStop,
  kResetEmergencyStop,
  kSetMode,
  kSetLimit,
  kSetLock,
  kForgetBond,
  kChangePasskey,
  kSetNewDevicePairing,
  kPing,
};

enum class SensorState : uint8_t {
  kNoData,
  kAvailable,
  kNotConfigured,
  kDisconnected,
  kInvalid,
  kFailed,
};

enum class FaultCode : uint8_t {
  kNone,
  kCommandTimeout,
  kInvalidCommand,
  kRxOverflow,
  kMotorOutput,
  kBatterySensor,
  kPhysicalEmergencyStop,
  kSecurityConfiguration,
};

enum class ErrorCode : uint8_t {
  kNone,
  kBadFrame,
  kBadCrc,
  kBadVersion,
  kBadSequence,
  kInvalidValue,
  kUnknownCommand,
  kControlRequired,
  kLocked,
  kEmergencyStopActive,
  kPhysicalEstopRequired,
  kFaultActive,
  kQueueFull,
  kPasskeyPolicyFailed,
  kSecurityStorageFailed,
  kChargingActive,
};

struct Command {
  CommandType type{CommandType::kInvalid};
  uint32_t sequence{0};
  int32_t valueA{0};
  int32_t valueB{0};
};

struct BatteryReading {
  SensorState state{SensorState::kNoData};
  uint16_t raw{0};
  uint32_t voltageMv{0};
  int16_t percentage{-1};
  uint32_t updatedAtMs{0};
};

struct MotorSnapshot {
  int16_t leftPwm{0};
  int16_t rightPwm{0};
  bool motionRequested{false};
  bool atRest{true};
};

const char* toString(DeviceState state);
const char* toString(SensorState state);
const char* toString(FaultCode fault);
const char* toString(ErrorCode error);

}  // namespace vaya
