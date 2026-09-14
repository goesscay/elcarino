<?php

namespace Tests\Feature\Chat;

use App\Models\User;
use App\Services\Gifs\GifProvider;
use App\Services\Gifs\GifResult;
use App\Services\Gifs\GifSearchResult;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Laravel\Sanctum\Sanctum;
use Tests\TestCase;

class GifSearchTest extends TestCase
{
    use RefreshDatabase;

    public function test_a_guest_cannot_search_gifs(): void
    {
        $this->getJson('/api/v1/gifs/search?q=cats')->assertUnauthorized();
    }

    public function test_q_is_required(): void
    {
        Sanctum::actingAs(User::factory()->create());

        $this->getJson('/api/v1/gifs/search')->assertStatus(422)->assertJsonValidationErrors('q');
    }

    /**
     * The endpoint just passes through whatever GifProvider::search()
     * returns — the log driver (this app's default, network-free) already
     * has its own dedicated unit test (LogGifProviderTest), so this
     * exercises the actual HTTP response shape against a fake provider
     * instead of asserting on an empty result set either way.
     */
    public function test_a_participant_can_search_and_gets_the_provider_results_back(): void
    {
        $this->app->bind(GifProvider::class, fn () => new class implements GifProvider
        {
            public function search(string $query, int $page = 1): GifSearchResult
            {
                return new GifSearchResult(
                    items: [new GifResult('1', 'https://example.com/1-preview.gif', 'https://example.com/1.gif', 200, 150)],
                    hasMore: true,
                );
            }

            public function find(string $id): ?GifResult
            {
                return null;
            }
        });

        Sanctum::actingAs(User::factory()->create());
        $response = $this->getJson('/api/v1/gifs/search?q=cats')->assertOk();

        $response->assertJsonCount(1, 'gifs');
        $response->assertJsonPath('gifs.0.id', '1');
        $response->assertJsonPath('gifs.0.preview_url', 'https://example.com/1-preview.gif');
        $response->assertJsonPath('gifs.0.width', 200);
        $response->assertJsonPath('meta.has_more', true);
    }
}
