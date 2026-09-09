import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/theme/app_colors.dart';
import '../models/emergency_plan.dart';
import '../services/emergency_assistance_service.dart';

class EmergencySettingsScreen extends StatefulWidget {
  const EmergencySettingsScreen({super.key});

  @override
  State<EmergencySettingsScreen> createState() =>
      _EmergencySettingsScreenState();
}

class _EmergencySettingsScreenState extends State<EmergencySettingsScreen> {
  final _service = EmergencyAssistanceService();
  late final TextEditingController _messageController;
  EmergencyPlan _plan = const EmergencyPlan();
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _messageController = TextEditingController();
    unawaited(_load());
  }

  Future<void> _load() async {
    final plan = await _service.loadPlan();
    if (!mounted) return;
    setState(() {
      _plan = plan;
      _messageController.text = plan.message;
      _loading = false;
    });
  }

  Future<void> _save(EmergencyPlan plan) async {
    setState(() => _plan = plan);
    await _service.savePlan(plan);
  }

  Future<void> _addContact() async {
    final contact = await showDialog<EmergencyContact>(
      context: context,
      builder: (_) => const _ContactDialog(),
    );
    if (contact == null) return;
    await _save(_plan.copyWith(contacts: [..._plan.contacts, contact]));
  }

  Future<void> _removeContact(EmergencyContact contact) async {
    final remaining =
        _plan.contacts.where((item) => item.id != contact.id).toList();
    final targetWasRemoved = _plan.callContactId == contact.id;
    await _save(_plan.copyWith(
      contacts: remaining,
      callTargetType:
          targetWasRemoved ? EmergencyCallTargetType.emergencyServices : null,
      clearCallContactId: targetWasRemoved,
    ));
  }

  @override
  void dispose() {
    _messageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('Emergency assistance')),
        body: _loading
            ? const Center(child: CircularProgressIndicator())
            : SafeArea(
                top: false,
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 700),
                    child: ListView(
                      padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
                      children: [
                        Text(
                          'Set who to contact when the SOS button is held. '
                          'The phone always asks for its final call or message confirmation.',
                          style: TextStyle(color: AppColors.textMuted),
                        ),
                        const SizedBox(height: 20),
                        _Panel(
                          title: 'Call target',
                          child: DropdownButtonFormField<String>(
                            key: ValueKey(_plan.callContactId ??
                                EmergencyPlan.emergencyNumber),
                            initialValue: _plan.callTargetType ==
                                        EmergencyCallTargetType.contact &&
                                    _plan.callContact != null
                                ? _plan.callContact!.id
                                : EmergencyPlan.emergencyNumber,
                            decoration: const InputDecoration(
                              labelText: 'Call first',
                            ),
                            items: [
                              const DropdownMenuItem(
                                value: EmergencyPlan.emergencyNumber,
                                child: Text('Emergency services (112)'),
                              ),
                              ..._plan.contacts.map(
                                (contact) => DropdownMenuItem(
                                  value: contact.id,
                                  child: Text(
                                      '${contact.name} (${contact.phoneNumber})'),
                                ),
                              ),
                            ],
                            onChanged: (value) {
                              if (value == null) return;
                              unawaited(
                                  _save(value == EmergencyPlan.emergencyNumber
                                      ? _plan.copyWith(
                                          callTargetType:
                                              EmergencyCallTargetType
                                                  .emergencyServices,
                                          clearCallContactId: true,
                                        )
                                      : _plan.copyWith(
                                          callTargetType:
                                              EmergencyCallTargetType.contact,
                                          callContactId: value,
                                        )));
                            },
                          ),
                        ),
                        const SizedBox(height: 16),
                        _Panel(
                          title: 'Emergency contacts',
                          child: Column(
                            children: [
                              if (_plan.contacts.isEmpty)
                                Align(
                                  alignment: Alignment.centerLeft,
                                  child: Text(
                                    'No contacts yet. SOS will call 112 by default.',
                                    style:
                                        TextStyle(color: AppColors.textMuted),
                                  ),
                                )
                              else
                                ..._plan.contacts.map(
                                  (contact) => ListTile(
                                    contentPadding: EdgeInsets.zero,
                                    title: Text(contact.name),
                                    subtitle: Text(contact.phoneNumber),
                                    trailing: IconButton(
                                      tooltip: 'Remove ${contact.name}',
                                      icon: const Icon(
                                          Icons.delete_outline_rounded),
                                      color: AppColors.danger,
                                      onPressed: () =>
                                          unawaited(_removeContact(contact)),
                                    ),
                                  ),
                                ),
                              const SizedBox(height: 8),
                              Align(
                                alignment: Alignment.centerLeft,
                                child: OutlinedButton.icon(
                                  onPressed: _addContact,
                                  icon: const Icon(
                                      Icons.person_add_alt_1_outlined),
                                  label: const Text('Add emergency contact'),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),
                        _Panel(
                          title: 'Text message',
                          child: TextField(
                            controller: _messageController,
                            maxLines: 4,
                            maxLength: 480,
                            textCapitalization: TextCapitalization.sentences,
                            onChanged: (value) => unawaited(
                              _save(_plan.copyWith(
                                message: value.trim().isEmpty
                                    ? EmergencyPlan.defaultMessage
                                    : value,
                              )),
                            ),
                            decoration: const InputDecoration(
                              helperText:
                                  'Use {location} to include a Google Maps link.',
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
      );
}

class _Panel extends StatelessWidget {
  const _Panel({required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 12),
            child,
          ],
        ),
      );
}

class _ContactDialog extends StatefulWidget {
  const _ContactDialog();

  @override
  State<_ContactDialog> createState() => _ContactDialogState();
}

class _ContactDialogState extends State<_ContactDialog> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _phone = TextEditingController();

  @override
  void dispose() {
    _name.dispose();
    _phone.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
        title: const Text('Add emergency contact'),
        content: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: _name,
                textCapitalization: TextCapitalization.words,
                decoration: const InputDecoration(labelText: 'Name'),
                validator: (value) => value == null || value.trim().isEmpty
                    ? 'Enter a name.'
                    : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _phone,
                keyboardType: TextInputType.phone,
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'[0-9+() -]')),
                ],
                decoration: const InputDecoration(labelText: 'Phone number'),
                validator: (value) {
                  final digits = value?.replaceAll(RegExp(r'[^0-9]'), '') ?? '';
                  return digits.length < 7
                      ? 'Enter a valid phone number.'
                      : null;
                },
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              if (!_formKey.currentState!.validate()) return;
              Navigator.pop(
                context,
                EmergencyContact(
                  id: DateTime.now().microsecondsSinceEpoch.toString(),
                  name: _name.text.trim(),
                  phoneNumber: _phone.text.trim(),
                ),
              );
            },
            child: const Text('Add'),
          ),
        ],
      );
}
