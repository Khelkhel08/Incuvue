import 'package:flutter/material.dart';

import '../models/incubator_model.dart';
import '../services/batch_service.dart';
import '../services/incubator_service.dart';
import '../widgets/app_header.dart';
import '../widgets/app_logo.dart';

const _navy = Color(0xFF1F2D3D);
const _teal = Color(0xFF1F6F7C);
const _green = Color(0xFF118339);
const _mint = Color(0xFFE8F5E9);
const _mintBorder = Color(0xFFA5D6A7);

class StartIncubationScreen extends StatefulWidget {
  const StartIncubationScreen({super.key});

  @override
  State<StartIncubationScreen> createState() => _StartIncubationScreenState();
}

class _StartIncubationScreenState extends State<StartIncubationScreen> {
  final _batchService = BatchService();
  bool _isSubmitting = false;
  bool _daysReady = false;

  int _incubationStart = 1;
  int _incubationEnd = 18;
  int _lockdownStart = 18;
  int _lockdownEnd = 21;

  void _applyDefaultsFrom(IncubatorData data) {
    if (_daysReady) return;
    _incubationStart = data.incubationStartDay > 0 ? data.incubationStartDay : 1;
    _incubationEnd = data.incubationEndDay > 0 ? data.incubationEndDay : 18;
    _lockdownStart =
        data.lockdownStartDay > 0 ? data.lockdownStartDay : _incubationEnd;
    _lockdownEnd = data.lockdownEndDay > 0 ? data.lockdownEndDay : 21;
    _daysReady = true;
  }

  void _setIncubationEnd(int value) {
    var end = value.clamp(1, 30);
    var lockdownStart = end;
    var lockdownEnd = _lockdownEnd;
    if (lockdownEnd < lockdownStart) {
      lockdownEnd = lockdownStart + 3;
    }
    setState(() {
      _incubationEnd = end;
      _lockdownStart = lockdownStart;
      _lockdownEnd = lockdownEnd.clamp(lockdownStart, 30);
    });
  }

  void _setLockdownEnd(int value) {
    final end = value.clamp(_lockdownStart, 30);
    setState(() => _lockdownEnd = end);
  }

  Future<void> _start(IncubatorData data) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Start Incubation?'),
          content: Text(
            'Incubation will begin at Day $_incubationStart.\n\n'
            'Incubation:\nDay $_incubationStart–$_incubationEnd\n\n'
            'Lockdown:\nDay $_lockdownStart–$_lockdownEnd',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text('Start'),
            ),
          ],
        );
      },
    );

    if (confirmed != true || !mounted) return;

    setState(() => _isSubmitting = true);
    try {
      await _batchService.startIncubation(
        data: data,
        currentDay: _incubationStart,
        incubationStartDay: _incubationStart,
        incubationEndDay: _incubationEnd,
        lockdownStartDay: _lockdownStart,
        lockdownEndDay: _lockdownEnd,
      );
      if (!mounted) return;
      Navigator.of(context).popUntil((route) => route.isFirst);
    } catch (error) {
      debugPrint('Firestore error: $error');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(BatchService.friendlyError(error))),
      );
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  Future<void> _editEndDay({
    required String title,
    required String helper,
    required int currentValue,
    required int min,
    required int max,
    required ValueChanged<int> onSave,
  }) async {
    final controller = TextEditingController(text: '$currentValue');
    final value = await showDialog<int>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: Text(title),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(helper, style: const TextStyle(color: _navy)),
              const SizedBox(height: 12),
              TextField(
                controller: controller,
                autofocus: true,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Day number',
                  border: OutlineInputBorder(),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                final parsed = int.tryParse(controller.text.trim());
                if (parsed == null || parsed < min || parsed > max) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Enter a day between $min and $max.')),
                  );
                  return;
                }
                Navigator.pop(dialogContext, parsed);
              },
              child: const Text('Save'),
            ),
          ],
        );
      },
    );
    controller.dispose();
    if (value != null) onSave(value);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const AppHeader(
        title: 'START INCUBATION',
        showBack: true,
        showLogoTrailing: true,
      ),
      body: SafeArea(
        top: false,
        child: StreamBuilder<IncubatorData>(
          stream: IncubatorService().watchIncubator(),
          builder: (context, snapshot) {
            if (!snapshot.hasData) {
              return const Center(child: CircularProgressIndicator());
            }

            final data = snapshot.data!;
            if (data.isActive) {
              return const Center(
                child: Padding(
                  padding: EdgeInsets.all(24),
                  child: Text(
                    'An incubation is already active. Finish or cancel it before starting a new one.',
                    textAlign: TextAlign.center,
                  ),
                ),
              );
            }

            _applyDefaultsFrom(data);

            return SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(18, 16, 18, 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Center(child: AppLogo(size: 84)),
                  const SizedBox(height: 16),
                  const Center(
                    child: Text(
                      'START INCUBATION',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: _navy,
                      ),
                    ),
                  ),
                  const SizedBox(height: 22),
                  const Text(
                    'SET DAYS',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: _navy,
                      letterSpacing: 0.4,
                    ),
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'Choose how long incubation and lockdown last. The summary below stays in sync.',
                    style: TextStyle(fontSize: 13, color: Color(0xFF5B6773)),
                  ),
                  const SizedBox(height: 12),
                  _SetDayCard(
                    title: 'Incubation Stage',
                    rangeLabel: 'Day $_incubationStart – $_incubationEnd',
                    subtitle: 'Eggs develop during this period.',
                    canDecrement: _incubationEnd > 1,
                    canIncrement: _incubationEnd < 30,
                    onDecrement: () => _setIncubationEnd(_incubationEnd - 1),
                    onIncrement: () => _setIncubationEnd(_incubationEnd + 1),
                    onEdit: () => _editEndDay(
                      title: 'Incubation Stage',
                      helper: 'Last day of incubation (default 18). Lockdown will start on this day.',
                      currentValue: _incubationEnd,
                      min: 1,
                      max: 30,
                      onSave: _setIncubationEnd,
                    ),
                  ),
                  const SizedBox(height: 10),
                  _SetDayCard(
                    title: 'Lockdown Stage',
                    rangeLabel: 'Day $_lockdownStart – $_lockdownEnd',
                    subtitle: 'Turning stops as hatch day approaches.',
                    canDecrement: _lockdownEnd > _lockdownStart,
                    canIncrement: _lockdownEnd < 30,
                    onDecrement: () => _setLockdownEnd(_lockdownEnd - 1),
                    onIncrement: () => _setLockdownEnd(_lockdownEnd + 1),
                    onEdit: () => _editEndDay(
                      title: 'Lockdown Stage',
                      helper: 'Last day of lockdown (default 21).',
                      currentValue: _lockdownEnd,
                      min: _lockdownStart,
                      max: 30,
                      onSave: _setLockdownEnd,
                    ),
                  ),
                  const SizedBox(height: 18),
                  _StageSummaryCard(
                    incubationStart: _incubationStart,
                    incubationEnd: _incubationEnd,
                    lockdownStart: _lockdownStart,
                    lockdownEnd: _lockdownEnd,
                  ),
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: ElevatedButton(
                      onPressed: _isSubmitting ? null : () => _start(data),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _green,
                        foregroundColor: Colors.white,
                      ),
                      child: _isSubmitting
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                color: Colors.white,
                                strokeWidth: 2,
                              ),
                            )
                          : const Text('START INCUBATION'),
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

