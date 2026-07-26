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


project_dir = Path(env.subst("$PROJECT_DIR"))
values = read_env(project_dir / ".env")

passkey = values.get("VAYA_BLE_PASSKEY", "")
if not passkey.isdigit() or len(passkey) != 6 or passkey == "000000":
    raise RuntimeError(
        "Create firmware/vaya_controller/.env with a unique "
        "six-digit VAYA_BLE_PASSKEY."
    )

env.Append(CPPDEFINES=[("VAYA_BLE_PASSKEY", int(passkey))])

pairing_button = values.get("VAYA_FEATURE_PAIRING_BUTTON", "false").lower()
if pairing_button not in {"true", "false"}:
    raise RuntimeError("VAYA_FEATURE_PAIRING_BUTTON must be true or false.")
env.Append(CPPDEFINES=[("VAYA_FEATURE_PAIRING_BUTTON", int(pairing_button == "true"))])

pair_wake_pin = values.get("VAYA_PAIR_WAKE_BUTTON_PIN", "-1")
try:
    pair_wake_pin = int(pair_wake_pin)
except ValueError as error:
    raise RuntimeError("VAYA_PAIR_WAKE_BUTTON_PIN must be a GPIO number.") from error
if pair_wake_pin < -1 or pair_wake_pin > 39:
    raise RuntimeError("VAYA_PAIR_WAKE_BUTTON_PIN must be between 0 and 39.")
if pairing_button == "true" and pair_wake_pin < 0:
    raise RuntimeError(
        "Set VAYA_PAIR_WAKE_BUTTON_PIN when VAYA_FEATURE_PAIRING_BUTTON is true."
    )
env.Append(CPPDEFINES=[("VAYA_PAIR_WAKE_BUTTON_PIN", pair_wake_pin)])

upload_port = values.get("VAYA_UPLOAD_PORT", "")
if upload_port:
    env.Replace(UPLOAD_PORT=upload_port)
