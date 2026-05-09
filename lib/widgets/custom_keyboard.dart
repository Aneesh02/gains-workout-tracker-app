import 'package:flutter/material.dart';
import '../models/exercise.dart';
import '../models/gym_settings.dart';
import '../theme/app_theme.dart';
import 'plate_calculator.dart';

class KeyboardController extends ChangeNotifier {
  int? activeExerciseIndex;
  int? activeSetIndex;
  bool isWeightField = true;
  bool isTimeField = false;
  String _input = '';
  double _incrementStep = 2.5;
  final List<int> _timeDigits = [];

  PlateLoadingType _plateLoadingType = PlateLoadingType.none;

  bool get isVisible => activeExerciseIndex != null;
  String get input => _input;
  PlateLoadingType get plateLoadingType => _plateLoadingType;

  /// MM:SS formatted display string when in time mode.
  String get timeDisplay => isTimeField ? _buildTimeStr() : _input;

  void activate({
    required int exerciseIndex,
    required int setIndex,
    required bool isWeight,
    required String initialValue,
    double? incrementStep,
    bool timeField = false,
    PlateLoadingType plateLoadingType = PlateLoadingType.none,
  }) {
    activeExerciseIndex = exerciseIndex;
    activeSetIndex = setIndex;
    isWeightField = isWeight;
    isTimeField = timeField;
    _input = initialValue;
    _incrementStep = incrementStep ?? (isWeight ? 2.5 : 1.0);
    _plateLoadingType = isWeight ? plateLoadingType : PlateLoadingType.none;
    if (timeField) _initTimeDigits(initialValue);
    notifyListeners();
  }

  void setInput(String v) {
    _input = v;
    notifyListeners();
  }

  void dismiss() {
    activeExerciseIndex = null;
    activeSetIndex = null;
    isTimeField = false;
    _timeDigits.clear();
    _input = '';
    _plateLoadingType = PlateLoadingType.none;
    notifyListeners();
  }

  void append(String char) {
    if (isTimeField) {
      final digit = int.tryParse(char);
      if (digit == null) return;
      if (_timeDigits.length >= 4) _timeDigits.removeAt(0);
      _timeDigits.add(digit);
      _commitTime();
      return;
    }
    if (char == '.' && _input.contains('.')) return;
    if (_input == '0' && char != '.') {
      _input = char;
    } else {
      _input += char;
    }
    notifyListeners();
  }

  void backspace() {
    if (isTimeField) {
      if (_timeDigits.isNotEmpty) _timeDigits.removeLast();
      _commitTime();
      return;
    }
    if (_input.isNotEmpty) {
      _input = _input.substring(0, _input.length - 1);
    }
    notifyListeners();
  }

  void increment() {
    if (isTimeField) {
      final val = (int.tryParse(_input) ?? 0) + 10;
      _initTimeDigits(val.toString());
      _commitTime();
      return;
    }
    final val = double.tryParse(_input) ?? 0;
    _input = _fmt(val + _incrementStep);
    notifyListeners();
  }

  void decrement() {
    if (isTimeField) {
      final val = ((int.tryParse(_input) ?? 0) - 10).clamp(0, 99999);
      _initTimeDigits(val.toString());
      _commitTime();
      return;
    }
    final val = double.tryParse(_input) ?? 0;
    final next = val - _incrementStep;
    if (next >= 0) {
      _input = _fmt(next);
      notifyListeners();
    }
  }

  void _initTimeDigits(String secondsStr) {
    _timeDigits.clear();
    final secs = int.tryParse(secondsStr) ?? 0;
    if (secs == 0) return;
    final mm = secs ~/ 60;
    final ss = secs % 60;
    final all = [mm ~/ 10, mm % 10, ss ~/ 10, ss % 10];
    int start = 0;
    while (start < all.length - 1 && all[start] == 0) { start++; }
    _timeDigits.addAll(all.sublist(start));
  }

  void _commitTime() {
    _input = _secondsFromDigits().toString();
    notifyListeners();
  }

  int _secondsFromDigits() {
    if (_timeDigits.isEmpty) return 0;
    final pad = List.filled((4 - _timeDigits.length).clamp(0, 4), 0) +
        _timeDigits.take(4).toList();
    final mm = pad[0] * 10 + pad[1];
    final ss = (pad[2] * 10 + pad[3]).clamp(0, 59);
    return mm * 60 + ss;
  }

  String _buildTimeStr() {
    final s = _secondsFromDigits();
    final m = s ~/ 60;
    final sec = s % 60;
    return '${m.toString().padLeft(2, '0')}:${sec.toString().padLeft(2, '0')}';
  }

  String _fmt(double v) {
    if (v % 1 == 0) return v.toInt().toString();
    return v.toString();
  }
}

class CustomKeyboard extends StatelessWidget {
  final KeyboardController controller;
  final void Function(String value, bool isWeight) onValueChanged;
  final VoidCallback onNext;
  final VoidCallback onDismiss;
  final GymSettings? gymSettings;

