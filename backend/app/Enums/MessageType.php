<?php

namespace App\Enums;

/**
 * messages.type. Phase 1 item 8 only ever writes `text` — voice_note/gif/
 * photo are open decisions #16-18, unconfirmed. The full enum is declared
 * now anyway so no migration is needed if/when they're confirmed in scope.
 */
enum MessageType: string
{
    case Text = 'text';
    case VoiceNote = 'voice_note';
    case Gif = 'gif';
    case Photo = 'photo';
}
