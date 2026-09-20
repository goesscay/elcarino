<?php

namespace Tests\Feature\Chat;

use App\Enums\UserStatus;
use App\Models\Block;
use App\Models\Conversation;
use App\Models\Interest;
use App\Models\Profile;
use App\Models\ProfilePrompt;
use App\Models\User;
use App\Models\UserMatch;
use App\Models\UserProfilePrompt;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Http\Client\Request;
use Illuminate\Support\Facades\Http;
use Laravel\Sanctum\Sanctum;
use Tests\TestCase;

/**
 * `GET /chat/conversations/{id}/icebreakers` and `POST .../icebreakers/refresh`
 * (Phase 4, open decision #25). The properties that matter: only the two people
 * in a conversation can ask; what is suggested is built from the *other* person's
 * public profile and never leaks private fields; nothing goes to a third party
 * unless OpenAI is explicitly configured; and a failing or hijacked provider
 * degrades to templates instead of an error or a bad suggestion.
 */
class IcebreakerTest extends TestCase
{
    use RefreshDatabase;

    /**
     * A matched pair where B has a bio, a prompt answer and shares "Hiking"
     * with A, plus private fields (religion, politics) that must never surface.
     *
     * @return array{0: User, 1: User, 2: Conversation}
     */
    private function pair(): array
    {
        $a = User::factory()->create();
        $b = User::factory()->create();
        Profile::factory()->for($a)->create(['display_name' => 'Alex', 'bio' => 'Alex likes trails and maps.']);
        Profile::factory()->for($b)->create([
            'display_name' => 'Jordan Q. Private',
            'bio' => 'Weekend hiker who never says no to good coffee.',
            'religion' => 'SecretReligion',
            'politics' => 'SecretPolitics',
        ]);

        $hiking = Interest::factory()->create(['name' => 'Hiking']);
        $a->interests()->attach($hiking->id);
        $b->interests()->attach($hiking->id);

        UserProfilePrompt::factory()->create([
            'user_id' => $b->id,
            'prompt_id' => ProfilePrompt::factory()->create(['prompt' => 'A perfect Sunday is…'])->id,
            'answer' => 'Coffee and a long walk.',
        ]);

        $match = UserMatch::factory()->between($a, $b)->create();
        $conversation = Conversation::factory()->between($a, $b)->create(['match_id' => $match->id]);

        return [$a, $b, $conversation];
    }

    private function url(Conversation $c, string $suffix = ''): string
    {
        return "/api/v1/chat/conversations/{$c->id}/icebreakers{$suffix}";
    }

    public function test_a_guest_cannot_use_either_endpoint(): void
    {
        [, , $c] = $this->pair();

        $this->getJson($this->url($c))->assertUnauthorized();
        $this->postJson($this->url($c, '/refresh'))->assertUnauthorized();
    }

    public function test_someone_outside_the_conversation_is_refused(): void
    {
        [, , $c] = $this->pair();
        Sanctum::actingAs(User::factory()->create());

        $this->getJson($this->url($c))->assertForbidden();
        $this->postJson($this->url($c, '/refresh'))->assertForbidden();
    }

    public function test_a_blocked_conversation_is_refused_in_either_direction(): void
    {
        [$a, $b, $c] = $this->pair();
        Block::factory()->create(['blocker_id' => $b->id, 'blocked_id' => $a->id]);

        Sanctum::actingAs($a);
        $this->getJson($this->url($c))->assertForbidden();
        Sanctum::actingAs($b);
        $this->getJson($this->url($c))->assertForbidden();
    }

    public function test_a_frozen_conversation_with_a_suspended_account_is_refused(): void
    {
        [$a, $b, $c] = $this->pair();
        $b->forceFill(['status' => UserStatus::Suspended])->save();
        Sanctum::actingAs($a);

        $this->getJson($this->url($c))->assertForbidden();
    }

