<?php

namespace Tests\Feature;

use Illuminate\Support\Facades\Storage;
use Tests\TestCase;

/**
 * A tripwire, not a feature test: the suite must never be able to touch the
 * developer's real storage folders (see Tests\TestCase::setUp). If the base
 * class ever stops faking the disks, this fails loudly instead of the suite
 * quietly deleting local dev media again.
 */
class TestIsolationTest extends TestCase
{
    public function test_the_default_disks_are_fakes_not_the_real_storage_folders(): void
    {
        foreach (['local', 'public'] as $disk) {
            $root = str_replace('\\', '/', Storage::disk($disk)->path(''));

            $this->assertStringContainsString('framework/testing/disks', $root, "The '{$disk}' disk is not faked.");
            $this->assertStringNotContainsString('storage/app/private', $root);
            $this->assertStringNotContainsString('storage/app/public', $root);
        }
    }

    public function test_the_app_default_disk_is_one_of_the_fakes(): void
    {
        // The upload code writes to config('filesystems.default'), not to a
        // hard-coded disk name.
        $default = Storage::disk(config('filesystems.default'));

        $this->assertStringContainsString('framework/testing/disks', str_replace('\\', '/', $default->path('')));
    }

    public function test_a_file_written_by_one_test_is_gone_in_the_next(): void
    {
        // Paired with the test below: each test starts with an empty disk.
        Storage::disk('local')->put('leak-canary.txt', 'x');

        $this->assertTrue(Storage::disk('local')->exists('leak-canary.txt'));
    }

    public function test_the_previous_tests_file_did_not_survive(): void
    {
        $this->assertFalse(Storage::disk('local')->exists('leak-canary.txt'));
    }
}
