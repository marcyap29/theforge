import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

final textScaleProvider = AsyncNotifierProvider<TextScaleNotifier, double>(
  TextScaleNotifier.new,
);

class TextScaleNotifier extends AsyncNotifier<double> {
  static const _prefsKey = 'forge_text_scale';
  static const _minScale = 0.8;
  static const _maxScale = 2.0;
  static const _step = 0.1;

  @override
  Future<double> build() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getDouble(_prefsKey) ?? 1.0;
    return saved.clamp(_minScale, _maxScale).toDouble();
  }

  Future<void> _setScale(double scale) async {
    final clamped = scale.clamp(_minScale, _maxScale).toDouble();
    state = AsyncData(clamped);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble(_prefsKey, clamped);
  }

  Future<void> increase() => _setScale((state.valueOrNull ?? 1.0) + _step);

  Future<void> decrease() => _setScale((state.valueOrNull ?? 1.0) - _step);

  Future<void> reset() => _setScale(1.0);
}
