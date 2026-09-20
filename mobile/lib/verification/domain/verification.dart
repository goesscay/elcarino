/// Where a verification request stands, from the person's side
/// (`GET /verification/status`, docs/03 "Verification"). The API folds its
/// internal `processing`/`pending` (AI vs. a human queue) into one
/// [inReview]: to the person both just mean "we're checking".
enum VerificationOutcome {
  inReview,
  approved,
  rejected;

  static VerificationOutcome fromApi(String value) => switch (value) {
    'approved' => approved,
    'rejected' => rejected,
    _ => inReview,
  };
}

/// The pose a selfie must show (`GET /verification/challenge`). Issued by the
/// server so a selfie taken — or stolen — beforehand doesn't fit.
class VerificationChallenge {
  const VerificationChallenge({
    required this.pose,
    required this.label,
    required this.expiresAt,
  });

  factory VerificationChallenge.fromJson(Map<String, dynamic> json) =>
      VerificationChallenge(
        pose: json['pose'] as String,
        label: json['label'] as String,
        expiresAt: DateTime.parse(json['expires_at'] as String),
      );

  /// The code to send back with the selfie.
  final String pose;

  /// What to show the person: "Give a thumbs up".
  final String label;
  final DateTime expiresAt;
}

/// One verification request as the person may see it: never a score, never
/// why it was routed where it was — only the outcome and, if rejected,
/// person-safe copy.
class VerificationRequestInfo {
  const VerificationRequestInfo({
    required this.id,
    required this.outcome,
    required this.submittedAt,
    this.decidedAt,
    this.reason,
    this.reasonMessage,
  });

  factory VerificationRequestInfo.fromJson(Map<String, dynamic> json) =>
      VerificationRequestInfo(
        id: json['id'] as int,
        outcome: VerificationOutcome.fromApi(json['status'] as String),
        submittedAt: DateTime.parse(json['submitted_at'] as String),
        decidedAt: json['decided_at'] == null
            ? null
            : DateTime.parse(json['decided_at'] as String),
        reason: json['reason'] as String?,
        reasonMessage: json['reason_message'] as String?,
      );

  final int id;
  final VerificationOutcome outcome;
  final DateTime submittedAt;
  final DateTime? decidedAt;

  /// A code such as `no_face_detected`; null unless rejected.
  final String? reason;

  /// Copy that is safe to show — what to do differently next time.
  final String? reasonMessage;
}

/// `GET /verification/status`.
class VerificationState {
  const VerificationState({
    required this.isVerified,
    required this.canStart,
    required this.request,
  });

  factory VerificationState.fromJson(Map<String, dynamic> json) =>
      VerificationState(
        isVerified: json['is_verified'] as bool,
        canStart: json['can_start'] as bool,
        request: json['request'] == null
            ? null
            : VerificationRequestInfo.fromJson(
                json['request'] as Map<String, dynamic>,
              ),
      );

  final bool isVerified;

  /// They may submit a selfie now: not verified, nothing already in review, and
  /// under the daily attempt cap.
  final bool canStart;

  /// The latest request, if any.
  final VerificationRequestInfo? request;
}
