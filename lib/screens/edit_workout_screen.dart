import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../models/set_entry.dart';
import '../models/workout_exercise.dart';
import '../models/workout_session.dart';
import '../providers/workout_provider.dart';
import '../theme/app_theme.dart';

class EditWorkoutScreen extends StatefulWidget {
  final WorkoutSession session;
  const EditWorkoutScreen({super.key, required this.session});

  @override
  State<EditWorkoutScreen> createState() => _EditWorkoutScreenState();
}

class _EditWorkoutScreenState extends State<EditWorkoutScreen> {
  late WorkoutSession _session;
  late TextEditingController _nameCtrl;
  final Map<int, TextEditingController> _weightCtrls = {};
  final Map<int, TextEditingController> _repsCtrls = {};

  @override
  void initState() {
    super.initState();
    // Deep copy via JSON roundtrip — edits are isolated from provider state
    _session = WorkoutSession.fromJson(
      jsonDecode(jsonEncode(widget.session.toJson())) as Map<String, dynamic>,
    );
    _nameCtrl = TextEditingController(text: _session.name);
    for (final ex in _session.exercises) {
      for (final set in ex.sets) {
        _attachControllers(set);
      }
    }
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    for (final c in _weightCtrls.values) c.dispose();
    for (final c in _repsCtrls.values) c.dispose();
    super.dispose();
  }

  void _attachControllers(SetEntry set) {
    final wc = TextEditingController(text: set.weightInput);
    final rc = TextEditingController(text: set.repsInput);
    wc.addListener(() => set.weightInput = wc.text);
    rc.addListener(() => set.repsInput = rc.text);
    _weightCtrls[set.id] = wc;
    _repsCtrls[set.id] = rc;
  }

  void _detachControllers(SetEntry set) {
    _weightCtrls.remove(set.id)?.dispose();
    _repsCtrls.remove(set.id)?.dispose();
  }

  void _save() {
    final name = _nameCtrl.text.trim();
    if (name.isNotEmpty) _session.name = name;
    context.read<WorkoutProvider>().saveHistorySession(_session);
    Navigator.pop(context, true);
  }

  void _addSet(WorkoutExercise ex) {
    setState(() {
      final lastType = ex.sets.isNotEmpty ? ex.sets.last.setType : SetType.normal;
      final newSet = SetEntry(setNumber: 0, setType: lastType, completed: false);
      ex.sets.add(newSet);
      _renumber(ex.sets);
      _attachControllers(newSet);
    });
  }

  void _removeSet(WorkoutExercise ex, SetEntry set) {
    if (ex.sets.length <= 1) return; // keep at least one set
    setState(() {
      ex.sets.remove(set);
      _detachControllers(set);
      _renumber(ex.sets);
    });
  }

  void _cycleType(WorkoutExercise ex, SetEntry set) {
    setState(() {
      const order = [SetType.normal, SetType.warmUp, SetType.dropSet, SetType.failure];
      set.setType = order[(order.indexOf(set.setType) + 1) % order.length];
      _renumber(ex.sets);
    });
  }

  static void _renumber(List<SetEntry> sets) {
    final counters = <SetType, int>{};
    for (final s in sets) {
      final n = (counters[s.setType] ?? 0) + 1;
      counters[s.setType] = n;
      s.setNumber = n;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        automaticallyImplyLeading: false,
        leadingWidth: 80,
        leading: TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel',
              style:
                  TextStyle(color: AppColors.textSecondary, fontSize: 14)),
        ),
        title: const Text('Edit Workout',
            style: TextStyle(
                color: AppColors.textPrimary,
                fontWeight: FontWeight.bold,
                fontSize: 17)),
        centerTitle: true,
        actions: [
          TextButton(
            onPressed: _save,
            child: const Text('Save',
                style: TextStyle(
                    color: AppColors.blue,
                    fontWeight: FontWeight.bold,
                    fontSize: 14)),
          ),
        ],
        elevation: 0,
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
        children: [
          _nameField(),
          const SizedBox(height: 20),
          for (final ex in _session.exercises)
            _ExerciseCard(
              ex: ex,
              weightCtrls: _weightCtrls,
              repsCtrls: _repsCtrls,
              onAddSet: () => _addSet(ex),
              onRemoveSet: (s) => _removeSet(ex, s),
              onCycleType: (s) => _cycleType(ex, s),
              onToggle: (s) => setState(() => s.completed = !s.completed),
            ),
        ],
      ),
    );
  }

  Widget _nameField() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(10),
      ),
      child: TextField(
        controller: _nameCtrl,
        style: const TextStyle(
            color: AppColors.textPrimary,
            fontSize: 15,
            fontWeight: FontWeight.bold),
        decoration: const InputDecoration(
          labelText: 'Workout Name',
          labelStyle:
              TextStyle(color: AppColors.textSecondary, fontSize: 12),
          border: InputBorder.none,
        ),
      ),
    );
  }
}

// ── Exercise card ─────────────────────────────────────────────────────────────

class _ExerciseCard extends StatelessWidget {
  final WorkoutExercise ex;
  final Map<int, TextEditingController> weightCtrls;
  final Map<int, TextEditingController> repsCtrls;
  final VoidCallback onAddSet;
  final void Function(SetEntry) onRemoveSet;
  final void Function(SetEntry) onCycleType;
  final void Function(SetEntry) onToggle;