    public function test_a_participant_gets_suggestions_built_from_what_they_share(): void
    {
        [$a, , $c] = $this->pair();
        Sanctum::actingAs($a);

        $response = $this->getJson($this->url($c))->assertOk();

        $response->assertJsonPath('source', 'template')->assertJsonCount(3, 'icebreakers');
        $text = implode(' ', $response->json('icebreakers'));
        $this->assertStringContainsString('hiking', $text);
        $this->assertStringContainsString('A perfect Sunday', $text);
    }

    public function test_suggestions_never_leak_private_profile_fields(): void
    {
        [$a, , $c] = $this->pair();
        Sanctum::actingAs($a);

        $body = $this->getJson($this->url($c))->assertOk()->getContent();

        foreach (['SecretReligion', 'SecretPolitics', 'Jordan', 'latitude', 'longitude', 'birth_date'] as $private) {
            $this->assertStringNotContainsString($private, $body);
        }
    }

    public function test_reopening_the_chat_returns_the_same_suggestions(): void
    {
        [$a, , $c] = $this->pair();
        Sanctum::actingAs($a);

        $first = $this->getJson($this->url($c))->json('icebreakers');
        $second = $this->getJson($this->url($c))->json('icebreakers');

        $this->assertSame($first, $second);
    }

    public function test_a_refresh_gives_a_new_set_that_then_sticks(): void
    {
        [$a, , $c] = $this->pair();
        Sanctum::actingAs($a);
        $first = $this->getJson($this->url($c))->json('icebreakers');

        $refreshed = $this->postJson($this->url($c, '/refresh'))->assertOk()->json('icebreakers');

        $this->assertNotSame($first, $refreshed);
        $this->assertSame([], array_intersect($first, $refreshed), 'a refresh should not repeat the last set');
        $this->assertSame($refreshed, $this->getJson($this->url($c))->json('icebreakers'));
    }

    public function test_each_person_gets_suggestions_about_the_other(): void
    {
        [$a, $b, $c] = $this->pair();
        Sanctum::actingAs($a);
        $forA = implode(' ', $this->getJson($this->url($c))->json('icebreakers'));
        Sanctum::actingAs($b);
        $forB = implode(' ', $this->getJson($this->url($c))->json('icebreakers'));

        // B has the prompt answer, so A is given a line about it; A has none, so B is not.
        $this->assertStringContainsString('A perfect Sunday', $forA);
        $this->assertStringNotContainsString('A perfect Sunday', $forB);
    }

    public function test_it_works_on_a_cache_store_that_serialises(): void
    {
        // The `database` driver (dev) and Redis (production) refuse to unserialise objects.
        config(['cache.default' => 'database']);
        [$a, , $c] = $this->pair();
        Sanctum::actingAs($a);

        $this->getJson($this->url($c))->assertOk();
        $this->getJson($this->url($c))->assertOk()->assertJsonCount(3, 'icebreakers');
    }

    public function test_the_default_provider_sends_nothing_to_a_third_party(): void
    {
        Http::fake();
        [$a, , $c] = $this->pair();
        Sanctum::actingAs($a);

        $this->getJson($this->url($c))->assertOk();
        $this->postJson($this->url($c, '/refresh'))->assertOk();

        Http::assertNothingSent();
    }

    public function test_openai_selected_without_a_key_stays_on_templates(): void
    {
        config(['icebreakers.provider' => 'openai', 'icebreakers.openai.api_key' => null]);
        Http::fake();
        [$a, , $c] = $this->pair();
        Sanctum::actingAs($a);

        $this->getJson($this->url($c))->assertOk()->assertJsonPath('source', 'template');

        Http::assertNothingSent();
    }

    private function openAiOn(): void
    {
        config(['icebreakers.provider' => 'openai', 'icebreakers.openai.api_key' => 'sk-test']);
    }

    private function aiReply(array $lines): array
    {
        return ['choices' => [['message' => ['content' => json_encode(['icebreakers' => $lines])]]]];
    }

