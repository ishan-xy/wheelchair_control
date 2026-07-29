class VayaAck {
  final int sequence;
  final String result;
  final String state;

  const VayaAck({
    required this.sequence,
    required this.result,
    required this.state,
  });

  bool get accepted => result == 'OK';
}

class VayaTelemetry {
  final int sequence;
  final int controllerUptimeMs;
  final String state;
  final String batteryState;
  final int batteryRaw;
  final int batteryMillivolts;
  final int batteryPercentage;
  final int leftPwm;
  final int rightPwm;
  final String fault;
  final bool locked;
  final bool emergencyStop;
  final bool allowNewDevices;
  final int trustedDeviceCount;
  final bool pairingWindowOpen;
  final bool chargerAvailable;
  final bool charging;
  final bool sosActive;
  final String firmwareVersion;

  const VayaTelemetry({
    required this.sequence,
    required this.controllerUptimeMs,
    required this.state,
    required this.batteryState,
    required this.batteryRaw,
    required this.batteryMillivolts,
    required this.batteryPercentage,
    required this.leftPwm,
    required this.rightPwm,
    required this.fault,
    required this.locked,
    required this.emergencyStop,
    required this.allowNewDevices,
    required this.trustedDeviceCount,
    required this.pairingWindowOpen,
    required this.chargerAvailable,
    required this.charging,
    required this.sosActive,
    required this.firmwareVersion,
  });
}

class VayaProtocol {
  static String hello(int sequence) => _command(sequence, 'HELLO|2');
  static String acquire(int sequence) => _command(sequence, 'ACQUIRE');
  static String setLock(int sequence, bool locked) =>
      _command(sequence, 'LOCK|${locked ? 1 : 0}');
  static String move(int sequence, double x, double y) => _command(
        sequence,
        'MOVE|${(x.clamp(-1, 1) * 1000).round()}|'
        '${(y.clamp(-1, 1) * 1000).round()}',
      );
  static String stop(int sequence) => _command(sequence, 'STOP');
  static String emergencyStop(int sequence) => _command(sequence, 'ESTOP');
  static String setMode(int sequence, {required bool indoor}) =>
      _command(sequence, 'MODE|${indoor ? 'INDOOR' : 'OUTDOOR'}');
  static String setLimit(int sequence, int pwm) =>
      _command(sequence, 'LIMIT|${pwm.clamp(1, 255)}');
  static String forgetBond(int sequence) => _command(sequence, 'FORGET');
  static String changePasskey(int sequence, String passkey) =>
      _command(sequence, 'PASSKEY|$passkey');
  static String setAllowNewDevices(int sequence, bool allowed) =>
      _command(sequence, 'ALLOW_NEW|${allowed ? 1 : 0}');
  static String ping(int sequence) => _command(sequence, 'PING');

  static Object? decode(String frame) {
    final trimmed = frame.trim();
    final separator = trimmed.lastIndexOf('|');
    if (separator <= 0) return null;
    final payload = trimmed.substring(0, separator);
    final supplied = int.tryParse(
      trimmed.substring(separator + 1),
      radix: 16,
    );
    if (supplied == null || _crc16(payload) != supplied) return null;

    final parts = payload.split('|');
    if (parts.length < 4 || parts[0] != 'V2') return null;
    if (parts[1] == 'A' && parts.length == 5) {
      final sequence = int.tryParse(parts[2]);
      if (sequence == null) return null;
      return VayaAck(
        sequence: sequence,
        result: parts[3],
        state: parts[4],
      );
    }
    if (parts[1] == 'T' &&
        (parts.length == 15 ||
            parts.length == 17 ||
            parts.length == 18 ||
            parts.length == 21)) {
      final values = [
        int.tryParse(parts[2]),
        int.tryParse(parts[3]),
        int.tryParse(parts[6]),
        int.tryParse(parts[7]),
        int.tryParse(parts[8]),
        int.tryParse(parts[9]),
        int.tryParse(parts[10]),
      ];
      if (values.any((value) => value == null)) return null;
      return VayaTelemetry(
        sequence: values[0]!,
        controllerUptimeMs: values[1]!,
        state: parts[4],
        batteryState: parts[5],
        batteryRaw: values[2]!,
        batteryMillivolts: values[3]!,
        batteryPercentage: values[4]!,
        leftPwm: values[5]!,
        rightPwm: values[6]!,
        fault: parts[11],
        locked: parts[12] == '1',
        emergencyStop: parts[13] == '1',
        allowNewDevices: parts.length >= 17 && parts[14] == '1',
        trustedDeviceCount:
            parts.length >= 17 ? int.tryParse(parts[15]) ?? -1 : -1,
        pairingWindowOpen: parts.length >= 18 && parts[16] == '1',
        chargerAvailable: parts.length == 21 && parts[17] == '1',
        charging: parts.length == 21 && parts[18] == '1',
        sosActive: parts.length == 21 && parts[19] == '1',
        firmwareVersion: parts.length >= 17 ? parts.last : parts[14],
      );
    }
    return null;
  }

  static String _command(int sequence, String body) {
    final payload = 'V2|C|$sequence|$body';
    return '$payload|${_crc16(payload).toRadixString(16).padLeft(4, '0').toUpperCase()}';
  }

  static int _crc16(String value) {
    var crc = 0xFFFF;
    for (final byte in value.codeUnits) {
      crc ^= byte << 8;
      for (var bit = 0; bit < 8; bit++) {
        crc = (crc & 0x8000) != 0
            ? ((crc << 1) ^ 0x1021) & 0xFFFF
            : (crc << 1) & 0xFFFF;
      }
    }
    return crc;
  }
}
