<?php

namespace App\Services\Verification;

use Illuminate\Support\Facades\Crypt;
use Illuminate\Support\Facades\Storage;
use Illuminate\Support\Str;

/**
 * Where selfies live while a request is open. docs/06 §5 classes verification
 * photos "Critical": encrypted at rest, access logged, never in a log sink,
 * shortest viable retention. So the bytes are encrypted with the app key
 * before they touch the (private) disk — a copy of the storage folder alone
 * reveals nothing — and [delete] is called the moment a decision is made.
 * "Access logged" is the admin viewer's job (VerificationSelfieController).
 */
class VerificationPhotoStore
{
    private function disk()
    {
        return Storage::disk(config('filesystems.default'));
    }

    /**
     * @return string the storage path to keep on the request
     */
    public function put(string $jpegBytes): string
    {
        $path = 'verification/'.Str::uuid().'.enc';
        $this->disk()->put($path, Crypt::encryptString(base64_encode($jpegBytes)));

        return $path;
    }

    /**
     * @return string|null the JPEG bytes, or null if the file is gone
     */
    public function get(string $path): ?string
    {
        if (! $this->disk()->exists($path)) {
            return null;
        }

        return base64_decode(Crypt::decryptString($this->disk()->get($path)), true) ?: null;
    }

    public function delete(?string $path): void
    {
        if ($path !== null && $this->disk()->exists($path)) {
            $this->disk()->delete($path);
        }
    }
}
