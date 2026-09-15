class MasterAvailabilityInterval {
  const MasterAvailabilityInterval({
    required this.weekday,
    required this.startMinute,
    required this.endMinute,
  });

  final int weekday;
  final int startMinute;
  final int endMinute;

  factory MasterAvailabilityInterval.fromJson(Map<String, dynamic> json) =>
      MasterAvailabilityInterval(
        weekday: (json['weekday'] as num?)?.toInt() ?? 1,
        startMinute: (json['startMinute'] as num?)?.toInt() ?? 0,
        endMinute: (json['endMinute'] as num?)?.toInt() ?? 0,
      );

  Map<String, int> toJson() => {
    'weekday': weekday,
    'startMinute': startMinute,
    'endMinute': endMinute,
  };
}

class MasterAvailability {
  const MasterAvailability({
    required this.timezoneOffsetMinutes,
    required this.intervals,
  });

  final int timezoneOffsetMinutes;
  final List<MasterAvailabilityInterval> intervals;

  factory MasterAvailability.fromJson(Map<String, dynamic> json) =>
      MasterAvailability(
        timezoneOffsetMinutes:
            (json['timezoneOffsetMinutes'] as num?)?.toInt() ?? 300,
        intervals: (json['intervals'] as List<dynamic>? ?? [])
            .map(
              (entry) => MasterAvailabilityInterval.fromJson(
                entry as Map<String, dynamic>,
              ),
            )
            .toList(growable: false),
      );
}
