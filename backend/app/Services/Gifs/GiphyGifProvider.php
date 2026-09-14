<?php

namespace App\Services\Gifs;

use Illuminate\Support\Facades\Http;
use RuntimeException;

/**
 * Default real-world provider (open decision #17 — GIFs; see
 * docs/05-open-decisions.md). Confirm before relying on this in production;
 * swap the GifProvider binding in AppServiceProvider if a different provider
 * is chosen — nothing else in the chat feature depends on Giphy specifically.
 * Not verified against a real Giphy response at all, not even a free one —
 * the api key this falls back to when unconfigured
 * (config('services.gifs.giphy.api_key')) is Giphy's own documented public
 * beta key, confirmed live to be dead (every request returns a 403 "BANNED"
 * response as of this feature being built). Only exercised against
 * Http::fake() in GiphyGifProviderTest, a stricter "confirm before
 * production" status than TwilioSmsSender/FcmPushSender/StripePaymentGateway
 * — those are untested against a *real account*, this is untested against
 * the provider at all. Set GIPHY_API_KEY to a real, registered key and
 * re-verify before relying on this.
 *
 * `search`'s `limit` is fixed at `self::PER_PAGE` rather than exposed as a
 * client-controlled parameter — same reasoning as `chat.default_per_page`:
 * a stable, server-controlled page size the mobile UI can rely on.
 */
class GiphyGifProvider implements GifProvider
{
    private const PER_PAGE = 24;

    private const BASE_URL = 'https://api.giphy.com/v1/gifs';

    public function __construct(
        private readonly string $apiKey,
        private readonly string $rating,
    ) {}

    public function search(string $query, int $page = 1): GifSearchResult
    {
        $offset = max(0, $page - 1) * self::PER_PAGE;

        $response = Http::get(self::BASE_URL.'/search', [
            'api_key' => $this->apiKey,
            'q' => $query,
            'limit' => self::PER_PAGE,
            'offset' => $offset,
            'rating' => $this->rating,
        ]);

        if ($response->failed()) {
            throw new RuntimeException('Giphy search failed: '.$response->body());
        }

        $data = $response->json('data') ?? [];
        $pagination = $response->json('pagination') ?? [];
        $totalCount = (int) ($pagination['total_count'] ?? 0);

        return new GifSearchResult(
            items: array_values(array_filter(array_map($this->mapResult(...), $data))),
            hasMore: $offset + count($data) < $totalCount,
        );
    }

    public function find(string $id): ?GifResult
    {
        $response = Http::get(self::BASE_URL.'/'.$id, ['api_key' => $this->apiKey]);

        if ($response->status() === 404) {
            return null;
        }

        if ($response->failed()) {
            throw new RuntimeException('Giphy lookup failed: '.$response->body());
        }

        return $this->mapResult($response->json('data') ?? []);
    }

    /**
     * @param  array<string, mixed>  $result  One entry of Giphy's `data` —
     *                                        width/height in `images.*` come back as JSON strings, a documented
     *                                        Giphy quirk, not a bug here.
     */
    private function mapResult(array $result): ?GifResult
    {
        $images = $result['images'] ?? [];
        $preview = $images['fixed_width_small'] ?? $images['fixed_width'] ?? null;
        $full = $images['downsized'] ?? $images['original'] ?? null;

        if (! isset($result['id'], $preview['url'], $full['url'])) {
            return null;
        }

        return new GifResult(
            id: (string) $result['id'],
            previewUrl: $preview['url'],
            url: $full['url'],
            width: (int) ($full['width'] ?? 0),
            height: (int) ($full['height'] ?? 0),
        );
    }
}
