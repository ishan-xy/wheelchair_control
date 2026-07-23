import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:permission_handler/permission_handler.dart';
import '../services/bluetooth_service.dart';
import '../services/wheelchair_commands.dart';

class AppState extends ChangeNotifier {
  final WheelchairBluetooth _bt;

  AppState({WheelchairBluetooth? bluetooth})
      : _bt = bluetooth ?? WheelchairBluetooth() {
    _connectionSub = _bt.connectionStream.listen(_handleConnectionChange);
    _errorSub = _bt.errorStream.listen(_setError);
  }

  final _knownDevices = <BleDevice>[];
  final _nearbyDevices = <BleDevice>[];
  StreamSubscription<Map<String, int>>? _telemetrySub;
  StreamSubscription<BleDevice>? _discoverySub;
  StreamSubscription<bool>? _connectionSub;
  StreamSubscription<String>? _errorSub;
  Timer? _scanTimer;
  bool _disposed = false;

  bool isScanning = false;
  bool isConnecting = false;
  bool isReconnecting = false;
  bool isLoadingDevices = false;
  int battery = 0;
  int currentSpeed = 0;
  double sensitivity = 0.5;
  double maxSpeedMph = 5;
  bool autoStop = true;
  String? errorMessage;

  bool get isConnected => _bt.isConnected;
  String get connectedDeviceName => _bt.connectedName;
  String get connectedDeviceAddress => _bt.connectedAddress;
  List<BleDevice> get pairedDevices => List.unmodifiable(_knownDevices);
  List<BleDevice> get discoveredDevices => List.unmodifiable(_nearbyDevices);

  Future<bool> hasRequiredPermissions() async {
    final platform = defaultTargetPlatform;

    if (kIsWeb ||
        platform == TargetPlatform.iOS ||
        platform == TargetPlatform.macOS) {
      return true;
    }

    if (platform != TargetPlatform.android) return true;

    final statuses = await Future.wait([
      Permission.bluetoothScan,
      Permission.bluetoothConnect,
      Permission.locationWhenInUse,
    ].map((permission) => permission.status));

    return statuses.every(_permissionReady);
  }

  Future<bool> requestPermissions() async {
    errorMessage = null;

    final platform = defaultTargetPlatform;

    if (kIsWeb ||
        platform == TargetPlatform.iOS ||
        platform == TargetPlatform.macOS) {
      _safeNotify();
      return true;
    }

    final permissions = platform == TargetPlatform.android
        ? [
            Permission.bluetoothScan,
            Permission.bluetoothConnect,
            Permission.locationWhenInUse,
          ]
        : <Permission>[];

    if (permissions.isEmpty) return true;

    final statuses = await permissions.request();

    final blocked = statuses.values.any(
      (status) =>
          status.isDenied || status.isPermanentlyDenied || status.isRestricted,
    );

    if (!blocked) {
      _safeNotify();
      return true;
    }

    final permanentlyBlocked = statuses.values.any(
      (status) => status.isPermanentlyDenied || status.isRestricted,
    );

    _setError(
      permanentlyBlocked
          ? 'Bluetooth permissions are blocked. Enable them from app settings.'
          : 'Bluetooth and Location permissions are required to scan.',
    );
    return false;
  }

  bool _permissionReady(PermissionStatus status) =>
      status.isGranted || status.isLimited || status.isProvisional;

  Future<void> loadPairedDevices() async {
    if (!await requestPermissions()) return;
    isLoadingDevices = true;
    _safeNotify();
    final devices = await _bt.getPairedDevices();
    _replaceDevices(_knownDevices, devices);
    isLoadingDevices = false;
    _safeNotify();
  }

  Future<void> startScan() async {
    if (isScanning || !await requestPermissions()) return;
    errorMessage = null;
    _nearbyDevices.clear();
    isScanning = true;
    _safeNotify();
    await _discoverySub?.cancel();
    _discoverySub = _bt.discoveryStream.listen(_upsertNearbyDevice);
    await _bt.startDiscovery();
    _scanTimer?.cancel();
    _scanTimer = Timer(
        WheelchairBluetooth.scanDuration + const Duration(seconds: 1), () {
      if (isScanning) unawaited(stopScan());
    });
  }

  Future<void> stopScan() async {
    _scanTimer?.cancel();
    _scanTimer = null;
    await _bt.stopDiscovery();
    await _discoverySub?.cancel();
    _discoverySub = null;
    isScanning = false;
    _safeNotify();
  }

  Future<bool> connectTo(BleDevice device) async {
    if (isConnecting) return false;
    if (isScanning) await stopScan();
    errorMessage = null;
    isConnecting = true;
    isReconnecting = false;
    _safeNotify();
    await _startTelemetry();
    final success = await _bt.connect(device);
    if (!success) await _stopTelemetry();
    isConnecting = false;
    _safeNotify();
    return success;
  }

  Future<void> disconnect() async {
    await _stopTelemetry();
    await _bt.disconnect();
    _resetTelemetry();
    isConnecting = false;
    isReconnecting = false;
    _safeNotify();
  }

  Future<void> sendCommand(String command, {bool reliable = false}) =>
      _bt.sendCommand(command, reliable: reliable);

  void setSensitivity(double value) {
    sensitivity = value.clamp(0.1, 1.0).toDouble();
    _safeNotify();
  }

  void setMaxSpeed(double value) {
    maxSpeedMph = value.clamp(1, 10).toDouble();
    unawaited(sendCommand(WheelchairCommands.maxSpeedMph(maxSpeedMph.round())));
    _safeNotify();
  }

  void setAutoStop(bool value) {
    autoStop = value;
    unawaited(sendCommand(WheelchairCommands.autoStop(value), reliable: true));
    _safeNotify();
  }

  Future<void> _startTelemetry() async {
    await _stopTelemetry();
    _telemetrySub = _bt.telemetryStream.listen((data) {
      final nextBattery = data['BAT'] ?? battery;
      final nextSpeed = data['SPD'] ?? currentSpeed;
      if (nextBattery == battery && nextSpeed == currentSpeed) return;
      battery = nextBattery.clamp(0, 100).toInt();
      currentSpeed = nextSpeed;
      _safeNotify();
    });
  }

  Future<void> _stopTelemetry() async {
    await _telemetrySub?.cancel();
    _telemetrySub = null;
  }

  void _handleConnectionChange(bool connected) {
    if (connected) {
      isReconnecting = false;
      _safeNotify();
      return;
    }
    if (!isConnecting) {
      _resetTelemetry();
      isReconnecting = _bt.lastDevice != null;
      _safeNotify();
    }
  }

  void _upsertNearbyDevice(BleDevice device) {
    if (_knownDevices.any((d) => d.address == device.address)) return;
    final index = _nearbyDevices.indexWhere((d) => d.address == device.address);
    if (index == -1) {
      _nearbyDevices.add(device);
    } else if (_nearbyDevices[index].name == null && device.name != null) {
      _nearbyDevices[index] = device;
    } else {
      return;
    }
    _safeNotify();
  }

  void _replaceDevices(List<BleDevice> target, List<BleDevice> source) {
    target
      ..clear()
      ..addAll(source);
  }

  void _resetTelemetry() {
    battery = 0;
    currentSpeed = 0;
  }

  void _setError(String message) {
    errorMessage = message;
    _safeNotify();
  }

  void _safeNotify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _scanTimer?.cancel();
    _telemetrySub?.cancel();
    _discoverySub?.cancel();
    _connectionSub?.cancel();
    _errorSub?.cancel();
    unawaited(_bt.dispose());
    super.dispose();
  }
}
