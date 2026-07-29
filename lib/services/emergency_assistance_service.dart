import 'dart:async';
import 'dart:convert';

import 'package:geolocator/geolocator.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/emergency_plan.dart';

class EmergencyLocation {
  final double latitude;
  final double longitude;

  const EmergencyLocation({required this.latitude, required this.longitude});

  String get mapsUrl =>
      'https://www.google.com/maps/search/?api=1&query=$latitude,$longitude';
}

class EmergencyAssistanceService {
  static const _planKey = 'emergency_plan_v1';

  Future<EmergencyPlan> loadPlan() async {
    final preferences = await SharedPreferences.getInstance();
    final encoded = preferences.getString(_planKey);
    if (encoded == null) return const EmergencyPlan();
    try {
      final decoded = jsonDecode(encoded);
      return decoded is Map<String, dynamic>
          ? EmergencyPlan.fromJson(decoded)
          : const EmergencyPlan();
    } on FormatException {
      return const EmergencyPlan();
    }
  }

  Future<void> savePlan(EmergencyPlan plan) async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.setString(_planKey, jsonEncode(plan.toJson()));
  }

  Future<EmergencyLocation?> currentLocation() async {
    if (!await Geolocator.isLocationServiceEnabled()) return null;
    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever) {
      return null;
    }
    try {
      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 10),
        ),
      );
      return EmergencyLocation(
        latitude: position.latitude,
        longitude: position.longitude,
      );
    } on TimeoutException {
      final position = await Geolocator.getLastKnownPosition();
      return position == null
          ? null
          : EmergencyLocation(
              latitude: position.latitude,
              longitude: position.longitude,
            );
    }
  }

  String formatMessage(EmergencyPlan plan, EmergencyLocation? location) {
    final locationText = location?.mapsUrl ?? 'Location unavailable.';
    return plan.message.replaceAll('{location}', locationText);
  }

  Future<bool> openCall(String phoneNumber) => _launch(
        Uri(scheme: 'tel', path: _normalisePhoneNumber(phoneNumber)),
      );

  Future<bool> composeText({
    required List<EmergencyContact> contacts,
    required String message,
  }) {
    if (contacts.isEmpty) return Future.value(false);
    final recipients = contacts
        .map((contact) => _normalisePhoneNumber(contact.phoneNumber))
        .join(',');
    return _launch(Uri(
      scheme: 'sms',
      path: recipients,
      queryParameters: {'body': message},
    ));
  }

  Future<bool> _launch(Uri uri) => launchUrl(
        uri,
        mode: LaunchMode.externalApplication,
      );

  String _normalisePhoneNumber(String value) =>
      value.replaceAll(RegExp(r'[^0-9+]'), '');
}
