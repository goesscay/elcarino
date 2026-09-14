<?php

namespace App\Services\Gifs;

use Illuminate\Support\Facades\Log;

/**
 * Default local-dev/test provider (GIF_PROVIDER=log in .env). Same role as
 * LogSmsSender/LogPushSender/LogPaymentGateway: no outbound call at all, so
 * `php artisan test`/CI never depends on a third party being reachable.
 * Unlike those, a real "gif" without a real provider isn't something this
 * driver can fake meaningfully (there's no local equivalent of "print the
 * OTP code to the log instead of texting it") — it just returns no results,
 * which is a normal, handled state for a search UI (an empty-results view),
 * not an error.
 */
class LogGifProvider implements GifProvider
{
    public function search(string $query, int $page = 1): GifSearchResult
    {
        Log::channel(config('logging.default'))->info('GIF search (log driver)', [
            'query' => $query,
            'page' => $page,
        ]);

        return new GifSearchResult(items: [], hasMore: false);
    }

    public function find(string $id): ?GifResult
    {
        Log::channel(config('logging.default'))->info('GIF find (log driver)', ['id' => $id]);

        return null;
    }
}
