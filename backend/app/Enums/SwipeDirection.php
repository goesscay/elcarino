<?php

namespace App\Enums;

/**
 * swipes.direction. `super` is reserved for the proposed Super Like
 * (docs/03 §Swipes, TBD-11) — writing rows is Phase 1 item 6, not item 5.
 */
enum SwipeDirection: string
{
    case Left = 'left';
    case Right = 'right';
    case Super = 'super';
}
