<?php

use App\Http\Controllers\Media\MessageAttachmentStreamController;
use Illuminate\Support\Facades\Route;

Route::get('/', function () {
    return view('welcome');
});

// Signed, short-lived (media.chat_media_signed_url_ttl_minutes) — see
// MessageAttachmentStreamController's doc comment for why this exists
// instead of Storage::temporaryUrl()'s built-in storage.local route.
// Outside `/api/v1` on purpose, same reasoning as storage.local itself: a
// native Android/iOS media player fetching this URL carries no Sanctum
// bearer token, only the query-string signature.
Route::get(
    'media/message-attachments/{attachment}',
    [MessageAttachmentStreamController::class, 'show'],
)->middleware('signed')->name('media.message-attachments.show');
