<?php

namespace App\Services\Gifs;

readonly class GifSearchResult
{
    /**
     * @param  GifResult[]  $items
     */
    public function __construct(
        public array $items,
        public bool $hasMore,
    ) {}
}
