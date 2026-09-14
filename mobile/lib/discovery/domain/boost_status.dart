/// docs/03-api-specification.md "Discovery": `GET/POST /discovery/boost`
/// (Phase 2 item 3 / open decision #14's "visibility window" boost
/// mechanic). `limit` is `null` for a non-subscriber (the backend returns
/// `false` there — no entitlement to report a number for), never `0` used
/// as a stand-in for "no access."
class BoostStatus {
  const BoostStatus({
    required this.active,
    required this.endsAt,
    required this.usedThisMonth,
    required this.limit,
  });

  factory BoostStatus.fromJson(Map<String, dynamic> json) {
    final limit = json['limit'];
    return BoostStatus(
      active: json['active'] as bool,
      endsAt: json['ends_at'] == null
          ? null
          : DateTime.parse(json['ends_at'] as String),
      usedThisMonth: json['used_this_month'] as int,
      limit: limit is int ? limit : null,
    );
  }

  final bool active;
  final DateTime? endsAt;
  final int usedThisMonth;
  final int? limit;

  bool get isEntitled => limit != null;

  bool get canActivateAnother =>
      isEntitled && !active && usedThisMonth < limit!;
}
