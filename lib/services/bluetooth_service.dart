import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'vaya_protocol.dart';

class BleDevice {
  final String address;
  final String? name;
  final BluetoothDevice native;

  BleDevice(this.native)
      : address = native.remoteId.str,
        name = native.platformName.isEmpty ? null : native.platformName;

  String get label => name ?? address;

  @override
  bool operator ==(Object other) =>
      identical(this, other) || other is BleDevice && other.address == address;

  @override
  int get hashCode => address.hashCode;
}

class WheelchairBluetooth {
  static final WheelchairBluetooth _instance = WheelchairBluetooth._internal();

  factory WheelchairBluetooth() => _instance;

  WheelchairBluetooth._internal();

  static const _nusServiceUuid = '6E400001-B5A3-F393-E0A9-E50E24DCCA9E';
  static const _nusTxUuid = '6E400003-B5A3-F393-E0A9-E50E24DCCA9E';
  static const _nusRxUuid = '6E400002-B5A3-F393-E0A9-E50E24DCCA9E';
  static const scanDuration = Duration(seconds: 12);
  static const securePairingTimeout = Duration(minutes: 2);
  static const _reconnectDelays = [
    Duration(seconds: 1),
    Duration(seconds: 2),
    Duration(seconds: 3),
    Duration(seconds: 5),
  ];
  static const _maxProtocolBufferLength = 512;

  final _telemetryController = StreamController<VayaTelemetry>.broadcast();
  final _ackController = StreamController<VayaAck>.broadcast();
  final _discoveryController = StreamController<BleDevice>.broadcast();
  final _connectionController = StreamController<bool>.broadcast();
  final _errorController = StreamController<String>.broadcast();
  final List<_PendingWrite> _writeQueue = [];

  BluetoothDevice? _device;
  BluetoothCharacteristic? _rxChar;
  BluetoothCharacteristic? _txChar;
  StreamSubscription? _notifySub;
  StreamSubscription? _scanSub;
  StreamSubscription? _stateSub;
  Timer? _reconnectTimer;
  BleDevice? _lastDevice;
  bool _connected = false;
  bool _shouldReconnect = false;
  int _reconnectAttempts = 0;
  int _writeEpoch = 0;
  int _nextProtocolSequence = 1;
  bool _drainingWrites = false;
  String _connectedName = '';
  String _connectedAddress = '';
  String _lineBuffer = '';

  Stream<VayaTelemetry> get telemetryStream => _telemetryController.stream;
  Stream<VayaAck> get ackStream => _ackController.stream;
  Stream<BleDevice> get discoveryStream => _discoveryController.stream;
  Stream<bool> get connectionStream => _connectionController.stream;
  Stream<String> get errorStream => _errorController.stream;
  bool get isConnected => _connected;
  String get connectedName => _connectedName;
  String get connectedAddress => _connectedAddress;
  BleDevice? get lastDevice => _lastDevice;
  bool get hasRememberedDevice => _lastDevice != null;

  /// Sequence values belong to the active BLE session rather than a screen.
  /// This prevents hot reload from replaying sequence 1 while still connected.
  int nextProtocolSequence() {
    final value = _nextProtocolSequence;
    _nextProtocolSequence =
        _nextProtocolSequence == 0x7FFFFFFF ? 1 : _nextProtocolSequence + 1;
    return value;
  }

  Future<List<BleDevice>> getPairedDevices() async {
    try {
      final devices = await FlutterBluePlus.systemDevices([
        Guid(_nusServiceUuid),
      ]);
      return {
        for (final device in devices) device.remoteId.str: BleDevice(device),
      }.values.toList();
    } catch (error) {
      _report(error);
      return [];
    }
  }

  Future<bool> startDiscovery() async {
    try {
      await stopDiscovery();
      _scanSub = FlutterBluePlus.onScanResults.listen((results) {
        for (final result in results) {
          _discoveryController.add(BleDevice(result.device));
        }
      });
      await FlutterBluePlus.startScan(
        withServices: [Guid(_nusServiceUuid)],
        timeout: scanDuration,
      );
      debugPrint('[BLE] scan started');
      return true;
    } catch (error) {
      _report(error);
      return false;
    }
  }

  Future<void> stopDiscovery() async {
    try {
      await FlutterBluePlus.stopScan();
      await _scanSub?.cancel();
      _scanSub = null;
    } catch (error) {
      _report(error);
    }
  }

