import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../models/exercise.dart';
import '../models/gym_settings.dart';
import '../theme/app_theme.dart';

// ── Plate colour / size helpers ───────────────────────────────────────────

Color _plateColor(double kg) {
  if (kg >= 25) return const Color(0xFFD32F2F);
  if (kg >= 20) return const Color(0xFF1565C0);
  if (kg >= 15) return const Color(0xFFF57F17);
  if (kg >= 10) return const Color(0xFF2E7D32);
  if (kg >= 5) return const Color(0xFFE0E0E0);
  if (kg >= 2.5) return const Color(0xFFC62828);
  return const Color(0xFF90A4AE);
}

Color _plateTextColor(double kg) => kg >= 5 ? Colors.black87 : Colors.white;

double _plateWidth(double kg) {
  if (kg >= 25) return 22;
  if (kg >= 20) return 19;
  if (kg >= 15) return 16;
  if (kg >= 10) return 14;
  if (kg >= 5) return 12;
  if (kg >= 2.5) return 10;
  return 8;
}

double _plateHeight(double kg) {
  if (kg >= 25) return 82;
  if (kg >= 20) return 76;
  if (kg >= 15) return 70;
  if (kg >= 10) return 64;
  if (kg >= 5) return 56;
  if (kg >= 2.5) return 48;
  return 40;
}

String _fmtKg(double kg) {
  if (kg % 1 == 0) return kg.toInt().toString();
  return kg.toString();
}

String _fmtTotal(double w) {
  if (w % 1 == 0) return w.toInt().toString();
  final s = w.toStringAsFixed(2);
  return s.replaceAll(RegExp(r'0+$'), '').replaceAll(RegExp(r'\.$'), '');
}

// ── Main sheet ────────────────────────────────────────────────────────────

class PlateCalculatorSheet extends StatefulWidget {
  final PlateLoadingType loadingType;
  final GymSettings gymSettings;
  final double initialWeight;

  const PlateCalculatorSheet({
    super.key,
    required this.loadingType,
    required this.gymSettings,
    required this.initialWeight,
  });

  @override
  State<PlateCalculatorSheet> createState() => _PlateCalculatorSheetState();
}

class _PlateCalculatorSheetState extends State<PlateCalculatorSheet> {
  int _selectedBarIdx = 0;
  // plates on ONE side, stored in order added (newest last)
  final List<double> _plates = [];
  late PlateLoadingType _mode;

  @override
  void initState() {
    super.initState();
    // Start in a sensible mode; fall back to barbellBoth for 'none'.
    _mode = widget.loadingType == PlateLoadingType.none
        ? PlateLoadingType.barbellBoth
        : widget.loadingType;
  }

  bool get _hasBars =>
      _mode == PlateLoadingType.barbellBoth ||
      _mode == PlateLoadingType.barbellSingle;

  bool get _isBothSides =>
      _mode == PlateLoadingType.barbellBoth ||
      _mode == PlateLoadingType.machineBoth;

  double get _barWeight {
    if (!_hasBars || widget.gymSettings.bars.isEmpty) return 0;
    return widget.gymSettings.bars[_selectedBarIdx].weight;
  }

  double get _platesSum => _plates.fold(0.0, (s, p) => s + p);

  double get _totalWeight =>
      _barWeight + _platesSum * (_isBothSides ? 2.0 : 1.0);

  String get _sideLabel {
    switch (_mode) {
      case PlateLoadingType.barbellBoth:
      case PlateLoadingType.machineBoth:
        return 'per side — total × 2';
      case PlateLoadingType.barbellSingle:
        return 'one end — bar + plates';
      case PlateLoadingType.machineSingle:
        return 'single side';
      case PlateLoadingType.none:
        return '';
    }
  }

