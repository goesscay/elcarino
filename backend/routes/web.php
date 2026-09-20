<?php

use App\Http\Controllers\Admin\VerificationSelfieController;
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

// A verification selfie, for the reviewer in the admin panel only. The panel's
// own session (not a signed URL): the image is "Critical" data (docs/06 section
// 5), so it is never linkable, and every view is audit-logged. The controller
// answers 403 to anyone who is not an admin/moderator, guests included — there
// is deliberately no `auth` middleware, which would try to redirect to a named
// `login` route this API-first app doesn't have.
Route::get(
    'admin/verification/{verificationRequest}/selfie',
    [VerificationSelfieController::class, 'show'],
)->middleware('web')->name('admin.verification.selfie');
