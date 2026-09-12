<?php

namespace Database\Seeders;

use App\Models\ProfilePrompt;
use Illuminate\Database\Seeder;

/**
 * The curated prompt library (spec §7). Placeholder copy — content, not
 * schema, so it's not one of the 30 tracked open decisions; revise freely
 * with the client without needing a migration.
 */
class ProfilePromptSeeder extends Seeder
{
    public function run(): void
    {
        $prompts = [
            ['prompt' => 'I feel most like myself when…', 'category' => 'About me'],
            ['prompt' => 'My ideal first date is…', 'category' => 'Dating'],
            ['prompt' => 'A green flag I look for is…', 'category' => 'Dating'],
            ['prompt' => 'My perfect weekend is…', 'category' => 'Fun'],
            ['prompt' => 'A skill I\'m proud of is…', 'category' => 'About me'],
            ['prompt' => 'The way to my heart is…', 'category' => 'Dating'],
            ['prompt' => 'I\'ll never shut up about…', 'category' => 'Fun'],
            ['prompt' => 'Two truths and a lie…', 'category' => 'Fun'],
        ];

        foreach ($prompts as $index => $prompt) {
            ProfilePrompt::query()->updateOrCreate(
                ['prompt' => $prompt['prompt']],
                ['category' => $prompt['category'], 'sort_order' => $index, 'is_active' => true],
            );
        }
    }
}
