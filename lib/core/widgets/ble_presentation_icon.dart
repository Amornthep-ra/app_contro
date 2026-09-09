import 'package:flutter/material.dart';

import '../ble/ble_presentation_state.dart';

IconData materialIconForBlePresentation(BlePresentationIcon icon) =>
    switch (icon) {
      BlePresentationIcon.connected => Icons.bluetooth_connected,
      BlePresentationIcon.neutral => Icons.bluetooth,
      BlePresentationIcon.searching => Icons.bluetooth_searching,
      BlePresentationIcon.disabled => Icons.bluetooth_disabled,
      BlePresentationIcon.unavailable => Icons.error_outline,
      BlePresentationIcon.permission => Icons.lock_outline,
    };
