#pragma once

#include <Arduino.h>

#include "vaya/types.h"

namespace vaya {

class Protocol {
 public:
  static ErrorCode parse(char* frame, Command& command);
  static size_t encodeAck(char* output, size_t capacity, uint32_t sequence,
                          ErrorCode error, DeviceState state);
  static size_t encodeTelemetry(char* output, size_t capacity,
                                uint32_t sequence, uint32_t uptimeMs,
                                DeviceState state,
                                const BatteryReading& battery,
                                const MotorSnapshot& motors, FaultCode fault,
                                bool locked, bool emergencyStop,
                                bool allowNewDevices,
                                uint8_t trustedDeviceCount,
                                bool pairingWindowOpen,
                                bool chargerAvailable,
                                bool charging,
                                bool sosActive);

 private:
  static uint16_t crc16(const char* data, size_t length);
  static bool parseInt(const char* value, int32_t min, int32_t max,
                       int32_t& output);
  static size_t appendCrc(char* output, size_t capacity, int payloadLength);
};

}  // namespace vaya
