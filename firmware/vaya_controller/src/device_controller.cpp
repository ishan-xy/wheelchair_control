#include "vaya/device_controller.h"

#include "vaya/config.h"
#include "vaya/logger.h"

namespace vaya {

DeviceController::DeviceController(MotorController& motors) : motors_(motors) {}

void DeviceController::begin() {
  motors_.emergencyStop();
  transition(DeviceState::kDisconnected);
}

void DeviceController::onConnected(uint32_t) {
  connected_ = true;
  locked_ = true;
  protocolNegotiated_ = false;
  leaseExpiresMs_ = 0;
  lastMoveCommandMs_ = 0;
  lastSequence_ = 0;
  lastCommandType_ = CommandType::kInvalid;
  physicalJoystickEnabled_ = false;
  motors_.emergencyStop();
  transition(emergencyStop_ ? DeviceState::kEmergencyStop
                            : fault_ != FaultCode::kNone
                                  ? DeviceState::kFault
                                  : DeviceState::kConnectedLocked);
}

void DeviceController::onDisconnected() {
  connected_ = false;
  locked_ = true;
  protocolNegotiated_ = false;
  leaseExpiresMs_ = 0;
  lastMoveCommandMs_ = 0;
  physicalJoystickEnabled_ = false;
  motors_.emergencyStop();
  transition(emergencyStop_ ? DeviceState::kEmergencyStop
                            : DeviceState::kDisconnected);
}

void DeviceController::setCharging(bool charging) {
  if (charging_ == charging) return;
  charging_ = charging;
  if (!charging_) {
    VAYA_LOG_INFO("CHARGER", "drive remains locked after charging ended");
    return;
  }
  locked_ = true;
  leaseExpiresMs_ = 0;
  lastMoveCommandMs_ = 0;
  motors_.emergencyStop();
  transition(connected_ ? DeviceState::kConnectedLocked
                        : DeviceState::kDisconnected);
  VAYA_LOG_WARNING("CHARGER", "charging detected; motors stopped and locked");
}

ErrorCode DeviceController::handle(const Command& command, uint32_t nowMs) {
  if (command.sequence < lastSequence_ ||
      (command.sequence == lastSequence_ &&
       !isDuplicateIdempotent(command))) {
    return ErrorCode::kBadSequence;
  }
  if (command.sequence > lastSequence_) {
    lastSequence_ = command.sequence;
    lastCommandType_ = command.type;
  }

  if (command.type == CommandType::kEmergencyStop) {
    latchEmergencyStop(FaultCode::kNone);
    return ErrorCode::kNone;
  }
  if (command.type == CommandType::kStop) {
    motors_.requestStop("APP");
    lastMoveCommandMs_ = 0;
    if (!emergencyStop_) transition(DeviceState::kStopping);
    return ErrorCode::kNone;
  }
  if (emergencyStop_ &&
      command.type != CommandType::kResetEmergencyStop &&
      command.type != CommandType::kHello &&
      command.type != CommandType::kPing) {
    return ErrorCode::kEmergencyStopActive;
  }

  switch (command.type) {
    case CommandType::kHello:
      protocolNegotiated_ = true;
      return ErrorCode::kNone;
    case CommandType::kAcquireControl:
      if (!protocolNegotiated_) return ErrorCode::kBadVersion;
      if (fault_ != FaultCode::kNone &&
          fault_ != FaultCode::kCommandTimeout) {
        return ErrorCode::kFaultActive;
      }
      fault_ = FaultCode::kNone;
      locked_ = true;
      leaseExpiresMs_ = nowMs + config::kControlLeaseMs;
      transition(DeviceState::kConnectedLocked);
      return ErrorCode::kNone;
    case CommandType::kSetLock:
      if (!controlLeaseValid(nowMs)) return ErrorCode::kControlRequired;
      // Locking is a security state change, not a substitute for a stop.
      // Both lock and unlock require zero output and no pending drive target.
      // This also rejects a MOVE followed immediately by LOCK in one BLE batch.
      if (const MotorSnapshot motors = motors_.snapshot(); !motors.atRest ||
          motors.motionRequested) {
        return ErrorCode::kInvalidValue;
      }
      if (command.valueA == 0) {
        if (charging_) return ErrorCode::kChargingActive;
        locked_ = false;
        transition(DeviceState::kConnectedIdle);
      } else {
        locked_ = true;
        transition(DeviceState::kConnectedLocked);
      }
      leaseExpiresMs_ = nowMs + config::kControlLeaseMs;
      return ErrorCode::kNone;
    case CommandType::kMove:
      if (physicalJoystickEnabled_) return ErrorCode::kInputSourceActive;
      if (!safetyStartupReady_) return ErrorCode::kFaultActive;
      if (!controlLeaseValid(nowMs)) return ErrorCode::kControlRequired;
      if (charging_) return ErrorCode::kChargingActive;
      if (locked_) return ErrorCode::kLocked;
      if (fault_ != FaultCode::kNone) return ErrorCode::kFaultActive;
      motors_.setDriveRequest(static_cast<int16_t>(command.valueA),
                              static_cast<int16_t>(command.valueB), "APP");
      lastMoveCommandMs_ = nowMs;
      leaseExpiresMs_ = nowMs + config::kControlLeaseMs;
      return ErrorCode::kNone;
    case CommandType::kSetInputSource:
      if (!controlLeaseValid(nowMs)) return ErrorCode::kControlRequired;
      if (command.valueA != 0 && !config::kPhysicalJoystickAvailable) {
        return ErrorCode::kInvalidValue;
      }
      physicalJoystickEnabled_ = command.valueA != 0;
      motors_.emergencyStop();
      lastMoveCommandMs_ = 0;
      leaseExpiresMs_ = nowMs + config::kControlLeaseMs;
      transition(locked_ ? DeviceState::kConnectedLocked
                         : DeviceState::kConnectedIdle);
      return ErrorCode::kNone;
    case CommandType::kSetMode:
      if (!controlLeaseValid(nowMs)) return ErrorCode::kControlRequired;
      motors_.setPwmLimit(command.valueA == 0 ? config::kIndoorPwmLimit
                                             : config::kOutdoorPwmLimit);
      leaseExpiresMs_ = nowMs + config::kControlLeaseMs;
      return ErrorCode::kNone;
    case CommandType::kSetLimit:
      if (!controlLeaseValid(nowMs)) return ErrorCode::kControlRequired;
      motors_.setPwmLimit(static_cast<int16_t>(command.valueA));
      leaseExpiresMs_ = nowMs + config::kControlLeaseMs;
      return ErrorCode::kNone;
    case CommandType::kForgetBond:
      if (!controlLeaseValid(nowMs)) return ErrorCode::kControlRequired;
      if (!motors_.snapshot().atRest) return ErrorCode::kInvalidValue;
      motors_.emergencyStop();
      locked_ = true;
      leaseExpiresMs_ = 0;
      lastMoveCommandMs_ = 0;
      transition(DeviceState::kConnectedLocked);
      return ErrorCode::kNone;
    case CommandType::kChangePasskey:
      if (!controlLeaseValid(nowMs)) return ErrorCode::kControlRequired;
      if (!motors_.snapshot().atRest) return ErrorCode::kInvalidValue;
      locked_ = true;
      motors_.emergencyStop();
      leaseExpiresMs_ = 0;
      lastMoveCommandMs_ = 0;
      transition(DeviceState::kConnectedLocked);
      return ErrorCode::kNone;
    case CommandType::kSetNewDevicePairing:
      if (!controlLeaseValid(nowMs)) return ErrorCode::kControlRequired;
      if (!motors_.snapshot().atRest || motors_.snapshot().motionRequested) {
        return ErrorCode::kInvalidValue;
      }
      locked_ = true;
      transition(DeviceState::kConnectedLocked);
      leaseExpiresMs_ = nowMs + config::kControlLeaseMs;
      return ErrorCode::kNone;
    case CommandType::kResetEmergencyStop:
      return ErrorCode::kInvalidValue;
    case CommandType::kPing:
      if (controlLeaseValid(nowMs)) {
        leaseExpiresMs_ = nowMs + config::kControlLeaseMs;
      }
      return ErrorCode::kNone;
    default:
      return ErrorCode::kUnknownCommand;
  }
}

ErrorCode DeviceController::handlePhysicalMove(int16_t xMilli, int16_t yMilli,
                                               uint32_t nowMs) {
  if (!physicalJoystickEnabled_) return ErrorCode::kInputSourceActive;
  if (!safetyStartupReady_) return ErrorCode::kFaultActive;
  if (!controlLeaseValid(nowMs)) return ErrorCode::kControlRequired;
  if (charging_) return ErrorCode::kChargingActive;
  if (locked_) return ErrorCode::kLocked;
  if (emergencyStop_) return ErrorCode::kEmergencyStopActive;
  if (fault_ != FaultCode::kNone) return ErrorCode::kFaultActive;
  motors_.setDriveRequest(xMilli, yMilli, "PHYSICAL");
  lastMoveCommandMs_ = nowMs;
  leaseExpiresMs_ = nowMs + config::kControlLeaseMs;
  return ErrorCode::kNone;
}

void DeviceController::update(uint32_t nowMs) {
  if (!connected_) {
    motors_.emergencyStop();
    return;
  }
  if (!emergencyStop_ && lastMoveCommandMs_ != 0 &&
      nowMs - lastMoveCommandMs_ > config::kMotionWatchdogMs) {
    const uint32_t commandAgeMs = nowMs - lastMoveCommandMs_;
    motors_.emergencyStop();
    lastMoveCommandMs_ = 0;
    locked_ = true;
    fault_ = FaultCode::kCommandTimeout;
    transition(DeviceState::kConnectedLocked);
    VAYA_LOG_WARNING("SAFETY",
                     "motion watchdog stopped motors; command age=%lu ms",
                     static_cast<unsigned long>(commandAgeMs));
  }
  if (!emergencyStop_ && leaseExpiresMs_ != 0 &&
      static_cast<int32_t>(nowMs - leaseExpiresMs_) >= 0) {
    motors_.emergencyStop();
    leaseExpiresMs_ = 0;
    locked_ = true;
    transition(DeviceState::kConnectedLocked);
    VAYA_LOG_WARNING("SAFETY", "control lease expired");
  }

  const MotorSnapshot motors = motors_.snapshot();
  if (!emergencyStop_ && fault_ == FaultCode::kNone) {
    if (motors.motionRequested) {
      transition(DeviceState::kMoving);
    } else if (!motors.atRest) {
      transition(DeviceState::kStopping);
    } else if (locked_) {
      transition(DeviceState::kConnectedLocked);
    } else {
      transition(DeviceState::kConnectedIdle);
    }
  }
}

void DeviceController::setStartupFault(FaultCode fault) {
  raiseFault(fault);
}

void DeviceController::setSafetyStartupReady(bool ready) {
  safetyStartupReady_ = ready;
}

void DeviceController::raiseFault(FaultCode fault) {
  fault_ = fault;
  locked_ = true;
  motors_.emergencyStop();
  transition(DeviceState::kFault);
}

void DeviceController::latchSafetyEvent(FaultCode fault) {
  latchEmergencyStop(fault);
}

ErrorCode DeviceController::resetSafetyEvent(const Command& command,
                                             bool toppleResetSafe) {
  if (command.sequence < lastSequence_) return ErrorCode::kBadSequence;
  if (command.sequence == lastSequence_) {
    return lastCommandType_ == CommandType::kResetEmergencyStop &&
                   !emergencyStop_
               ? ErrorCode::kNone
               : ErrorCode::kBadSequence;
  }
  if (!connected_ || !protocolNegotiated_) return ErrorCode::kControlRequired;
  if (!emergencyStop_ || !motors_.snapshot().atRest) {
    return ErrorCode::kEmergencyStopActive;
  }
  if (fault_ == FaultCode::kToppleDetected && !toppleResetSafe) {
    return ErrorCode::kEmergencyStopActive;
  }
  if (fault_ != FaultCode::kToppleDetected && fault_ != FaultCode::kSosRequested) {
    if (fault_ != FaultCode::kNone) return ErrorCode::kFaultActive;
  }
  emergencyStop_ = false;
  fault_ = FaultCode::kNone;
  locked_ = true;
  leaseExpiresMs_ = 0;
  lastMoveCommandMs_ = 0;
  motors_.emergencyStop();
  transition(connected_ ? DeviceState::kConnectedLocked
                        : DeviceState::kDisconnected);
  lastSequence_ = command.sequence;
  lastCommandType_ = command.type;
  VAYA_LOG_INFO("SAFETY", "app reset accepted; chair remains locked");
  return ErrorCode::kNone;
}

DeviceState DeviceController::state() const { return state_; }
FaultCode DeviceController::fault() const { return fault_; }
bool DeviceController::locked() const { return locked_; }
bool DeviceController::emergencyStopActive() const { return emergencyStop_; }

bool DeviceController::canChangePairingPolicy(uint32_t nowMs) const {
  const MotorSnapshot motors = motors_.snapshot();
  return controlLeaseValid(nowMs) && !emergencyStop_ &&
         fault_ == FaultCode::kNone && motors.atRest &&
         !motors.motionRequested;
}

bool DeviceController::canOpenPairingWindow() const {
  const MotorSnapshot motors = motors_.snapshot();
  return locked_ && !emergencyStop_ && fault_ == FaultCode::kNone &&
         motors.atRest && !motors.motionRequested;
}

bool DeviceController::canEnterStandby() const {
  const MotorSnapshot motors = motors_.snapshot();
  return !connected_ && locked_ && !emergencyStop_ &&
         fault_ == FaultCode::kNone && motors.atRest &&
         !motors.motionRequested;
}

bool DeviceController::charging() const { return charging_; }
bool DeviceController::physicalJoystickEnabled() const {
  return physicalJoystickEnabled_;
}

bool DeviceController::controlLeaseValid(uint32_t nowMs) const {
  return connected_ && protocolNegotiated_ && leaseExpiresMs_ != 0 &&
         static_cast<int32_t>(nowMs - leaseExpiresMs_) < 0;
}

bool DeviceController::isDuplicateIdempotent(const Command& command) const {
  if (command.type != lastCommandType_) return false;
  return command.type == CommandType::kHello ||
         command.type == CommandType::kAcquireControl ||
         command.type == CommandType::kStop ||
         command.type == CommandType::kEmergencyStop ||
         command.type == CommandType::kPing;
}

void DeviceController::transition(DeviceState next) {
  if (state_ == next) return;
  VAYA_LOG_INFO("STATE", "%s -> %s", toString(state_), toString(next));
  state_ = next;
}

void DeviceController::latchEmergencyStop(FaultCode cause) {
  emergencyStop_ = true;
  locked_ = true;
  leaseExpiresMs_ = 0;
  lastMoveCommandMs_ = 0;
  if (cause != FaultCode::kNone) fault_ = cause;
  motors_.emergencyStop();
  transition(DeviceState::kEmergencyStop);
}

}  // namespace vaya
