# VAYA One Controller Firmware

This PlatformIO project is the production-oriented replacement for the original
single-file prototype. It targets ESP32 Arduino 3.x and NimBLE-Arduino 2.x.

## Safety boundary

The firmware always boots with motor PWM at zero. Movement requires:

1. an encrypted BLE connection;
2. successful v2 protocol negotiation;
3. an active control lease;
4. an explicit unlock command;
5. fresh, valid movement commands;
6. no fault or emergency-stop state.

The 500 ms movement watchdog cannot be disabled. BLE disconnect, lease expiry,
or controller fault forces immediate zero PWM.

The app never locks a moving wheelchair. `LOCK|1` is accepted only when motor
PWM is zero and no drive target is pending; it is not a replacement for Stop or
Emergency Stop. A new BLE connection always starts locked, and movement needs a
deliberate app unlock after the chair reports stopped.

Emergency Stop is a software safety latch: it immediately commands zero PWM,
locks the chair, and requires an authenticated app reset while stationary.

### HW-504 physical joystick

The firmware supports an HW-504 two-axis joystick. Connect common ground, VRx
to ESP32 GPIO32, and VRy to GPIO33. The SW pin is unused. Power the module
from 3.3 V so its analog outputs never exceed the ESP32 ADC limit; if it is
powered from 5 V, add a voltage divider to each VR output before connecting it
to the ESP32. The app's Settings switch selects either `APP` or `PHYSICAL`
input; only the selected source can command movement, and the chair must be
connected and free of an active safety fault to change it. Changing the source
first forces motor output to zero. Keep the joystick centered while physical
mode is enabled; the firmware samples its neutral position before accepting
movement. The default source is the app joystick.

## Required production configuration

Create the local configuration file and assign a unique six-digit passkey:

```bash
cp .env.example .env
```

Edit `.env`:

```dotenv
VAYA_BLE_PASSKEY=483921
VAYA_UPLOAD_PORT=/dev/cu.usbserial-0001
VAYA_FEATURE_PAIRING_BUTTON=false
VAYA_FEATURE_AUTO_STANDBY=false
VAYA_FEATURE_SOS_BUTTON=false
VAYA_FEATURE_CHARGER_DETECTION=false
```

The `.env` file is ignored by Git. Do not deploy the example key. Provision a
unique key per wheelchair and place it on the device label or secure
commissioning record.

`VAYA_FEATURE_PAIRING_BUTTON=false` is for development without the physical
Pair / Wake button. When the button is installed, set it to `true` and assign
`VAYA_PAIR_WAKE_BUTTON_PIN` to its GPIO. The button is wired from that GPIO to
GND and uses the ESP32 internal pull-up.

With the button enabled: a short press wakes BLE advertising without unlocking
the chair. Holding it for five seconds opens a two-minute pairing window only
when the chair is locked, stationary, and a trusted caregiver has allowed new
devices. It disconnects the current phone without deleting any saved bond.

## Optional hardware features

Every optional feature is disabled by default. Enable a feature only after its
input/output circuit has been wired, electrically verified, and tested with
motor power isolated.

- `VAYA_FEATURE_AUTO_STANDBY=true`: after ten minutes locked, stationary, and
  disconnected, BLE advertising stops. The Pair / Wake button wakes the chair
  back into its locked state. This is BLE standby, not ESP32 deep sleep.
- `VAYA_FEATURE_SOS_BUTTON=true` with `VAYA_SOS_BUTTON_PIN=<gpio>`: holding
  the button for two seconds publishes an SOS event for two minutes. It does
  not replace the physical emergency-stop circuit.
- `VAYA_FEATURE_ALERT_INDICATOR=true` with `VAYA_ALERT_INDICATOR_PIN=<gpio>`:
  pulses an externally driven LED or buzzer while an SOS event is active.
- `VAYA_FEATURE_CHARGER_DETECTION=true` with
  `VAYA_CHARGER_DETECT_PIN=<gpio>`: locks the chair and stops motors whenever
  charging is detected. Movement and unlock commands are rejected until the
  charger is disconnected.
