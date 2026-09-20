<?php

namespace App\Services\Icebreakers;

use App\Models\Conversation;
use App\Models\User;
use App\Models\UserProfilePrompt;
use Illuminate\Support\Facades\Cache;
use Illuminate\Support\Facades\Log;
use Illuminate\Support\Str;

/**
 * Opening lines for a new conversation (Phase 4, open decision #25).
 *
 * Builds the [IcebreakerContext] (the *only* thing a generator ever sees),
 * asks the configured generator, runs the result through [IcebreakerFilter],
 * and falls back to templates if the provider fails or everything it wrote was
 * rejected — so this never errors and never shows unfiltered text.
 *
 * Suggestions are cached per (conversation, viewer) so re-opening a chat is
 * free and doesn't re-run a paid generator; a refresh bumps a seed and passes
 * the lines already shown so it doesn't repeat them. The cache holds plain
 * arrays only: a serialising store (`database`, Redis) won't hand objects back
 * (the lesson from verification's challenge).
 */
class IcebreakerService
{
    public function __construct(
        private readonly IcebreakerGenerator $generator,
        private readonly TemplateIcebreakerGenerator $templates,
        private readonly IcebreakerFilter $filter,
    ) {}

    /**
     * @return array{lines: list<string>, source: string}
     */
    public function suggestions(User $viewer, Conversation $conversation, bool $refresh = false): array
    {
        $key = "icebreakers.{$conversation->id}.{$viewer->id}";
        $cached = Cache::get($key);

        if (! $refresh && $this->isValid($cached)) {
            return ['lines' => $cached['lines'], 'source' => $cached['source']];
        }

        $seed = $this->isValid($cached) ? $cached['seed'] + 1 : 0;
        $avoid = $this->isValid($cached) ? $cached['lines'] : [];

        [$lines, $source] = $this->generate($this->context($viewer, $conversation), $avoid, $seed);

        Cache::put($key, ['lines' => $lines, 'source' => $source, 'seed' => $seed], now()->addHours(config('icebreakers.cache_ttl_hours')));

        return ['lines' => $lines, 'source' => $source];
    }

    /**
     * @param  list<string>  $avoid
     * @return array{0: list<string>, 1: string}
     */
    private function generate(IcebreakerContext $context, array $avoid, int $seed): array
    {
        $count = config('icebreakers.count');

        try {
            $lines = array_slice($this->filter->clean($this->generator->generate($context, $count, $avoid, $seed)), 0, $count);
            if ($lines !== []) {
                return [$lines, $this->generator->source()];
            }
        } catch (IcebreakerGenerationException $e) {
            // Class only: the message can carry provider detail, and the prompt held profile text.
            Log::warning('Icebreaker generation failed; using templates.', ['error' => $e::class]);
        }

        return [
            array_slice($this->filter->clean($this->templates->generate($context, $count, $avoid, $seed)), 0, $count),
            $this->templates->source(),
        ];
    }

    /**
     * What a generator may know: the *other* person's public prompt answers and
     * bio, and the interests the two share. Nothing else — see IcebreakerContext.
     */
    private function context(User $viewer, Conversation $conversation): IcebreakerContext
    {
        $other = $conversation->otherUser($viewer);

        $mine = $viewer->interests()->pluck('interests.name');
        $shared = $other->interests()->pluck('interests.name')->intersect($mine)->values()
            ->take(config('icebreakers.max_shared_interests'))->all();

        $prompts = $other->profilePrompts()->with('prompt')->orderBy('sort_order')
            ->limit(config('icebreakers.max_prompts'))->get()
            ->map(fn (UserProfilePrompt $answer) => [
                'question' => (string) $answer->prompt?->prompt,
                'answer' => Str::limit(trim($answer->answer), 200, '…'),
            ])
            ->filter(fn (array $p) => $p['question'] !== '' && $p['answer'] !== '')
            ->values()->all();

        $bio = $other->profile?->bio;

        return new IcebreakerContext(
            sharedInterests: $shared,
            prompts: $prompts,
            bio: $bio === null || trim($bio) === '' ? null : Str::limit(trim($bio), config('icebreakers.max_bio_chars'), '…'),
        );
    }

    private function isValid(mixed $cached): bool
    {
        return is_array($cached)
            && isset($cached['lines'], $cached['source'], $cached['seed'])
            && is_array($cached['lines']) && $cached['lines'] !== [];
    }
}
