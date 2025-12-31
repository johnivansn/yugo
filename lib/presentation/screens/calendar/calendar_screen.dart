import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:table_calendar/table_calendar.dart';

import '../../../core/constants/storage_keys.dart';
import '../../../data/models/habit_model.dart';
import '../../../data/models/streak_model.dart';
import 'day_detail_screen.dart';

class CalendarScreen extends StatefulWidget {
  const CalendarScreen({super.key});

  @override
  State<CalendarScreen> createState() => _CalendarScreenState();
}

class _CalendarScreenState extends State<CalendarScreen> {
  DateTime _focusedDay = DateTime.now();
  DateTime? _selectedDay;
  CalendarFormat _calendarFormat = CalendarFormat.month;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Calendario'),
        actions: [
          IconButton(
            icon: const Icon(Icons.today),
            onPressed: () {
              setState(() {
                _focusedDay = DateTime.now();
                _selectedDay = DateTime.now();
              });
            },
            tooltip: 'Hoy',
          ),
        ],
      ),
      body: Column(
        children: [
          _buildCalendar(),
          const Divider(height: 1),
          Expanded(child: _buildDaySummary()),
        ],
      ),
    );
  }

  Widget _buildCalendar() {
    return ValueListenableBuilder(
      valueListenable: Hive.box<StreakModel>(
        StorageKeys.streaksBox,
      ).listenable(),
      builder: (context, Box<StreakModel> box, _) {
        final streaks = box.values.toList();

        return TableCalendar(
          firstDay: DateTime.utc(2020, 1, 1),
          lastDay: DateTime.utc(2030, 12, 31),
          focusedDay: _focusedDay,
          calendarFormat: _calendarFormat,
          selectedDayPredicate: (day) => isSameDay(_selectedDay, day),
          onDaySelected: (selectedDay, focusedDay) {
            setState(() {
              _selectedDay = selectedDay;
              _focusedDay = focusedDay;
            });
          },
          onFormatChanged: (format) {
            setState(() {
              _calendarFormat = format;
            });
          },
          onPageChanged: (focusedDay) {
            _focusedDay = focusedDay;
          },
          calendarStyle: CalendarStyle(
            todayDecoration: BoxDecoration(
              color: Colors.blue.withValues(alpha: 0.5),
              shape: BoxShape.circle,
            ),
            selectedDecoration: const BoxDecoration(
              color: Colors.blue,
              shape: BoxShape.circle,
            ),
            markerDecoration: const BoxDecoration(
              color: Colors.green,
              shape: BoxShape.circle,
            ),
          ),
          calendarBuilders: CalendarBuilders(
            markerBuilder: (context, day, events) {
              final dayStatus = _getDayStatus(day, streaks);
              if (dayStatus == null) return null;

              return Positioned(
                bottom: 1,
                child: Container(
                  width: 6,
                  height: 6,
                  decoration: BoxDecoration(
                    color: dayStatus == _DayStatus.completed
                        ? Colors.green
                        : Colors.red,
                    shape: BoxShape.circle,
                  ),
                ),
              );
            },
          ),
          headerStyle: const HeaderStyle(
            formatButtonVisible: true,
            titleCentered: true,
          ),
        );
      },
    );
  }

  Widget _buildDaySummary() {
    if (_selectedDay == null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.calendar_today, size: 80, color: Colors.grey.shade400),
            const SizedBox(height: 16),
            Text(
              'Selecciona un día',
              style: Theme.of(
                context,
              ).textTheme.titleLarge?.copyWith(color: Colors.grey.shade600),
            ),
            const SizedBox(height: 8),
            Text(
              'Toca una fecha para ver detalles',
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(color: Colors.grey.shade500),
            ),
          ],
        ),
      );
    }

    return ValueListenableBuilder(
      valueListenable: Hive.box<StreakModel>(
        StorageKeys.streaksBox,
      ).listenable(),
      builder: (context, Box<StreakModel> box, _) {
        final streaks = box.values.toList();
        final dayData = _getDayData(_selectedDay!, streaks);

        return SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                _formatDayHeader(_selectedDay!),
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 16),
              _buildDayStats(dayData),
              const SizedBox(height: 16),
              if (dayData.completedHabits.isNotEmpty)
                _buildHabitsList(
                  'Completados',
                  dayData.completedHabits,
                  Colors.green,
                ),
              if (dayData.failedHabits.isNotEmpty) ...[
                const SizedBox(height: 16),
                _buildHabitsList('Fallidos', dayData.failedHabits, Colors.red),
              ],
              if (dayData.completedHabits.isEmpty &&
                  dayData.failedHabits.isEmpty)
                Center(
                  child: Padding(
                    padding: const EdgeInsets.all(32),
                    child: Text(
                      'Sin actividad registrada',
                      style: TextStyle(
                        color: Colors.grey.shade600,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ),
                ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) =>
                            DayDetailScreen(date: _selectedDay!),
                      ),
                    );
                  },
                  icon: const Icon(Icons.info_outline),
                  label: const Text('Ver detalles completos'),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildDayStats(_DayData dayData) {
    final total = dayData.completedHabits.length + dayData.failedHabits.length;

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceAround,
      children: [
        _buildStatCard(
          'Completados',
          dayData.completedHabits.length.toString(),
          Icons.check_circle,
          Colors.green,
        ),
        _buildStatCard(
          'Fallidos',
          dayData.failedHabits.length.toString(),
          Icons.cancel,
          Colors.red,
        ),
        _buildStatCard(
          'Total',
          total.toString(),
          Icons.calendar_today,
          Colors.blue,
        ),
      ],
    );
  }

  Widget _buildStatCard(
    String label,
    String value,
    IconData icon,
    Color color,
  ) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Column(
        children: [
          Icon(icon, size: 24, color: color),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
          ),
        ],
      ),
    );
  }

  Widget _buildHabitsList(String title, List<String> habitIds, Color color) {
    final habitsBox = Hive.box<HabitModel>(StorageKeys.habitsBox);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(
              title == 'Completados' ? Icons.check_circle : Icons.cancel,
              size: 20,
              color: color,
            ),
            const SizedBox(width: 8),
            Text(
              title,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
            const Spacer(),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                '${habitIds.length}',
                style: TextStyle(
                  color: color,
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        ...habitIds.map((habitId) {
          final habit = habitsBox.get(habitId);
          if (habit == null) return const SizedBox.shrink();

          return Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: color.withValues(alpha: 0.3)),
              ),
              child: Row(
                children: [
                  Icon(
                    title == 'Completados' ? Icons.check : Icons.close,
                    size: 18,
                    color: color,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      habit.name,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        }),
      ],
    );
  }

  _DayStatus? _getDayStatus(DateTime day, List<StreakModel> streaks) {
    final dayStr = _formatDateForComparison(day);
    bool hasCompleted = false;
    bool hasFailed = false;

    for (final streak in streaks) {
      if (streak.completedDates.contains(dayStr)) {
        hasCompleted = true;
      }
      if (streak.failedDates.contains(dayStr)) {
        hasFailed = true;
      }
    }

    if (hasCompleted && !hasFailed) return _DayStatus.completed;
    if (hasFailed) return _DayStatus.failed;
    if (hasCompleted && hasFailed) return _DayStatus.mixed;
    return null;
  }

  _DayData _getDayData(DateTime day, List<StreakModel> streaks) {
    final dayStr = _formatDateForComparison(day);
    final completedHabits = <String>[];
    final failedHabits = <String>[];

    for (final streak in streaks) {
      if (streak.completedDates.contains(dayStr)) {
        completedHabits.add(streak.habitId);
      }
      if (streak.failedDates.contains(dayStr)) {
        failedHabits.add(streak.habitId);
      }
    }

    return _DayData(
      completedHabits: completedHabits,
      failedHabits: failedHabits,
    );
  }

  String _formatDateForComparison(DateTime date) {
    return DateTime(date.year, date.month, date.day).toIso8601String();
  }

  String _formatDayHeader(DateTime date) {
    final weekdays = [
      'Lunes',
      'Martes',
      'Miércoles',
      'Jueves',
      'Viernes',
      'Sábado',
      'Domingo',
    ];
    final months = [
      'Enero',
      'Febrero',
      'Marzo',
      'Abril',
      'Mayo',
      'Junio',
      'Julio',
      'Agosto',
      'Septiembre',
      'Octubre',
      'Noviembre',
      'Diciembre',
    ];

    final weekday = weekdays[date.weekday - 1];
    final month = months[date.month - 1];

    return '$weekday, ${date.day} de $month ${date.year}';
  }
}

enum _DayStatus { completed, failed, mixed }

class _DayData {
  final List<String> completedHabits;
  final List<String> failedHabits;

  _DayData({required this.completedHabits, required this.failedHabits});
}
