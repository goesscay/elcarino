<?php

namespace App\Services\Gifs;

interface GifProvider
{
    /**
     * @param  int  $page  1-indexed, matching this app's other paginated
     *                     endpoints (e.g. ChatController::messages) rather than a provider's
     *                     own offset/cursor convention.
     */
    public function search(string $query, int $page = 1): GifSearchResult;

    /**
     * Re-resolves a single gif by id server-side — used when a message is
     * actually sent (ChatController::sendMessage), so the stored URL always
     * comes from a fresh provider lookup, never trusted directly from the
     * client (the client only ever sends the `id` it got from `search()`).
     */
    public function find(string $id): ?GifResult;
}
