<?php

namespace App\Http\Controllers\Api\Notifications;

use App\Http\Controllers\Controller;
use App\Http\Resources\Notifications\NotificationResource;
use App\Models\Notification;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Gate;

class NotificationController extends Controller
{
    /**
     * GET /api/v1/notifications — "paginated, unread-first" (docs/03).
     * Same orderByRaw(bool-expression, tiebreaker) shape as
     * ChatController::index's "unmessaged matches sort last" — unread
     * (read_at IS NULL) first, newest-first within each of those two groups.
     */
    public function index(Request $request): JsonResponse
    {
        $perPage = min(
            (int) $request->integer('per_page', config('notifications.default_per_page')),
            config('notifications.max_per_page'),
        );

        $notifications = $request->user()->appNotifications()
            ->orderByRaw('read_at IS NOT NULL, created_at DESC')
            ->paginate($perPage);

        return response()->json([
            'notifications' => NotificationResource::collection($notifications->items()),
            'meta' => [
                'page' => $notifications->currentPage(),
                'per_page' => $notifications->perPage(),
                'has_more' => $notifications->hasMorePages(),
            ],
        ]);
    }

    /**
     * PUT /api/v1/notifications/{notification}/read
     */
    public function markRead(Request $request, Notification $notification): JsonResponse
    {
        Gate::authorize('update', $notification);

        if ($notification->read_at === null) {
            $notification->update(['read_at' => now()]);
        }

        return response()->json(['notification' => new NotificationResource($notification)]);
    }

    /**
     * PUT /api/v1/notifications/read-all
     */
    public function markAllRead(Request $request): JsonResponse
    {
        $request->user()->appNotifications()->whereNull('read_at')->update(['read_at' => now()]);

        return response()->json(['message' => 'All notifications marked read.']);
    }
}
