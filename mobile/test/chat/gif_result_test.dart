import 'package:datingapp/chat/domain/gif_result.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('GifResult.fromJson parses a search result', () {
    final gif = GifResult.fromJson({
      'id': 'abc123',
      'preview_url': 'https://media.giphy.com/abc123/small.gif',
      'url': 'https://media.giphy.com/abc123/downsized.gif',
      'width': 400,
      'height': 300,
    });

    expect(gif.id, 'abc123');
    expect(gif.previewUrl, 'https://media.giphy.com/abc123/small.gif');
    expect(gif.url, 'https://media.giphy.com/abc123/downsized.gif');
    expect(gif.width, 400);
    expect(gif.height, 300);
  });
}