class _SetDayCard extends StatelessWidget {
  final String title;
  final String rangeLabel;
  final String subtitle;
  final bool canDecrement;
  final bool canIncrement;
  final VoidCallback onDecrement;
  final VoidCallback onIncrement;
  final VoidCallback onEdit;

  const _SetDayCard({
    required this.title,
    required this.rangeLabel,
    required this.subtitle,
    required this.canDecrement,
    required this.canIncrement,
    required this.onDecrement,
    required this.onIncrement,
    required this.onEdit,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onEdit,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.fromLTRB(14, 12, 10, 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFFD5DDE3)),
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: _navy,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      rangeLabel,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: _teal,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: const TextStyle(
                        fontSize: 12,
                        color: Color(0xFF5B6773),
                      ),
                    ),
                  ],
                ),
              ),
              _DayStepButton(
                icon: Icons.remove,
                enabled: canDecrement,
                onTap: onDecrement,
              ),
              const SizedBox(width: 6),
              _DayStepButton(
                icon: Icons.add,
                enabled: canIncrement,
                onTap: onIncrement,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DayStepButton extends StatelessWidget {
  final IconData icon;
  final bool enabled;
  final VoidCallback onTap;

  const _DayStepButton({
    required this.icon,
    required this.enabled,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: enabled ? const Color(0xFFEEF4F6) : const Color(0xFFF3F5F7),
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        onTap: enabled ? onTap : null,
        borderRadius: BorderRadius.circular(8),
        child: SizedBox(
          width: 40,
          height: 40,
          child: Icon(
            icon,
            size: 20,
            color: enabled ? _navy : const Color(0xFFB0B8C0),
          ),
        ),
      ),
    );
  }
}

class _StageSummaryCard extends StatelessWidget {
  final int incubationStart;
  final int incubationEnd;
  final int lockdownStart;
  final int lockdownEnd;

  const _StageSummaryCard({
    required this.incubationStart,
    required this.incubationEnd,
    required this.lockdownStart,
    required this.lockdownEnd,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 16),
      decoration: BoxDecoration(
        color: _mint,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: _mintBorder),
      ),
      child: Column(
        children: [
          const Text(
            'Normal Incubation',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: Color(0xFF2F3A44),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Day $incubationStart – $incubationEnd',
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: _teal,
            ),
          ),
          const SizedBox(height: 14),
          const Text(
            'Lockdown',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: Color(0xFF2F3A44),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Day $lockdownStart – $lockdownEnd',
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: _teal,
            ),
          ),
        ],
      ),
    );
  }
}