  Widget _modeChip(String label, PlateLoadingType mode) {
    final selected = _mode == mode;
    return GestureDetector(
      onTap: () => setState(() {
        _mode = mode;
        _plates.clear();
      }),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        decoration: BoxDecoration(
          color: selected ? AppColors.blue : AppColors.background,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
              color: selected ? AppColors.blue : AppColors.divider),
        ),
        child: Text(label,
            style: TextStyle(
                color: selected ? Colors.white : AppColors.textSecondary,
                fontSize: 13,
                fontWeight:
                    selected ? FontWeight.bold : FontWeight.normal)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Display plates sorted heaviest first (innermost = heaviest in real gym)
    final displayPlates = [..._plates]..sort((a, b) => b.compareTo(a));

    return Container(
      decoration: const BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      padding: EdgeInsets.fromLTRB(
        16,
        12,
        16,
        math.max(MediaQuery.of(context).padding.bottom, 16),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Handle bar
          Center(
            child: Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.divider,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 10),

          // ── Mode selector ─────────────────────────────────────────────────
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _modeChip('Barbell', PlateLoadingType.barbellBoth),
              const SizedBox(width: 8),
              _modeChip('Machine', PlateLoadingType.machineBoth),
              const SizedBox(width: 8),
              _modeChip('Single', PlateLoadingType.machineSingle),
            ],
          ),
          const SizedBox(height: 14),

          // ── Header: total weight + Use button ────────────────────────────
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${_fmtTotal(_totalWeight)} kg',
                    style: const TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 32,
                      fontWeight: FontWeight.bold,
                      height: 1,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    _plates.isEmpty
                        ? (_hasBars
                            ? 'bar only — add plates below'
                            : 'add plates below')
                        : '${_fmtTotal(_platesSum)} kg $_sideLabel',
                    style: const TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
              const Spacer(),
              FilledButton(
                onPressed: () => Navigator.pop(context, _totalWeight),
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.blue,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10)),
                ),
                child: const Text('Use weight',
                    style:
                        TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // ── Barbell visual ───────────────────────────────────────────────
          _BarbellVisual(
            plates: displayPlates,
            onRemovePlateWeight: (kg) => setState(() {
              // Remove the last-added plate of this weight (outermost)
              for (int i = _plates.length - 1; i >= 0; i--) {
                if (_plates[i] == kg) {
                  _plates.removeAt(i);
                  break;
                }
              }
            }),
          ),
          const SizedBox(height: 12),

          // ── Bar selector (barbells only) ─────────────────────────────────
          if (_hasBars && widget.gymSettings.bars.isNotEmpty) ...[
            SizedBox(
              height: 60,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                padding: EdgeInsets.zero,
                itemCount: widget.gymSettings.bars.length,
                separatorBuilder: (_, __) => const SizedBox(width: 8),
                itemBuilder: (_, i) {
                  final bar = widget.gymSettings.bars[i];
                  final selected = i == _selectedBarIdx;
                  return GestureDetector(
                    onTap: () => setState(() => _selectedBarIdx = i),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 150),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 6),
                      decoration: BoxDecoration(
                        color: selected
                            ? AppColors.blue
                            : AppColors.background,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: selected
                              ? AppColors.blue
                              : AppColors.divider,
                        ),
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            bar.name,
                            style: TextStyle(
                              color: selected
                                  ? Colors.white
                                  : AppColors.textPrimary,
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          Text(
                            '${_fmtKg(bar.weight)} kg',
                            style: TextStyle(
                              color: selected
                                  ? Colors.white70
                                  : AppColors.textSecondary,
                              fontSize: 11,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 12),
          ] else if (_hasBars && widget.gymSettings.bars.isEmpty) ...[
            const Text(
              'No bars configured. Add bars in Profile → Settings.',
              style:
                  TextStyle(color: AppColors.textSecondary, fontSize: 12),
            ),
            const SizedBox(height: 12),
          ],

          // ── Available plate buttons ──────────────────────────────────────
          if (widget.gymSettings.plates.isEmpty)
            const Text(
              'No plates configured. Add plates in Profile → Settings.',
              style: TextStyle(color: AppColors.textSecondary, fontSize: 12),
            )
          else
            Wrap(
              spacing: 10,
              runSpacing: 10,
              alignment: WrapAlignment.center,
              children: widget.gymSettings.plates.map((kg) {
                return GestureDetector(
                  onTap: () => setState(() => _plates.add(kg)),
                  child: Container(
                    width: 54,
                    height: 54,
                    decoration: BoxDecoration(
                      color: _plateColor(kg),
                      shape: BoxShape.circle,
                      boxShadow: const [
                        BoxShadow(
                          color: Colors.black26,
                          blurRadius: 4,
                          offset: Offset(0, 2),
                        ),
                      ],
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      _fmtKg(kg),
                      style: TextStyle(
                        color: _plateTextColor(kg),
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),

          // ── Clear + hint ─────────────────────────────────────────────────
          const SizedBox(height: 10),
          Row(
            children: [
              Text(
                'Tap plate to add · Tap bar plate to remove',
                style: const TextStyle(
                    color: AppColors.textSecondary, fontSize: 11),
              ),
              const Spacer(),
              if (_plates.isNotEmpty)
                GestureDetector(
                  onTap: () => setState(() => _plates.clear()),
                  child: const Text(
                    'Clear',
                    style: TextStyle(
                        color: AppColors.red,
                        fontSize: 12,
                        fontWeight: FontWeight.w600),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

// ── Barbell visual ────────────────────────────────────────────────────────

class _BarbellVisual extends StatelessWidget {
  final List<double> plates; // sorted descending (heaviest first)
  final void Function(double kg) onRemovePlateWeight;

  const _BarbellVisual({
    required this.plates,
    required this.onRemovePlateWeight,
  });

  @override
  Widget build(BuildContext context) {
    final maxH = plates.isEmpty
        ? 56.0
        : plates.map(_plateHeight).reduce(math.max);
    final totalH = maxH + 10;

    return SizedBox(
      height: totalH,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Centre-bar shaft (left)
          Container(
            width: 20,
            height: 8,
            decoration: BoxDecoration(
              color: const Color(0xFF9E9E9E),
              borderRadius: BorderRadius.circular(4),
            ),
          ),
          // Inner collar
          Container(
            width: 10,
            height: 26,
            decoration: BoxDecoration(
              color: const Color(0xFF616161),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          // Plates
          Expanded(
            child: plates.isEmpty
                ? const Center(
                    child: Text(
                      'No plates added',
                      style: TextStyle(
                          color: AppColors.textSecondary, fontSize: 12),
                    ),
                  )
                : SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: plates.map((kg) {
                        return GestureDetector(
                          onTap: () => onRemovePlateWeight(kg),
                          child: _PlateRect(kg: kg),
                        );
                      }).toList(),
                    ),
                  ),
          ),
          // Outer collar
          Container(
            width: 10,
            height: 26,
            decoration: BoxDecoration(
              color: const Color(0xFF616161),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          // Sleeve (outer shaft)
          Container(
            width: 30,
            height: 8,
            decoration: BoxDecoration(
              color: const Color(0xFF9E9E9E),
              borderRadius: BorderRadius.circular(4),
            ),
          ),
        ],
      ),
    );
  }
}

class _PlateRect extends StatelessWidget {
  final double kg;

  const _PlateRect({required this.kg});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: _plateWidth(kg),
      height: _plateHeight(kg),
      margin: const EdgeInsets.symmetric(horizontal: 1),
      decoration: BoxDecoration(
        color: _plateColor(kg),
        borderRadius: BorderRadius.circular(3),
      ),
      alignment: Alignment.center,
      child: RotatedBox(
        quarterTurns: 1,
        child: Text(
          _fmtKg(kg),
          style: TextStyle(
            color: _plateTextColor(kg),
            fontSize: 8,
            fontWeight: FontWeight.bold,
            height: 1.1,
          ),
        ),
      ),
    );
  }
}
