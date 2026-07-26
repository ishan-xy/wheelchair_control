import 'package:flutter_test/flutter_test.dart';
import 'package:wheelchair_control/services/vaya_protocol.dart';

void main() {
  test('movement commands are sequenced, bounded, and CRC protected', () {
    final command = VayaProtocol.move(42, 1.5, -1.5);

    expect(command, startsWith('V2|C|42|MOVE|1000|-1000|'));
    expect(command.split('|').last, hasLength(4));
  });

  test('forget command is sequenced and CRC protected', () {
    final command = VayaProtocol.forgetBond(43);

    expect(command, startsWith('V2|C|43|FORGET|'));
    expect(command.split('|').last, hasLength(4));
  });

  test('passkey changes are sequenced and CRC protected', () {
    final command = VayaProtocol.changePasskey(44, '483921');

    expect(command, startsWith('V2|C|44|PASSKEY|483921|'));
    expect(command.split('|').last, hasLength(4));
  });

  test('new-device trust commands are sequenced and CRC protected', () {
    final command = VayaProtocol.setAllowNewDevices(45, true);

    expect(command, startsWith('V2|C|45|ALLOW_NEW|1|'));
    expect(command.split('|').last, hasLength(4));
  });

  test('decodes a valid controller acknowledgement', () {
    final frame = withCrc('V2|A|42|OK|CONNECTED_IDLE');
    final decoded = VayaProtocol.decode(frame);

    expect(decoded, isA<VayaAck>());
    final ack = decoded! as VayaAck;
    expect(ack.sequence, 42);
    expect(ack.accepted, isTrue);
    expect(ack.state, 'CONNECTED_IDLE');
  });

  test('decodes unavailable battery telemetry without inventing a value', () {
    final frame = withCrc(
      'V2|T|8|91822|CONNECTED_IDLE|NOT_CONFIGURED|0|0|-1|0|0|NONE|0|0|2.0.0',
    );
    final decoded = VayaProtocol.decode(frame);

    expect(decoded, isA<VayaTelemetry>());
    final telemetry = decoded! as VayaTelemetry;
    expect(telemetry.batteryState, 'NOT_CONFIGURED');
    expect(telemetry.batteryPercentage, -1);
    expect(telemetry.locked, isFalse);
    expect(telemetry.trustedDeviceCount, -1);
  });

  test('decodes new-device trust telemetry', () {
    final frame = withCrc(
      'V2|T|8|91822|CONNECTED_LOCKED|NOT_CONFIGURED|0|0|-1|0|0|NONE|1|0|1|2|2.0.8',
    );
    final telemetry = VayaProtocol.decode(frame)! as VayaTelemetry;

    expect(telemetry.allowNewDevices, isTrue);
    expect(telemetry.trustedDeviceCount, 2);
    expect(telemetry.firmwareVersion, '2.0.8');
    expect(telemetry.pairingWindowOpen, isFalse);
  });

  test('decodes an open physical pairing window', () {
    final frame = withCrc(
      'V2|T|8|91822|CONNECTED_LOCKED|NOT_CONFIGURED|0|0|-1|0|0|NONE|1|0|1|1|1|2.0.9',
    );
    final telemetry = VayaProtocol.decode(frame)! as VayaTelemetry;

    expect(telemetry.pairingWindowOpen, isTrue);
  });

  test('rejects a corrupted controller frame', () {
    expect(
      VayaProtocol.decode('V2|A|42|OK|CONNECTED_IDLE|0000'),
      isNull,
    );
  });
}

String withCrc(String payload) =>
    '$payload|${crc16(payload).toRadixString(16).padLeft(4, '0').toUpperCase()}';

int crc16(String value) {
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
