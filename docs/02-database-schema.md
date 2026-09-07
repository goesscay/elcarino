# Database Schema — PostgreSQL

Companion to [`01-technical-specification.md`](01-technical-specification.md). Every
table below becomes one Laravel migration. Conventions used throughout:

- `id` — `bigint` primary key, auto-increment, unless noted otherwise.
- `*_id` — foreign key, `bigint`, indexed, `on delete cascade` unless noted.
- `created_at` / `updated_at` — standard Laravel timestamps on every table.
- Soft-deletable tables (`users`, `profiles`, `conversations`) additionally carry
  `deleted_at` so moderation actions (ban/suspend) don't destroy audit trails.
- Money stored as integer minor units (cents) with an ISO currency code column, never
  as float.

## Identity & profile

### `users`
| Column | Type | Notes |
|---|---|---|
| id | bigint PK | |
| email | string, unique, nullable | nullable — phone-only signup is allowed |
| phone | string, unique, nullable | E.164 format |
| password | string, nullable | null for OAuth-only accounts |
| google_id / apple_id | string, unique, nullable | OAuth identifiers |
| email_verified_at | timestamp, nullable | |
| phone_verified_at | timestamp, nullable | |
| status | enum: active, suspended, banned, deleted | default `active` |
| role | enum: user, admin, moderator | default `user` |
| last_active_at | timestamp, nullable | for "online/offline" and admin dashboard |
| deleted_at | timestamp, nullable | soft delete (account deletion) |

### `profiles`
| Column | Type | Notes |
|---|---|---|
| id | bigint PK | |
| user_id | FK → users, unique | one profile per user |
| display_name | string | |
| birth_date | date | age derived, never store raw age; 18+ enforced at signup |
| gender | enum: man, woman, non_binary | open decision #6 — confirmed |
| bio | text, nullable | |
| relationship_goal | string, nullable | |
| is_verified | boolean | default false; set by verification pipeline |
| completion_pct | smallint | denormalized for gamification "profile completion" |

### `profile_photos`
| Column | Type | Notes |
|---|---|---|
| id | bigint PK | |
| profile_id | FK → profiles | |
| storage_path | string | object-store key, not a public URL |
| sort_order | smallint | primary photo = order 0 |
| moderation_status | enum: pending, approved, rejected | default `pending` |

### `profile_prompts`
| Column | Type | Notes |
|---|---|---|
| id | bigint PK | |
| prompt | string | e.g. *"My ideal first date is…"* |
| category | string, nullable | |
| is_active | boolean | default true |
| sort_order | smallint | |

### `user_profile_prompts`
| Column | Type | Notes |
|---|---|---|
| id | bigint PK | |
| user_id | FK → users | |
| prompt_id | FK → profile_prompts | |
| answer | text | |
| sort_order | smallint | |

### `interests`
| Column | Type | Notes |
|---|---|---|
| id | bigint PK | |
| name | string, unique | |
| category | string, nullable | |

### `user_interests`
| Column | Type | Notes |
|---|---|---|
| user_id | FK → users | composite PK with interest_id |
| interest_id | FK → interests | |

### `user_preferences`
| Column | Type | Notes |
|---|---|---|
| id | bigint PK | |
| user_id | FK → users, unique | |
| min_age / max_age | smallint | min_age floor 18 |
| max_distance_km | smallint | |
| interested_in_genders | jsonb | multi-select of man / woman / non_binary |
| religion_filter | jsonb, nullable | advanced filter |
| politics_filter | jsonb, nullable | advanced filter |
| relationship_goal_filter | jsonb, nullable | |

### `user_locations`
| Column | Type | Notes |
|---|---|---|
| id | bigint PK | |
| user_id | FK → users, unique | |
| latitude / longitude | double precision | **exact value — never returned to clients directly** |
| geohash | string, indexed | for efficient proximity queries |
| updated_at | timestamp | |

### `user_devices`
| Column | Type | Notes |
|---|---|---|
| id | bigint PK | |
| user_id | FK → users | |
| fcm_token | string | for push notifications |
| platform | enum: ios, android | |
| app_version | string, nullable | |
| last_seen_at | timestamp | |

## Discovery & matching

### `swipes`
| Column | Type | Notes |
|---|---|---|
| id | bigint PK | |
| actor_id | FK → users | who swiped |
| target_id | FK → users | who was swiped on |
| direction | enum: left, right, super | `super` reserved for proposed Super Like |
| unique (actor_id, target_id) | | one swipe per pair; index for feed exclusion |

### `likes`
| Column | Type | Notes |
|---|---|---|
| id | bigint PK | |
| user_id | FK → users | derived from a right/super swipe — kept distinct from `swipes` so "who liked me" queries stay cheap |
| liked_user_id | FK → users | |
| is_super | boolean | default false |

### `matches`
| Column | Type | Notes |
|---|---|---|
| id | bigint PK | |
| user_one_id / user_two_id | FK → users | always stored with the lower user id first, enforced at write time, to keep the pair unique |
| matched_at | timestamp | |
| unmatched_at | timestamp, nullable | |
| unmatched_by | FK → users, nullable | |

### `boosts`
| Column | Type | Notes |
|---|---|---|
| id | bigint PK | |
| user_id | FK → users | |
| starts_at / ends_at | timestamp | |
| source | enum: purchase, subscription_perk | |

