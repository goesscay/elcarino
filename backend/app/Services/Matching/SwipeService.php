<?php

namespace App\Services\Matching;

use App\Enums\SwipeDirection;
use App\Models\Like;
use App\Models\Swipe;
use App\Models\User;
use App\Models\UserMatch;
use Illuminate\Support\Facades\DB;

/**
 * Phase 1 item 6's core: record a swipe, and on a mutual right/super,
 * create the match. Rule-based scoring/ranking of *which* candidates to
 * show is item 7 (Matching engine v1) — this only detects a match once two
 * people have already both said yes.
 */
class SwipeService
{
    /**
     * @return array{swipe: Swipe, match: ?UserMatch}
     *
     * @throws AlreadySwipedException
     */
    public function recordSwipe(User $actor, User $target, SwipeDirection $direction): array
    {
        return DB::transaction(function () use ($actor, $target, $direction) {
            $alreadySwiped = Swipe::query()
                ->where('actor_id', $actor->id)
                ->where('target_id', $target->id)
                ->exists();

            if ($alreadySwiped) {
                throw new AlreadySwipedException("You've already swiped on this profile.");
            }

            $swipe = Swipe::query()->create([
                'actor_id' => $actor->id,
                'target_id' => $target->id,
                'direction' => $direction,
            ]);

            $match = null;

            if ($direction !== SwipeDirection::Left) {
                Like::query()->create([
                    'user_id' => $actor->id,
                    'liked_user_id' => $target->id,
                    'is_super' => $direction === SwipeDirection::Super,
                ]);

                $reciprocated = Swipe::query()
                    ->where('actor_id', $target->id)
                    ->where('target_id', $actor->id)
                    ->whereIn('direction', [SwipeDirection::Right, SwipeDirection::Super])
                    ->exists();

                if ($reciprocated) {
                    $match = $this->createMatch($actor, $target);
                }
            }

            return ['swipe' => $swipe, 'match' => $match];
        });
    }

    private function createMatch(User $actor, User $target): UserMatch
    {
        // Always the lower id first (docs/02-database-schema.md) — enforced
        // here, not the database, so the unique(user_one_id, user_two_id)
        // constraint actually catches a duplicate regardless of which side
        // swiped second.
        return UserMatch::query()->create([
            'user_one_id' => min($actor->id, $target->id),
            'user_two_id' => max($actor->id, $target->id),
            'matched_at' => now(),
        ]);
    }
}
