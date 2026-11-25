#include "vaya/motor_controller.h"

#include <algorithm>
#include <cmath>
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

void MotorController::setDriveRequest(int16_t xMilli, int16_t yMilli,
                                       const char* source) {
  if (std::abs(xMilli) < config::kInputDeadZoneMilli) xMilli = 0;
  if (std::abs(yMilli) < config::kInputDeadZoneMilli) yMilli = 0;
  setMixedTargets(xMilli, yMilli);
  if (source != lastLoggedSource_ || xMilli != lastLoggedX_ ||
      yMilli != lastLoggedY_ ||
      requestedLeft_ != lastLoggedCommandLeft_ ||
      requestedRight_ != lastLoggedCommandRight_) {
    VAYA_LOG_INFO("PWM", "source=%s x=%d y=%d left=%d right=%d limit=%d",
                  source, xMilli, yMilli, requestedLeft_, requestedRight_,
                  pwmLimit_);
    lastLoggedSource_ = source;
    lastLoggedX_ = xMilli;
    lastLoggedY_ = yMilli;
    lastLoggedCommandLeft_ = requestedLeft_;
    lastLoggedCommandRight_ = requestedRight_;
  }
}

void MotorController::setPwmLimit(int16_t limit) {
  pwmLimit_ = std::max<int16_t>(1, std::min<int16_t>(limit, 255));
  requestedLeft_ =
      std::max<int16_t>(-pwmLimit_, std::min(requestedLeft_, pwmLimit_));
  requestedRight_ =
      std::max<int16_t>(-pwmLimit_, std::min(requestedRight_, pwmLimit_));
}

void MotorController::requestStop(const char* source) {
  const bool changed = requestedLeft_ != 0 || requestedRight_ != 0;
  requestedLeft_ = 0;
  requestedRight_ = 0;
  if (changed) {
    VAYA_LOG_INFO("PWM", "source=%s x=0 y=0 left=0 right=0", source);
    lastLoggedSource_ = source;
    lastLoggedX_ = 0;
    lastLoggedY_ = 0;
    lastLoggedCommandLeft_ = 0;
    lastLoggedCommandRight_ = 0;
  }
}

void MotorController::emergencyStop() {
  requestedLeft_ = 0;
  requestedRight_ = 0;
  currentLeft_ = 0.0F;
  currentRight_ = 0.0F;
  left_.stop();
  right_.stop();
}

float MotorController::calculateStep(float current, int16_t target,
                                     float elapsedSec) {
  const float currentAbs = std::abs(current);
  const float targetAbs = static_cast<float>(std::abs(target));

  // Accelerating: increasing speed away from zero in the commanded direction
  const bool sameDirection =
      (current > 0.0F && target > 0) || (current < 0.0F && target < 0) ||
      (currentAbs < 0.001F);
  const bool accelerating = sameDirection && (targetAbs > currentAbs);

  if (accelerating && targetAbs > 0.001F) {
    const float progress = std::min(1.0F, currentAbs / targetAbs);
    const float curvedProgress =
        std::pow(progress, config::kPwmAccelerationExponent);
    const float rampRate =
        static_cast<float>(config::kPwmInitialRampPerSecond) +
        static_cast<float>(config::kPwmRampPerSecond -
                           config::kPwmInitialRampPerSecond) *
            curvedProgress;
    return rampRate * elapsedSec;
  }

  // Decelerating / braking / return to neutral: fast linear deceleration
  return static_cast<float>(config::kPwmDecelPerSecond) * elapsedSec;
}

void MotorController::update(uint32_t nowMs) {
  if (nowMs - lastUpdateMs_ < config::kMotorUpdateMs) return;
  const uint32_t elapsedMs =
      lastUpdateMs_ == 0 ? config::kMotorUpdateMs : nowMs - lastUpdateMs_;
  lastUpdateMs_ = nowMs;
  const float elapsedSec = static_cast<float>(elapsedMs) / 1000.0F;

  const bool reversing =
      (std::abs(currentLeft_) > 0.001F && requestedLeft_ != 0 &&
       (currentLeft_ > 0.0F) != (requestedLeft_ > 0)) ||
      (std::abs(currentRight_) > 0.001F && requestedRight_ != 0 &&
       (currentRight_ > 0.0F) != (requestedRight_ > 0));

  const int16_t leftTarget = reversing ? 0 : requestedLeft_;
  const int16_t rightTarget = reversing ? 0 : requestedRight_;

  const float leftStep = calculateStep(currentLeft_, leftTarget, elapsedSec);
  const float rightStep = calculateStep(currentRight_, rightTarget, elapsedSec);

  currentLeft_ = approach(currentLeft_, static_cast<float>(leftTarget), leftStep);
  currentRight_ = approach(currentRight_, static_cast<float>(rightTarget), rightStep);

  if (reversing && std::abs(currentLeft_) < 0.001F &&
      std::abs(currentRight_) < 0.001F && directionChangeAllowedMs_ == 0) {
    directionChangeAllowedMs_ = nowMs + config::kDirectionDeadTimeMs;
  }
  if (directionChangeAllowedMs_ != 0) {
    if (static_cast<int32_t>(nowMs - directionChangeAllowedMs_) < 0) {
      currentLeft_ = 0.0F;
      currentRight_ = 0.0F;
    } else {
      directionChangeAllowedMs_ = 0;
    }
  }

  const int16_t outLeft = static_cast<int16_t>(std::round(currentLeft_));
  const int16_t outRight = static_cast<int16_t>(std::round(currentRight_));
  left_.write(outLeft);
  right_.write(outRight);
  logOutputIfChanged(nowMs);
}

MotorSnapshot MotorController::snapshot() const {
  MotorSnapshot value;
  value.leftPwm = static_cast<int16_t>(std::round(currentLeft_));
  value.rightPwm = static_cast<int16_t>(std::round(currentRight_));
  value.motionRequested = requestedLeft_ != 0 || requestedRight_ != 0;
  value.atRest = (value.leftPwm == 0 && value.rightPwm == 0);
  return value;
}

float MotorController::approach(float current, float target, float step) {
  if (current < target) return std::min(target, current + step);
  if (current > target) return std::max(target, current - step);
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
  const int16_t outLeft = static_cast<int16_t>(std::round(currentLeft_));
  const int16_t outRight = static_cast<int16_t>(std::round(currentRight_));
  const bool changed =
      outLeft != lastLoggedLeft_ || outRight != lastLoggedRight_ ||
      requestedLeft_ != lastLoggedRequestedLeft_ ||
      requestedRight_ != lastLoggedRequestedRight_;
  if (!changed) return;

  const bool justStopped = outLeft == 0 && outRight == 0 &&
                           (lastLoggedLeft_ != 0 || lastLoggedRight_ != 0);
  if (!justStopped &&
      nowMs - lastOutputLogMs_ < config::kMotorOutputLogPeriodMs) {
    return;
  }

  VAYA_LOG_INFO(
      "MOTOR",
      "applied L=%d(%s) R=%d(%s); target L=%d R=%d; limit=%d",
      outLeft, directionLabel(outLeft), outRight,
      directionLabel(outRight), requestedLeft_, requestedRight_,
      pwmLimit_);
  lastLoggedLeft_ = outLeft;
  lastLoggedRight_ = outRight;
  lastLoggedRequestedLeft_ = requestedLeft_;
  lastLoggedRequestedRight_ = requestedRight_;
  lastOutputLogMs_ = nowMs;
}

}  // namespace vaya
