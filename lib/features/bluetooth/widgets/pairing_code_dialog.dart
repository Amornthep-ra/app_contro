import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/ble/ble_connection_coordinator.dart';
import '../../../core/ble/ble_pairing_store.dart';

typedef BlePairingPromptLauncher =
    Future<bool?> Function({
      required BuildContext context,
      required bool isThai,
      BleConnectionCoordinator? coordinator,
    });

/// Opens the pairing dialog, saves the code, and authenticates the connected
/// board. A `null` result means the user cancelled the dialog.
Future<bool?> promptForBlePairingCode({
  required BuildContext context,
  required bool isThai,
  BleConnectionCoordinator? coordinator,
}) async {
  final target = coordinator ?? BleConnectionCoordinator.instance;
  final generation = target.pairingConnectionGeneration;
  final navigator = Navigator.of(context, rootNavigator: true);
  var expired = false;
  final route = DialogRoute<bool>(
    context: context,
    themes: InheritedTheme.capture(from: context, to: navigator.context),
    builder: (_) => PairingCodeDialog(
      replacingSavedCode:
          target.state.recoveryOutcome ==
              BleRecoveryOutcome.credentialMismatchSuspected ||
          target.state.recoveryOutcome == BleRecoveryOutcome.credentialRejected,
      isThai: isThai,
      onPair: (code) async {
        if (generation != target.pairingConnectionGeneration) {
          return const BlePairingAttemptResult(
            ready: false,
            failure: BlePairingFailure.protocolError,
          );
        }
        final result = await target.savePairingCode(code);
        if (generation != target.pairingConnectionGeneration) {
          return const BlePairingAttemptResult(
            ready: false,
            failure: BlePairingFailure.protocolError,
          );
        }
        return result;
      },
    ),
  );
  void closeExpiredSession() {
    if (generation == target.pairingConnectionGeneration) return;
    expired = true;
    if (route.isActive) navigator.removeRoute(route);
  }

  final subscription = target.stream.listen((_) => closeExpiredSession());
  try {
    final completion = navigator.push<bool>(route);
    closeExpiredSession();
    final paired = await completion;
    if (!expired &&
        paired != true &&
        generation == target.pairingConnectionGeneration) {
      await target.cancelPairing(generation);
    }
    return expired ? null : paired;
  } finally {
    unawaited(subscription.cancel());
  }
}

/// A keyboard-safe dialog for entering the BLE pairing code configured on a board.
class PairingCodeDialog extends StatefulWidget {
  const PairingCodeDialog({
    super.key,
    required this.isThai,
    this.onPair,
    this.replacingSavedCode = false,
  });

  final bool replacingSavedCode;

  final bool isThai;
  final Future<BlePairingAttemptResult> Function(String code)? onPair;

  @override
  State<PairingCodeDialog> createState() => _PairingCodeDialogState();
}

class _PairingCodeDialogState extends State<PairingCodeDialog> {
  static const _purple = Color(0xFF7256B6);
  static const _cyan = Color(0xFFDDA9DF);

  final _controller = TextEditingController();
  bool _showValidationError = false;
  bool _submitting = false;
  String? _pairingError;

  bool get _isValid => secretFromBlePairingCode(_controller.text) != null;

  Future<void> _submit() async {
    if (!_isValid || _submitting) {
      setState(() => _showValidationError = true);
      return;
    }
    final onPair = widget.onPair;
    if (onPair == null) {
      Navigator.of(context).pop(_controller.text);
      return;
    }
    setState(() {
      _submitting = true;
      _pairingError = null;
    });
    final result = await onPair(_controller.text);
    if (!mounted) return;
    if (result.ready) {
      Navigator.of(context).pop(true);
      return;
    }
    setState(() {
      _submitting = false;
      _pairingError = switch (result.failure) {
        BlePairingFailure.codeRejected =>
          widget.isThai
              ? 'This code does not match the board. Try again.'
              : 'This code does not match the board. Try again.',
        BlePairingFailure.timeout || BlePairingFailure.protocolError =>
          widget.isThai
              ? 'The board did not complete pairing. Check firmware and retry.'
              : 'The board did not complete pairing. Check firmware and retry.',
        BlePairingFailure.storageError =>
          widget.isThai
              ? 'Connected, but the pairing code could not be saved. Try again.'
              : 'Connected, but the pairing code could not be saved. Try again.',
        _ =>
          widget.isThai
              ? 'Pairing failed. Try again.'
              : 'Pairing failed. Try again.',
      };
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final colors = Theme.of(context).colorScheme;
    final valid = _isValid;
    final isThai = widget.isThai;

    return AlertDialog(
      scrollable: true,
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      backgroundColor: isDark
          ? colors.surfaceContainerHighest
          : const Color(0xFFF8EEFF),
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(28),
        side: BorderSide(color: Colors.white.withAlpha(238), width: 1.35),
      ),
      titlePadding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
      contentPadding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
      actionsPadding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
      title: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              gradient: const LinearGradient(colors: [_purple, _cyan]),
            ),
            child: const Icon(Icons.lock_outline_rounded, color: Colors.white),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Pair Code',
                  style: TextStyle(
                    color: colors.onSurface,
                    fontSize: 21,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  widget.replacingSavedCode
                      ? 'Saved Pair Code no longer works. Enter the current code.'
                      : isThai
                      ? 'Use the code set on your board.'
                      : 'Use the code set on your board.',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: colors.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      content: TextField(
        controller: _controller,
        enabled: !_submitting,
        textInputAction: TextInputAction.done,
        cursorColor: _purple,
        autofocus: true,
        autocorrect: false,
        enableSuggestions: false,
        textCapitalization: TextCapitalization.characters,
        maxLength: 16,
        inputFormatters: [
          FilteringTextInputFormatter.allow(RegExp(r'[A-Za-z0-9]')),
        ],
        onChanged: (_) => setState(() {
          _pairingError = null;
        }),
        onSubmitted: (_) => _submit(),
        style: TextStyle(color: colors.onSurface, fontWeight: FontWeight.w700),
        decoration: InputDecoration(
          hintText: 'Enter code',
          labelText: isThai ? 'Pair Code' : 'Pair Code',
          helperText: isThai
              ? 'English/Number · 8–16'
              : 'English/Number · 8–16',
          helperMaxLines: 2,
          errorMaxLines: 4,
          errorText:
              _pairingError ??
              (_showValidationError && !valid
                  ? (isThai
                        ? 'Enter a valid 8–16 character code.'
                        : 'Enter a valid 8–16 character code.')
                  : null),
          prefixIcon: const Icon(Icons.key_rounded),
          filled: true,
          fillColor: isDark ? colors.surface : Colors.white.withAlpha(174),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: const BorderSide(color: Color(0xFFC7B7E8)),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: const BorderSide(color: _purple, width: 1.5),
          ),
        ),
      ),
      actions: [
        TextButton(
          style: TextButton.styleFrom(
            foregroundColor: _purple,
            minimumSize: const Size(100, 48),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
          ),
          onPressed: _submitting ? null : () => Navigator.of(context).pop(),
          child: Text(isThai ? 'Cancel' : 'Cancel'),
        ),
        FilledButton(
          style: FilledButton.styleFrom(
            backgroundColor: _purple,
            foregroundColor: Colors.white,
            minimumSize: const Size(120, 48),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
          ),
          onPressed: valid && !_submitting ? _submit : null,
          child: _submitting
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: _purple,
                  ),
                )
              : const Text('Pair'),
        ),
      ],
    );
  }
}
