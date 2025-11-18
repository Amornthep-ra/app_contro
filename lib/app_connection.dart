import 'dart:async';
import 'package:flutter/foundation.dart';

class AppConnection extends ValueNotifier<bool> {
  AppConnection._() : super(false);
  static final AppConnection instance = AppConnection._();

  bool _classicConnected = false;
  bool _bleConnected = false;

  // ⬅⬅⬅ เพิ่ม stream controller
  final StreamController<bool> _bleStreamController =
      StreamController<bool>.broadcast();

  // ⬅⬅⬅ เพิ่ม getter สำหรับ badge
  Stream<bool> get bleConnectedStream => _bleStreamController.stream;
  bool get isBleConnected => _bleConnected;

  bool get classicConnected => _classicConnected;
  bool get bleConnected => _bleConnected;

  void setClassicConnected(bool v) {
    if (_classicConnected == v) return;
    _classicConnected = v;
    _update();
  }

  void setBleConnected(bool v) {
    if (_bleConnected == v) return;
    _bleConnected = v;

    _bleStreamController.add(v);    // ⬅ ส่งค่าใหม่ให้ ConnectionStatusBadge

    _update();
  }

  void _update() {
    final newValue = _classicConnected || _bleConnected;
    if (newValue != value) {
      value = newValue;
    }
  }
}