  Future<bool> connect(BleDevice device) async {
    try {
      await _cleanupConnection();
      _device = device.native;
      _stateSub = _device!.connectionState.listen(_handleConnectionState);
      debugPrint('[BLE] connecting to ${device.label}');
      await _device!.connect(
        license: License.nonprofit,
        timeout: securePairingTimeout,
      );
      final pair = _findNus(await _device!.discoverServices());
      if (pair == null) {
        throw StateError('Nordic UART service was not found');
      }
      _rxChar = pair.rx;
      _txChar = pair.tx;
      await _startNotifications();
      _connected = true;
      _nextProtocolSequence = 1;
      _connectedName = device.label;
      _connectedAddress = device.address;
      _lastDevice = device;
      _shouldReconnect = true;
      _reconnectAttempts = 0;
      _connectionController.add(true);
      debugPrint('[BLE] connected to $_connectedName');
      return true;
    } catch (error) {
      _report(error);
      await _cleanupConnection();
      _connected = false;
      _connectionController.add(false);
      return false;
    }
  }

  Future<void> disconnect() async {
    _shouldReconnect = false;
    _reconnectAttempts = 0;
    _reconnectTimer?.cancel();
    _reconnectTimer = null;
    await _cleanupConnection();
    _connected = false;
    _connectedName = '';
    _connectedAddress = '';
    _connectionController.add(false);
  }

  Future<void> forgetDevice() async {
    final device = _lastDevice?.native ?? _device;
    _lastDevice = null;
    await disconnect();

    if (!kIsWeb &&
        defaultTargetPlatform == TargetPlatform.android &&
        device != null) {
      try {
        await device.removeBond();
      } catch (error) {
        debugPrint('[BLE] Android bond removal was not completed: $error');
      }
    }
  }

  void suspendReconnect() {
    _shouldReconnect = false;
    _reconnectTimer?.cancel();
    _reconnectTimer = null;
  }

  void resumeReconnect() {
    if (_lastDevice != null) _shouldReconnect = true;
  }

  Future<bool> sendCommand(
    String command, {
    bool reliable = false,
    bool safetyBarrier = false,
  }) =>
      _enqueueWrite(
        command,
        reliable: reliable,
        kind: _WriteKind.command,
        safetyBarrier: safetyBarrier,
      );

  Future<bool> sendMovementCommand(String command) => _enqueueWrite(
        command,
        reliable: false,
        kind: _WriteKind.movement,
      );

  Future<void> dispose() async {
    _shouldReconnect = false;
    _reconnectTimer?.cancel();
    await _notifySub?.cancel();
    await _stateSub?.cancel();
    await _scanSub?.cancel();
    await _device?.disconnect();
    await _telemetryController.close();
    await _ackController.close();
    await _discoveryController.close();
    await _connectionController.close();
    await _errorController.close();
  }

  _NusPair? _findNus(List<BluetoothService> services) {
    BluetoothCharacteristic? rx;
    BluetoothCharacteristic? tx;
    for (final service in services) {
      if (!_sameUuid(service.uuid.toString(), _nusServiceUuid)) continue;
      for (final c in service.characteristics) {
        final uuid = c.uuid.toString();
        if (_sameUuid(uuid, _nusRxUuid)) rx = c;
        if (_sameUuid(uuid, _nusTxUuid)) tx = c;
      }
    }
    return rx == null || tx == null ? null : _NusPair(rx, tx);
  }

  Future<void> _startNotifications() async {
    await _txChar!.setNotifyValue(true);
    _notifySub = _txChar!.lastValueStream.listen((bytes) {
      if (bytes.isEmpty) return;
      _lineBuffer += utf8.decode(bytes, allowMalformed: true);
      if (_lineBuffer.length > _maxProtocolBufferLength) {
        _lineBuffer = '';
        _report(StateError('Controller protocol frame exceeded safe limit'));
        return;
      }
      _flushTelemetryLines();
    });
  }

  void _flushTelemetryLines() {
    while (_lineBuffer.contains('\n')) {
      final index = _lineBuffer.indexOf('\n');
      _parseProtocolLine(_lineBuffer.substring(0, index).trim());
      _lineBuffer = _lineBuffer.substring(index + 1);
    }
  }

  void _parseProtocolLine(String line) {
    if (line.isEmpty) return;
    final decoded = VayaProtocol.decode(line);
    if (decoded is VayaTelemetry) {
      _telemetryController.add(decoded);
    } else if (decoded is VayaAck) {
      _ackController.add(decoded);
    }
  }

