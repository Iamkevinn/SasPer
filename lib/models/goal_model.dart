// lib/models/goal_model.dart

import 'package:equatable/equatable.dart';
import 'package:sasper/models/category_model.dart';

// ─── Sentinel para copyWith nullable ─────────────────────────────────────────
// Permite diferenciar "el caller no pasó el campo" de "el caller pasó null".
// Sin esto, copyWith no puede poner savingsFrequency en null (bug 5 del análisis).
const _kUnset = Object();

// ─── Enums ────────────────────────────────────────────────────────────────────

enum GoalSavingsFrequency {
  daily,
  weekly,
  monthly;

  static GoalSavingsFrequency? fromString(String? value) {
    switch (value?.toLowerCase()) {
      case 'daily':   return GoalSavingsFrequency.daily;
      case 'weekly':  return GoalSavingsFrequency.weekly;
      case 'monthly': return GoalSavingsFrequency.monthly;
      default:        return null;
    }
  }
}

enum GoalTimeframe {
  short,
  medium,
  long,
  custom;

  static GoalTimeframe fromString(String? value) {
    switch (value?.toLowerCase()) {
      case 'short':  return GoalTimeframe.short;
      case 'medium': return GoalTimeframe.medium;
      case 'long':   return GoalTimeframe.long;
      case 'custom': return GoalTimeframe.custom;
      default:       return GoalTimeframe.short;
    }
  }
}

enum GoalPriority {
  low,
  medium,
  high;

  static GoalPriority fromString(String? value) {
    switch (value?.toLowerCase()) {
      case 'low':    return GoalPriority.low;
      case 'medium': return GoalPriority.medium;
      case 'high':   return GoalPriority.high;
      default:       return GoalPriority.medium;
    }
  }
}

enum GoalStatus {
  active,
  completed,
  archived;

  static GoalStatus fromString(String? value) {
    switch (value?.toLowerCase()) {
      case 'active':   return GoalStatus.active;
      case 'completed': return GoalStatus.completed;
      case 'archived': return GoalStatus.archived;
      default:         return GoalStatus.active;
    }
  }
}

// ─── Modelo ───────────────────────────────────────────────────────────────────

class Goal extends Equatable {
  final String id;
  final String userId;
  final String name;
  final double targetAmount;
  final double currentAmount;
  final DateTime? targetDate;
  final DateTime createdAt;
  final GoalStatus status;
  final String? iconName;
  final GoalTimeframe timeframe;
  final GoalPriority priority;
  final String? categoryId;
  final Category? category;
  final dynamic notesContent;

  final int streakCount;
  final int longestStreak;

  // Ritual de ahorro
  final GoalSavingsFrequency? savingsFrequency;
  final int? savingsDayOfWeek;
  final int? savingsDayOfMonth;
  final double? savingsAmount;
  final DateTime? nextReminderDate;
  final DateTime? lastContributionDate;

  // ── NUEVOS: Hora de notificación configurable por el usuario ──────────────
  // Default 9:00 AM — mismo valor que tenía hardcodeado el servicio antes.
  final int notificationHour;    // 0–23
  final int notificationMinute;  // 0–59

  const Goal({
    required this.id,
    required this.userId,
    required this.name,
    required this.targetAmount,
    required this.currentAmount,
    this.targetDate,
    required this.createdAt,
    required this.status,
    this.iconName,
    required this.timeframe,
    required this.priority,
    this.categoryId,
    this.category,
    this.notesContent,
    this.savingsFrequency,
    this.savingsDayOfWeek,
    this.savingsDayOfMonth,
    this.savingsAmount,
    this.nextReminderDate,
    this.lastContributionDate,
    this.notificationHour   = 9,
    this.notificationMinute = 0,
    this.streakCount = 0,
    this.longestStreak = 0,

  });

  factory Goal.empty() {
    return Goal(
      id:            '',
      userId:        '',
      name:          'Cargando meta...',
      targetAmount:  1000,
      currentAmount: 0,
      createdAt:     DateTime.now(),
      status:        GoalStatus.active,
      timeframe:     GoalTimeframe.short,
      priority:      GoalPriority.medium,
    );
  }

