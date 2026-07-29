#include "vaya/charger_sensor.h"

#include "vaya/config.h"
#include "vaya/logger.h"

namespace vaya {

void ChargerSensor::begin() {
  enabled_ = config::kChargerDetectionEnabled;
  if (!enabled_) return;
  pinMode(config::kChargerDetectPin,
          config::kChargerDetectActiveLow ? INPUT_PULLUP : INPUT_PULLDOWN);
  rawConnected_ = digitalRead(config::kChargerDetectPin) ==
                  (config::kChargerDetectActiveLow ? LOW : HIGH);
  connected_ = rawConnected_;
  VAYA_LOG_INFO("CHARGER", "charger %s at boot",
                connected_ ? "connected" : "disconnected");
}

void ChargerSensor::update(uint32_t nowMs) {
  if (!enabled_) return;
  const bool rawConnected = digitalRead(config::kChargerDetectPin) ==
                            (config::kChargerDetectActiveLow ? LOW : HIGH);
  if (rawConnected != rawConnected_) {
    rawConnected_ = rawConnected;
    rawChangedAtMs_ = nowMs;
  }
  if (rawConnected_ != connected_ &&
      nowMs - rawChangedAtMs_ >= config::kChargerDebounceMs) {
    connected_ = rawConnected_;
    VAYA_LOG_INFO("CHARGER", "charger %s",
                  connected_ ? "connected" : "disconnected");
  }
}

bool ChargerSensor::available() const { return enabled_; }
bool ChargerSensor::connected() const { return enabled_ && connected_; }

}  // namespace vaya
