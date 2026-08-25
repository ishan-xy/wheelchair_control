#pragma once

#include <Arduino.h>

#include "vaya/motor_controller.h"
#include "vaya/types.h"

namespace vaya {

class DeviceController {
 public:
  explicit DeviceController(MotorController& motors);
  void begin();
  void onConnected(uint32_t nowMs);
  void onDisconnected();
  void setCharging(bool charging);
  ErrorCode handle(const Command& command, uint32_t nowMs);
  void update(uint32_t nowMs);
  void setStartupFault(FaultCode fault);
  void setSafetyStartupReady(bool ready);
  void raiseFault(FaultCode fault);
  void latchSafetyEvent(FaultCode fault);
  bool resetSafetyEvent(bool toppleResetSafe);

  DeviceState state() const;
  FaultCode fault() const;
  bool locked() const;
  bool emergencyStopActive() const;
  bool canChangePairingPolicy(uint32_t nowMs) const;
  bool canOpenPairingWindow() const;
  bool canEnterStandby() const;
  bool charging() const;

 private:
  bool physicalEstopAsserted() const;
  bool controlLeaseValid(uint32_t nowMs) const;
  bool isDuplicateIdempotent(const Command& command) const;
  void transition(DeviceState next);
  void latchEmergencyStop(FaultCode cause);

  MotorController& motors_;
  DeviceState state_{DeviceState::kBooting};
  FaultCode fault_{FaultCode::kNone};
  bool connected_{false};
  bool locked_{true};
  bool emergencyStop_{false};
  bool safetyStartupReady_{true};
  bool charging_{false};
  bool protocolNegotiated_{false};
  uint32_t lastSequence_{0};
  CommandType lastCommandType_{CommandType::kInvalid};
  uint32_t leaseExpiresMs_{0};
  uint32_t lastMoveCommandMs_{0};
};

}  // namespace vaya
