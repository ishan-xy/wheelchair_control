#pragma once

#include <Arduino.h>

namespace vaya {

enum class LogLevel : uint8_t { kDebug, kInfo, kWarning, kError };

class Logger {
 public:
  static void begin(uint32_t baud);
  static void setLevel(LogLevel level);
  static void log(LogLevel level, const char* tag, const char* format, ...);
  static void flush();

 private:
  static constexpr size_t kLineLength = 128;
  static constexpr size_t kQueueDepth = 12;
  struct Entry {
    char text[kLineLength];
  };
  static Entry queue_[kQueueDepth];
  static volatile uint8_t head_;
  static volatile uint8_t tail_;
  static LogLevel level_;
};

#define VAYA_LOG_DEBUG(tag, format, ...) \
  ::vaya::Logger::log(::vaya::LogLevel::kDebug, tag, format, ##__VA_ARGS__)
#define VAYA_LOG_INFO(tag, format, ...) \
  ::vaya::Logger::log(::vaya::LogLevel::kInfo, tag, format, ##__VA_ARGS__)
#define VAYA_LOG_WARNING(tag, format, ...) \
  ::vaya::Logger::log(::vaya::LogLevel::kWarning, tag, format, ##__VA_ARGS__)
#define VAYA_LOG_ERROR(tag, format, ...) \
  ::vaya::Logger::log(::vaya::LogLevel::kError, tag, format, ##__VA_ARGS__)

}  // namespace vaya
