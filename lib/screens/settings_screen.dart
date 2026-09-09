import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../core/theme/app_colors.dart';
import '../models/wheelchair_runtime.dart';
import '../providers/app_state.dart';
import 'emergency_settings_screen.dart';
import 'onboarding_screen.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    return SafeArea(
      bottom: false,
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 700),
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 28),
            children: [
              Text(
                'Settings',
                style: Theme.of(context).textTheme.headlineMedium,
              ),
              const SizedBox(height: 6),
              Text(
                'Connection and diagnostic information',
                style: TextStyle(color: AppColors.textMuted),
              ),
              const SizedBox(height: 20),
              _Section(
                title: 'Appearance',
                child: SwitchListTile.adaptive(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Light mode'),
                  subtitle: const Text('Dark mode is the default.'),
                  value: state.isLightMode,
                  onChanged: (value) => state.setLightMode(value),
                ),
              ),
              const SizedBox(height: 16),
              _Section(
                title: 'Wheelchair',
                child: Column(
                  children: [
                    _DetailRow(
                      label: 'Connection',
                      value: state.connectionStatus.label,
                    ),
                    const Divider(),
                    _DetailRow(
                      label: 'Device',
                      value: state.isConnected
                          ? (state.connectedDeviceName.isEmpty
                              ? 'VAYA One'
                              : state.connectedDeviceName)
                          : 'Not connected',
                    ),
                    const Divider(),
                    SwitchListTile.adaptive(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Use physical joystick'),
                      subtitle: Text(
                        state.physicalJoystickEnabled
                            ? 'Physical joystick active; app joystick is disabled.'
                            : 'App joystick active; physical joystick is disabled. Switching sources stops output.',
                      ),
                      value: state.physicalJoystickEnabled,
                      onChanged: state.canChangePhysicalJoystick
                          ? (value) async {
                              final changed =
                                  await state.setPhysicalJoystickEnabled(value);
                              if (!changed && context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text(
                                      'The joystick source could not be changed. Check the connection and safety state.',
                                    ),
                                  ),
                                );
                              }
                            }
                          : null,
                    ),
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: state.isConnected
                            ? () async {
                                await state.disconnect();
                                if (!context.mounted) return;
                                Navigator.of(context).pushReplacement(
                                  MaterialPageRoute(
                                    builder: (_) => const OnboardingScreen(),
                                  ),
                                );
                              }
                            : () {
                                Navigator.of(context).pushReplacement(
                                  MaterialPageRoute(
                                    builder: (_) => const OnboardingScreen(),
                                  ),
                                );
                              },
                        icon: Icon(
                          state.isConnected
                              ? Icons.link_off_rounded
                              : Icons.refresh_rounded,
                        ),
                        label: Text(
                          state.isConnected
                              ? 'Disconnect wheelchair'
                              : 'Connect wheelchair',
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    _NewDeviceTrustControl(state: state),
                    const SizedBox(height: 10),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: state.isConnected &&
                                state.protocolReady &&
                                !state.isChangingPasskey
                            ? () => _changePasskey(context, state)
                            : null,
                        icon: state.isChangingPasskey
                            ? const SizedBox.square(
                                dimension: 18,
                                child:
                                    CircularProgressIndicator(strokeWidth: 2),
                              )
                            : const Icon(Icons.password_rounded),
                        label: Text(
                          state.isChangingPasskey
                              ? 'Updating passkey'
                              : 'Change wheelchair passkey',
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: state.hasRememberedWheelchair
                            ? () => _confirmRemove(context, state)
                            : null,
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppColors.danger,
                          side: BorderSide(
                            color: state.hasRememberedWheelchair
                                ? AppColors.danger.withValues(alpha: 0.7)
                                : AppColors.border,
                          ),
                        ),
                        icon: const Icon(Icons.delete_outline_rounded),
                        label: const Text('Remove wheelchair'),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              _Section(
                title: 'Emergency assistance',
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      'Choose who to call and message when SOS is requested.',
                      style: TextStyle(color: AppColors.textMuted),
                    ),
                    const SizedBox(height: 14),
                    OutlinedButton.icon(
                      onPressed: () => Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => const EmergencySettingsScreen(),
                        ),
                      ),
                      icon: const Icon(Icons.sos_rounded),
                      label: const Text('Configure emergency assistance'),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              _Section(
                title: 'Diagnostics',
                child: Column(
                  children: [
                    _DetailRow(
                      label: 'Battery telemetry',
                      value: _telemetryLabel(state.batteryStatus),
                    ),
                    const Divider(),
                    _DetailRow(
                      label: 'Movement telemetry',
                      value: _telemetryLabel(state.speedStatus),
                    ),
                    const Divider(),
                    _DetailRow(
                      label: 'Wheelchair lock',
                      value: state.isLocked ? 'Locked' : 'Unlocked',
                    ),
                    const Divider(),
                    _DetailRow(
                      label: 'New caregiver devices',
                      value: state.allowNewDevices ? 'Allowed' : 'Blocked',
                      warning: state.allowNewDevices,
                    ),
                    const Divider(),
                    _DetailRow(
                      label: 'Trusted devices',
                      value: '${state.trustedDeviceCount}',
                    ),
                    const Divider(),
                    _DetailRow(
                      label: 'Pairing window',
                      value: state.pairingWindowOpen ? 'Open' : 'Closed',
                      warning: state.pairingWindowOpen,
                    ),
                    const Divider(),
                    _DetailRow(
                      label: 'Controller fault',
                      value: state.faultCode == 'NONE'
                          ? 'None reported'
                          : state.faultCode,
                      warning: state.faultCode != 'NONE',
                    ),
                    const Divider(),
                    _DetailRow(
                      label: 'Command confirmation',
                      value: state.protocolReady ? 'Active' : 'Unavailable',
                      warning: !state.protocolReady,
                    ),
                    const Divider(),
                    _DetailRow(
                      label: 'Firmware version',
                      value: state.firmwareVersion.isEmpty
                          ? 'Unavailable'
                          : state.firmwareVersion,
                    ),
                    if (state.isConnected &&
                        state.connectedDeviceAddress.isNotEmpty) ...[
                      const Divider(),
                      _DetailRow(
                        label: 'Device ID',
                        value: state.connectedDeviceAddress,
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 16),
              const _Section(
                title: 'About',
                child: _DetailRow(
                  label: 'VAYA Connect',
                  value: '1.0.0',
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  static String _telemetryLabel(TelemetryStatus status) => switch (status) {
        TelemetryStatus.current => 'Current',
        TelemetryStatus.stale => 'Delayed',
        TelemetryStatus.unavailable => 'Unavailable',
      };

  static Future<void> _confirmRemove(
    BuildContext context,
    AppState state,
  ) async {
    final needsIosReset =
        !kIsWeb && defaultTargetPlatform == TargetPlatform.iOS;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Remove wheelchair?'),
        content: Text(
          needsIosReset
              ? 'This disconnects the wheelchair and removes its caregiver key. '
                  'To finish on iPhone, you must also open Settings > Bluetooth, '
                  'tap VAYA One, and choose Forget This Device.'
              : 'This disconnects the wheelchair and returns to setup. '
                  'You will need to connect it again before movement controls can be used.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.danger,
              foregroundColor: Colors.white,
            ),
            child: const Text('Remove'),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;

    final removed = await state.forgetWheelchair();
    if (!context.mounted) return;
    if (!removed) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'The wheelchair did not confirm removal. Reconnect and try again.',
          ),
        ),
      );
      return;
    }
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const OnboardingScreen()),
      (_) => false,
    );
  }

  static Future<void> _changePasskey(
    BuildContext context,
    AppState state,
  ) async {
    final passkey = await showDialog<String>(
      context: context,
      builder: (_) => const _ChangePasskeyDialog(),
    );
    if (passkey == null || !context.mounted) return;

    final changed = await state.changePasskey(passkey);
    if (!context.mounted) return;
    if (!changed) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content:
              Text(state.errorMessage ?? 'Passkey change was not confirmed.'),
        ),
      );
      return;
    }

    final needsIosReset =
        !kIsWeb && defaultTargetPlatform == TargetPlatform.iOS;
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Passkey changed'),
        content: Text(
          needsIosReset
              ? 'The wheelchair is locked and disconnected. This iPhone still '
                  'has the old Bluetooth pairing, so open Settings > Bluetooth, '
                  'tap VAYA One, then choose Forget This Device. Return here '
                  'and connect with the new passkey.'
              : 'The wheelchair is locked and disconnected. Connect it again with '
                  'the new passkey before using movement controls.',
        ),
        actions: [
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Continue'),
          ),
        ],
      ),
    );
    if (!context.mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const OnboardingScreen()),
      (_) => false,
    );
  }
}

