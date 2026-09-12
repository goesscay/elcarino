<?php

namespace App\Enums;

/**
 * profiles.gender and user_preferences.interested_in_genders values.
 * Confirmed set — open decision #6 (docs/05-open-decisions.md). Don't add a
 * fourth option without that decision changing; see CLAUDE.md "handling open
 * decisions".
 */
enum Gender: string
{
    case Man = 'man';
    case Woman = 'woman';
    case NonBinary = 'non_binary';
}
