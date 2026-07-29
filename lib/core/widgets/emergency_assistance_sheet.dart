import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/emergency_plan.dart';
import '../../providers/app_state.dart';
import '../../services/emergency_assistance_service.dart';
import '../theme/app_colors.dart';

Future<void> showEmergencyAssistanceSheet(
  BuildContext context, {
  required EmergencySignalSource source,
}) =>
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      isDismissible: source != EmergencySignalSource.physicalButton,
      enableDrag: source != EmergencySignalSource.physicalButton,
      builder: (_) => _EmergencyAssistanceSheet(source: source),
    );

class _EmergencyAssistanceSheet extends StatefulWidget {
  const _EmergencyAssistanceSheet({required this.source});

  final EmergencySignalSource source;

  @override
  State<_EmergencyAssistanceSheet> createState() =>
      _EmergencyAssistanceSheetState();
}

class _EmergencyAssistanceSheetState extends State<_EmergencyAssistanceSheet> {
  final _service = EmergencyAssistanceService();
  EmergencyPlan _plan = const EmergencyPlan();
  EmergencyLocation? _location;
  bool _loading = true;
  bool _automaticCallStarted = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    unawaited(_prepare());
  }

  Future<void> _prepare() async {
    try {
      final results = await Future.wait<Object?>([
        _service.loadPlan(),
        _service.currentLocation(),
      ]);
      if (!mounted) return;
      setState(() {
        _plan = results[0]! as EmergencyPlan;
        _location = results[1] as EmergencyLocation?;
        _loading = false;
      });
      if (widget.source == EmergencySignalSource.physicalButton &&
          _plan.contacts.isEmpty &&
          !_automaticCallStarted) {
        _automaticCallStarted = true;
        unawaited(_call());
      }
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = 'Location could not be prepared. You can still call for help.';
      });
    }
  }

  Future<void> _call() async {
    final opened = await _service.openCall(_plan.callNumber);
    if (!mounted || opened) return;
    setState(() => _error = 'The phone app could not open the call.');
  }

  Future<void> _messageContacts() async {
    final opened = await _service.composeText(
      contacts: _plan.contacts,
      message: _service.formatMessage(_plan, _location),
    );
    if (!mounted || opened) return;
    setState(() => _error = 'The messaging app could not open.');
  }

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
        child: _loading
            ? const SizedBox(
                height: 260,
                child: Center(child: CircularProgressIndicator()),
              )
            : Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Center(
                    child: Container(
                      width: 36,
                      height: 4,
                      decoration: BoxDecoration(
                        color: AppColors.textDim,
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  Row(
                    children: [
                      const Icon(Icons.sos_rounded,
                          color: AppColors.danger, size: 30),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'Emergency assistance',
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Text(
                    widget.source == EmergencySignalSource.physicalButton
                        ? 'The wheelchair SOS button was held.'
                        : 'Emergency assistance was requested from this phone.',
                    style: const TextStyle(color: AppColors.textMuted),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    _location == null
                        ? 'Location is unavailable. Your call can still go through.'
                        : 'Current location is ready to include in the message.',
                    style: TextStyle(
                      color: _location == null
                          ? AppColors.warning
                          : AppColors.success,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  if (_error != null) ...[
                    const SizedBox(height: 10),
                    Text(_error!,
                        style: const TextStyle(color: AppColors.danger)),
                  ],
                  const SizedBox(height: 20),
                  FilledButton.icon(
                    onPressed: _call,
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.danger,
                      foregroundColor: Colors.white,
                      minimumSize: const Size.fromHeight(54),
                    ),
                    icon: const Icon(Icons.call_rounded),
                    label: Text('Call ${_plan.callLabel}'),
                  ),
                  const SizedBox(height: 10),
                  OutlinedButton.icon(
                    onPressed: _plan.contacts.isEmpty ? null : _messageContacts,
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size.fromHeight(52),
                    ),
                    icon: const Icon(Icons.sms_outlined),
                    label: Text(
                      _plan.contacts.isEmpty
                          ? 'No emergency contacts configured'
                          : 'Message ${_plan.contacts.length} emergency contact${_plan.contacts.length == 1 ? '' : 's'}',
                    ),
                  ),
                  const SizedBox(height: 4),
                  TextButton(
                    onPressed: () {
                      if (widget.source ==
                          EmergencySignalSource.physicalButton) {
                        context.read<AppState>().acknowledgeSosAlert();
                      }
                      Navigator.pop(context);
                    },
                    child: Text(
                      widget.source == EmergencySignalSource.physicalButton
                          ? 'Acknowledge alert'
                          : 'Close',
                    ),
                  ),
                ],
              ),
      );
}
