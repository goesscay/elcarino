<div style="display:flex;flex-direction:column;gap:12px">
    {{-- Streamed through an audited, session-only route: opening this is a
         `verification.selfie_viewed` audit-log entry, and the response is
         `no-store`. It is never a public URL. --}}
    <img
        src="{{ route('admin.verification.selfie', $record) }}"
        alt="Selfie submitted for verification"
        style="max-width:100%;max-height:60vh;object-fit:contain;border-radius:12px"
    >
    <p style="margin:0">
        <strong>Pose asked:</strong>
        {{ config('verification.poses.'.$record->pose, $record->pose) }}
    </p>
    <p style="margin:0;font-size:0.875rem;opacity:0.75">
        Compare the face to the profile photos, and check the pose matches what was asked.
    </p>
</div>