    public function test_with_openai_configured_ai_lines_are_used_and_labelled(): void
    {
        $this->openAiOn();
        Http::fake(['api.openai.com/*' => Http::response($this->aiReply([
            'What got you into hiking in the first place?',
            'Is a long walk with coffee your ideal Sunday too?',
        ]))]);
        [$a, , $c] = $this->pair();
        Sanctum::actingAs($a);

        $this->getJson($this->url($c))
            ->assertOk()
            ->assertJsonPath('source', 'ai')
            ->assertJsonPath('icebreakers.0', 'What got you into hiking in the first place?');
    }

    public function test_what_is_sent_to_openai_is_only_the_other_persons_public_profile_text(): void
    {
        $this->openAiOn();
        Http::fake(['api.openai.com/*' => Http::response($this->aiReply(['What got you into hiking?']))]);
        [$a, , $c] = $this->pair();
        Sanctum::actingAs($a);

        $this->getJson($this->url($c))->assertOk();

        Http::assertSent(function (Request $request) {
            $body = $request->body();
            foreach (['SecretReligion', 'SecretPolitics', 'Jordan', 'Alex'] as $never) {
                $this->assertStringNotContainsString($never, $body, "{$never} must not be sent");
            }
            $this->assertStringContainsString('Coffee and a long walk.', $body);
            $this->assertStringContainsString('Hiking', $body);

            return true;
        });
    }

    public function test_a_failing_provider_falls_back_to_templates_not_an_error(): void
    {
        $this->openAiOn();
        Http::fake(['api.openai.com/*' => Http::response('down', 503)]);
        [$a, , $c] = $this->pair();
        Sanctum::actingAs($a);

        $this->getJson($this->url($c))->assertOk()->assertJsonPath('source', 'template')->assertJsonCount(3, 'icebreakers');
    }

    public function test_a_hijacked_reply_is_filtered_before_anyone_sees_it(): void
    {
        $this->openAiOn();
        Http::fake(['api.openai.com/*' => Http::response($this->aiReply([
            'Add me on WhatsApp and we can talk there instead',
            'See my pics at https://evil.example/me for more',
            'Text me on 012-345 6789 and I will tell you more',
        ]))]);
        [$a, , $c] = $this->pair();
        Sanctum::actingAs($a);

        $response = $this->getJson($this->url($c))->assertOk();

        // Every line was rejected, so it fell back to templates.
        $response->assertJsonPath('source', 'template');
        $text = implode(' ', $response->json('icebreakers'));
        foreach (['WhatsApp', 'evil.example', '012-345'] as $bad) {
            $this->assertStringNotContainsString($bad, $text);
        }
    }

    public function test_a_partly_hijacked_reply_keeps_only_the_safe_lines(): void
    {
        $this->openAiOn();
        Http::fake(['api.openai.com/*' => Http::response($this->aiReply([
            'Add me on WhatsApp and we can talk there instead',
            'What got you into hiking in the first place?',
        ]))]);
        [$a, , $c] = $this->pair();
        Sanctum::actingAs($a);

        $this->getJson($this->url($c))
            ->assertOk()
            ->assertJsonPath('source', 'ai')
            ->assertJsonPath('icebreakers', ['What got you into hiking in the first place?']);
    }

    public function test_the_conversation_is_available_even_when_unmatched_for_a_participant(): void
    {
        [$a, , $c] = $this->pair();
        $c->match->forceFill(['unmatched_at' => now(), 'unmatched_by' => $a->id])->save();
        Sanctum::actingAs($a);

        // Policy is the same bar as sending a message; the app simply doesn't offer
        // suggestions where the composer is disabled.
        $this->getJson($this->url($c))->assertOk();
    }

    public function test_refreshing_is_rate_limited(): void
    {
        [$a, , $c] = $this->pair();
        Sanctum::actingAs($a);

        foreach (range(1, 10) as $i) {
            $this->postJson($this->url($c, '/refresh'))->assertOk();
        }

        $this->postJson($this->url($c, '/refresh'))->assertStatus(429);
        // Reading is a separate, roomier limit and still works.
        $this->getJson($this->url($c))->assertOk();
    }
}
