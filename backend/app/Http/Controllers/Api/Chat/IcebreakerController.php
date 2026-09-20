<?php

namespace App\Http\Controllers\Api\Chat;

use App\Http\Controllers\Controller;
use App\Http\Requests\Chat\IcebreakersRequest;
use App\Http\Resources\Chat\IcebreakerSetResource;
use App\Models\Conversation;
use App\Services\Icebreakers\IcebreakerService;

class IcebreakerController extends Controller
{
    public function __construct(private readonly IcebreakerService $icebreakers) {}

    /**
     * GET /api/v1/chat/conversations/{conversation}/icebreakers
     *
     * A few tappable opening lines. Cached per person and conversation, so
     * opening the chat repeatedly costs nothing.
     */
    public function show(IcebreakersRequest $request, Conversation $conversation): IcebreakerSetResource
    {
        return new IcebreakerSetResource($this->icebreakers->suggestions($request->user(), $conversation));
    }

    /**
     * POST /api/v1/chat/conversations/{conversation}/icebreakers/refresh
     *
     * A new set that avoids repeating the last one. Its own, tighter rate limit
     * (`icebreaker-refresh`) because each call can be a paid generator run.
     */
    public function refresh(IcebreakersRequest $request, Conversation $conversation): IcebreakerSetResource
    {
        return new IcebreakerSetResource($this->icebreakers->suggestions($request->user(), $conversation, refresh: true));
    }
}
