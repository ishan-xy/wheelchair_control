#pragma once

#include <Arduino.h>

#include "vaya/types.h"

namespace vaya {

class MotorController {
 public:
  MotorController();
  void begin();
  void setDriveRequest(int16_t xMilli, int16_t yMilli,
                       const char* source = "UNKNOWN");
  void setPwmLimit(int16_t limit);
  void requestStop(const char* source = "SYSTEM");
  void emergencyStop();
  void update(uint32_t nowMs);
  MotorSnapshot snapshot() const;

 private:
  class MotorOutput {
   public:
    MotorOutput(uint8_t sleep, uint8_t direction, uint8_t pwm,
                uint8_t channel, bool forwardDirectionHigh);
    void begin();
    void write(int16_t signedPwm);
    void stop();

   private:
    uint8_t sleep_;
    uint8_t direction_;
    uint8_t pwm_;
    uint8_t channel_;
    bool forwardDirectionHigh_;
  };

  static float approach(float current, float target, float step);
  static float calculateStep(float current, int16_t target, float elapsedSec);
  void setMixedTargets(int16_t xMilli, int16_t yMilli);
  void logOutputIfChanged(uint32_t nowMs);

  MotorOutput left_;
  MotorOutput right_;
  int16_t requestedLeft_{0};
  int16_t requestedRight_{0};
  float currentLeft_{0.0F};
  float currentRight_{0.0F};
  int16_t pwmLimit_{0};
  int16_t lastLoggedLeft_{0};
  int16_t lastLoggedRight_{0};
  int16_t lastLoggedRequestedLeft_{0};
  int16_t lastLoggedRequestedRight_{0};
  uint32_t lastUpdateMs_{0};
  uint32_t lastOutputLogMs_{0};
  uint32_t directionChangeAllowedMs_{0};
  const char* lastLoggedSource_{nullptr};
  int16_t lastLoggedX_{0};
  int16_t lastLoggedY_{0};
  int16_t lastLoggedCommandLeft_{0};
  int16_t lastLoggedCommandRight_{0};
};

}  // namespace vaya