  void _handleConnectionState(BluetoothConnectionState state) {
    if (state == BluetoothConnectionState.disconnected && _connected) {
      _onConnectionLost();
    }
  }

  void _onConnectionLost() {
    if (!_connected) return;
    _connected = false;
    _writeEpoch++;
    _failQueuedWrites();
    _rxChar = null;
    _txChar = null;
    _notifySub?.cancel();
    _notifySub = null;
    _connectionController.add(false);
    if (_shouldReconnect && _lastDevice != null) _scheduleReconnect();
  }

  void _scheduleReconnect() {
    _reconnectTimer?.cancel();
    final delay = _reconnectDelays[_reconnectAttempts < _reconnectDelays.length
        ? _reconnectAttempts
        : _reconnectDelays.length - 1];
    _reconnectTimer = Timer(delay, () async {
      if (!_shouldReconnect || _lastDevice == null) return;
      _reconnectAttempts++;
      final ok = await connect(_lastDevice!);
      if (!ok) _scheduleReconnect();
    });
  }

  Future<void> _cleanupConnection() async {
    _writeEpoch++;
    _failQueuedWrites();
    await _notifySub?.cancel();
    await _stateSub?.cancel();
    _notifySub = null;
    _stateSub = null;
    _lineBuffer = '';
    _rxChar = null;
    _txChar = null;
    try {
      await _device?.disconnect();
    } catch (_) {}
    _device = null;
  }

  bool _sameUuid(String a, String b) => a.toUpperCase() == b.toUpperCase();

  Future<bool> _enqueueWrite(
    String command, {
    required bool reliable,
    required _WriteKind kind,
    bool safetyBarrier = false,
  }) {
    if (!_connected || _rxChar == null) return Future.value(false);

    final pending = _PendingWrite(
      bytes: utf8.encode('$command\n'),
      reliable: reliable,
      kind: kind,
      epoch: _writeEpoch,
    );

    if (safetyBarrier) {
      _failQueuedWrites();
      _writeQueue.add(pending);
    } else if (kind == _WriteKind.movement &&
        _writeQueue.isNotEmpty &&
        _writeQueue.last.kind == _WriteKind.movement) {
      final replaced = _writeQueue.removeLast();
      replaced.complete(false);
      _writeQueue.add(pending);
    } else {
      _writeQueue.add(pending);
    }

    unawaited(_drainWrites());
    return pending.result;
  }

  Future<void> _drainWrites() async {
    if (_drainingWrites) return;
    _drainingWrites = true;
    try {
      while (_writeQueue.isNotEmpty) {
        final pending = _writeQueue.removeAt(0);
        final characteristic = _rxChar;
        if (!_connected ||
            characteristic == null ||
            pending.epoch != _writeEpoch) {
          pending.complete(false);
          continue;
        }

        try {
          await characteristic.write(
            pending.bytes,
            withoutResponse: !pending.reliable,
          );
          pending.complete(
            _connected &&
                characteristic == _rxChar &&
                pending.epoch == _writeEpoch,
          );
        } catch (error) {
          pending.complete(false);
          if (pending.epoch == _writeEpoch) {
            _report(error);
            _onConnectionLost();
          }
        }
      }
    } finally {
      _drainingWrites = false;
      if (_writeQueue.isNotEmpty) unawaited(_drainWrites());
    }
  }

  void _failQueuedWrites() {
    for (final pending in _writeQueue) {
      pending.complete(false);
    }
    _writeQueue.clear();
  }

  void _report(Object error) {
    final message = error.toString();
    debugPrint('[BLE] $message');
    if (!_errorController.isClosed) _errorController.add(message);
  }
}

class _NusPair {
  final BluetoothCharacteristic rx;
  final BluetoothCharacteristic tx;

  const _NusPair(this.rx, this.tx);
}

enum _WriteKind { command, movement }

class _PendingWrite {
  final List<int> bytes;
  final bool reliable;
  final _WriteKind kind;
  final int epoch;
  final Completer<bool> _completer = Completer<bool>();

  _PendingWrite({
    required this.bytes,
    required this.reliable,
    required this.kind,
    required this.epoch,
  });

  Future<bool> get result => _completer.future;

  void complete(bool value) {
    if (!_completer.isCompleted) _completer.complete(value);
  }
}
