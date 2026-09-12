<?php

namespace Tests\Feature\Profile;

use App\Models\Profile;
use App\Models\ProfilePrompt;
use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Laravel\Sanctum\Sanctum;
use Tests\TestCase;

class PromptTest extends TestCase
{
    use RefreshDatabase;

    public function test_a_guest_cannot_list_or_answer_prompts(): void
    {
        $this->getJson('/api/v1/prompts')->assertUnauthorized();
        $this->putJson('/api/v1/prompts/me', [])->assertUnauthorized();
    }

    public function test_it_lists_only_active_prompts_from_the_library(): void
    {
        ProfilePrompt::factory()->create(['prompt' => 'Active one', 'is_active' => true]);
        ProfilePrompt::factory()->create(['prompt' => 'Retired one', 'is_active' => false]);
        Sanctum::actingAs(User::factory()->create());

        $response = $this->getJson('/api/v1/prompts')->assertOk();

        $response->assertJsonCount(1, 'prompts');
        $response->assertJsonPath('prompts.0.prompt', 'Active one');
    }

    public function test_a_user_can_answer_prompts(): void
    {
        [$p1, $p2] = ProfilePrompt::factory()->count(2)->create();
        Sanctum::actingAs($user = User::factory()->create());
        Profile::factory()->for($user)->create();

        $response = $this->putJson('/api/v1/prompts/me', [
            'prompts' => [
                ['prompt_id' => $p1->id, 'answer' => 'First answer'],
                ['prompt_id' => $p2->id, 'answer' => 'Second answer'],
            ],
        ]);

        $response->assertOk()->assertJsonCount(2, 'prompts');
        $this->assertDatabaseHas('user_profile_prompts', [
            'user_id' => $user->id, 'prompt_id' => $p1->id, 'sort_order' => 0,
        ]);
        // completion_pct: basics (40) + a prompt answer (15) = 55.
        $this->assertSame(55, $user->profile()->first()->completion_pct);
    }

    public function test_answering_replaces_the_previous_set(): void
    {
        [$p1, $p2] = ProfilePrompt::factory()->count(2)->create();
        Sanctum::actingAs($user = User::factory()->create());

        $this->putJson('/api/v1/prompts/me', [
            'prompts' => [['prompt_id' => $p1->id, 'answer' => 'First']],
        ])->assertOk();
        $this->putJson('/api/v1/prompts/me', [
            'prompts' => [['prompt_id' => $p2->id, 'answer' => 'Second']],
        ])->assertOk();

        $this->assertSame(1, $user->profilePrompts()->count());
        $this->assertDatabaseHas('user_profile_prompts', ['prompt_id' => $p2->id]);
    }

    public function test_it_rejects_more_than_the_configured_max_prompts(): void
    {
        $prompts = ProfilePrompt::factory()->count(config('media.max_prompts_per_profile') + 1)->create();
        Sanctum::actingAs(User::factory()->create());

        $payload = $prompts->map(fn (ProfilePrompt $p) => ['prompt_id' => $p->id, 'answer' => 'x'])->all();

        $this->putJson('/api/v1/prompts/me', ['prompts' => $payload])
            ->assertStatus(422)->assertJsonValidationErrors('prompts');
    }

    public function test_it_rejects_a_prompt_id_that_does_not_exist(): void
    {
        Sanctum::actingAs(User::factory()->create());

        $this->putJson('/api/v1/prompts/me', [
            'prompts' => [['prompt_id' => 999999, 'answer' => 'x']],
        ])->assertStatus(422)->assertJsonValidationErrors('prompts.0.prompt_id');
    }

    public function test_a_user_can_remove_one_prompt_answer(): void
    {
        $prompt = ProfilePrompt::factory()->create();
        Sanctum::actingAs($user = User::factory()->create());
        $user->profilePrompts()->create(['prompt_id' => $prompt->id, 'answer' => 'x', 'sort_order' => 0]);

        $this->deleteJson("/api/v1/prompts/me/{$prompt->id}")->assertOk();

        $this->assertDatabaseMissing('user_profile_prompts', ['user_id' => $user->id, 'prompt_id' => $prompt->id]);
    }

    public function test_removing_an_unanswered_prompt_404s(): void
    {
        $prompt = ProfilePrompt::factory()->create();
        Sanctum::actingAs(User::factory()->create());

        $this->deleteJson("/api/v1/prompts/me/{$prompt->id}")
            ->assertStatus(404)->assertJsonPath('error.code', 'prompt_answer_not_found');
    }
}
