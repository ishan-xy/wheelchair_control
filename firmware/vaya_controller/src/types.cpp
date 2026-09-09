#include "vaya/types.h"

namespace vaya {

const char* toString(DeviceState value) {
  switch (value) {
    case DeviceState::kBooting: return "BOOTING";
    case DeviceState::kDisconnected: return "DISCONNECTED";
    case DeviceState::kConnectedLocked: return "CONNECTED_LOCKED";
    case DeviceState::kConnectedIdle: return "CONNECTED_IDLE";
    case DeviceState::kMoving: return "MOVING";
    case DeviceState::kStopping: return "STOPPING";
    case DeviceState::kFault: return "FAULT";
    case DeviceState::kEmergencyStop: return "EMERGENCY_STOP";
  }
  return "UNKNOWN";
}

const char* toString(SensorState value) {
  switch (value) {
    case SensorState::kNoData: return "NO_DATA";
    case SensorState::kAvailable: return "AVAILABLE";
    case SensorState::kNotConfigured: return "NOT_CONFIGURED";
    case SensorState::kDisconnected: return "DISCONNECTED";
    case SensorState::kInvalid: return "INVALID";
    case SensorState::kFailed: return "FAILED";
  }
  return "INVALID";
}

const char* toString(FaultCode value) {
  switch (value) {
    case FaultCode::kNone: return "NONE";
    case FaultCode::kCommandTimeout: return "COMMAND_TIMEOUT";
    case FaultCode::kInvalidCommand: return "INVALID_COMMAND";
    case FaultCode::kRxOverflow: return "RX_OVERFLOW";
    case FaultCode::kMotorOutput: return "MOTOR_OUTPUT";
    case FaultCode::kBatterySensor: return "BATTERY_SENSOR";
    case FaultCode::kSecurityConfiguration: return "SECURITY_CONFIG";
    case FaultCode::kToppleDetected: return "TOPPLE_DETECTED";
    case FaultCode::kSosRequested: return "SOS_REQUESTED";
    case FaultCode::kImuUnavailable: return "IMU_UNAVAILABLE";
  }
  return "UNKNOWN";
}

const char* toString(ErrorCode value) {
  switch (value) {
    case ErrorCode::kNone: return "OK";
    case ErrorCode::kBadFrame: return "BAD_FRAME";
    case ErrorCode::kBadCrc: return "BAD_CRC";
    case ErrorCode::kBadVersion: return "BAD_VERSION";
    case ErrorCode::kBadSequence: return "BAD_SEQUENCE";
    case ErrorCode::kInvalidValue: return "INVALID_VALUE";
    case ErrorCode::kUnknownCommand: return "UNKNOWN_COMMAND";
    case ErrorCode::kControlRequired: return "CONTROL_REQUIRED";
    case ErrorCode::kLocked: return "LOCKED";
    case ErrorCode::kEmergencyStopActive: return "EMERGENCY_STOP_ACTIVE";
    case ErrorCode::kFaultActive: return "FAULT_ACTIVE";
    case ErrorCode::kQueueFull: return "QUEUE_FULL";
    case ErrorCode::kPasskeyPolicyFailed: return "PASSKEY_POLICY_FAILED";
    case ErrorCode::kSecurityStorageFailed: return "SECURITY_STORAGE_FAILED";
    case ErrorCode::kChargingActive: return "CHARGING_ACTIVE";
    case ErrorCode::kInputSourceActive: return "INPUT_SOURCE_ACTIVE";
  }
  return "UNKNOWN";
}

}  // namespace vaya
