import 'package:flutter_test/flutter_test.dart';
import 'package:wheelchair_control/models/emergency_plan.dart';

void main() {
  test('defaults emergency calls to India emergency services', () {
    const plan = EmergencyPlan();

    expect(plan.callNumber, EmergencyPlan.emergencyNumber);
    expect(plan.callLabel, 'Emergency services (112)');
    expect(plan.contacts, isEmpty);
  });

  test('uses the selected emergency contact as the call target', () {
    const contact = EmergencyContact(
      id: 'caregiver-1',
      name: 'Asha',
      phoneNumber: '+919999999999',
    );
    const plan = EmergencyPlan(
      contacts: [contact],
      callTargetType: EmergencyCallTargetType.contact,
      callContactId: 'caregiver-1',
    );

    expect(plan.callNumber, '+919999999999');
    expect(plan.callLabel, 'Asha');
  });
}
