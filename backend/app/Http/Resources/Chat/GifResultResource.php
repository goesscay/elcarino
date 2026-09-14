<?php

namespace App\Http\Resources\Chat;

use App\Services\Gifs\GifResult;
use Illuminate\Http\Request;
use Illuminate\Http\Resources\Json\JsonResource;

/**
 * @mixin GifResult
 */
class GifResultResource extends JsonResource
{
    public function toArray(Request $request): array
    {
        return [
            'id' => $this->id,
            'preview_url' => $this->previewUrl,
            'url' => $this->url,
            'width' => $this->width,
            'height' => $this->height,
        ];
    }
}
