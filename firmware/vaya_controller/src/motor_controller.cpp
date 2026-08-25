#include "vaya/motor_controller.h"

#include <algorithm>
#include <cstdlib>

#include "vaya/config.h"
#include "vaya/logger.h"

namespace vaya {
namespace {

const char* directionLabel(int16_t pwm) {
  if (pwm > 0) return "FWD";
  if (pwm < 0) return "REV";
  return "STOP";
}

}  // namespace

MotorController::MotorOutput::MotorOutput(uint8_t sleep, uint8_t direction,
                                          uint8_t pwm, uint8_t channel,
                                          bool forwardDirectionHigh)
    : sleep_(sleep),
      direction_(direction),
      pwm_(pwm),
      channel_(channel),
      forwardDirectionHigh_(forwardDirectionHigh) {}

void MotorController::MotorOutput::begin() {
  pinMode(sleep_, OUTPUT);
  pinMode(direction_, OUTPUT);
  digitalWrite(sleep_, HIGH);
  digitalWrite(direction_, LOW);
#if ESP_ARDUINO_VERSION_MAJOR >= 3
  ledcAttach(pwm_, config::kPwmFrequencyHz, config::kPwmResolutionBits);
#else
  ledcSetup(channel_, config::kPwmFrequencyHz, config::kPwmResolutionBits);
  ledcAttachPin(pwm_, channel_);
#endif
  stop();
}

void MotorController::MotorOutput::write(int16_t signedPwm) {
  const uint8_t duty =
      static_cast<uint8_t>(std::min<int16_t>(std::abs(signedPwm), 255));
  if (duty == 0) {
    stop();
    return;
  }
  const bool forward = signedPwm > 0;
  digitalWrite(direction_,
               forward == forwardDirectionHigh_ ? HIGH : LOW);
  digitalWrite(sleep_, LOW);
#if ESP_ARDUINO_VERSION_MAJOR >= 3
  ledcWrite(pwm_, duty);
#else
  ledcWrite(channel_, duty);
#endif
}

void MotorController::MotorOutput::stop() {
#if ESP_ARDUINO_VERSION_MAJOR >= 3
  ledcWrite(pwm_, 0);
#else
  ledcWrite(channel_, 0);
#endif
  digitalWrite(sleep_, HIGH);
  digitalWrite(direction_, LOW);
}

MotorController::MotorController()
    : left_(config::kLeftSleep, config::kLeftDirection, config::kLeftPwm,
            config::kLeftPwmChannel, config::kLeftForwardDirectionHigh),
      right_(config::kRightSleep, config::kRightDirection, config::kRightPwm,
             config::kRightPwmChannel, config::kRightForwardDirectionHigh),
      pwmLimit_(config::kDefaultPwmLimit) {}

void MotorController::begin() {
  left_.begin();
  right_.begin();
  emergencyStop();
  VAYA_LOG_INFO("MOTOR", "outputs initialized safe");
}

void MotorController::setDriveRequest(int16_t xMilli, int16_t yMilli) {
  if (std::abs(xMilli) < config::kInputDeadZoneMilli) xMilli = 0;
  if (std::abs(yMilli) < config::kInputDeadZoneMilli) yMilli = 0;
  setMixedTargets(xMilli, yMilli);
}

void MotorController::setPwmLimit(int16_t limit) {
  pwmLimit_ = std::max<int16_t>(1, std::min<int16_t>(limit, 255));
  requestedLeft_ =
      std::max<int16_t>(-pwmLimit_, std::min(requestedLeft_, pwmLimit_));
  requestedRight_ =
      std::max<int16_t>(-pwmLimit_, std::min(requestedRight_, pwmLimit_));
}

void MotorController::requestStop() {
  requestedLeft_ = 0;
  requestedRight_ = 0;
}

void MotorController::emergencyStop() {
  requestedLeft_ = 0;
  requestedRight_ = 0;
  currentLeft_ = 0;
  currentRight_ = 0;
  left_.stop();
  right_.stop();
}

void MotorController::update(uint32_t nowMs) {
  if (nowMs - lastUpdateMs_ < config::kMotorUpdateMs) return;
  const uint32_t elapsed =
      lastUpdateMs_ == 0 ? config::kMotorUpdateMs : nowMs - lastUpdateMs_;
  lastUpdateMs_ = nowMs;
  const int16_t step = std::max<int16_t>(
      1, static_cast<int16_t>((config::kPwmRampPerSecond * elapsed) / 1000U));

  const bool reversing =
      (currentLeft_ != 0 && requestedLeft_ != 0 &&
       (currentLeft_ > 0) != (requestedLeft_ > 0)) ||
      (currentRight_ != 0 && requestedRight_ != 0 &&
       (currentRight_ > 0) != (requestedRight_ > 0));

  int16_t leftTarget = reversing ? 0 : requestedLeft_;
  int16_t rightTarget = reversing ? 0 : requestedRight_;
  currentLeft_ = approach(currentLeft_, leftTarget, step);
  currentRight_ = approach(currentRight_, rightTarget, step);

  if (reversing && currentLeft_ == 0 && currentRight_ == 0 &&
      directionChangeAllowedMs_ == 0) {
    directionChangeAllowedMs_ = nowMs + config::kDirectionDeadTimeMs;
  }
  if (directionChangeAllowedMs_ != 0) {
    if (static_cast<int32_t>(nowMs - directionChangeAllowedMs_) < 0) {
      currentLeft_ = 0;
      currentRight_ = 0;
    } else {
      directionChangeAllowedMs_ = 0;
    }
  }

  left_.write(currentLeft_);
  right_.write(currentRight_);
  logOutputIfChanged(nowMs);
}

MotorSnapshot MotorController::snapshot() const {
  MotorSnapshot value;
  value.leftPwm = currentLeft_;
  value.rightPwm = currentRight_;
  value.motionRequested = requestedLeft_ != 0 || requestedRight_ != 0;
  value.atRest = currentLeft_ == 0 && currentRight_ == 0;
  return value;
}

int16_t MotorController::approach(int16_t current, int16_t target,
                                  int16_t step) {
  if (current < target) return std::min<int16_t>(target, current + step);
  if (current > target) return std::max<int16_t>(target, current - step);
  return current;
}

void MotorController::setMixedTargets(int16_t xMilli, int16_t yMilli) {
  const int32_t leftMix =
      std::max<int32_t>(-1000, std::min<int32_t>(
                                  static_cast<int32_t>(yMilli) + xMilli, 1000));
  const int32_t rightMix =
      std::max<int32_t>(-1000, std::min<int32_t>(
                                  static_cast<int32_t>(yMilli) - xMilli, 1000));
  requestedLeft_ = static_cast<int16_t>((leftMix * pwmLimit_) / 1000);
  requestedRight_ = static_cast<int16_t>((rightMix * pwmLimit_) / 1000);
}

void MotorController::logOutputIfChanged(uint32_t nowMs) {
  const bool changed =
      currentLeft_ != lastLoggedLeft_ || currentRight_ != lastLoggedRight_ ||
      requestedLeft_ != lastLoggedRequestedLeft_ ||
      requestedRight_ != lastLoggedRequestedRight_;
  if (!changed) return;

  const bool justStopped = currentLeft_ == 0 && currentRight_ == 0 &&
                           (lastLoggedLeft_ != 0 || lastLoggedRight_ != 0);
  if (!justStopped &&
      nowMs - lastOutputLogMs_ < config::kMotorOutputLogPeriodMs) {
    return;
  }

  VAYA_LOG_INFO(
      "MOTOR",
      "output L=%d(%s) R=%d(%s); target L=%d R=%d; limit=%d",
      currentLeft_, directionLabel(currentLeft_), currentRight_,
      directionLabel(currentRight_), requestedLeft_, requestedRight_,
      pwmLimit_);
  lastLoggedLeft_ = currentLeft_;
  lastLoggedRight_ = currentRight_;
  lastLoggedRequestedLeft_ = requestedLeft_;
  lastLoggedRequestedRight_ = requestedRight_;
  lastOutputLogMs_ = nowMs;
}

}  // namespace vaya
