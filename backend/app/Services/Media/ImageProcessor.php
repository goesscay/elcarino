<?php

namespace App\Services\Media;

use Illuminate\Http\UploadedFile;

/**
 * Server-side upload handling for profile photos — docs/06-security-architecture.md
 * §6: "Uploads validated server-side: MIME sniff (not trust the extension), max
 * dimensions, max file size, re-encode to strip EXIF (GPS EXIF stripping is
 * mandatory — a photo with embedded coordinates defeats §4)."
 */
class ImageProcessor
{
    public function __construct(private readonly int $maxDimension = 4096) {}

    /**
     * Re-encodes the upload to JPEG via GD. `getimagesize()` sniffs the real
     * image type (ignoring the client-supplied extension/MIME), and GD's
     * decode-then-encode round-trip drops EXIF entirely as a side effect —
     * the decoded bitmap carries no metadata, so nothing is left to
     * re-attach. This is what actually satisfies the mandatory GPS-EXIF-strip
     * rule above; it is not merely a format conversion.
     *
     * @return string raw JPEG bytes, ready to write to disk.
     *
     * @throws InvalidImageException
     */
    public function reencode(UploadedFile $file): string
    {
        $info = @getimagesize($file->getRealPath());

        if ($info === false) {
            throw new InvalidImageException('The uploaded file is not a valid image.');
        }

        [$width, $height, $type] = $info;

        if ($width > $this->maxDimension || $height > $this->maxDimension) {
            throw new InvalidImageException("Image dimensions must not exceed {$this->maxDimension}px.");
        }

        $source = match ($type) {
            IMAGETYPE_JPEG => @imagecreatefromjpeg($file->getRealPath()),
            IMAGETYPE_PNG => @imagecreatefrompng($file->getRealPath()),
            IMAGETYPE_WEBP => @imagecreatefromwebp($file->getRealPath()),
            default => null,
        };

        if (! $source instanceof \GdImage) {
            throw new InvalidImageException('Unsupported or corrupt image file. Use JPEG, PNG, or WebP.');
        }

        // Flatten onto a white canvas so PNG/WebP transparency doesn't turn black
        // when re-encoded to JPEG (which has no alpha channel).
        $flattened = imagecreatetruecolor($width, $height);
        imagefill($flattened, 0, 0, (int) imagecolorallocate($flattened, 255, 255, 255));
        imagecopy($flattened, $source, 0, 0, 0, 0, $width, $height);
        imagedestroy($source);

        ob_start();
        imagejpeg($flattened, quality: 85);
        $bytes = ob_get_clean();
        imagedestroy($flattened);

        if ($bytes === false || $bytes === '') {
            throw new InvalidImageException('Failed to process the uploaded image.');
        }

        return $bytes;
    }
}
