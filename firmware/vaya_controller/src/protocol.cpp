#include "vaya/protocol.h"

#include <cerrno>
#include <cstdio>
#include <cstdlib>
#include <cstring>

#include "vaya/config.h"

namespace vaya {
namespace {

constexpr size_t kMaxTokens = 9;

size_t split(char* value, char* tokens[], size_t capacity) {
  size_t count = 0;
  char* cursor = value;
  while (cursor != nullptr && count < capacity) {
    tokens[count++] = cursor;
    char* separator = strchr(cursor, '|');
    if (separator == nullptr) break;
    *separator = '\0';
    cursor = separator + 1;
  }
  return count;
}

}  // namespace

ErrorCode Protocol::parse(char* frame, Command& command) {
  if (frame == nullptr || *frame == '\0') return ErrorCode::kBadFrame;
  char* crcSeparator = strrchr(frame, '|');
  if (crcSeparator == nullptr) return ErrorCode::kBadFrame;

  char* crcEnd = nullptr;
  errno = 0;
  const unsigned long receivedCrc = strtoul(crcSeparator + 1, &crcEnd, 16);
  if (errno != 0 || crcEnd == crcSeparator + 1 || *crcEnd != '\0' ||
      receivedCrc > 0xFFFFUL) {
    return ErrorCode::kBadCrc;
  }
  const size_t payloadLength = static_cast<size_t>(crcSeparator - frame);
  if (crc16(frame, payloadLength) != static_cast<uint16_t>(receivedCrc)) {
    return ErrorCode::kBadCrc;
  }
  *crcSeparator = '\0';

  char* tokens[kMaxTokens]{};
  const size_t count = split(frame, tokens, kMaxTokens);
  if (count < 4 || strcmp(tokens[0], "V2") != 0 ||
      strcmp(tokens[1], "C") != 0) {
    return count > 0 && strcmp(tokens[0], "V2") != 0
               ? ErrorCode::kBadVersion
               : ErrorCode::kBadFrame;
  }

  int32_t sequence = 0;
  if (!parseInt(tokens[2], 1, INT32_MAX, sequence)) {
    return ErrorCode::kBadSequence;
  }
  command = {};
  command.sequence = static_cast<uint32_t>(sequence);

  if (strcmp(tokens[3], "HELLO") == 0 && count == 5) {
    int32_t version = 0;
    if (!parseInt(tokens[4], 2, 2, version)) return ErrorCode::kBadVersion;
    command.type = CommandType::kHello;
  } else if (strcmp(tokens[3], "ACQUIRE") == 0 && count == 4) {
    command.type = CommandType::kAcquireControl;
  } else if (strcmp(tokens[3], "MOVE") == 0 && count == 6) {
    if (!parseInt(tokens[4], -1000, 1000, command.valueA) ||
        !parseInt(tokens[5], -1000, 1000, command.valueB)) {
      return ErrorCode::kInvalidValue;
    }
    command.type = CommandType::kMove;
  } else if (strcmp(tokens[3], "STOP") == 0 && count == 4) {
    command.type = CommandType::kStop;
  } else if (strcmp(tokens[3], "ESTOP") == 0 && count == 4) {
    command.type = CommandType::kEmergencyStop;
  } else if (strcmp(tokens[3], "RESET_ESTOP") == 0 && count == 4) {
    command.type = CommandType::kResetEmergencyStop;
  } else if (strcmp(tokens[3], "MODE") == 0 && count == 5) {
    command.valueA = strcmp(tokens[4], "INDOOR") == 0
                         ? 0
                         : strcmp(tokens[4], "OUTDOOR") == 0 ? 1 : -1;
    if (command.valueA < 0) return ErrorCode::kInvalidValue;
    command.type = CommandType::kSetMode;
  } else if (strcmp(tokens[3], "LIMIT") == 0 && count == 5) {
    if (!parseInt(tokens[4], 1, 255, command.valueA)) {
      return ErrorCode::kInvalidValue;
    }
    command.type = CommandType::kSetLimit;
  } else if (strcmp(tokens[3], "LOCK") == 0 && count == 5) {
    if (!parseInt(tokens[4], 0, 1, command.valueA)) {
      return ErrorCode::kInvalidValue;
    }
    command.type = CommandType::kSetLock;
  } else if (strcmp(tokens[3], "FORGET") == 0 && count == 4) {
    command.type = CommandType::kForgetBond;
  } else if (strcmp(tokens[3], "PASSKEY") == 0 && count == 5) {
    if (!parseInt(tokens[4], 100000, 999999, command.valueA)) {
      return ErrorCode::kPasskeyPolicyFailed;
    }
    command.type = CommandType::kChangePasskey;
  } else if (strcmp(tokens[3], "ALLOW_NEW") == 0 && count == 5) {
    if (!parseInt(tokens[4], 0, 1, command.valueA)) {
      return ErrorCode::kInvalidValue;
    }
    command.type = CommandType::kSetNewDevicePairing;
  } else if (strcmp(tokens[3], "PING") == 0 && count == 4) {
    command.type = CommandType::kPing;
  } else {
    return ErrorCode::kUnknownCommand;
  }
  return ErrorCode::kNone;
}

size_t Protocol::encodeAck(char* output, size_t capacity, uint32_t sequence,
                           ErrorCode error, DeviceState state) {
  const int length = snprintf(output, capacity, "V2|A|%lu|%s|%s",
                              static_cast<unsigned long>(sequence),
                              toString(error), toString(state));
  return appendCrc(output, capacity, length);
}

size_t Protocol::encodeTelemetry(char* output, size_t capacity,
                                 uint32_t sequence, uint32_t uptimeMs,
                                 DeviceState state,
                                 const BatteryReading& battery,
                                 const MotorSnapshot& motors, FaultCode fault,
                                 bool locked, bool emergencyStop,
                                 bool allowNewDevices,
                                 uint8_t trustedDeviceCount,
                                 bool pairingWindowOpen) {
  const int length = snprintf(
      output, capacity, "V2|T|%lu|%lu|%s|%s|%u|%lu|%d|%d|%d|%s|%u|%u|%u|%u|%u",
      static_cast<unsigned long>(sequence),
      static_cast<unsigned long>(uptimeMs), toString(state),
      toString(battery.state), battery.raw,
      static_cast<unsigned long>(battery.voltageMv), battery.percentage,
      motors.leftPwm, motors.rightPwm, toString(fault), locked ? 1U : 0U,
      emergencyStop ? 1U : 0U, allowNewDevices ? 1U : 0U,
      static_cast<unsigned>(trustedDeviceCount), pairingWindowOpen ? 1U : 0U);
  if (length <= 0 || static_cast<size_t>(length + 1) >= capacity) return 0;
  const int withVersion =
      snprintf(output + length, capacity - length, "|%s",
               config::kFirmwareVersion);
  return appendCrc(output, capacity,
                   withVersion > 0 ? length + withVersion : -1);
}

uint16_t Protocol::crc16(const char* data, size_t length) {
  uint16_t crc = 0xFFFF;
  for (size_t i = 0; i < length; ++i) {
    crc ^= static_cast<uint16_t>(static_cast<uint8_t>(data[i])) << 8U;
    for (uint8_t bit = 0; bit < 8; ++bit) {
      crc = (crc & 0x8000U) != 0U ? static_cast<uint16_t>((crc << 1U) ^ 0x1021U)
                                 : static_cast<uint16_t>(crc << 1U);
    }
  }
  return crc;
}

bool Protocol::parseInt(const char* value, int32_t min, int32_t max,
                        int32_t& output) {
  if (value == nullptr || *value == '\0') return false;
  char* end = nullptr;
  errno = 0;
  const long parsed = strtol(value, &end, 10);
  if (errno != 0 || end == value || *end != '\0' || parsed < min ||
      parsed > max) {
    return false;
  }
  output = static_cast<int32_t>(parsed);
  return true;
}

size_t Protocol::appendCrc(char* output, size_t capacity, int payloadLength) {
  if (payloadLength <= 0 || static_cast<size_t>(payloadLength + 7) > capacity) {
    if (capacity > 0) output[0] = '\0';
    return 0;
  }
  const uint16_t crc = crc16(output, static_cast<size_t>(payloadLength));
  const int written =
      snprintf(output + payloadLength, capacity - payloadLength, "|%04X\n", crc);
  return written > 0 ? static_cast<size_t>(payloadLength + written) : 0;
}

}  // namespace vaya
