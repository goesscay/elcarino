<?php

namespace App\Enums;

/**
 * messages.type. `text` (Phase 1 item 8), `voice_note` (Phase 3 item 1) and
 * `gif` (Phase 3 item 2) are all written now — `photo` is still open
 * decision #18, unconfirmed. The full enum was declared from the start
 * anyway so no migration was ever needed as each of these got confirmed in
 * scope.
 */
enum MessageType: string
{
    case Text = 'text';
    case VoiceNote = 'voice_note';
    case Gif = 'gif';
    case Photo = 'photo';
}