  const CustomKeyboard({
    super.key,
    required this.controller,
    required this.onValueChanged,
    required this.onNext,
    required this.onDismiss,
    this.gymSettings,
  });

  void _tap(String key) {
    controller.append(key);
    onValueChanged(controller.input, controller.isWeightField);
  }

  void _back() {
    controller.backspace();
    onValueChanged(controller.input, controller.isWeightField);
  }

  void _inc() {
    controller.increment();
    onValueChanged(controller.input, controller.isWeightField);
  }

  void _dec() {
    controller.decrement();
    onValueChanged(controller.input, controller.isWeightField);
  }

  bool get _showPlateBtn =>
      gymSettings != null &&
      controller.plateLoadingType != PlateLoadingType.none &&
      controller.isWeightField;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppColors.keyboardBackground,
      padding: const EdgeInsets.fromLTRB(8, 6, 8, 8),
      child: SafeArea(
        top: false,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _row(['1', '2', '3']),
                  _row(['4', '5', '6']),
                  _row(['7', '8', '9']),
                  _row([controller.isTimeField ? ':' : '.', '0', '⌫']),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _iconBtn(Icons.keyboard_hide, onDismiss, width: 96, height: 48),
                const SizedBox(height: 4),
                Row(children: [
                  _textBtn('−', _dec, width: 46, height: 44),
                  const SizedBox(width: 4),
                  _textBtn('+', _inc, width: 46, height: 44),
                ]),
                const SizedBox(height: 4),
                _nextBtn(),
                if (_showPlateBtn) ...[
                  const SizedBox(height: 4),
                  _plateBtn(context),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _row(List<String> keys) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: keys.map((k) => Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 2),
            child: k == '⌫'
                ? _iconBtn(Icons.backspace_outlined, _back)
                : _textBtn(k, () => _tap(k)),
          ),
        )).toList(),
      ),
    );
  }

  Widget _textBtn(String label, VoidCallback onTap, {double? width, double? height}) {
    return _KbdKey(
      onTap: onTap,
      color: AppColors.keyboardKey,
      width: width,
      height: height ?? 48,
      child: Text(label,
          style: const TextStyle(
              color: AppColors.textPrimary,
              fontSize: 20,
              fontWeight: FontWeight.w400)),
    );
  }

  Widget _iconBtn(IconData icon, VoidCallback onTap, {double? width, double? height}) {
    return _KbdKey(
      onTap: onTap,
      color: AppColors.keyboardKey,
      width: width ?? double.infinity,
      height: height ?? 48,
      child: Icon(icon, color: AppColors.textPrimary, size: 22),
    );
  }

  Widget _nextBtn() {
    return _KbdKey(
      onTap: onNext,
      color: AppColors.blue,
      width: 96,
      height: 48,
      child: const Text('NEXT',
          style: TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.bold)),
    );
  }

  Widget _plateBtn(BuildContext ctx) {
    return _KbdKey(
      onTap: () async {
        final result = await showModalBottomSheet<double>(
          context: ctx,
          isScrollControlled: true,
          backgroundColor: Colors.transparent,
          builder: (_) => PlateCalculatorSheet(
            loadingType: controller.plateLoadingType,
            gymSettings: gymSettings!,
            initialWeight: double.tryParse(controller.input) ?? 0,
          ),
        );
        if (result != null) {
          final formatted = result % 1 == 0
              ? result.toInt().toString()
              : result.toString();
          controller.setInput(formatted);
          onValueChanged(controller.input, controller.isWeightField);
        }
      },
      color: AppColors.blue.withValues(alpha: 0.18),
      width: 96,
      height: 44,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.fitness_center, color: AppColors.blue, size: 14),
          const SizedBox(width: 5),
          const Text(
            'Plates',
            style: TextStyle(
              color: AppColors.blue,
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

/// A keyboard button with press-scale animation and ink splash feedback.
class _KbdKey extends StatefulWidget {
  final VoidCallback onTap;
  final Color color;
  final double? width;
  final double height;
  final Widget child;

  const _KbdKey({
    required this.onTap,
    required this.color,
    required this.height,
    required this.child,
    this.width,
  });

  @override
  State<_KbdKey> createState() => _KbdKeyState();
}

class _KbdKeyState extends State<_KbdKey> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    const radius = BorderRadius.all(Radius.circular(6));
    return GestureDetector(
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) {
        setState(() => _pressed = false);
        widget.onTap();
      },
      onTapCancel: () => setState(() => _pressed = false),
      child: AnimatedScale(
        scale: _pressed ? 0.91 : 1.0,
        duration: const Duration(milliseconds: 70),
        curve: Curves.easeOut,
        child: Material(
          color: widget.color,
          borderRadius: radius,
          child: InkWell(
            borderRadius: radius,
            splashColor: Colors.white.withValues(alpha: 0.18),
            highlightColor: Colors.white.withValues(alpha: 0.08),
            onTap: null,
            child: SizedBox(
              width: widget.width,
              height: widget.height,
              child: Center(child: widget.child),
            ),
          ),
        ),
      ),
    );
  }
}