class _NewDeviceTrustControl extends StatelessWidget {
  const _NewDeviceTrustControl({required this.state});

  final AppState state;

  @override
  Widget build(BuildContext context) {
    final enabled = state.canChangeNewDeviceTrust;
    return Semantics(
      label: 'Allow new caregiver devices',
      hint: 'Requires the wheelchair to be stopped and locked.',
      child: SwitchListTile.adaptive(
        contentPadding: const EdgeInsets.symmetric(horizontal: 4),
        title: const Text('Allow new caregiver devices'),
        subtitle: Text(
          !state.supportsNewDeviceTrust
              ? 'Update the wheelchair firmware to manage trusted devices.'
              : state.pairingWindowOpen
                  ? 'Pairing is open for a new caregiver device.'
                  : state.allowNewDevices
                      ? 'New phones can pair during a physical pairing window.'
                      : 'Only trusted phones can reconnect.',
          style: TextStyle(color: AppColors.textMuted),
        ),
        value: state.allowNewDevices,
        onChanged: enabled
            ? (allowed) async {
                final updated = await state.setAllowNewDevices(allowed);
                if (!context.mounted || updated) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text(
                      'The wheelchair did not confirm the pairing setting.',
                    ),
                  ),
                );
              }
            : null,
      ),
    );
  }
}

