<?php

namespace Tests;

use Illuminate\Foundation\Testing\TestCase as BaseTestCase;
use Illuminate\Support\Facades\Storage;

abstract class TestCase extends BaseTestCase
{
    /**
     * Every test runs against fake storage disks, never the real ones.
     *
     * Without this, a test that uploads a photo, a voice note or a selfie writes
     * into `storage/app/private` — the same folder the local dev server serves
     * real profile photos and chat media from — and two test classes used to
     * "clean up" by deleting `photos/`, `voice-notes/` and `chat-photos/` there,
     * which wiped a developer's seeded media on every `php artisan test`.
     *
     * Doing it here (rather than in each test that happens to write a file)
     * means a new test can't reintroduce the problem by forgetting. The fake
     * disks live under `storage/framework/testing/disks` and are emptied for
     * each test, so there is nothing to clean up in `tearDown` either.
     */
    protected function setUp(): void
    {
        parent::setUp();

        Storage::fake('local');
        Storage::fake('public');
    }
}
