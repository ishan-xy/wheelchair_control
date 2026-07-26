#include "vaya/battery_sensor.h"

#include <algorithm>

#include "vaya/config.h"
#include "vaya/logger.h"

namespace vaya {

void BatterySensor::begin() {
  if (!config::kBattery.enabled) {
    reading_.state = SensorState::kNotConfigured;
    VAYA_LOG_WARNING("BATTERY", "sensor calibration not configured");
    return;
  }
  pinMode(config::kBatteryAdcPin, INPUT);
  analogReadResolution(12);
  reading_.state = SensorState::kNoData;
}

void BatterySensor::update(uint32_t nowMs) {
  if (!config::kBattery.enabled ||
      nowMs - lastSampleMs_ < config::kBatterySamplePeriodMs) {
    return;
  }
  lastSampleMs_ = nowMs;
  accumulator_ += static_cast<uint32_t>(analogRead(config::kBatteryAdcPin));
  if (++sampleCount_ >= config::kBatterySamplesPerReading) finishReading(nowMs);
}

const BatteryReading& BatterySensor::reading() const { return reading_; }

void BatterySensor::finishReading(uint32_t nowMs) {
  const uint16_t previousRaw = reading_.raw;
  reading_.raw = static_cast<uint16_t>(accumulator_ / sampleCount_);
  accumulator_ = 0;
  sampleCount_ = 0;
  reading_.updatedAtMs = nowMs;

  if (reading_.raw <= config::kBattery.disconnectedBelowRaw) {
    reading_.state = SensorState::kDisconnected;
    reading_.voltageMv = 0;
    reading_.percentage = -1;
  } else if (config::kBattery.adcMax == 0 ||
             config::kBattery.dividerDenominator == 0 ||
             config::kBattery.packFullMv <= config::kBattery.packEmptyMv) {
    reading_.state = SensorState::kInvalid;
    reading_.voltageMv = 0;
    reading_.percentage = -1;
  } else {
    const uint64_t pinMv =
        (static_cast<uint64_t>(reading_.raw) *
         config::kBattery.adcReferenceMv) /
        config::kBattery.adcMax;
    const int64_t packMv =
        static_cast<int64_t>((pinMv * config::kBattery.dividerNumerator) /
                             config::kBattery.dividerDenominator) +
        config::kBattery.offsetMv;
    if (packMv <= 0 || packMv > UINT32_MAX) {
      reading_.state = SensorState::kInvalid;
      reading_.voltageMv = 0;
      reading_.percentage = -1;
    } else {
      reading_.state = SensorState::kAvailable;
      reading_.voltageMv = static_cast<uint32_t>(packMv);
      reading_.percentage = estimatePercentage(reading_.voltageMv);
    }
  }

  if (previousRaw != reading_.raw) {
    VAYA_LOG_DEBUG("BATTERY", "raw changed %u -> %u", previousRaw,
                   reading_.raw);
  }
}

int16_t BatterySensor::estimatePercentage(uint32_t voltageMv) const {
  if (config::kBattery.packFullMv <= config::kBattery.packEmptyMv) return -1;
  if (voltageMv <= config::kBattery.packEmptyMv) return 0;
  if (voltageMv >= config::kBattery.packFullMv) return 100;
  const uint32_t span =
      config::kBattery.packFullMv > config::kBattery.packEmptyMv
          ? config::kBattery.packFullMv - config::kBattery.packEmptyMv
          : 1U;
  return static_cast<int16_t>(
      ((voltageMv - config::kBattery.packEmptyMv) * 100U) / span);
}

}  // namespace vaya
