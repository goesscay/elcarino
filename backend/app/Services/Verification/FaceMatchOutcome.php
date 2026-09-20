<?php

namespace App\Services\Verification;

/**
 * What a [FaceMatcher] concluded. Deliberately coarse: the service, not the
 * provider, decides what each one means for the request.
 */
enum FaceMatchOutcome: string
{
    /** Same person, with a confidence score. */
    case Matched = 'matched';

    /** A face was found but it doesn't look like the profile photos. */
    case NotMatched = 'not_matched';

    /** No usable face in the selfie. The one objective failure. */
    case NoFace = 'no_face';

    /** The matcher couldn't say (unconfigured, provider error, no reference face). */
    case Inconclusive = 'inconclusive';
}
