<?php

namespace App\Services\Icebreakers;

/**
 * Everything a generator is allowed to know about the person being written to.
 *
 * This is the data-minimisation boundary (docs/06 §5; the Phase 4 gate "AI
 * provider receives only the minimum necessary data"): a generator receives
 * this object and *nothing else*, so what can leave the system is decided by
 * what fields exist here, not by each generator's good behaviour. There is
 * deliberately no name, age, gender, location, photo, religion, politics or
 * relationship goal — none of them is needed to say something good about a
 * shared hobby.
 *
 * `bio` and the prompt answers are text another user typed, so they are
 * **untrusted**: a generator must treat them as data to talk about, never as
 * instructions (see OpenAiIcebreakerGenerator).
 */
final readonly class IcebreakerContext
{
    /**
     * @param  list<string>  $sharedInterests  interests both people have
     * @param  list<array{question: string, answer: string}>  $prompts  the other person's answered prompts
     */
    public function __construct(
        public array $sharedInterests = [],
        public array $prompts = [],
        public ?string $bio = null,
    ) {}
}
