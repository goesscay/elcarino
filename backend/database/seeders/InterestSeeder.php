<?php

namespace Database\Seeders;

use App\Models\Interest;
use Illuminate\Database\Seeder;

/**
 * The interest catalogue (spec §6). Placeholder copy, same as
 * ProfilePromptSeeder — content, not schema, so freely revisable with the
 * client without a migration.
 */
class InterestSeeder extends Seeder
{
    public function run(): void
    {
        $interests = [
            'Sports' => ['Running', 'Gym & fitness', 'Football', 'Badminton', 'Hiking', 'Swimming'],
            'Arts' => ['Live music', 'Photography', 'Painting', 'Movies', 'Theatre', 'Reading'],
            'Food & drink' => ['Coffee', 'Cooking', 'Baking', 'Street food', 'Wine tasting'],
            'Lifestyle' => ['Travel', 'Yoga', 'Meditation', 'Gaming', 'Volunteering', 'Pets'],
            'Learning' => ['Languages', 'Investing', 'Tech', 'Startups'],
        ];

        foreach ($interests as $category => $names) {
            foreach ($names as $name) {
                Interest::query()->updateOrCreate(['name' => $name], ['category' => $category]);
            }
        }
    }
}
