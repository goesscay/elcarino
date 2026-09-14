<?php

namespace App\Models;

use Database\Factories\MessageAttachmentFactory;
use Illuminate\Database\Eloquent\Attributes\Fillable;
use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;

/**
 * docs/02-database-schema.md `message_attachments`. Phase 3 item 1 (voice
 * notes) is the only writer so far — `storage_path` points at a private
 * disk, never served directly (docs/06-security-architecture.md §6: "a
 * signed URL is minted per request for a participant, never a stable
 * public link" — see MessageAttachmentResource).
 */
#[Fillable(['message_id', 'storage_path', 'mime_type', 'duration_seconds'])]
class MessageAttachment extends Model
{
    /** @use HasFactory<MessageAttachmentFactory> */
    use HasFactory;

    public function message(): BelongsTo
    {
        return $this->belongsTo(Message::class);
    }
}