  factory Goal.fromMap(Map<String, dynamic> map) {
    try {
      return Goal(
        id:            map['id']      as String,
        userId:        map['user_id'] as String,
        name:          map['name']    as String? ?? 'Meta sin nombre',
        targetAmount:  (map['target_amount']  as num? ?? 0).toDouble(),
        currentAmount: (map['current_amount'] as num? ?? 0).toDouble(),
        targetDate:    map['target_date'] != null
            ? DateTime.parse(map['target_date'] as String)
            : null,
        createdAt: DateTime.parse(map['created_at'] as String),
        status:    GoalStatus.fromString(map['status'] as String?),
        iconName:  map['icon_name'] as String?,
        timeframe: GoalTimeframe.fromString(map['timeframe'] as String?),
        priority:  GoalPriority.fromString(map['priority'] as String?),
        categoryId: map['category_id'] as String?,
        category:   map['categories'] != null
            ? Category.fromMap(map['categories'] as Map<String, dynamic>)
            : null,
        notesContent:     map['notes_content'],
        savingsFrequency: GoalSavingsFrequency.fromString(
            map['savings_frequency'] as String?),
        savingsDayOfWeek:  map['savings_day_of_week']  as int?,
        savingsDayOfMonth: map['savings_day_of_month'] as int?,
        savingsAmount: (map['savings_amount'] as num?)?.toDouble(),
        nextReminderDate: map['next_reminder_date'] != null
            ? DateTime.parse(map['next_reminder_date'] as String)
            : null,
        lastContributionDate: map['last_contribution_date'] != null
            ? DateTime.parse(map['last_contribution_date'] as String)
            : null,
        // Nuevos campos — con fallback al default 9:00 si la columna aún no existe
        notificationHour:   map['notification_hour']   as int? ?? 9,
        notificationMinute: map['notification_minute'] as int? ?? 0,
        streakCount:   map['streak_count'] as int? ?? 0,
        longestStreak: map['longest_streak'] as int? ?? 0,
      );
    } catch (e) {
      throw FormatException('Error al parsear Goal: $e', map);
    }
  }

  // ── copyWith con sentinel para campos nullables ───────────────────────────
  // Los campos marcados como Object? con default _kUnset pueden recibir null
  // explícitamente y el método lo diferencia de "no se pasó nada".
  Goal copyWith({
    String? id,
    String? userId,
    String? name,
    double? targetAmount,
    double? currentAmount,
    Object? targetDate              = _kUnset,
    DateTime? createdAt,
    GoalStatus? status,
    Object? iconName                = _kUnset,
    GoalTimeframe? timeframe,
    GoalPriority? priority,
    Object? categoryId              = _kUnset,
    Object? category                = _kUnset,
    Object? notesContent            = _kUnset,
    Object? savingsFrequency        = _kUnset,   // puede ponerse en null
    Object? savingsDayOfWeek        = _kUnset,
    Object? savingsDayOfMonth       = _kUnset,
    Object? savingsAmount           = _kUnset,
    Object? nextReminderDate        = _kUnset,
    Object? lastContributionDate    = _kUnset,
    int? notificationHour,
    int? notificationMinute,
  }) {
    return Goal(
      id:            id            ?? this.id,
      userId:        userId        ?? this.userId,
      name:          name          ?? this.name,
      targetAmount:  targetAmount  ?? this.targetAmount,
      currentAmount: currentAmount ?? this.currentAmount,
      targetDate:    targetDate    == _kUnset
          ? this.targetDate   : targetDate   as DateTime?,
      createdAt:     createdAt     ?? this.createdAt,
      status:        status        ?? this.status,
      iconName:      iconName      == _kUnset
          ? this.iconName     : iconName     as String?,
      timeframe:     timeframe     ?? this.timeframe,
      priority:      priority      ?? this.priority,
      categoryId:    categoryId    == _kUnset
          ? this.categoryId   : categoryId   as String?,
      category:      category      == _kUnset
          ? this.category     : category     as Category?,
      notesContent:  notesContent  == _kUnset
          ? this.notesContent : notesContent,
      savingsFrequency: savingsFrequency == _kUnset
          ? this.savingsFrequency
          : savingsFrequency as GoalSavingsFrequency?,
      savingsDayOfWeek: savingsDayOfWeek == _kUnset
          ? this.savingsDayOfWeek  : savingsDayOfWeek  as int?,
      savingsDayOfMonth: savingsDayOfMonth == _kUnset
          ? this.savingsDayOfMonth : savingsDayOfMonth as int?,
      savingsAmount: savingsAmount == _kUnset
          ? this.savingsAmount : savingsAmount as double?,
      nextReminderDate: nextReminderDate == _kUnset
          ? this.nextReminderDate : nextReminderDate as DateTime?,
      lastContributionDate: lastContributionDate == _kUnset
          ? this.lastContributionDate : lastContributionDate as DateTime?,
      notificationHour:   notificationHour   ?? this.notificationHour,
      notificationMinute: notificationMinute ?? this.notificationMinute,
    );
  }

  // ── Getters computados ────────────────────────────────────────────────────

  double get progress => (currentAmount > 0 && targetAmount > 0)
      ? (currentAmount / targetAmount).clamp(0.0, 1.0)
      : 0.0;

  double get remainingAmount => targetAmount - currentAmount;

  bool get isCompleted => currentAmount >= targetAmount;

  @override
  List<Object?> get props => [
    id, userId, name, targetAmount, currentAmount,
    targetDate, createdAt, status, iconName,
    timeframe, priority, categoryId, category, notesContent,
    savingsFrequency, savingsDayOfWeek, savingsDayOfMonth,
    savingsAmount, nextReminderDate, lastContributionDate,
    notificationHour, notificationMinute,
  ];
}