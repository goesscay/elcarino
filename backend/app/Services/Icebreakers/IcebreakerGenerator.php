<?php

namespace App\Services\Icebreakers;

/**
 * Writes opening lines for a new conversation. Provider-agnostic (same shape as
 * FaceMatcher / SmsSender / GifProvider) because whether to send anyone's
 * profile text to a third party is an open decision [TBD-25]: the default
 * implementation sends nothing anywhere.
 *
 * Implementations get only an [IcebreakerContext] and return raw candidate
 * lines; IcebreakerFilter, not the generator, has the final say on what is
 * allowed to reach a screen.
 */
interface IcebreakerGenerator
{
    /**
     * @param  list<string>  $avoid  lines already shown, so a refresh isn't a repeat
     * @return list<string> up to about $count candidate lines
     *
     * @throws IcebreakerGenerationException when the provider fails
     */
    public function generate(IcebreakerContext $context, int $count, array $avoid = [], int $seed = 0): array;

    /** `template` or `ai` — shown to the person so AI text is labelled as such. */
    public function source(): string;
}
