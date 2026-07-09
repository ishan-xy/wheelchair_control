class WheelchairCommands {
  static String joystick(double x, double y) =>
      'J:${x.toStringAsFixed(2)},${y.toStringAsFixed(2)}';

  static const stop = 'J:0.00,0.00';

  static String maxPwm(int value) => 'MAX:$value';

  static String maxSpeedMph(int value) => 'MAXSPEED:$value';

  static String autoStop(bool enabled) => 'AUTOSTOP:${enabled ? 1 : 0}';
}
