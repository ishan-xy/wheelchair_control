#include "vaya/topple_detector.h"

#include <cmath>

#include <Wire.h>

#include "vaya/config.h"

namespace vaya {
namespace {
constexpr uint8_t kWhoAmI = 0x75;
constexpr uint8_t kPowerManagement = 0x6B;
constexpr uint8_t kDataStart = 0x3B;
constexpr float kRadiansToDegrees = 57.2957795F;
constexpr float kGravityRaw = 16384.0F;

float angleDifference(float value, float reference) {
  float difference = value - reference;
  while (difference > 180.0F) difference -= 360.0F;
  while (difference < -180.0F) difference += 360.0F;
  return difference;
}
}  // namespace

void ToppleDetector::begin() {
  if (!config::kToppleDetectionEnabled) return;
  Wire.begin(config::kMpu6050SdaPin, config::kMpu6050SclPin);
  Wire.beginTransmission(config::kMpu6050Address);
  Wire.write(kWhoAmI);
  if (Wire.endTransmission(false) != 0 || Wire.requestFrom(config::kMpu6050Address, 1U) != 1) {
    fail();
    return;
  }
  const uint8_t identity = Wire.read();
  if (identity != 0x68 && identity != 0x69) {
    fail();
    return;
  }
  Wire.beginTransmission(config::kMpu6050Address);
  Wire.write(kPowerManagement);
  Wire.write(0);
  if (Wire.endTransmission() != 0) {
    fail();
    return;
  }
  state_ = SensorState::kNoData;
}

void ToppleDetector::update(uint32_t nowMs) {
  if (!config::kToppleDetectionEnabled || state_ == SensorState::kFailed) return;
  if (nowMs - lastSampleMs_ < config::kImuSamplePeriodMs) return;
  lastSampleMs_ = nowMs;
  float roll = 0;
  float pitch = 0;
  float gyroMagnitude = 0;
  if (!readSample(roll, pitch, gyroMagnitude)) {
    fail();
    return;
  }
  if (state_ != SensorState::kAvailable) {
    if (calibrationStartedMs_ == 0) calibrationStartedMs_ = nowMs;
    if (gyroMagnitude > 5.0F) {
      calibrationStartedMs_ = nowMs;
      rollSum_ = pitchSum_ = 0;
      calibrationSamples_ = 0;
      return;
    }
    rollSum_ += roll;
    pitchSum_ += pitch;
    ++calibrationSamples_;
    if (nowMs - calibrationStartedMs_ >= config::kImuCalibrationMs && calibrationSamples_ > 0) {
      referenceRoll_ = rollSum_ / calibrationSamples_;
      referencePitch_ = pitchSum_ / calibrationSamples_;
      state_ = SensorState::kAvailable;
    }
    return;
  }
  const float tilt = std::sqrt(std::pow(angleDifference(roll, referenceRoll_), 2.0F) +
                               std::pow(angleDifference(pitch, referencePitch_), 2.0F));
  if (tilt >= config::kToppleThresholdDegrees) {
    if (toppleStartedMs_ == 0) toppleStartedMs_ = nowMs;
    if (!toppled_ && nowMs - toppleStartedMs_ >= config::kToppleTriggerMs) {
      toppled_ = true;
      toppleEvent_ = true;
    }
  } else {
    toppleStartedMs_ = 0;
  }
  if (tilt <= config::kToppleResetThresholdDegrees && gyroMagnitude <= 5.0F) {
    if (uprightStartedMs_ == 0) uprightStartedMs_ = nowMs;
  } else {
    uprightStartedMs_ = 0;
  }
}

bool ToppleDetector::consumeToppleEvent() {
  const bool event = toppleEvent_;
  toppleEvent_ = false;
  return event;
}

void ToppleDetector::acknowledgeReset() {
  toppled_ = false;
  toppleEvent_ = false;
  toppleStartedMs_ = 0;
}

bool ToppleDetector::ready() const { return !config::kToppleDetectionEnabled || state_ == SensorState::kAvailable; }
bool ToppleDetector::canReset() const {
  return !config::kToppleDetectionEnabled ||
         (state_ == SensorState::kAvailable && uprightStartedMs_ != 0 &&
          millis() - uprightStartedMs_ >= config::kToppleResetStableMs);
}
SensorState ToppleDetector::state() const { return state_; }

bool ToppleDetector::readSample(float& roll, float& pitch, float& gyroMagnitude) {
  Wire.beginTransmission(config::kMpu6050Address);
  Wire.write(kDataStart);
  if (Wire.endTransmission(false) != 0 || Wire.requestFrom(config::kMpu6050Address, 14U) != 14) return false;
  const auto read16 = []() {
    const uint8_t high = Wire.read();
    const uint8_t low = Wire.read();
    return static_cast<int16_t>((static_cast<uint16_t>(high) << 8) | low);
  };
  const float ax = read16();
  const float ay = read16();
  const float az = read16();
  read16();
  const float gx = read16() / 131.0F;
  const float gy = read16() / 131.0F;
  const float gz = read16() / 131.0F;
  const float magnitude = std::sqrt(ax * ax + ay * ay + az * az) / kGravityRaw;
  if (magnitude < 0.75F || magnitude > 1.25F) return false;
  roll = std::atan2(ay, az) * kRadiansToDegrees;
  pitch = std::atan2(-ax, std::sqrt(ay * ay + az * az)) * kRadiansToDegrees;
  gyroMagnitude = std::sqrt(gx * gx + gy * gy + gz * gz);
  return true;
}

void ToppleDetector::fail() { state_ = SensorState::kFailed; }

}  // namespace vaya
