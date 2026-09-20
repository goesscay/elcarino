<?php

namespace App\Services\Icebreakers;

use Illuminate\Support\Str;

/**
 * The default generator: fixed patterns filled with what the two people share.
 * No key, no network, nothing leaves the system — so it is safe as the default
 * and as the fallback whenever a real provider is off, unconfigured or down.
 *
 * It aims for the same shape a good opener has: a specific hook (a shared
 * interest, a prompt answer) plus an open question, never a compliment on
 * looks. When there is no hook it falls back to a few warm, generic questions,
 * so a conversation always gets [count] suggestions.
 *
 * Variety: candidates are grouped by kind (interest / prompt / bio / generic)
 * and taken one kind at a time, and [seed] rotates which line of each kind wins,
 * so "more ideas" gives different lines. Lines in [avoid] are skipped while
 * alternatives remain.
 */
class TemplateIcebreakerGenerator implements IcebreakerGenerator
{
    private const GENERIC = [
        "Hi! What's something you're looking forward to this week?",
        "What's the best thing that happened to you recently?",
        'If you could be anywhere this weekend, where would it be?',
        "What's a small thing that always makes your day better?",
        'Coffee, tea or something else entirely? Tell me everything.',
    ];

    public function generate(IcebreakerContext $context, int $count, array $avoid = [], int $seed = 0): array
    {
        $groups = [
            $this->fromInterests($context),
            $this->fromPrompts($context),
            $this->fromBio($context),
            self::GENERIC,
        ];

        $avoid = array_map(Str::lower(...), $avoid);
        $queues = array_map(fn (array $lines) => $this->rotate($this->fresh($lines, $avoid), $seed), $groups);

        // One from each kind first (variety), then whatever is left.
        $picked = [];
        while (count($picked) < $count && array_filter($queues)) {
            foreach ($queues as $i => $queue) {
                if ($queue !== [] && count($picked) < $count) {
                    $picked[] = array_shift($queues[$i]);
                }
            }
        }

        // Everything was in $avoid (a long run of refreshes): repeat rather than come up empty.
        return $picked !== [] ? $picked : array_slice(self::GENERIC, 0, $count);
    }

    public function source(): string
    {
        return 'template';
    }

    /**
     * @return list<string>
     */
    private function fromInterests(IcebreakerContext $context): array
    {
        $lines = [];
        foreach ($context->sharedInterests as $interest) {
            $name = Str::lower($interest);
            $lines[] = "I noticed we're both into {$name}. What got you started?";
            $lines[] = "Another {$name} fan! What's your favourite part of it?";
        }

        return $lines;
    }

    /**
     * @return list<string>
     */
    private function fromPrompts(IcebreakerContext $context): array
    {
        $lines = [];
        foreach ($context->prompts as $prompt) {
            $question = rtrim(Str::limit(trim($prompt['question']), 60, ''), ' .…:?');
            $answer = rtrim(Str::limit(trim($prompt['answer']), 50, '…'));
            if ($question === '' || $answer === '') {
                continue;
            }
            $lines[] = "Your answer to \"{$question}\" made me curious: \"{$answer}\" What's the story?";
            $lines[] = "\"{$answer}\" — I love that. Tell me more?";
        }

        return $lines;
    }

    /**
     * @return list<string>
     */
    private function fromBio(IcebreakerContext $context): array
    {
        if ($context->bio === null || mb_strlen(trim($context->bio)) < 20) {
            return [];
        }

        return [
            'Your bio made me smile. What would a perfect free Sunday look like for you?',
            'I liked your bio. What are you most excited about right now?',
        ];
    }

    /**
     * @param  list<string>  $lines
     * @param  list<string>  $avoid  lower-cased
     * @return list<string>
     */
    private function fresh(array $lines, array $avoid): array
    {
        return array_values(array_filter($lines, fn (string $line) => ! in_array(Str::lower($line), $avoid, true)));
    }

    /**
     * @param  list<string>  $lines
     * @return list<string>
     */
    private function rotate(array $lines, int $seed): array
    {
        if ($lines === []) {
            return [];
        }

        $offset = $seed % count($lines);

        return [...array_slice($lines, $offset), ...array_slice($lines, 0, $offset)];
    }
}
