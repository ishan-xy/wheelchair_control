import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';

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
  static const _reconnectDelay = Duration(seconds: 3);
  static const _maxReconnectAttempts = 5;

  final _telemetryController = StreamController<Map<String, int>>.broadcast();
  final _discoveryController = StreamController<BleDevice>.broadcast();
  final _connectionController = StreamController<bool>.broadcast();
  final _errorController = StreamController<String>.broadcast();

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
  String _connectedName = '';
  String _connectedAddress = '';
  String _lineBuffer = '';

  Stream<Map<String, int>> get telemetryStream => _telemetryController.stream;
  Stream<BleDevice> get discoveryStream => _discoveryController.stream;
  Stream<bool> get connectionStream => _connectionController.stream;
  Stream<String> get errorStream => _errorController.stream;
  bool get isConnected => _connected;
  String get connectedName => _connectedName;
  String get connectedAddress => _connectedAddress;
  BleDevice? get lastDevice => _lastDevice;

  Future<List<BleDevice>> getPairedDevices() async {
    try {
      final devices = await FlutterBluePlus.systemDevices([]);
      return devices.map(BleDevice.new).toList();
    } catch (error) {
      _report(error);
      return [];
    }
  }

  Future<void> startDiscovery() async {
    try {
      await stopDiscovery();
      _scanSub = FlutterBluePlus.onScanResults.listen((results) {
        for (final result in results) {
          _discoveryController.add(BleDevice(result.device));
        }
      });
      await FlutterBluePlus.startScan(timeout: scanDuration);
      debugPrint('[BLE] scan started');
    } catch (error) {
      _report(error);
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
      await _device!.connect(license: License.nonprofit);
      final pair = _findNus(await _device!.discoverServices());
      if (pair == null) {
        throw StateError('Nordic UART service was not found');
      }
      _rxChar = pair.rx;
      _txChar = pair.tx;
      await _startNotifications();
      _connected = true;
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

  Future<void> sendCommand(String command, {bool reliable = false}) async {
    if (!_connected || _rxChar == null) return;
    try {
      await _rxChar!.write(utf8.encode('$command\n'), withoutResponse: !reliable);
    } catch (error) {
      _report(error);
      _onConnectionLost();
    }
  }

  Future<void> dispose() async {
    _shouldReconnect = false;
    _reconnectTimer?.cancel();
    await _notifySub?.cancel();
    await _stateSub?.cancel();
    await _scanSub?.cancel();
    await _device?.disconnect();
    await _telemetryController.close();
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
      _flushTelemetryLines();
    });
  }

  void _flushTelemetryLines() {
    while (_lineBuffer.contains('\n')) {
      final index = _lineBuffer.indexOf('\n');
      _parseTelemetry(_lineBuffer.substring(0, index).trim());
      _lineBuffer = _lineBuffer.substring(index + 1);
    }
  }

  void _parseTelemetry(String line) {
    if (line.isEmpty) return;
    final data = <String, int>{};
    for (final part in line.split(',')) {
      final index = part.indexOf(':');
      if (index == -1) continue;
      final key = part.substring(0, index).trim();
      final value = int.tryParse(part.substring(index + 1).trim());
      if (key.isNotEmpty && value != null) data[key] = value;
    }
    if (data.isNotEmpty) _telemetryController.add(data);
  }

  void _handleConnectionState(BluetoothConnectionState state) {
    if (state == BluetoothConnectionState.disconnected && _connected) {
      _onConnectionLost();
    }
  }

  void _onConnectionLost() {
    if (!_connected) return;
    _connected = false;
    _rxChar = null;
    _txChar = null;
    _notifySub?.cancel();
    _notifySub = null;
    _connectionController.add(false);
    if (_shouldReconnect && _lastDevice != null) _scheduleReconnect();
  }

  void _scheduleReconnect() {
    if (_reconnectAttempts >= _maxReconnectAttempts) return;
    _reconnectTimer?.cancel();
    _reconnectTimer = Timer(_reconnectDelay, () async {
      if (!_shouldReconnect || _lastDevice == null) return;
      _reconnectAttempts++;
      final ok = await connect(_lastDevice!);
      if (!ok) _scheduleReconnect();
    });
  }

  Future<void> _cleanupConnection() async {
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
