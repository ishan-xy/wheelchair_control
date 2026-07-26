# VAYA Control Protocol v2

This is the shared wire contract implemented by the Flutter app and
`firmware/vaya_controller`.

## Frame format

Frames are UTF-8 ASCII terminated by `\n`:

```text
V2|<kind>|<sequence>|<fields...>|<crc16>
```

`crc16` is uppercase, four-digit CRC16-CCITT over every character before the
last separator. Sequence numbers are positive and monotonically increasing for
each BLE connection. The sequence counter belongs to the BLE transport session
and must not reset during a hot reload.

## Commands

```text
V2|C|1|HELLO|2|<crc>
V2|C|2|ACQUIRE|<crc>
V2|C|3|LOCK|0|<crc>
V2|C|4|MOVE|x_milli|y_milli|<crc>
V2|C|5|STOP|<crc>
V2|C|6|ESTOP|<crc>
V2|C|7|RESET_ESTOP|<crc>
V2|C|8|MODE|INDOOR|<crc>
V2|C|9|LIMIT|120|<crc>
V2|C|10|PING|<crc>
```

Movement values are integers from `-1000` to `1000`. Movement is never retried.
`HELLO`, `ACQUIRE`, `STOP`, `ESTOP`, and `PING` are idempotent when repeated
with the same sequence. This allows negotiation and safety commands to recover
when an acknowledgement notification is lost.

## Acknowledgements

```text
V2|A|<command_sequence>|OK|<controller_state>|<crc>
V2|A|<command_sequence>|LOCKED|<controller_state>|<crc>
```

BLE write completion means only that the local Bluetooth stack accepted a
write. A protocol `OK` acknowledgement means the controller validated and
accepted it. Actual motor state comes from telemetry.

Stable error codes include `BAD_FRAME`, `BAD_CRC`, `BAD_VERSION`,
`BAD_SEQUENCE`, `INVALID_VALUE`, `CONTROL_REQUIRED`, `LOCKED`,
`EMERGENCY_STOP_ACTIVE`, `PHYSICAL_ESTOP_REQUIRED`, and `FAULT_ACTIVE`.

## Telemetry

```text
V2|T|seq|uptime_ms|state|battery_state|raw|millivolts|percentage|
left_pwm|right_pwm|fault|locked|estop|firmware|crc
```

The frame is transmitted on one line; it is wrapped above for readability.
Battery percentage is `-1` unless `battery_state` is `AVAILABLE`.

Controller states:

- `BOOTING`
- `DISCONNECTED`
- `CONNECTED_LOCKED`
- `CONNECTED_IDLE`
- `MOVING`
- `STOPPING`
- `FAULT`
- `EMERGENCY_STOP`

Sensor states:

- `NO_DATA`
- `AVAILABLE`
- `NOT_CONFIGURED`
- `DISCONNECTED`
- `INVALID`
- `FAILED`

## Safety behavior

- The controller owns motor safety; the phone sends requests.
- Movement requires negotiation, a control lease, unlock, and fresh commands.
- Missing movement commands for 250 ms force immediate zero PWM and lock.
- BLE disconnect and lease expiry force immediate zero PWM.
- Emergency stop is latched and overrides all ordinary commands.
- Emergency reset requires a configured, released physical E-stop input.
- Invalid, corrupt, delayed, and out-of-order commands never produce movement.
- A hardwired stop must remove motor-driver enable or power independently of
  BLE, the Flutter app, and the ESP32 task scheduler.