- `VAYA_FEATURE_PHYSICAL_JOYSTICK` is enabled by default with GPIO32/GPIO33
  above. Set it to `false` in the build configuration if the joystick is not
  installed.

### Flash from the PlatformIO GUI

1. Install Visual Studio Code and the recommended PlatformIO IDE extension.
2. Open `firmware/vaya_controller` as the VS Code folder.
3. Create and edit `.env` as shown above.
4. Select the PlatformIO icon in the activity bar.
5. Open `Project Tasks > esp32dev > General`.
6. Select `Upload` to build and flash.
7. Select `Monitor` to open the 115200 baud serial monitor.

Disconnect motor power before flashing. If upload remains on `Connecting`,
hold the ESP32 `BOOT` button, briefly press `EN/RESET`, and release `BOOT` when
writing begins.

Configure the real battery calibration in `include/vaya/config.h`. Battery telemetry intentionally reports
`NOT_CONFIGURED` until calibration is supplied.

Verify motor direction pins, stop/brake behavior, PWM polarity, driver enable
logic, and electrical fail-safe behavior against the production motor driver.

## Protocol

Frames are UTF-8 ASCII, newline terminated, and protected by CRC16-CCITT:

```text
V2|C|41|HELLO|2|7A3F
V2|C|42|ACQUIRE|C182
V2|C|43|LOCK|0|9D20
V2|C|44|MOVE|0|500|3A10
V2|C|45|STOP|0E3B
V2|C|46|ESTOP|9F0A
V2|C|47|RESET_ESTOP|<crc>
V2|C|48|FORGET|<crc>
V2|C|49|PASSKEY|483921|<crc>
V2|C|50|ALLOW_NEW|1|<crc>
V2|C|51|INPUT|APP|<crc>
V2|C|52|INPUT|PHYSICAL|<crc>
```

The final CRC values above are illustrative. Implementations must calculate
them over all characters before the final separator.

ACK:

```text
V2|A|44|OK|MOVING|<crc>
V2|A|44|LOCKED|CONNECTED_LOCKED|<crc>
```

Telemetry:

```text
V2|T|8|91822|CONNECTED_IDLE|AVAILABLE|2048|24700|72|0|0|NONE|0|0|2.0.5|<crc>
```

`ALLOW_NEW` is accepted only from a connected caregiver control session while
the chair is stationary. It controls whether a physical pairing window may add
a new bonded caregiver device. With no saved bonds, new-device setup is always
allowed so a chair cannot be stranded without a caregiver phone.

Battery state may be `NO_DATA`, `AVAILABLE`, `NOT_CONFIGURED`,
`DISCONNECTED`, `INVALID`, or `FAILED`. Percentage is `-1` unless available.

## Passkey rotation

The boot-time `.env` passkey is used only when the ESP32 has no stored
passkey. The active passkey lives in ESP32 NVS and can be changed in VAYA
Connect over an encrypted, authenticated BLE session. The command is accepted
only while the caregiver has a valid control lease and the motors are at rest.
It locks the wheelchair, stores the replacement passkey, removes the current
bond, and disconnects immediately. The caregiver must pair again using the
new passkey.

On iPhone, iOS may retain the old pairing record. After a passkey change, use
Settings > Bluetooth > VAYA One > Forget This Device before reconnecting.

## Validation before occupied testing

- Static analysis and warning-clean firmware build.
- Bench test with motor power physically isolated.
- Wheels-off-ground direction, ramp, and zero-crossing tests.
- Disconnect and app-kill tests at every speed and direction.
- Delayed, duplicated, corrupt, oversized, and out-of-order packet tests.
- BLE congestion and queue-overflow tests.
- App emergency-stop and reset-interlock tests.
- Brownout, reboot, sensor disconnect, motor-driver fault, and stuck-output tests.
- Independent clinical, electrical, risk-management, and regulatory review.
