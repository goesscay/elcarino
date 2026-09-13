<?php

return [

    // No length limit is specified anywhere in /docs — a provisional cap
    // (not one of the 30 tracked decisions), same spirit as the photo/prompt/
    // interest caps elsewhere. Safe to retune.
    'max_message_length' => 2000,

    'default_per_page' => 30,
    'max_per_page' => 100,

];
