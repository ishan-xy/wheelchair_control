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
physical E-stop, or controller fault forces immediate zero PWM.

The app never locks a moving wheelchair. `LOCK|1` is accepted only when motor
PWM is zero and no drive target is pending; it is not a replacement for Stop or
Emergency Stop. A new BLE connection always starts locked, and movement needs a
deliberate app unlock after the chair reports stopped.

Software is not a substitute for a hardwired, normally closed emergency-stop
circuit that removes motor-driver enable/power independently of the ESP32.

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

Configure `kPhysicalEstopPin` and the real battery calibration in
`include/vaya/config.h`. Battery telemetry intentionally reports
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
V2|C|47|FORGET|<crc>
V2|C|48|PASSKEY|483921|<crc>
V2|C|49|ALLOW_NEW|1|<crc>
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
- Physical E-stop and reset-interlock tests.
- Brownout, reboot, sensor disconnect, motor-driver fault, and stuck-output tests.
- Independent clinical, electrical, risk-management, and regulatory review.
