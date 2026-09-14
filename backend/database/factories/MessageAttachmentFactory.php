<?php

namespace Database\Factories;

use App\Models\Message;
use App\Models\MessageAttachment;
use Illuminate\Database\Eloquent\Factories\Factory;

/**
 * @extends Factory<MessageAttachment>
 */
class MessageAttachmentFactory extends Factory
{
    public function definition(): array
    {
        return [
            'message_id' => Message::factory(),
            'storage_path' => 'voice-notes/1/'.fake()->uuid().'.m4a',
            'mime_type' => 'audio/mp4',
            'duration_seconds' => fake()->numberBetween(1, 60),
        ];
    }
}
