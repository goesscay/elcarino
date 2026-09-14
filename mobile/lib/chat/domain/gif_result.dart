/// Mirrors the backend's `GifResultResource` (docs/03-api-specification.md
/// "GIFs"). `id` is what a subsequent `POST .../messages` sends as
/// `gif_id` — never `url` directly, the server re-resolves it
/// (`ChatRepository.sendGif`'s doc comment explains why).
class GifResult {
  const GifResult({
    required this.id,
    required this.previewUrl,
    required this.url,
    required this.width,
    required this.height,
  });

  factory GifResult.fromJson(Map<String, dynamic> json) => GifResult(
    id: json['id'] as String,
    previewUrl: json['preview_url'] as String,
    url: json['url'] as String,
    width: json['width'] as int,
    height: json['height'] as int,
  );

  final String id;
  final String previewUrl;
  final String url;
  final int width;
  final int height;
}
