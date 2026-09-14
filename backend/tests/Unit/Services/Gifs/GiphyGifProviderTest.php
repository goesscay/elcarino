<?php

namespace Tests\Unit\Services\Gifs;

use App\Services\Gifs\GiphyGifProvider;
use Illuminate\Support\Facades\Http;
use RuntimeException;
use Tests\TestCase;

/**
 * Not verified against a real (paid) Giphy account — this asserts the
 * request this app *sends* is shaped the way Giphy's documented Search/Get
 * GIF by ID API expects, and that a real-looking response is parsed
 * correctly, including Giphy's own width/height-as-strings quirk. Same
 * "confirm before production" status as TwilioSmsSender/StripePaymentGateway's
 * own tests.
 */
class GiphyGifProviderTest extends TestCase
{
    private function giphyResult(string $id = 'abc123'): array
    {
        return [
            'id' => $id,
            'images' => [
                'fixed_width_small' => ['url' => "https://media.giphy.com/{$id}/small.gif", 'width' => '100', 'height' => '75'],
                'downsized' => ['url' => "https://media.giphy.com/{$id}/downsized.gif", 'width' => '400', 'height' => '300'],
                'original' => ['url' => "https://media.giphy.com/{$id}/original.gif", 'width' => '480', 'height' => '360'],
            ],
        ];
    }

    public function test_search_maps_results_and_pagination(): void
    {
        Http::fake([
            'api.giphy.com/v1/gifs/search*' => Http::response([
                'data' => [$this->giphyResult('a'), $this->giphyResult('b')],
                'pagination' => ['total_count' => 50, 'count' => 2, 'offset' => 0],
            ]),
        ]);

        $provider = new GiphyGifProvider('test-key', 'pg-13');
        $result = $provider->search('cats', page: 1);

        $this->assertCount(2, $result->items);
        $this->assertTrue($result->hasMore);
        $first = $result->items[0];
        $this->assertSame('a', $first->id);
        $this->assertSame('https://media.giphy.com/a/small.gif', $first->previewUrl);
        $this->assertSame('https://media.giphy.com/a/downsized.gif', $first->url);
        // Giphy returns width/height as JSON strings — must come back as int.
        $this->assertSame(400, $first->width);
        $this->assertSame(300, $first->height);

        Http::assertSent(function ($request) {
            return $request->url() === 'https://api.giphy.com/v1/gifs/search?api_key=test-key&q=cats&limit=24&offset=0&rating=pg-13'
                || ($request['api_key'] === 'test-key' && $request['q'] === 'cats' && $request['rating'] === 'pg-13');
        });
    }

    public function test_search_computes_offset_and_has_more_from_the_page_number(): void
    {
        Http::fake([
            'api.giphy.com/v1/gifs/search*' => Http::response([
                'data' => [$this->giphyResult('c')],
                'pagination' => ['total_count' => 25, 'count' => 1, 'offset' => 24],
            ]),
        ]);

        $provider = new GiphyGifProvider('test-key', 'pg-13');
        $result = $provider->search('cats', page: 2);

        $this->assertFalse($result->hasMore);
        Http::assertSent(fn ($request) => $request['offset'] === 24);
    }

    public function test_a_result_missing_a_required_rendition_is_dropped_not_fatal(): void
    {
        Http::fake([
            'api.giphy.com/v1/gifs/search*' => Http::response([
                'data' => [
                    ['id' => 'broken', 'images' => []],
                    $this->giphyResult('ok'),
                ],
                'pagination' => ['total_count' => 2, 'count' => 2, 'offset' => 0],
            ]),
        ]);

        $provider = new GiphyGifProvider('test-key', 'pg-13');
        $result = $provider->search('cats');

        $this->assertCount(1, $result->items);
        $this->assertSame('ok', $result->items[0]->id);
    }

    public function test_search_throws_on_a_failed_response(): void
    {
        Http::fake(['api.giphy.com/*' => Http::response(['error' => 'nope'], 500)]);

        $this->expectException(RuntimeException::class);
        (new GiphyGifProvider('test-key', 'pg-13'))->search('cats');
    }

    public function test_find_returns_a_single_mapped_result(): void
    {
        Http::fake([
            'api.giphy.com/v1/gifs/xyz*' => Http::response(['data' => $this->giphyResult('xyz')]),
        ]);

        $result = (new GiphyGifProvider('test-key', 'pg-13'))->find('xyz');

        $this->assertNotNull($result);
        $this->assertSame('xyz', $result->id);

        Http::assertSent(fn ($request) => $request->url() === 'https://api.giphy.com/v1/gifs/xyz?api_key=test-key');
    }

    public function test_find_returns_null_on_a_404(): void
    {
        Http::fake(['api.giphy.com/v1/gifs/missing*' => Http::response(['message' => 'not found'], 404)]);

        $this->assertNull((new GiphyGifProvider('test-key', 'pg-13'))->find('missing'));
    }
}
