import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:local_auth/local_auth.dart';
import 'package:permission_handler/permission_handler.dart';
import '../models/wheelchair_runtime.dart';
import '../services/bluetooth_service.dart';
import '../services/vaya_protocol.dart';

enum EmergencySignalSource { physicalButton, app }

class AppState extends ChangeNotifier {
  final WheelchairBluetooth _bt;
  final LocalAuthentication _localAuthentication;

  AppState({
    WheelchairBluetooth? bluetooth,
    LocalAuthentication? localAuthentication,
  })  : _bt = bluetooth ?? WheelchairBluetooth(),
        _localAuthentication = localAuthentication ?? LocalAuthentication() {
    _connectionSub = _bt.connectionStream.listen(_handleConnectionChange);
    _errorSub = _bt.errorStream.listen(_setError);
    _ackSub = _bt.ackStream.listen(_handleAck);
    if (_bt.isConnected) unawaited(_restoreActiveConnection());
  }

  final _knownDevices = <BleDevice>[];
  final _nearbyDevices = <BleDevice>[];
  StreamSubscription<VayaTelemetry>? _telemetrySub;
  StreamSubscription<BleDevice>? _discoverySub;
  StreamSubscription<bool>? _connectionSub;
  StreamSubscription<String>? _errorSub;
  StreamSubscription<VayaAck>? _ackSub;
  final Map<int, Completer<VayaAck>> _pendingAcks = {};
  final _emergencySignalController =
      StreamController<EmergencySignalSource>.broadcast();
  Timer? _scanTimer;
  Timer? _healthTimer;
  Timer? _controlHeartbeat;
  bool _disposed = false;
  DateTime? _batteryUpdatedAt;
  DateTime? _speedUpdatedAt;
  final Stopwatch _controlClock = Stopwatch()..start();
  int? _lastMovementCommandMs;
  bool _recoveringControl = false;
  bool isChangingPasskey = false;
  bool isAuthenticating = false;
  bool isUpdatingWheelchairLock = false;
  bool isUpdatingNewDeviceTrust = false;

  static const telemetryFreshness = Duration(seconds: 3);

  bool isScanning = false;
  bool isConnecting = false;
  bool isReconnecting = false;
  bool isLoadingDevices = false;
  bool protocolReady = false;
  bool requiresSystemPairingReset = false;
  String? systemPairingResetMessage;
  int battery = 0;
  int currentSpeed = 0;
  double sensitivity = 0.5;
  String controllerState = 'DISCONNECTED';
  String batterySensorState = 'NO_DATA';
  String faultCode = 'NONE';
  String firmwareVersion = '';
  bool isLocked = true;
  bool emergencyStopActive = false;
  bool allowNewDevices = false;
  int trustedDeviceCount = 0;
  bool pairingWindowOpen = false;
  bool chargerDetectionAvailable = false;
  bool isCharging = false;
  bool sosActive = false;
  bool sosNeedsAcknowledgement = false;
  String? errorMessage;

