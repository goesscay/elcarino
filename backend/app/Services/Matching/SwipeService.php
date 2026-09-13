<?php

namespace App\Services\Matching;

use App\Enums\SwipeDirection;
use App\Models\Conversation;
use App\Models\Like;
use App\Models\Swipe;
use App\Models\User;
use App\Models\UserMatch;
use App\Services\Notifications\NotificationService;
use Illuminate\Support\Facades\DB;

/**
 * Phase 1 item 6's core: record a swipe, and on a mutual right/super,
 * create the match. Rule-based scoring/ranking of *which* candidates to
 * show is item 7 (Matching engine v1) — this only detects a match once two
 * people have already both said yes.
 *
 * Also creates the match's Conversation (item 8), so the chat inbox can list
 * "new match, no messages yet" the moment two people match — docs/07 §3.3
 * shows that as part of the inbox, not something that only appears once a
 * first message exists.
 *
 * Also fires the item-9 "new_match"/"like" notifications — deliberately
 * *outside* the DB transaction below (see `recordSwipe`), so a push-provider
 * failure can never roll back an already-valid swipe/match.
 */
class SwipeService
{
    public function __construct(private readonly NotificationService $notifications) {}

    /**
     * @return array{swipe: Swipe, match: ?UserMatch}
     *
     * @throws AlreadySwipedException
     */
    public function recordSwipe(User $actor, User $target, SwipeDirection $direction): array
    {
        $result = DB::transaction(function () use ($actor, $target, $direction) {
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
            $liked = false;

            if ($direction !== SwipeDirection::Left) {
                Like::query()->create([
                    'user_id' => $actor->id,
                    'liked_user_id' => $target->id,
                    'is_super' => $direction === SwipeDirection::Super,
                ]);
                $liked = true;

                $reciprocated = Swipe::query()
                    ->where('actor_id', $target->id)
                    ->where('target_id', $actor->id)
                    ->whereIn('direction', [SwipeDirection::Right, SwipeDirection::Super])
                    ->exists();

                if ($reciprocated) {
                    $match = $this->createMatch($actor, $target);
                }
            }

            return ['swipe' => $swipe, 'match' => $match, 'liked' => $liked];
        });

        if ($result['match'] !== null) {
            $this->notifications->notifyNewMatch($result['match'], $result['match']->conversation, $actor, $target);
        } elseif ($result['liked']) {
            $this->notifications->notifyLike($target);
        }

        return ['swipe' => $result['swipe'], 'match' => $result['match']];
    }

    private function createMatch(User $actor, User $target): UserMatch
    {
        // Always the lower id first (docs/02-database-schema.md) — enforced
        // here, not the database, so the unique(user_one_id, user_two_id)
        // constraint actually catches a duplicate regardless of which side
        // swiped second.
        $userOneId = min($actor->id, $target->id);
        $userTwoId = max($actor->id, $target->id);

        $match = UserMatch::query()->create([
            'user_one_id' => $userOneId,
            'user_two_id' => $userTwoId,
            'matched_at' => now(),
        ]);

        Conversation::query()->create([
            'match_id' => $match->id,
            'user_one_id' => $userOneId,
            'user_two_id' => $userTwoId,
        ]);

        return $match;
    }
}
