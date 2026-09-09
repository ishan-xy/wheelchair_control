from pathlib import Path

Import("env")


def read_env(path):
    values = {}
    if not path.exists():
        return values

    for raw_line in path.read_text(encoding="utf-8").splitlines():
        line = raw_line.strip()
        if not line or line.startswith("#") or "=" not in line:
            continue
        key, value = line.split("=", 1)
        values[key.strip()] = value.strip().strip("\"'")
    return values


def add_bool_define(values, key):
    value = values.get(key, "false").lower()
    if value not in {"true", "false"}:
        raise RuntimeError(f"{key} must be true or false.")
    env.Append(CPPDEFINES=[(key, int(value == "true"))])
    return value == "true"


def add_pin_define(values, key, required=False):
    raw = values.get(key, "-1")
    try:
        pin = int(raw)
    except ValueError as error:
        raise RuntimeError(f"{key} must be a GPIO number.") from error
    if pin < -1 or pin > 39 or (required and pin < 0):
        raise RuntimeError(f"Set {key} to a GPIO number between 0 and 39.")
    env.Append(CPPDEFINES=[(key, pin)])


project_dir = Path(env.subst("$PROJECT_DIR"))
values = read_env(project_dir / ".env")

passkey = values.get("VAYA_BLE_PASSKEY", "")
if not passkey.isdigit() or len(passkey) != 6 or passkey == "000000":
    raise RuntimeError(
        "Create firmware/vaya_controller/.env with a unique "
        "six-digit VAYA_BLE_PASSKEY."
    )

env.Append(CPPDEFINES=[("VAYA_BLE_PASSKEY", int(passkey))])

pairing_button = add_bool_define(values, "VAYA_FEATURE_PAIRING_BUTTON")
add_pin_define(values, "VAYA_PAIR_WAKE_BUTTON_PIN", pairing_button)
auto_standby = add_bool_define(values, "VAYA_FEATURE_AUTO_STANDBY")
if auto_standby and not pairing_button:
    raise RuntimeError("VAYA_FEATURE_AUTO_STANDBY requires VAYA_FEATURE_PAIRING_BUTTON=true.")
sos_button = add_bool_define(values, "VAYA_FEATURE_SOS_BUTTON")
add_pin_define(values, "VAYA_SOS_BUTTON_PIN", sos_button)
alert_indicator = add_bool_define(values, "VAYA_FEATURE_ALERT_INDICATOR")
add_pin_define(values, "VAYA_ALERT_INDICATOR_PIN", alert_indicator)
pairing_led = add_bool_define(values, "VAYA_FEATURE_PAIRING_LED")
add_pin_define(values, "VAYA_PAIRING_LED_PIN", pairing_led)
fault_led = add_bool_define(values, "VAYA_FEATURE_FAULT_LED")
add_pin_define(values, "VAYA_FAULT_LED_PIN", fault_led)
add_bool_define(values, "VAYA_FEATURE_TOPPLE_DETECTION")
charger_detection = add_bool_define(values, "VAYA_FEATURE_CHARGER_DETECTION")
add_pin_define(values, "VAYA_CHARGER_DETECT_PIN", charger_detection)

upload_port = values.get("VAYA_UPLOAD_PORT", "")
if upload_port:
    env.Replace(UPLOAD_PORT=upload_port)