  bool get isConnected => _bt.isConnected;
  Stream<EmergencySignalSource> get emergencySignalStream =>
      _emergencySignalController.stream;
  String get connectedDeviceName => _bt.connectedName;
  String get connectedDeviceAddress => _bt.connectedAddress;
  bool get hasRememberedWheelchair => _bt.hasRememberedDevice;
  List<BleDevice> get pairedDevices => List.unmodifiable(_knownDevices);
  List<BleDevice> get discoveredDevices => List.unmodifiable(_nearbyDevices);
  bool get canDrive =>
      isConnected &&
      protocolReady &&
      !isLocked &&
      !emergencyStopActive &&
      !isCharging &&
      faultCode == 'NONE';
  List<DriveReadinessCheck> get driveReadiness => [
        DriveReadinessCheck(
          label: 'Connection',
          detail: isConnected && protocolReady
              ? 'Safety connection active'
              : 'Connect to the wheelchair',
          ready: isConnected && protocolReady,
        ),
        DriveReadinessCheck(
          label: 'Lock state',
          detail: isLocked ? 'Unlock when it is safe to drive' : 'Unlocked',
          ready: !isLocked,
        ),
        DriveReadinessCheck(
          label: 'Movement',
          detail: motionStatus == WheelchairMotionStatus.stopped
              ? 'Stopped'
              : 'Confirm the wheelchair is stopped',
          ready: motionStatus == WheelchairMotionStatus.stopped,
        ),
        DriveReadinessCheck(
          label: 'Safety state',
          detail: emergencyStopActive
              ? 'Emergency stop is active'
              : isCharging
                  ? 'Charging is connected'
                  : faultCode == 'NONE'
                      ? 'No fault reported'
                      : 'Wheelchair fault reported',
          ready: !emergencyStopActive && !isCharging && faultCode == 'NONE',
        ),
        DriveReadinessCheck(
          label: 'Battery',
          detail: batteryStatus == TelemetryStatus.current
              ? '$battery% reported'
              : 'Battery information unavailable',
          ready: batteryStatus == TelemetryStatus.current,
        ),
      ];
  bool get isDriveChecklistComplete =>
      driveReadiness.every((check) => check.ready);
  bool get isWheelchairAtRest =>
      speedStatus == TelemetryStatus.current &&
      currentSpeed == 0 &&
      (controllerState == 'CONNECTED_IDLE' ||
          controllerState == 'CONNECTED_LOCKED');
  bool get canChangeWheelchairLock =>
      isConnected &&
      protocolReady &&
      !isUpdatingWheelchairLock &&
      !emergencyStopActive &&
      !isCharging &&
      faultCode == 'NONE' &&
      isWheelchairAtRest;
  bool get canChangeNewDeviceTrust =>
      canChangeWheelchairLock &&
      supportsNewDeviceTrust &&
      !isUpdatingNewDeviceTrust;
  bool get supportsNewDeviceTrust {
    final parts = firmwareVersion.split('.');
    if (parts.length != 3) return false;
    final major = int.tryParse(parts[0]);
    final minor = int.tryParse(parts[1]);
    final patch = int.tryParse(parts[2]);
    if (major == null || minor == null || patch == null) return false;
    return major > 2 || (major == 2 && (minor > 0 || patch >= 8));
  }

  ConnectionStatus get connectionStatus {
    if (isConnecting) return ConnectionStatus.connecting;
    if (isConnected && protocolReady) return ConnectionStatus.connected;
    if (isReconnecting) return ConnectionStatus.reconnecting;
    if (isScanning) return ConnectionStatus.scanning;
    return ConnectionStatus.disconnected;
  }

  TelemetryStatus get batteryStatus => _telemetryStatus(_batteryUpdatedAt);
  TelemetryStatus get speedStatus => _telemetryStatus(_speedUpdatedAt);

