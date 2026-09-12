/// Mirrors `App\Enums\Gender` on the backend — confirmed set, open decision
/// #6 (docs/05-open-decisions.md). Don't add a fourth value without that
/// decision changing (see CLAUDE.md "handling open decisions").
enum Gender {
  man('man', 'Man'),
  woman('woman', 'Woman'),
  nonBinary('non_binary', 'Non-binary');

  const Gender(this.apiValue, this.label);

  final String apiValue;
  final String label;

  static Gender fromApiValue(String value) =>
      Gender.values.firstWhere((g) => g.apiValue == value);
}
