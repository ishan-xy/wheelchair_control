enum ConnectionStatus {
  disconnected,
  scanning,
  connecting,
  reconnecting,
  connected,
}

enum WheelchairMotionStatus {
  unavailable,
  unknown,
  stopped,
  moving,
}

enum TelemetryStatus {
  unavailable,
  current,
  stale,
}

extension ConnectionStatusLabel on ConnectionStatus {
  String get label => switch (this) {
        ConnectionStatus.disconnected => 'Disconnected',
        ConnectionStatus.scanning => 'Searching',
        ConnectionStatus.connecting => 'Connecting',
        ConnectionStatus.reconnecting => 'Reconnecting',
        ConnectionStatus.connected => 'Connected',
      };
}

extension WheelchairMotionStatusLabel on WheelchairMotionStatus {
  String get label => switch (this) {
        WheelchairMotionStatus.unavailable => 'Unavailable',
        WheelchairMotionStatus.unknown => 'State unavailable',
        WheelchairMotionStatus.stopped => 'Stopped',
        WheelchairMotionStatus.moving => 'Moving',
      };
}
