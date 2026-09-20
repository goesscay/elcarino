<?php

namespace App\Services\Icebreakers;

use RuntimeException;

/**
 * A generator couldn't produce suggestions (provider down, timeout, unusable
 * reply). IcebreakerService catches it and falls back to templates, so the
 * person never sees an error for what is only a nicety.
 */
class IcebreakerGenerationException extends RuntimeException {}
