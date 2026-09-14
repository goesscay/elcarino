<?php

namespace App\Http\Controllers\Api\Profile;

use App\Http\Concerns\RespondsWithErrorEnvelope;
use App\Http\Controllers\Controller;
use App\Http\Requests\Profile\PreferencesUpdateRequest;
use App\Http\Resources\Profile\PreferenceResource;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;

class PreferenceController extends Controller
{
    use RespondsWithErrorEnvelope;

    /**
     * GET /api/v1/preferences/me
     */
    public function show(Request $request): JsonResponse
    {
        $preferences = $request->user()->preferences;

        if (! $preferences) {
            return $this->errorResponse('preferences_not_found', 'Preferences have not been set yet.', 404);
        }

        return response()->json(['preferences' => new PreferenceResource($preferences)]);
    }

    /**
     * PUT /api/v1/preferences/me. docs/06-security-architecture.md §3.4:
     * "Premium filters ... check user->entitlement($key) | 403 +
     * error.code = upgrade_required" (Phase 2 item 2).
     *
     * This is a *full replace* (same as prompts' `PUT /prompts/me`) — the
     * client always resends every field, including a religion_filter/
     * politics_filter set back when the caller *was* a subscriber. Rejecting
     * on "the field is non-empty" would then lock a lapsed subscriber out of
     * saving *any* preference change, including ones with nothing to do with
     * advanced filters. Only reject an actual attempt to set/change one
     * without the entitlement — resubmitting the same value that's already
     * stored is allowed through unchanged. The real, authoritative gate is
     * still at read time (DiscoveryFeedService checks the entitlement again
     * before ever applying either filter), so stale stored data from a
     * lapsed subscription never actually narrows their feed either way.
     */
    public function update(PreferencesUpdateRequest $request): JsonResponse
    {
        $user = $request->user();
        $existing = $user->preferences;
        $data = $request->validated();

        if (! $user->entitlement('advanced_filters')) {
            if ($this->attemptsToChange($existing?->religion_filter, $data['religion_filter'] ?? [])
                || $this->attemptsToChange($existing?->politics_filter, $data['politics_filter'] ?? [])) {
                return $this->errorResponse(
                    'upgrade_required',
                    'Filtering by religion or politics is a Premium feature.',
                    403,
                );
            }

            // Not an attempted change — e.g. no entitlement and nothing
            // supplied, or resubmitting a lapsed subscriber's own unchanged
            // stored value. Preserve whatever is already on the row rather
            // than silently wiping it out from an unrelated field update.
            $data['religion_filter'] = $existing?->religion_filter ?? [];
            $data['politics_filter'] = $existing?->politics_filter ?? [];
        }

        $preferences = $user->preferences()->updateOrCreate([], $data);
        $user->profile?->recalculateCompletion();

        return response()->json(['preferences' => new PreferenceResource($preferences)]);
    }

    /**
     * @param  array<string>|null  $stored
     * @param  array<string>  $submitted
     */
    private function attemptsToChange(?array $stored, array $submitted): bool
    {
        if (empty($submitted)) {
            return false;
        }

        $normalize = fn (array $values) => collect($values)->sort()->values()->all();

        return $normalize($submitted) !== $normalize($stored ?? []);
    }
}
