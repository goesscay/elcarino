<?php

namespace App\Services\Likes;

use App\Enums\UserStatus;
use App\Models\Block;
use App\Models\Like;
use App\Models\Swipe;
use App\Models\User;
use App\Models\UserMatch;
use App\Services\Discovery\CandidateAnnotator;
use Illuminate\Database\Eloquent\Builder;
use Illuminate\Support\Collection;

/**
 * The two lists behind the Likes tab (docs/07 §3.4).
 *
 * **received** — people who liked the viewer and haven't been answered yet.
 * This is the premium-gated "who liked me" feature ([PROPOSED]): the gate
 * itself (`view-who-liked-me`) is the controller's, and the controller only
 * ever calls [receivedCount] for a non-subscriber, so no liker's identity is
 * even loaded for them. Same no-derivative-signal principle as the `like`
 * notification carrying no identity (docs/03 Notifications).
 *
 * **sent** — people the viewer liked who haven't matched with them. Free.
 *
 * Both lists drop anyone who is no longer visible to the viewer: inactive
 * (suspended/banned/deleted) accounts, anyone blocked in either direction, and
 * anyone the viewer has since matched with. Received also drops anyone the
 * viewer has already swiped on (an answered like isn't a pending one).
 */
class LikesService
{
    public function __construct(private readonly CandidateAnnotator $annotator) {}

    public function receivedCount(User $viewer): int
    {
        return $this->receivedQuery($viewer)->count();
    }

    /**
     * @return array{users: Collection<int, User>, hasMore: bool}
     */
    public function received(User $viewer, int $page, int $perPage): array
    {
        return $this->page($viewer, $this->receivedQuery($viewer), 'user', $page, $perPage);
    }

    /**
     * @return array{users: Collection<int, User>, hasMore: bool}
     */
    public function sent(User $viewer, int $page, int $perPage): array
    {
        return $this->page($viewer, $this->sentQuery($viewer), 'likedUser', $page, $perPage);
    }

    public function sentCount(User $viewer): int
    {
        return $this->sentQuery($viewer)->count();
    }

    /**
     * @return Builder<Like>
     */
    private function receivedQuery(User $viewer): Builder
    {
        $excluded = $this->blockedIds($viewer)
            ->merge(Swipe::query()->where('actor_id', $viewer->id)->pluck('target_id'))
            ->merge($this->matchedIds($viewer));

        return Like::query()
            ->where('liked_user_id', $viewer->id)
            ->whereHas('user', fn (Builder $q) => $this->visible($q)->whereNotIn('id', $excluded));
    }

    /**
     * @return Builder<Like>
     */
    private function sentQuery(User $viewer): Builder
    {
        $excluded = $this->blockedIds($viewer)->merge($this->matchedIds($viewer));

        return Like::query()
            ->where('user_id', $viewer->id)
            ->whereHas('likedUser', fn (Builder $q) => $this->visible($q)->whereNotIn('id', $excluded));
    }

    /**
     * @param  Builder<Like>  $likes
     * @return array{users: Collection<int, User>, hasMore: bool}
     */
    private function page(User $viewer, Builder $likes, string $relation, int $page, int $perPage): array
    {
        $rows = $likes
            ->with([
                "{$relation}.profile.photos" => fn ($q) => $q->where('moderation_status', 'approved')->orderBy('sort_order'),
                "{$relation}.location",
                "{$relation}.profilePrompts.prompt",
                "{$relation}.interests",
            ])
            ->orderByDesc('created_at')
            ->orderByDesc('id')
            ->skip(($page - 1) * $perPage)
            ->take($perPage + 1)
            ->get();

        $hasMore = $rows->count() > $perPage;

        $users = $rows->take($perPage)->map(function (Like $like) use ($relation) {
            $user = $like->{$relation};
            $user->setAttribute('liked_at', $like->created_at);

            return $user;
        })->values();

        return [
            'users' => $this->annotator->annotate(
                $users,
                $viewer->location,
                $viewer->interests()->pluck('interests.id'),
            ),
            'hasMore' => $hasMore,
        ];
    }

    /**
     * @param  Builder<User>  $query
     * @return Builder<User>
     */
    private function visible(Builder $query): Builder
    {
        // `has('profile')` because a like can outlive a half-deleted account,
        // and a row with no profile has nothing to render.
        return $query->where('status', UserStatus::Active)->has('profile');
    }

    /**
     * @return Collection<int, int>
     */
    private function blockedIds(User $viewer): Collection
    {
        return collect([$viewer->id])
            ->merge(Block::query()->where('blocker_id', $viewer->id)->pluck('blocked_id'))
            ->merge(Block::query()->where('blocked_id', $viewer->id)->pluck('blocker_id'));
    }

    /**
     * Everyone the viewer has ever matched with, including unmatched pairs:
     * an ended relationship isn't a pending like.
     *
     * @return Collection<int, int>
     */
    private function matchedIds(User $viewer): Collection
    {
        return UserMatch::query()
            ->where('user_one_id', $viewer->id)
            ->orWhere('user_two_id', $viewer->id)
            ->get(['user_one_id', 'user_two_id'])
            ->flatMap(fn (UserMatch $m) => [$m->user_one_id, $m->user_two_id])
            ->reject(fn (int $id) => $id === $viewer->id)
            ->values();
    }
}
