<?php

namespace App\Http\Controllers\Api\Profile;

use App\Http\Concerns\RespondsWithErrorEnvelope;
use App\Http\Controllers\Controller;
use App\Http\Requests\Profile\PromptsUpdateRequest;
use App\Http\Resources\Profile\ProfilePromptResource;
use App\Http\Resources\Profile\UserProfilePromptResource;
use App\Models\ProfilePrompt;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;

class PromptController extends Controller
{
    use RespondsWithErrorEnvelope;

    /**
     * GET /api/v1/prompts — the library. Public-ish (docs/06 §5) but still
     * behind auth for now since every route in this group is; revisit if an
     * unauthenticated marketing surface ever needs it.
     */
    public function index(): JsonResponse
    {
        $prompts = ProfilePrompt::query()->where('is_active', true)->orderBy('sort_order')->get();

        return response()->json(['prompts' => ProfilePromptResource::collection($prompts)]);
    }

    /**
     * GET /api/v1/prompts/me
     */
    public function mine(Request $request): JsonResponse
    {
        $answers = $request->user()->profilePrompts()->with('prompt')->orderBy('sort_order')->get();

        return response()->json(['prompts' => UserProfilePromptResource::collection($answers)]);
    }

    /**
     * PUT /api/v1/prompts/me — full replace (upsert answers + sort_order),
     * matching docs/03's "upsert answers + sort_order" for this endpoint.
     */
    public function update(PromptsUpdateRequest $request): JsonResponse
    {
        $user = $request->user();

        $user->profilePrompts()->delete();
        foreach ($request->input('prompts') as $index => $item) {
            $user->profilePrompts()->create([
                'prompt_id' => $item['prompt_id'],
                'answer' => $item['answer'],
                'sort_order' => $index,
            ]);
        }

        $user->profile?->recalculateCompletion();

        $answers = $user->profilePrompts()->with('prompt')->orderBy('sort_order')->get();

        return response()->json(['prompts' => UserProfilePromptResource::collection($answers)]);
    }

    /**
     * DELETE /api/v1/prompts/me/{promptId} — removes one answer. Scoped to
     * the caller via the profilePrompts() relation, so a mismatched id just
     * 404s rather than needing a separate ownership check/Policy.
     */
    public function destroy(Request $request, ProfilePrompt $prompt): JsonResponse
    {
        $deleted = $request->user()->profilePrompts()->where('prompt_id', $prompt->id)->delete();

        if ($deleted === 0) {
            return $this->errorResponse('prompt_answer_not_found', 'No answer found for that prompt.', 404);
        }

        $request->user()->profile?->recalculateCompletion();

        return response()->json(['message' => 'Prompt answer removed.']);
    }
}
