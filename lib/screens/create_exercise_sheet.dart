import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/exercise.dart';
import '../providers/workout_provider.dart';
import '../theme/app_theme.dart';

class CreateExerciseSheet extends StatefulWidget {
  /// Pass an existing custom exercise to enter edit mode.
  final Exercise? existing;

  const CreateExerciseSheet({super.key, this.existing});

  @override
  State<CreateExerciseSheet> createState() => _CreateExerciseSheetState();
}

class _CreateExerciseSheetState extends State<CreateExerciseSheet> {
  late final TextEditingController _nameCtrl;
  late String? _muscleGroup;
  late ExerciseType _type;
  late final Set<String> _tags;
  late PlateLoadingType _plateLoading;

  static const _muscleGroups = [
    'Chest', 'Back', 'Shoulders', 'Arms', 'Legs', 'Core', 'Full Body', 'Cardio',
  ];
  static const _allTags = ['Push', 'Pull', 'Compound', 'Isolation', 'Bodyweight', 'Unilateral'];

  bool get _isEdit => widget.existing != null;

  @override
  void initState() {
    super.initState();
    final ex = widget.existing;
    _nameCtrl = TextEditingController(text: ex?.name ?? '');
    _muscleGroup = ex?.muscleGroup;
    _type = ex?.type ?? ExerciseType.weight;
    _tags = Set.from(ex?.tags ?? []);
    _plateLoading = ex?.plateLoadingType ?? PlateLoadingType.none;
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    super.dispose();
  }

  bool get _valid => _nameCtrl.text.trim().isNotEmpty && _muscleGroup != null;

  void _submit() {
    if (!_valid) return;
    final provider = context.read<WorkoutProvider>();
    if (_isEdit) {
      provider.updateCustomExercise(widget.existing!.copyWith(
        name: _nameCtrl.text,
        muscleGroup: _muscleGroup,
        type: _type,
        tags: _tags.toList(),
        plateLoadingType: _type == ExerciseType.weight ? _plateLoading : PlateLoadingType.none,
      ));
    } else {
      provider.createCustomExercise(
        name: _nameCtrl.text,
        muscleGroup: _muscleGroup!,
        type: _type,
        tags: _tags.toList(),
        plateLoadingType: _type == ExerciseType.weight ? _plateLoading : PlateLoadingType.none,
      );
    }
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    _isEdit ? 'Edit Exercise' : 'Create Exercise',
                    style: const TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 18,
                        fontWeight: FontWeight.bold),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close, color: AppColors.textSecondary),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Name
            _label('Exercise Name'),
            const SizedBox(height: 8),
            Container(
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(10),
              ),
              child: TextField(
                controller: _nameCtrl,
                autofocus: !_isEdit,
                style: const TextStyle(color: AppColors.textPrimary),
                onChanged: (_) => setState(() {}),
                decoration: const InputDecoration(
                  hintText: 'e.g. Cable Fly',
                  hintStyle: TextStyle(color: AppColors.textSecondary),
                  border: InputBorder.none,
                  contentPadding:
                      EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                ),
              ),
            ),
            const SizedBox(height: 20),

            // Muscle group
            _label('Muscle Group'),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _muscleGroups.map((g) {
                final sel = _muscleGroup == g;
                return _chip(g, sel, () => setState(() => _muscleGroup = sel ? null : g));
              }).toList(),
            ),
            const SizedBox(height: 20),

            // Type
            _label('Type'),
            const SizedBox(height: 8),
            Row(children: [
              Expanded(
                child: _typeBtn('Weight', ExerciseType.weight),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _typeBtn('Cardio', ExerciseType.cardio),
              ),
            ]),
            const SizedBox(height: 20),

            // Tags
            _label('Tags (optional)'),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _allTags.map((t) {
                final sel = _tags.contains(t);
                return _chip(t, sel, () => setState(() {
                  if (sel) _tags.remove(t); else _tags.add(t);
                }));
              }).toList(),
            ),

            // Plate loading (weight exercises only)
            if (_type == ExerciseType.weight) ...[
              const SizedBox(height: 20),
              _label('Plate Loading (optional)'),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _plateChip('None', PlateLoadingType.none),
                  _plateChip('Barbell', PlateLoadingType.barbellBoth),
                  _plateChip('Machine (2 sides)', PlateLoadingType.machineBoth),
                  _plateChip('Machine (1 side)', PlateLoadingType.machineSingle),
                ],
              ),
            ],

            const SizedBox(height: 28),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _valid ? _submit : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.blue,
                  disabledBackgroundColor: AppColors.surface,
                  minimumSize: const Size.fromHeight(48),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10)),
                ),
                child: Text(
                  _isEdit ? 'Save Changes' : 'Create Exercise',
                  style: TextStyle(
                    color: _valid ? Colors.white : AppColors.textSecondary,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _label(String text) => Text(
        text,
        style: const TextStyle(
            color: AppColors.textSecondary,
            fontSize: 12,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.5),
      );

  Widget _chip(String label, bool selected, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? AppColors.blue : AppColors.background,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
              color: selected ? AppColors.blue : AppColors.divider),
        ),
        child: Text(label,
            style: TextStyle(
                color: selected ? Colors.white : AppColors.textPrimary,
                fontSize: 13,
                fontWeight:
                    selected ? FontWeight.bold : FontWeight.normal)),
      ),
    );
  }

  Widget _typeBtn(String label, ExerciseType t) {
    final sel = _type == t;
    return GestureDetector(
      onTap: () => setState(() => _type = t),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: sel ? AppColors.blue : AppColors.surface,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
              color: sel ? AppColors.blue : Colors.transparent),
        ),
        child: Center(
          child: Text(label,
              style: TextStyle(
                  color: sel ? Colors.white : AppColors.textPrimary,
                  fontWeight: sel ? FontWeight.bold : FontWeight.normal)),
        ),
      ),
    );
  }

  Widget _plateChip(String label, PlateLoadingType t) {
    final sel = _plateLoading == t;
    return GestureDetector(
      onTap: () => setState(() => _plateLoading = t),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: sel ? AppColors.blue : AppColors.background,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
              color: sel ? AppColors.blue : AppColors.divider),
        ),
        child: Text(label,
            style: TextStyle(
                color: sel ? Colors.white : AppColors.textPrimary,
                fontSize: 13,
                fontWeight:
                    sel ? FontWeight.bold : FontWeight.normal)),
      ),
    );
  }
}

void showCreateExerciseSheet(BuildContext context, {Exercise? existing}) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: AppColors.surface,
    shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
    builder: (_) => CreateExerciseSheet(existing: existing),
  );
}
