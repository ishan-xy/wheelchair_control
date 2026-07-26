#include "vaya/logger.h"

#include <cstdarg>
#include <cstdio>

namespace vaya {

Logger::Entry Logger::queue_[Logger::kQueueDepth]{};
volatile uint8_t Logger::head_ = 0;
volatile uint8_t Logger::tail_ = 0;
LogLevel Logger::level_ = LogLevel::kInfo;

void Logger::begin(uint32_t baud) { Serial.begin(baud); }

void Logger::setLevel(LogLevel level) { level_ = level; }

void Logger::log(LogLevel level, const char* tag, const char* format, ...) {
  if (static_cast<uint8_t>(level) < static_cast<uint8_t>(level_)) return;
  const uint8_t next = (head_ + 1U) % kQueueDepth;
  if (next == tail_) return;

  const char levelChar[] = {'D', 'I', 'W', 'E'};
  Entry& entry = queue_[head_];
  const int prefix = snprintf(entry.text, kLineLength, "[%lu][%c][%s] ",
                              millis(), levelChar[static_cast<uint8_t>(level)],
                              tag);
  if (prefix < 0 || static_cast<size_t>(prefix) >= kLineLength) return;

  va_list args;
  va_start(args, format);
  vsnprintf(entry.text + prefix, kLineLength - prefix, format, args);
  va_end(args);
  head_ = next;
}

void Logger::flush() {
  if (tail_ == head_ || Serial.availableForWrite() < 32) return;
  Serial.println(queue_[tail_].text);
  tail_ = (tail_ + 1U) % kQueueDepth;
}

}  // namespace vaya
