# UI/UX Design

Phase 0 deliverable — the **wireframe + information-architecture layer**. It defines
every screen, how they connect, the components they're built from, and the states each
must handle, so Phase 1 engineering can start without guessing.

**What this document is not:** high-fidelity visual design. Open decision #2 (brand
name + primary colour) is now confirmed — **Elcarino**, brand red `#DC2626`, logo in
[`/branding`](../branding) — and `color.primary` below reflects it. Final imagery,
illustration style, a brand typeface, motion polish, and a clickable prototype are
still a separate track that needs a visual designer. The rest of the colour/type
tokens below remain a **neutral placeholder system** — structurally complete, visually
provisional; the token *names* and component structure stay as branding fills in.

---

## 1. Design principles

1. **Safety is a first-class surface, not a settings sub-menu.** Block/report reachable
   in ≤ 2 taps from any profile or conversation.
2. **Earn the swipe.** Prompts and verified badges are shown prominently — the product
   competes on connection quality, not volume.
3. **No dark patterns around location or money.** Distance is always approximate and
   labelled as such; the paywall states exactly what's gated and why, once.
4. **Every screen has a defined empty, loading, error, and offline state.** (§7)
5. **Accessible by default:** min 44×44 pt tap targets, WCAG AA contrast, full dynamic
   type support, every interactive element labelled for screen readers.

---

## 2. Information architecture

### 2.1 Top-level navigation (authenticated)

Bottom tab bar. **Built (UI redesign, `MainShell`): Discover · Chats · Profile.**
Explore and Likes are part of the target design but are not tabs yet — neither has a
screen or an API behind it (`GET /who-liked-me` is `[PROPOSED]`), and they join the bar
as two more destinations when they do. Each tab keeps its own stack and state; the
Chats tab reloads whenever it is (re)selected.

| Tab | Screen | Notes |
|---|---|---|
| **Discover** | Card stack | Default tab on launch |
| **Chats** | Matches + inbox | Badge = unread conversations *(not built — needs a shared unread source)* |
| **Likes** *(not built)* | Who liked me | Premium — shows blurred grid + paywall for free users |
| **Explore** *(not built)* | Interest categories | Needs a categories/member-count endpoint |
| **Profile** | Own profile + entry to Edit / Verification / Settings | |

Modal / pushed flows (not tabs): Onboarding, Filters, Profile detail, Match
celebration, Report, Block confirm, Subscription paywall, Verification, Settings and
its children, Call UI.

### 2.2 Navigation map

```
Splash
 └─ (not authed) ─ Welcome ─ Auth method ┬─ Email/Phone ─ OTP ──┐
 │                                       └─ Google / Apple ──────┤
 │                                                               ▼
 │                                                        Onboarding wizard
 │                                                        (basics → photos →
 │                                                         prompts → prefs →
 │                                                         location → notifs)
 │                                                               │
 └─ (authed) ────────────────────────────────────────────────────┴─► Main tabs
                                                                       │
        ┌──────────────┬──────────────┬──────────────┬─────────────────┤
        ▼              ▼              ▼              ▼
     Discover        Matches        Likes         Profile
        │              │              │              │
     Filters        Conversation   Paywall        Edit profile
     Profile detail    │                          Edit photos
     Match modal     Report/Block                 Edit prompts
                                                  Edit preferences
                                                  Verification flow
                                                  Settings ─┬─ Account
                                                            ├─ Notifications
                                                            ├─ Privacy & Safety
                                                            │   └─ Blocked users
                                                            ├─ Subscription
                                                            ├─ Help & Support
                                                            ├─ Legal (ToS/Privacy)
                                                            ├─ Log out
                                                            └─ Delete account
```

---

## 3. Screen inventory & wireframe specs

