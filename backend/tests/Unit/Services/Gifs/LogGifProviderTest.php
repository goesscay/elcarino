<?php

namespace Tests\Unit\Services\Gifs;

use App\Services\Gifs\LogGifProvider;
use Tests\TestCase;

class LogGifProviderTest extends TestCase
{
    public function test_search_returns_no_results_without_an_outbound_call(): void
    {
        $result = (new LogGifProvider)->search('cats');

        $this->assertSame([], $result->items);
        $this->assertFalse($result->hasMore);
    }

    public function test_find_returns_null(): void
    {
        $this->assertNull((new LogGifProvider)->find('anything'));
    }
}
