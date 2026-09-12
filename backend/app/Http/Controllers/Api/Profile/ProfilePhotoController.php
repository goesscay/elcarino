<?php

namespace App\Http\Controllers\Api\Profile;

use App\Http\Concerns\RespondsWithErrorEnvelope;
use App\Http\Controllers\Controller;
use App\Http\Requests\Profile\PhotoOrderRequest;
use App\Http\Requests\Profile\PhotoUploadRequest;
use App\Http\Resources\Profile\ProfilePhotoResource;
use App\Models\ProfilePhoto;
use App\Services\Media\ImageProcessor;
use App\Services\Media\InvalidImageException;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Gate;
use Illuminate\Support\Facades\Storage;
use Illuminate\Support\Str;

class ProfilePhotoController extends Controller
{
    use RespondsWithErrorEnvelope;

    public function __construct(private readonly ImageProcessor $images) {}

    /**
     * POST /api/v1/profiles/me/photos
     */
    public function store(PhotoUploadRequest $request): JsonResponse
    {
        $profile = $request->user()->profile;

        if (! $profile) {
            return $this->errorResponse('profile_not_found', 'Complete profile basics before adding photos.', 422);
        }

        if ($profile->photos()->count() >= config('media.max_photos_per_profile')) {
            return $this->errorResponse(
                'photo_limit_reached',
                'You can have up to '.config('media.max_photos_per_profile').' photos.',
                422,
            );
        }

        try {
            $bytes = $this->images->reencode($request->file('photo'));
        } catch (InvalidImageException $e) {
            return $this->errorResponse('invalid_image', $e->getMessage(), 422);
        }

        $path = 'photos/'.$profile->user_id.'/'.Str::uuid().'.jpg';
        Storage::disk(config('filesystems.default'))->put($path, $bytes);

        $photo = $profile->photos()->create([
            'storage_path' => $path,
            'sort_order' => $profile->photos()->count(),
        ]);

        $profile->recalculateCompletion();

        return response()->json(['photo' => new ProfilePhotoResource($photo)], 201);
    }

    /**
     * DELETE /api/v1/profiles/me/photos/{photo}
     */
    public function destroy(Request $request, ProfilePhoto $photo): JsonResponse
    {
        // The default Laravel 13 base Controller no longer pulls in
        // AuthorizesRequests, so this goes through the Gate facade rather
        // than $this->authorize() — same policy check either way.
        Gate::authorize('delete', $photo);

        Storage::disk(config('filesystems.default'))->delete($photo->storage_path);
        $profile = $photo->profile;
        $photo->delete();
        $profile->recalculateCompletion();

        return response()->json(['message' => 'Photo deleted.']);
    }

    /**
     * PUT /api/v1/profiles/me/photos/order
     */
    public function order(PhotoOrderRequest $request): JsonResponse
    {
        $profile = $request->user()->profile;
        $ids = $request->input('photo_ids');
        $owned = $profile->photos()->pluck('id')->all();

        // Ownership check, not a Policy class: the ids arrive in the request
        // body, not the route, so there is no single model to route-model-bind
        // and authorize against — see PhotoOrderRequest's rules() comment.
        if (count($ids) !== count($owned) || array_diff($ids, $owned) !== []) {
            return $this->errorResponse('invalid_photo_ids', 'photo_ids must be exactly your own photo ids.', 422);
        }

        foreach ($ids as $index => $id) {
            ProfilePhoto::query()->whereKey($id)->update(['sort_order' => $index]);
        }

        return response()->json(['photos' => ProfilePhotoResource::collection($profile->photos()->get())]);
    }
}
