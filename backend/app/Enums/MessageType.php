<?php

namespace App\Enums;

/**
 * messages.type. `text` (Phase 1 item 8), `voice_note` (Phase 3 item 1),
 * `gif` (Phase 3 item 2) and `photo` (Phase 3 item 3) are all written now —
 * every case in this enum is in active use. Declared in full from the start
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