  const _ExerciseCard({
    required this.ex,
    required this.weightCtrls,
    required this.repsCtrls,
    required this.onAddSet,
    required this.onRemoveSet,
    required this.onCycleType,
    required this.onToggle,
  });

  bool get _isCardio => ex.exerciseType.index == 1; // ExerciseType.cardio

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Padding(
            padding:
                const EdgeInsets.fromLTRB(14, 12, 14, 0),
            child: Text(ex.exerciseName,
                style: const TextStyle(
                    color: AppColors.blue,
                    fontSize: 14,
                    fontWeight: FontWeight.bold)),
          ),
          const SizedBox(height: 10),
          // Column headers
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14),
            child: Row(children: [
              const SizedBox(width: 40),
              Expanded(
                  flex: 2,
                  child: Text(_isCardio ? 'KM' : 'KG',
                      style: _hdr)),
              Expanded(
                  child: Text(_isCardio ? 'TIME' : 'REPS',
                      style: _hdr)),
              const SizedBox(width: 28), // complete
              const SizedBox(width: 28), // delete
            ]),
          ),
          const SizedBox(height: 4),
          // Set rows
          ...ex.sets.map((set) => _SetRow(
                set: set,
                weightCtrl: weightCtrls[set.id],
                repsCtrl: repsCtrls[set.id],
                isCardio: _isCardio,
                onCycleType: () => onCycleType(set),
                onToggle: () => onToggle(set),
                onRemove: () => onRemoveSet(set),
              )),
          // Add set
          InkWell(
            onTap: onAddSet,
            borderRadius: const BorderRadius.vertical(
                bottom: Radius.circular(10)),
            child: const Padding(
              padding: EdgeInsets.symmetric(vertical: 12),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.add, color: AppColors.blue, size: 16),
                  SizedBox(width: 4),
                  Text('Add Set',
                      style: TextStyle(
                          color: AppColors.blue,
                          fontSize: 13,
                          fontWeight: FontWeight.w500)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  static const _hdr = TextStyle(
      color: AppColors.textSecondary,
      fontSize: 11,
      fontWeight: FontWeight.w600);
}

// ── Set row ───────────────────────────────────────────────────────────────────

class _SetRow extends StatelessWidget {
  final SetEntry set;
  final TextEditingController? weightCtrl;
  final TextEditingController? repsCtrl;
  final bool isCardio;
  final VoidCallback onCycleType;
  final VoidCallback onToggle;
  final VoidCallback onRemove;

  const _SetRow({
    required this.set,
    required this.weightCtrl,
    required this.repsCtrl,
    required this.isCardio,
    required this.onCycleType,
    required this.onToggle,
    required this.onRemove,
  });

  String get _typeLabel {
    switch (set.setType) {
      case SetType.warmUp:
        return 'W${set.setNumber}';
      case SetType.dropSet:
        return 'D${set.setNumber}';
      case SetType.failure:
        return 'F${set.setNumber}';
      default:
        return '${set.setNumber}';
    }
  }

  Color get _typeColor {
    switch (set.setType) {
      case SetType.warmUp:
        return Colors.amber;
      case SetType.dropSet:
        return AppColors.blue;
      case SetType.failure:
        return AppColors.red;
      default:
        return AppColors.textSecondary;
    }
  }

  @override
  Widget build(BuildContext context) {
    final rowBg =
        set.completed ? AppColors.completedGreen : Colors.transparent;

    return Container(
      color: rowBg,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
      child: Row(children: [
        // Set type badge — tap to cycle
        GestureDetector(
          onTap: onCycleType,
          child: SizedBox(
            width: 40,
            child: Text(_typeLabel,
                style: TextStyle(
                    color: _typeColor,
                    fontSize: 13,
                    fontWeight: FontWeight.bold)),
          ),
        ),
        // Weight / km field
        Expanded(
          flex: 2,
          child: _field(
            ctrl: weightCtrl,
            hint: isCardio ? '0.00' : '0',
            isDecimal: true,
          ),
        ),
        const SizedBox(width: 8),
        // Reps / time field
        Expanded(
          child: _field(
            ctrl: repsCtrl,
            hint: isCardio ? '0:00' : '0',
            isDecimal: isCardio,
          ),
        ),
        const SizedBox(width: 4),
        // Completion toggle
        GestureDetector(
          onTap: onToggle,
          child: SizedBox(
            width: 28,
            child: Icon(
              set.completed
                  ? Icons.check_circle
                  : Icons.radio_button_unchecked,
              color: set.completed
                  ? AppColors.checkGreen
                  : AppColors.textSecondary,
              size: 20,
            ),
          ),
        ),
        // Delete
        GestureDetector(
          onTap: onRemove,
          child: const SizedBox(
            width: 28,
            child: Icon(Icons.close,
                color: AppColors.textSecondary, size: 16),
          ),
        ),
      ]),
    );
  }

  Widget _field({
    required TextEditingController? ctrl,
    required String hint,
    required bool isDecimal,
  }) {
    return TextField(
      controller: ctrl,
      keyboardType: TextInputType.numberWithOptions(decimal: isDecimal),
      inputFormatters: [
        FilteringTextInputFormatter.allow(
            isDecimal ? RegExp(r'[\d.]') : RegExp(r'\d')),
      ],
      style: const TextStyle(color: AppColors.textPrimary, fontSize: 14),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(
            color: AppColors.textSecondary, fontSize: 14),
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(vertical: 6),
        border: InputBorder.none,
      ),
    );
  }
}
