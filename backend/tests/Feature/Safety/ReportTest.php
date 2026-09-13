<?php

namespace Tests\Feature\Safety;

use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Laravel\Sanctum\Sanctum;
use Tests\TestCase;

class ReportTest extends TestCase
{
    use RefreshDatabase;

    public function test_a_guest_cannot_report_or_list_categories(): void
    {
        $target = User::factory()->create();

        $this->postJson('/api/v1/safety/report', ['user_id' => $target->id, 'category' => 'spam'])
            ->assertUnauthorized();
        $this->getJson('/api/v1/safety/report-categories')->assertUnauthorized();
    }

    public function test_a_user_can_report_another_user(): void
    {
        Sanctum::actingAs($reporter = User::factory()->create());
        $reported = User::factory()->create();

        $this->postJson('/api/v1/safety/report', [
            'user_id' => $reported->id,
            'category' => 'harassment',
            'description' => 'Kept messaging after I said no.',
        ])->assertCreated();

        $this->assertDatabaseHas('reports', [
            'reporter_id' => $reporter->id,
            'reported_id' => $reported->id,
            'category' => 'harassment',
            'status' => 'pending',
        ]);
    }

    public function test_description_is_optional(): void
    {
        Sanctum::actingAs(User::factory()->create());
        $reported = User::factory()->create();

        $this->postJson('/api/v1/safety/report', ['user_id' => $reported->id, 'category' => 'spam'])
            ->assertCreated();
    }

    public function test_an_invalid_category_is_rejected(): void
    {
        Sanctum::actingAs(User::factory()->create());
        $reported = User::factory()->create();

        $this->postJson('/api/v1/safety/report', ['user_id' => $reported->id, 'category' => 'nonsense'])
            ->assertStatus(422)->assertJsonValidationErrors('category');
    }

    public function test_a_user_cannot_report_themselves(): void
    {
        Sanctum::actingAs($user = User::factory()->create());

        $this->postJson('/api/v1/safety/report', ['user_id' => $user->id, 'category' => 'other'])
            ->assertForbidden();
    }

    public function test_also_block_creates_a_block_alongside_the_report(): void
    {
        Sanctum::actingAs($reporter = User::factory()->create());
        $reported = User::factory()->create();

        $this->postJson('/api/v1/safety/report', [
            'user_id' => $reported->id,
            'category' => 'scam',
            'also_block' => true,
        ])->assertCreated();

        $this->assertDatabaseHas('blocks', ['blocker_id' => $reporter->id, 'blocked_id' => $reported->id]);
    }

    public function test_without_also_block_no_block_is_created(): void
    {
        Sanctum::actingAs($reporter = User::factory()->create());
        $reported = User::factory()->create();

        $this->postJson('/api/v1/safety/report', ['user_id' => $reported->id, 'category' => 'other'])
            ->assertCreated();

        $this->assertDatabaseMissing('blocks', ['blocker_id' => $reporter->id, 'blocked_id' => $reported->id]);
    }

    public function test_report_categories_returns_the_full_enum(): void
    {
        Sanctum::actingAs(User::factory()->create());

        $response = $this->getJson('/api/v1/safety/report-categories')->assertOk();

        $response->assertJson([
            'categories' => ['harassment', 'fake_profile', 'spam', 'inappropriate_content', 'scam', 'other'],
        ]);
    }
}