## Messaging

### `conversations`
| Column | Type | Notes |
|---|---|---|
| id | bigint PK | |
| match_id | FK → matches, nullable | null only if unmatched-messaging is enabled and used |
| user_one_id / user_two_id | FK → users | |
| last_message_at | timestamp, nullable | for inbox ordering |
| deleted_at | timestamp, nullable | |

### `messages`
| Column | Type | Notes |
|---|---|---|
| id | bigint PK | |
| conversation_id | FK → conversations | |
| sender_id | FK → users | |
| body | text, nullable | null if attachment-only |
| type | enum: text, voice_note, gif, photo | see open decisions #16–18 |
| read_at | timestamp, nullable | read receipts |
| created_at | timestamp, indexed | |

### `message_attachments`
| Column | Type | Notes |
|---|---|---|
| id | bigint PK | |
| message_id | FK → messages | |
| storage_path | string | |
| mime_type | string | |
| duration_seconds | smallint, nullable | voice notes |

## Safety

### `blocks`
| Column | Type | Notes |
|---|---|---|
| id | bigint PK | |
| blocker_id | FK → users | |
| blocked_id | FK → users | |
| unique (blocker_id, blocked_id) | | |

### `reports`
| Column | Type | Notes |
|---|---|---|
| id | bigint PK | |
| reporter_id | FK → users | |
| reported_id | FK → users | |
| category | enum: harassment, fake_profile, spam, inappropriate_content, scam, other | |
| description | text, nullable | |
| status | enum: pending, reviewing, actioned, dismissed | default `pending` |
| reviewed_by | FK → users (admin), nullable | |
| reviewed_at | timestamp, nullable | |

## Monetisation

### `subscription_plans`
| Column | Type | Notes |
|---|---|---|
| id | bigint PK | |
| name | string | |
| price_cents | integer | |
| currency | char(3) | ISO 4217 |
| billing_interval | enum: monthly, quarterly, annual | |
| entitlements | jsonb | e.g. `{"unlimited_likes": true, "boosts_per_month": 1}` — keeps pricing/entitlement changes migration-free |
| is_active | boolean | default true |

### `subscriptions`
| Column | Type | Notes |
|---|---|---|
| id | bigint PK | |
| user_id | FK → users | |
| plan_id | FK → subscription_plans | |
| status | enum: active, canceled, expired, past_due | |
| started_at / ends_at | timestamp | |
| provider | enum: app_store, play_store, stripe, other | see open decision #27 |
| provider_subscription_id | string, nullable | external reference |

### `payments`
| Column | Type | Notes |
|---|---|---|
| id | bigint PK | |
| user_id | FK → users | |
| subscription_id | FK → subscriptions, nullable | |
| amount_cents | integer | |
| currency | char(3) | |
| status | enum: pending, succeeded, failed, refunded | |
| provider_reference | string | gateway transaction id |

## Verification

### `verification_requests`
| Column | Type | Notes |
|---|---|---|
| id | bigint PK | |
| user_id | FK → users | |
| method | enum: ai_selfie, manual_review, id_document | open decisions #21–23 |
| status | enum: pending, processing, approved, rejected | |
| submitted_at | timestamp | |

### `verification_results`
| Column | Type | Notes |
|---|---|---|
| id | bigint PK | |
| verification_request_id | FK → verification_requests | |
| decided_by | enum: ai, admin | |
| confidence_score | float, nullable | AI-path only |
| reviewer_id | FK → users (admin), nullable | manual-path only |
| decided_at | timestamp | |

## Notifications

### `notifications`
| Column | Type | Notes |
|---|---|---|
| id | bigint PK | |
| user_id | FK → users | recipient |
| type | enum: new_match, new_message, like, subscription, verification, report_status, system | |
| payload | jsonb | type-specific data for deep-linking |
| read_at | timestamp, nullable | |
| sent_via_push | boolean | default false |

## Future — AI tables (Phase 4, schema reserved from Phase 0)

### `ai_profile_analysis`
| Column | Type | Notes |
|---|---|---|
| id | bigint PK | |
| user_id | FK → users | |
| analysis_type | string | e.g. `photo_authenticity`, `bio_sentiment` |
| result | jsonb | |
| model_version | string | for reproducibility/audit |

### `compatibility_scores`
| Column | Type | Notes |
|---|---|---|
| id | bigint PK | |
| user_one_id / user_two_id | FK → users | |
| score | smallint | 0–100, formula **[TBD]** — see spec §10 |
| computed_at | timestamp | |

### `recommendation_history`
| Column | Type | Notes |
|---|---|---|
| id | bigint PK | |
| user_id | FK → users | |
| recommended_user_id | FK → users | |
| reason | jsonb, nullable | interpretability trail for the recommendation |
| shown_at | timestamp | |

## Indexing notes

- `user_locations.geohash` + a bounding-box query is the Phase-1 proximity approach;
  revisit PostGIS only if geohash precision becomes a bottleneck.
- `swipes(actor_id, target_id)` composite index powers both write-time dedup and the
  discovery feed's "exclude already-swiped" filter.
- `messages(conversation_id, created_at)` composite index for paginated history.
- All `*_id` foreign keys get a btree index by default (Laravel does this automatically
  when the column is declared via `foreignId()`).