Notation: **[REQUIRED]/[PROPOSED]/[TBD-#]** tags carry the same meaning as elsewhere in
`/docs`. Each screen lists: purpose · key layout · primary actions · notable states.

### 3.1 Onboarding

| Screen | Spec |
|---|---|
| **Splash** | Logo centred; decides authed vs not; ≤ 1.5 s then routes. States: checking / update-required / offline. |
| **Welcome** | Full-bleed brand imagery placeholder; value prop line; `Create account` / `Sign in`. |
| **Auth method** | Buttons: Continue with phone, email, Google, Apple. Legal microcopy with ToS/Privacy links (placeholder URLs, [TBD] legal). |
| **Email / phone entry** | Single field; country-code picker for phone; `Continue`. Validation inline. |
| **OTP** | 6-box code input; auto-advance; resend timer (60 s); "wrong number?" back link. States: sending / invalid / expired / locked-out. |
| **Profile basics** | Fields: first name, date of birth (spinner, 18+ enforced [TBD-4]), gender select [TBD-6]. Progress `1 / 5`. |
| **Photos** | Grid of 6 slots, first is primary; add from camera/library; drag to reorder; min 1 to continue [TBD — min count]. Upload progress + moderation-pending hint. |
| **Prompts** | Pick 3 prompts from the library, answer each (char limit). Skippable? [TBD — recommend: require 1]. |
| **Preferences** | Interested in (gender multi-select [TBD-6]); age range dual slider; max distance slider. Advanced filters (religion, politics) collapsible, optional. |
| **Location permission** | Rationale screen → OS prompt. Fallback: manual city/region picker if denied. |
| **Notification permission** | Rationale → OS prompt. Denial is fine; app continues. |
| **Onboarding complete** | Confirmation; CTA into Discover. |

### 3.2 Discover

| Screen | Spec |
|---|---|
| **Card stack** | **Built (UI redesign).** One large photo-first card (24 px corners, soft lift — the only shadow in the app): primary photo, name + age + verified badge, approximate distance, bio (2 lines) and up to three *shared* interests as translucent chips, on a short bottom fade. Drag left = pass, right = like: the card tilts, a LIKE/PASS stamp fades in with the drag, a light haptic marks the commit line, and the next card grows into place behind it; a short drag springs back. Action row under the card: **Pass · Like · Boost** (circular; Like is the solid-red primary). Header: wordmark + filter icon. *Not built:* swipe-up Super Like and **Undo** (rewind) — no API for either yet ([PROPOSED, TBD-11]); they join the action row when they exist. *Not built:* tap card → Profile detail (below). |
| **Profile detail** | Scrollable: photo carousel interleaved with prompt answers, bio, interests (chips), relationship goal, distance. Sticky footer pass/like. Overflow menu: Report, Block. |
| **Filters sheet** | Bottom sheet: age, distance, interests, relationship goals (free); religion, politics, "additional preferences" (advanced — gated to premium in Phase 2 [TBD-13]). `Apply` / `Reset`. |
| **Match celebration** | **Built (UI redesign).** Full-screen and always dark (a moment, not a page): the viewer's and the match's portraits overlap as circles with a heart badge between them, on a soft red glow. Photos slide together, the heart pops, the text fades up, then it's still — no confetti or heart shower; honours reduce-motion. "It's a Match!" / "You both liked each other." · `Send a message` (opens the conversation) / `Keep discovering`. The viewer's own photo is a best-effort profile read; if it fails or there's no photo the celebration shows a placeholder rather than waiting on it. |
| **Out of likes** (free) | Replaces stack when the free daily like limit is hit [TBD-11/13]: countdown to reset + `Get unlimited likes` (paywall). |
| **Empty feed** | No candidates in range: illustration + `Widen your filters` / `Increase distance`. |

### 3.3 Matches & chat

| Screen | Spec |
|---|---|
| **Matches + inbox** | **Built (UI redesign) as the "Chats" tab.** Large "Chats" title. *New matches*: a horizontal row of avatars with a brand-red ring (no messages yet). *Messages*: rows of avatar, name, one-line preview, timestamp (time today · "Yesterday" · weekday · M/D) and a red **unread count badge** (99+ cap; unread rows get a bold name/preview and a red time), with hairline dividers aligned to the text. Unmatch is a long-press (and a screen-reader custom action) rather than a per-row icon; it is also in the conversation overflow. First load shows skeleton rows; later reloads refresh in place. Empty: "No matches yet" + `Keep discovering` (goes to Discover). *Not built:* the search field — there is no conversation-search API. |
| **Conversation** | Message list (bubbles, own = trailing), date separators, read receipt on last own message, typing indicator, online/last-active in header. Composer: text field, send; attachment button reveals voice note / photo / GIF **only if those are in scope** [TBD-16/17/18] and, for unmatched conversations, only for subscribers (server-enforced — spec §12). Header overflow: View profile, Unmatch, Report, Block. |
| **Unmatched-conversation banner** (free user) | Inline banner in the composer area: "Subscribe to message people you haven't matched with" → paywall. Composer disabled. |
| **Report from chat** | See §3.7. |

### 3.4 Likes (premium)

| Screen | Spec |
|---|---|
| **Who liked me** | Grid of profile thumbnails. Free: blurred + count ("7 people like you") + `See who likes you` paywall. Premium: unblurred, tap → Profile detail with quick like/pass. |

### 3.5 Profile (own)

| Screen | Spec |
|---|---|
| **My profile** | Preview as others see it; completion meter (gamification — spec §17); `Edit profile`; verification status chip (`Verify` CTA if unverified); gear → Settings. |
| **Edit profile** | Sections: photos, prompts, bio, basics, relationship goal, interests. Each opens a focused editor. Autosave or explicit save [decide — recommend explicit save per section]. |
| **Edit photos** | Same grid as onboarding; reorder; delete; moderation status per photo. |
| **Edit prompts** | Reorder answered prompts; swap a prompt; edit an answer. |
| **Edit preferences** | Age, distance, interested-in, advanced filters. |

### 3.6 Verification — **[PROPOSED]**

| Screen | Spec |
|---|---|
| **Verification intro** | What it is, why (trust/safety), what's captured, privacy note (photos handled per security doc §6). `Start`. |
| **Selfie capture** | Guided pose prompt(s); camera with overlay; auto or manual capture. [TBD-21/22/23 — method]. |
| **Processing** | Spinner / progress; "usually takes under a minute"; can leave and get a notification. |
| **Result** | Approved → verified badge celebration. Rejected → reason (if safe to show) + `Try again` / `Request manual review` [TBD-22]. |

### 3.7 Safety

| Screen | Spec |
|---|---|
| **Block confirm** | Dialog: "Block <name>? They won't be able to see your profile or message you, and you won't see them." `Block` / `Cancel`. Blocking also unmatches. |
| **Report — category** | List: Harassment, Fake profile, Spam, Inappropriate content, Scam, Other (from `report-categories` endpoint). |
| **Report — detail** | Free-text (optional), option to also block, option to attach which messages/photos. `Submit`. |
| **Report — confirmation** | "Thanks — our team will review this." No status promises beyond what moderation SLA allows. |
| **Blocked users** (Settings child) | List with unblock. |

### 3.8 Subscription — **[PROPOSED]**

| Screen | Spec |
|---|---|
| **Paywall** | Triggered contextually (out of likes, advanced filter, unmatched message, who-liked-me, call). Shows: the one benefit that triggered it, then the full benefit list, then plan(s) [TBD-11/12/13]. Store-billing disclaimer. `Subscribe` / `Restore purchases` / dismiss. |
| **Checkout** | Native store sheet (Apple/Google) [TBD-27/28], or gateway flow if a gateway is chosen. |
| **Manage subscription** (Settings child) | Current plan, renewal date, `Change plan` / `Cancel` (deep-links to store where required). |

### 3.9 Settings

Account (email/phone, password, connected accounts) · Notifications (per-type toggles:
matches, messages, likes, system) · Privacy & Safety (blocked users, show/hide
distance, discovery on/off, read receipts toggle [decide]) · Subscription · Help &
Support (ticket/contact — tool is a cost-deck line item) · Legal (ToS, Privacy —
placeholder links [TBD]) · Log out · Delete account (confirmation + consequences + data
export offer, per security doc §9 and §11).

### 3.10 Admin panel (Filament, web — not part of the Flutter app)

Resource screens: Users (list/filter/view/suspend/ban/delete), Reports queue
(list/detail/action/dismiss), Verifications (queue/approve/reject), Subscriptions &
Payments (read + plan CRUD), Dashboard (metrics per spec §19), Audit log (read-only).

---

## 4. Design system (placeholder tokens)

### 4.1 Colour tokens

Confirmed direction (UI/UX redesign, 2026-09): premium, clean, warm, photo-first.
Roughly **70% neutral · 20% white surface · 10% Elcarino red** — red marks the
important action (like, send, primary CTA, the selected tab), never large fills; the
user's photos are the most important thing on any screen.

| Token | Light / Dark | Use |
|---|---|---|
| `color.bg` | `#FAFAFA` / `#111111` | screen background |
| `color.surface` | `#FFFFFF` / `#1C1C1E` | cards, sheets, nav bar |
| `color.fill` | `#F1F1F3` / `#2A2A2D` | quiet fill on surfaces: chips, incoming bubble, inputs |
| `color.text.primary` | `#111111` / `#FFFFFF` | body text |
| `color.text.secondary` | `#6B6B6B` / `#A1A1AA` | captions, metadata |
| `color.border` | `#E5E5E5` / `#2C2C2E` | hairlines, dividers |
| `color.primary` | `#DC2626` (Elcarino brand red, decision #2) | primary actions, like, selected tab |
| `color.primary.dark` | `#B91C1C` | pressed / emphasis on light |
| `color.primary.tint` | `#FEE2E2` / `#3B1414` | selected chip fill, soft highlights |
| `color.on-primary` | `#FFFFFF` | text/icons on primary |
| `color.pass` | `#8A8A8E` | pass action |
| `color.success` | `#2E9C68` | verified, confirmations |
| `color.warning` | `#D9832A` | caution states |
| `color.danger` | `#D64545` | destructive, block, errors |
| `color.on-photo` (+ muted / faint / scrim / control) | white / black-alpha | text and controls over a user's photo — white in both themes, since a photo isn't themed |

Dark mode is **required** (system-driven) and is designed, not inverted. Every token has
a light and dark value; no hard-coded colours in widgets — read `AppColors.*` or, for
anything that changes with brightness, `context.palette.*`.

### 4.2 Typography

One family — the platform's own (SF on iOS, Roboto on Android; Inter is not bundled).
Three weights only (400 / 600 / 700); hierarchy comes from size. Scale:

| Role | Size / weight |
|---|---|
| Hero | 32 / 700 |
| Screen title | 28 / 700 |
| Section title | 22 / 600 |
| Card title | 22 / 700 |
| Row title | 17 / 600 |
| Body | 16 / 400 (dense 15) |
| Secondary | 13 / 400 |
| Button | 16 / 600 |
| Chip / label | 13 / 600 |
| Caption | 12 / 400 |

All sizes scale with the OS dynamic-type setting.

### 4.3 Spacing & radius

Spacing: `xs 4 · sm 8 · md 12 · lg 16 · screen 20 · xl 24 · xxl 32 · huge 40`; default
horizontal screen padding **20**. Corner radius: `sm 8 · md 12 · lg 16 · card 20 ·
profile-card 24 · button 16 · pill 999` — pills only for avatars, circular actions and
small chips; rounding is a hierarchy. Card separation by a 1 px border, not shadow
(never both).

### 4.4 Component library (Phase 1 build order roughly follows this)

Buttons (primary / secondary / text / destructive / icon) · Text field + inline
validation · OTP input · Dual-range slider · Chip / chip group (interests, filters) ·
Avatar (with verified badge overlay) · Profile card · Photo grid slot · Bottom sheet ·
Dialog · Snackbar / toast · Segmented control · Tab bar · List row (conversation,
setting) · Message bubble · Empty-state block · Loading skeletons · Paywall layout ·
Progress meter (onboarding, profile completion).

### 4.5 Motion & haptics

- Swipe: card follows the finger, springs on release, light haptic on like/pass commit.
- Match modal: celebratory but brief (< 800 ms in).
- Respect "reduce motion" — swap transitions for fades.

### 4.6 Accessibility baseline

Contrast AA for text and essential icons · tap targets ≥ 44 pt · every icon-only
button has an accessible label · form fields have programmatic labels + error
associations · card-stack actions available as buttons, not gesture-only · dynamic
type does not clip or overlap · screen-reader reading order matches visual order.

---

## 5. Per-screen state checklist

Every screen that loads or submits data must handle:

- **Loading** — skeletons for content screens, spinner-in-button for submits.
- **Empty** — purposeful copy + a next action (never a blank page).
- **Error** — inline where possible; retry affordance; the consistent error envelope's
  `message` is safe to surface, `code` drives client behaviour.
- **Offline** — cached content shown read-only with an offline banner; writes queue or
  fail gracefully with a clear message.
- **Permission denied** (camera, photos, location, notifications) — explain the impact
  and offer the manual fallback or a deep link to OS settings.

---

## 6. What Phase 1 still needs before UI work starts

Pulled from [`05-open-decisions.md`](05-open-decisions.md) — these directly shape
screens above:

- **#2 brand name** — ✅ confirmed (Elcarino, `#DC2626`, logo in `/branding`); still
  needed: splash artwork and store listing assets built from it.
- **#6 gender options** → Profile basics, Preferences, "interested in".
- **#4 age policy** → DOB picker constraints, onboarding gate.
- **State management choice** (spec §4) → how every screen's presentation layer is wired.
- **#11 / #13** (plan count, premium benefits) → what the paywall and "out of likes"
  screens actually say.
- **#16 / #17 / #18** (voice notes / GIFs / photo sharing) → the chat composer's
  attachment menu.