class _ChangePasskeyDialog extends StatefulWidget {
  const _ChangePasskeyDialog();

  @override
  State<_ChangePasskeyDialog> createState() => _ChangePasskeyDialogState();
}

class _ChangePasskeyDialogState extends State<_ChangePasskeyDialog> {
  final _formKey = GlobalKey<FormState>();
  final _passkey = TextEditingController();
  final _confirmation = TextEditingController();

  @override
  void dispose() {
    _passkey.dispose();
    _confirmation.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
        title: const Text('Change wheelchair passkey?'),
        content: SingleChildScrollView(
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Your secure Bluetooth connection confirms your current passkey. '
                  'The wheelchair will lock, remove this pairing, and disconnect.',
                ),
                const SizedBox(height: 18),
                _PasskeyField(
                  controller: _passkey,
                  label: 'New six-digit passkey',
                ),
                const SizedBox(height: 10),
                _PasskeyField(
                  controller: _confirmation,
                  label: 'Confirm new passkey',
                  validator: (value) {
                    if (value != _passkey.text) return 'Passkeys do not match.';
                    return null;
                  },
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              if (_formKey.currentState!.validate()) {
                Navigator.pop(context, _passkey.text);
              }
            },
            child: const Text('Change & disconnect'),
          ),
        ],
      );
}

class _PasskeyField extends StatelessWidget {
  const _PasskeyField({
    required this.controller,
    required this.label,
    this.validator,
  });

  final TextEditingController controller;
  final String label;
  final String? Function(String?)? validator;

  @override
  Widget build(BuildContext context) => TextFormField(
        controller: controller,
        autofocus: label.startsWith('New'),
        obscureText: true,
        enableSuggestions: false,
        autocorrect: false,
        keyboardType: TextInputType.number,
        textInputAction: TextInputAction.next,
        maxLength: 6,
        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
        decoration: InputDecoration(
          labelText: label,
          counterText: '',
        ),
        validator: validator ??
            (value) {
              if (value == null ||
                  !RegExp(r'^[1-9][0-9]{5}$').hasMatch(value)) {
                return 'Enter six digits; the first digit cannot be zero.';
              }
              return null;
            },
      );
}

class _Section extends StatelessWidget {
  final String title;
  final Widget child;

  const _Section({required this.title, required this.child});

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 16),
            child,
          ],
        ),
      );
}

class _DetailRow extends StatelessWidget {
  final String label;
  final String value;
  final bool warning;

  const _DetailRow({
    required this.label,
    required this.value,
    this.warning = false,
  });

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 5),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child: Text(label)),
            const SizedBox(width: 16),
            Flexible(
              child: Text(
                value,
                textAlign: TextAlign.end,
                style: TextStyle(
                  color: warning ? AppColors.warning : AppColors.textMuted,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
      );
}
