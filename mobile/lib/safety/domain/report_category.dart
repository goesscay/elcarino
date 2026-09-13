/// Mirrors `App\Enums\ReportCategory` on the backend. Hardcoded here rather
/// than fetched from `GET /safety/report-categories` — the same
/// client-mirrors-the-backend-enum convention as `SwipeDirection`/
/// `MessageType`, not a dynamically-loaded list. docs/07-ui-ux-design.md
/// §3.7 "Report — category" lists these exact six labels.
enum ReportCategory {
  harassment('harassment', 'Harassment'),
  fakeProfile('fake_profile', 'Fake profile'),
  spam('spam', 'Spam'),
  inappropriateContent('inappropriate_content', 'Inappropriate content'),
  scam('scam', 'Scam'),
  other('other', 'Other');

  const ReportCategory(this.apiValue, this.label);

  final String apiValue;
  final String label;
}
