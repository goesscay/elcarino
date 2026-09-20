<?php

namespace App\Services\Explore;

use App\Models\Interest;
use App\Models\User;
use App\Models\UserLocation;
use App\Models\UserPreference;
use App\Services\Discovery\DiscoveryFeedService;
use Illuminate\Support\Collection;

/**
 * Explore (docs/07 §2.1): browse people by interest instead of one at a time.
 *
 * Everything here is derived from `DiscoveryFeedService::eligible()`, the same
 * set the Discover deck draws from. So a member count is "people you could
 * actually be shown who share this", not a raw head-count of everyone with the
 * interest, and tapping a category can never surface someone the viewer's own
 * filters, distance, blocks or earlier swipes would hide. It also means the
 * counts are bounded by the feed's scan limit, like the feed itself.
 */
class ExploreService
{
    public function __construct(private readonly DiscoveryFeedService $feed) {}

    /**
     * Every interest at least one eligible person has, most popular first
     * (ties by name). An interest nobody eligible shares is left out: a tile
     * that opens an empty list is a dead end.
     *
     * @return Collection<int, array{interest: Interest, member_count: int, is_yours: bool}>
     */
    public function interests(User $viewer, UserLocation $location, UserPreference $preferences): Collection
    {
        $counts = $this->feed->eligible($viewer, $location, $preferences)
            ->flatMap(fn (User $person) => $person->interests->pluck('id'))
            ->countBy();

        $mine = $viewer->interests()->pluck('interests.id')->all();

        return Interest::query()
            ->whereIn('id', $counts->keys())
            ->get()
            ->map(fn (Interest $interest) => [
                'interest' => $interest,
                'member_count' => (int) $counts[$interest->id],
                'is_yours' => in_array($interest->id, $mine, true),
            ])
            ->sort(fn (array $a, array $b) => [$b['member_count'], $a['interest']->name] <=> [$a['member_count'], $b['interest']->name])
            ->values();
    }

    /**
     * One page of the eligible people who share [$interest], in the feed's own
     * order.
     *
     * @return array{people: Collection<int, User>, hasMore: bool, total: int}
     */
    public function people(User $viewer, UserLocation $location, UserPreference $preferences, Interest $interest, int $page, int $perPage): array
    {
        $matching = $this->feed->eligible($viewer, $location, $preferences)
            ->filter(fn (User $person) => $person->interests->contains('id', $interest->id))
            ->values();

        return [
            'people' => $matching->slice(($page - 1) * $perPage, $perPage)->values(),
            'hasMore' => $matching->count() > $page * $perPage,
            'total' => $matching->count(),
        ];
    }
}