  WheelchairMotionStatus get motionStatus {
    if (!isConnected) return WheelchairMotionStatus.unavailable;
    if (speedStatus != TelemetryStatus.current) {
      return WheelchairMotionStatus.unknown;
    }
    return switch (controllerState) {
      'MOVING' => WheelchairMotionStatus.moving,
      'STOPPING' => currentSpeed == 0
          ? WheelchairMotionStatus.stopped
          : WheelchairMotionStatus.moving,
      'CONNECTED_IDLE' || 'CONNECTED_LOCKED' => WheelchairMotionStatus.stopped,
      _ => WheelchairMotionStatus.unknown,
    };
  }

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
    if (isScanning || isConnecting || !await requestPermissions()) return;
    errorMessage = null;
    _nearbyDevices.clear();
    isScanning = true;
    _safeNotify();
    await _discoverySub?.cancel();
    _discoverySub = _bt.discoveryStream.listen(_upsertNearbyDevice);
    final started = await _bt.startDiscovery();
    if (!started) {
      isScanning = false;
      _safeNotify();
      return;
    }
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
    requiresSystemPairingReset = false;
    systemPairingResetMessage = null;
    isConnecting = true;
    isReconnecting = false;
    _safeNotify();
    await _startTelemetry();
    final success = await _bt.connect(device);
    final negotiated = success && await _negotiateProtocol();
    if (!negotiated) {
      if (success) await _bt.disconnect();
      await _stopTelemetry();
      protocolReady = false;
      errorMessage ??=
          'The wheelchair did not complete its safety connection. Try again.';
    }
    isConnecting = false;
    if (negotiated) {
      errorMessage = null;
      requiresSystemPairingReset = false;
      systemPairingResetMessage = null;
    }
    _safeNotify();
    return negotiated;
  }

  Future<void> disconnect() async {
    if (isConnected && protocolReady) {
      await _sendConfirmed(
        VayaProtocol.stop,
        safetyBarrier: true,
      );
    }
    await _stopTelemetry();
    await _bt.disconnect();
    _resetTelemetry();
    protocolReady = false;
    isConnecting = false;
    isReconnecting = false;
    _safeNotify();
  }

  Future<bool> forgetWheelchair() async {
    if (!isConnected || !protocolReady) return false;
    if (!await stopWheelchair()) return false;

    _bt.suspendReconnect();
    final disconnected = _bt.connectionStream
        .firstWhere((connected) => !connected)
        .timeout(const Duration(seconds: 3));
    final forgotten = await _sendConfirmed(
      VayaProtocol.forgetBond,
      safetyBarrier: true,
    );
    if (forgotten?.accepted != true) {
      _bt.resumeReconnect();
      return false;
    }

    try {
      await disconnected;
    } on TimeoutException {
      _bt.resumeReconnect();
      return false;
    }

    await _stopTelemetry();
    await _bt.forgetDevice();
    _knownDevices.clear();
    _nearbyDevices.clear();
    _resetTelemetry();
    protocolReady = false;
    isConnecting = false;
    isReconnecting = false;
    errorMessage = null;
    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.iOS) {
      requiresSystemPairingReset = true;
      systemPairingResetMessage =
          'The wheelchair was removed, but this iPhone still has its old '
          'Bluetooth pairing. Open Settings > Bluetooth, tap VAYA One, and '
          'choose Forget This Device before connecting again.';
    }
    _safeNotify();
    return true;
  }

  Future<bool> sendMovement(double x, double y) {
    if (!canDrive) return Future.value(false);
    _lastMovementCommandMs = _controlClock.elapsedMilliseconds;
    return _bt.sendMovementCommand(
      VayaProtocol.move(_takeSequence(), x, y),
    );
  }

  Future<bool> stopWheelchair() async {
    if (!isConnected || !protocolReady) return false;
    final ack = await _sendConfirmed(
      VayaProtocol.stop,
      retries: 1,
      safetyBarrier: true,
    );
    if (ack?.accepted != true) return false;
    if (faultCode == 'COMMAND_TIMEOUT') {
      return _recoverControlAfterWatchdog();
    }
    return true;
  }

  Future<bool> emergencyStop() async {
    if (!isConnected || !protocolReady) return false;
    final ack = await _sendConfirmed(
      VayaProtocol.emergencyStop,
      retries: 2,
      safetyBarrier: true,
    );
    return ack?.accepted ?? false;
  }

  void requestEmergencyAssistance() {
    _emergencySignalController.add(EmergencySignalSource.app);
  }

  void acknowledgeSosAlert() {
    if (!sosNeedsAcknowledgement) return;
    sosNeedsAcknowledgement = false;
    _safeNotify();
  }

  Future<bool> setDriveMode({required bool indoor}) async {
    if (!canDrive) return false;
    final ack = await _sendConfirmed(
      (sequence) => VayaProtocol.setMode(sequence, indoor: indoor),
    );
    return ack?.accepted ?? false;
  }

  Future<bool> setWheelchairLocked(bool locked) async {
    if (!canChangeWheelchairLock) return false;
    if (!locked &&
        !await _authenticateCaregiver(
          'Confirm your identity to unlock VAYA One.',
        )) {
      return false;
    }
    isUpdatingWheelchairLock = true;
    _safeNotify();
    try {
      final ack = await _sendWithLeaseRecovery(
        (sequence) => VayaProtocol.setLock(sequence, locked),
        safetyBarrier: true,
      );
      if (ack?.accepted != true) return false;
      isLocked = locked;
      if (locked) _lastMovementCommandMs = null;
      return true;
    } finally {
      isUpdatingWheelchairLock = false;
      _safeNotify();
    }
  }

  Future<bool> changePasskey(String passkey) async {
    if (!RegExp(r'^[1-9][0-9]{5}$').hasMatch(passkey)) {
      errorMessage =
          'Choose a six-digit passkey that does not start with zero.';
      _safeNotify();
      return false;
    }
    if (!isConnected || !protocolReady || isChangingPasskey) return false;
    if (!await _authenticateCaregiver(
      'Confirm your identity to change the wheelchair passkey.',
    )) {
      return false;
    }
    if (!await stopWheelchair()) {
      errorMessage =
          'The wheelchair must be stopped before changing its passkey.';
      _safeNotify();
      return false;
    }
    if (!await _waitForWheelchairRest()) {
      errorMessage =
          'Wait for the wheelchair to stop completely, then change its passkey.';
      _safeNotify();
      return false;
    }

    isChangingPasskey = true;
    errorMessage = null;
    _bt.suspendReconnect();
    _safeNotify();
    final disconnected = _bt.connectionStream
        .firstWhere((connected) => !connected)
        .timeout(const Duration(seconds: 4));
    final acknowledgement = await _sendWithLeaseRecovery(
      (sequence) => VayaProtocol.changePasskey(sequence, passkey),
      safetyBarrier: true,
    );
    if (acknowledgement?.accepted != true) {
      isChangingPasskey = false;
      _bt.resumeReconnect();
      errorMessage = _passkeyChangeFailure(acknowledgement?.result);
      _safeNotify();
      return false;
    }

    try {
      await disconnected;
    } on TimeoutException {
      isChangingPasskey = false;
      _bt.resumeReconnect();
      errorMessage =
          'The new passkey may have been saved, but the wheelchair did not complete '
          'the required disconnection. '
          'Turn the wheelchair off and on, then connect with the new passkey.';
      _safeNotify();
      return false;
    }

    await _stopTelemetry();
    await _bt.forgetDevice();
    _knownDevices.clear();
    _nearbyDevices.clear();
    _resetTelemetry();
    protocolReady = false;
    isChangingPasskey = false;
    isConnecting = false;
    isReconnecting = false;
    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.iOS) {
      requiresSystemPairingReset = true;
      systemPairingResetMessage =
          'The wheelchair passkey changed, but this iPhone still has the old '
          'Bluetooth pairing. Open Settings > Bluetooth, tap VAYA One, and '
          'choose Forget This Device before connecting with the new passkey.';
    }
    _safeNotify();
    return true;
  }

  Future<bool> setAllowNewDevices(bool allowed) async {
    if (!canChangeNewDeviceTrust) return false;
    isUpdatingNewDeviceTrust = true;
    _safeNotify();
    try {
      final acknowledgement = await _sendWithLeaseRecovery(
        (sequence) => VayaProtocol.setAllowNewDevices(sequence, allowed),
        safetyBarrier: true,
      );
      if (acknowledgement?.accepted != true) return false;
      allowNewDevices = allowed;
      return true;
    } finally {
      isUpdatingNewDeviceTrust = false;
      _safeNotify();
    }
  }

  void setSensitivity(double value) {
    sensitivity = value.clamp(0.1, 1.0).toDouble();
    _safeNotify();
  }

  Future<void> _startTelemetry() async {
    await _stopTelemetry();
    _telemetrySub = _bt.telemetryStream.listen((data) {
      final now = DateTime.now();
      controllerState = data.state;
      batterySensorState = data.batteryState;
      faultCode = data.fault;
      firmwareVersion = data.firmwareVersion;
      isLocked = data.locked;
      emergencyStopActive = data.emergencyStop;
      allowNewDevices = data.allowNewDevices;
      trustedDeviceCount = data.trustedDeviceCount < 0
          ? trustedDeviceCount
          : data.trustedDeviceCount;
      pairingWindowOpen = data.pairingWindowOpen;
      chargerDetectionAvailable = data.chargerAvailable;
      isCharging = data.charging;
      final newSosSignal = data.sosActive && !sosActive;
      sosActive = data.sosActive;
      if (newSosSignal) {
        sosNeedsAcknowledgement = true;
        _emergencySignalController.add(EmergencySignalSource.physicalButton);
      }
      _speedUpdatedAt = now;
      currentSpeed = data.leftPwm.abs() > data.rightPwm.abs()
          ? data.leftPwm.abs()
          : data.rightPwm.abs();
      if (data.batteryState == 'AVAILABLE' && data.batteryPercentage >= 0) {
        battery = data.batteryPercentage.clamp(0, 100);
        _batteryUpdatedAt = now;
      } else {
        _batteryUpdatedAt = null;
      }
      _safeNotify();
    });
    _healthTimer?.cancel();
    _healthTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (isConnected) _safeNotify();
    });
  }

  Future<void> _stopTelemetry() async {
    await _telemetrySub?.cancel();
    _telemetrySub = null;
    _healthTimer?.cancel();
    _healthTimer = null;
    _controlHeartbeat?.cancel();
    _controlHeartbeat = null;
  }

  Future<bool> _authenticateCaregiver(String reason) async {
    if (isAuthenticating) return false;
    isAuthenticating = true;
    errorMessage = null;
    _safeNotify();
    try {
      if (!await _localAuthentication.isDeviceSupported()) {
        errorMessage =
            'Set up a device passcode, Face ID, or fingerprint before changing this safety setting.';
        return false;
      }
      final confirmed = await _localAuthentication.authenticate(
        localizedReason: reason,
        biometricOnly: false,
        persistAcrossBackgrounding: true,
        sensitiveTransaction: true,
      );
      if (!confirmed) errorMessage = 'Identity confirmation was not completed.';
      return confirmed;
    } on LocalAuthException {
      errorMessage =
          'Identity confirmation is unavailable. Check the phone security settings and try again.';
      return false;
    } catch (_) {
      errorMessage = 'Identity confirmation could not be completed.';
      return false;
    } finally {
      isAuthenticating = false;
      _safeNotify();
    }
  }

  void _handleConnectionChange(bool connected) {
    if (connected) {
      isReconnecting = false;
      if (!isConnecting && !protocolReady) unawaited(_recoverProtocol());
      _safeNotify();
      return;
    }
    if (!isConnecting) {
      _controlHeartbeat?.cancel();
      _controlHeartbeat = null;
      _resetTelemetry();
      protocolReady = false;
      isReconnecting = _bt.lastDevice != null;
      _safeNotify();
    }
  }

  Future<void> _recoverProtocol() async {
    isReconnecting = true;
    _safeNotify();
    final ready = await _negotiateProtocol();
    if (!ready) {
      protocolReady = false;
      errorMessage =
          'The wheelchair reconnected but did not complete its safety check.';
    }
    isReconnecting = false;
    _safeNotify();
  }

  Future<void> _restoreActiveConnection() async {
    isReconnecting = true;
    _safeNotify();
    await _startTelemetry();
    await _recoverProtocol();
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
    _batteryUpdatedAt = null;
    _speedUpdatedAt = null;
    controllerState = 'DISCONNECTED';
    batterySensorState = 'NO_DATA';
    faultCode = 'NONE';
    firmwareVersion = '';
    isLocked = true;
    emergencyStopActive = false;
    allowNewDevices = false;
    trustedDeviceCount = 0;
    pairingWindowOpen = false;
    chargerDetectionAvailable = false;
    isCharging = false;
    sosActive = false;
    _lastMovementCommandMs = null;
  }

  Future<bool> _negotiateProtocol() async {
    final hello = await _sendConfirmed(VayaProtocol.hello, retries: 1);
    if (hello?.accepted != true) return false;
    if (!await _acquireControlLease()) return false;
    _startControlHeartbeat();
    return true;
  }

  Future<bool> _acquireControlLease() async {
    final acquire = await _sendConfirmed(VayaProtocol.acquire, retries: 1);
    if (acquire?.accepted != true) return false;
    // A lease is deliberately locked. The caregiver must unlock from Status.
    protocolReady = true;
    isLocked = true;
    return true;
  }

  void _startControlHeartbeat() {
    _controlHeartbeat?.cancel();
    _controlHeartbeat = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!isConnected || !protocolReady) return;
      final lastMovementMs = _lastMovementCommandMs;
      if (lastMovementMs != null &&
          _controlClock.elapsedMilliseconds - lastMovementMs < 750) {
        return;
      }
      unawaited(
        _bt.sendCommand(VayaProtocol.ping(_takeSequence()), reliable: true),
      );
    });
  }

  Future<VayaAck?> _sendConfirmed(
    String Function(int sequence) builder, {
    int retries = 0,
    bool safetyBarrier = false,
  }) async {
    final sequence = _takeSequence();
    final command = builder(sequence);
    for (var attempt = 0; attempt <= retries; attempt++) {
      final completer = Completer<VayaAck>();
      _pendingAcks[sequence] = completer;
      final sent = await _bt.sendCommand(
        command,
        reliable: true,
        safetyBarrier: safetyBarrier,
      );
      if (!sent) {
        _pendingAcks.remove(sequence);
        continue;
      }
      try {
        return await completer.future
            .timeout(const Duration(milliseconds: 700));
      } on TimeoutException {
        _pendingAcks.remove(sequence);
      }
    }
    return null;
  }

  /// Configuration commands are safe to retry after a lease refresh because
  /// ACQUIRE always leaves the wheelchair locked and with zero motor output.
  Future<VayaAck?> _sendWithLeaseRecovery(
    String Function(int sequence) builder, {
    bool safetyBarrier = false,
  }) async {
    var acknowledgement = await _sendConfirmed(
      builder,
      safetyBarrier: safetyBarrier,
    );
    if (acknowledgement?.result != 'CONTROL_REQUIRED') {
      return acknowledgement;
    }
    if (!await _acquireControlLease()) return acknowledgement;
    acknowledgement = await _sendConfirmed(
      builder,
      safetyBarrier: safetyBarrier,
    );
    return acknowledgement;
  }

  Future<bool> _recoverControlAfterWatchdog() async {
    if (_recoveringControl) return false;
    _recoveringControl = true;
    _safeNotify();
    try {
      if (!await _acquireControlLease()) return false;
      faultCode = 'NONE';
      return true;
    } finally {
      _recoveringControl = false;
      _safeNotify();
    }
  }

  Future<bool> _waitForWheelchairRest() async {
    const timeout = Duration(seconds: 2);
    const poll = Duration(milliseconds: 50);
    final deadline = DateTime.now().add(timeout);
    while (DateTime.now().isBefore(deadline)) {
      if (!isConnected || !protocolReady) return false;
      final isResting = speedStatus == TelemetryStatus.current &&
          currentSpeed == 0 &&
          controllerState != 'MOVING' &&
          controllerState != 'STOPPING';
      if (isResting) return true;
      await Future<void>.delayed(poll);
    }
    return false;
  }

  // Kept as an AppState shim so timers created before a hot reload can finish
  // safely. Sequence ownership remains with the persistent BLE transport.
  int _takeSequence() => _bt.nextProtocolSequence();

  void _handleAck(VayaAck ack) {
    final completer = _pendingAcks.remove(ack.sequence);
    if (completer != null && !completer.isCompleted) completer.complete(ack);
  }

  void _setError(String message) {
    final lower = message.toLowerCase();
    if (lower.contains('peer removed pairing information') ||
        lower.contains('apple-code: 14')) {
      requiresSystemPairingReset = true;
      systemPairingResetMessage ??=
          'This iPhone has an old Bluetooth pairing for the wheelchair. Open '
          'Settings > Bluetooth, tap VAYA One, and choose Forget This Device '
          'before connecting again.';
    }
    if (message.contains('startScan') ||
        lower.contains('bluetooth must be turned on')) {
      isScanning = false;
      _scanTimer?.cancel();
      _scanTimer = null;
    }
    errorMessage = _caregiverMessage(message);
    _safeNotify();
  }

  TelemetryStatus _telemetryStatus(DateTime? updatedAt) {
    if (!isConnected || updatedAt == null) return TelemetryStatus.unavailable;
    return DateTime.now().difference(updatedAt) <= telemetryFreshness
        ? TelemetryStatus.current
        : TelemetryStatus.stale;
  }

  String _caregiverMessage(String message) {
    final lower = message.toLowerCase();
    if (lower.contains('peer removed pairing information') ||
        lower.contains('apple-code: 14')) {
      return 'This iPhone has an old Bluetooth pairing for the wheelchair. '
          'Open Settings > Bluetooth, tap VAYA One, choose Forget This Device, '
          'then return and connect again.';
    }
    if (lower.contains('bluetooth must be turned on') ||
        lower.contains('adapter') && lower.contains('off')) {
      return 'Bluetooth is off. Turn it on, then try again.';
    }
    if (lower.contains('permission')) {
      return 'VAYA Connect needs Bluetooth permission to find the wheelchair.';
    }
    if (lower.contains('service was not found')) {
      return 'This device is not a compatible VAYA One.';
    }
    if (lower.contains('timeout')) {
      return 'Secure pairing was not completed in time. Keep the wheelchair '
          'nearby and try again.';
    }
    return 'Unable to communicate with the wheelchair. Check the connection and try again.';
  }

  String _passkeyChangeFailure(String? result) => switch (result) {
        'PASSKEY_POLICY_FAILED' =>
          'Choose a six-digit passkey that does not start with zero.',
        'INVALID_VALUE' =>
          'The wheelchair must be completely stopped before changing its passkey.',
        'CONTROL_REQUIRED' =>
          'The secure control session expired. Reconnect and try again.',
        'SECURITY_STORAGE_FAILED' =>
          'The wheelchair could not save the new passkey. Its current passkey is unchanged.',
        _ => 'The wheelchair did not confirm the passkey change. Try again.',
      };

  void _safeNotify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _scanTimer?.cancel();
    _healthTimer?.cancel();
    _controlHeartbeat?.cancel();
    _telemetrySub?.cancel();
    _emergencySignalController.close();
    _discoverySub?.cancel();
    _connectionSub?.cancel();
    _errorSub?.cancel();
    _ackSub?.cancel();
    for (final completer in _pendingAcks.values) {
      if (!completer.isCompleted) {
        completer.completeError(StateError('App state disposed'));
      }
    }
    _pendingAcks.clear();
    unawaited(_bt.dispose());
    super.dispose();
  }
}
