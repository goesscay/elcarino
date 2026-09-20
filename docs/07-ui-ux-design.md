# UI/UX Design

Phase 0 deliverable — the **wireframe + information-architecture layer**. It defines
every screen, how they connect, the components they're built from, and the states each
must handle, so Phase 1 engineering can start without guessing.

**What this document is not:** high-fidelity visual design. Open decision #2 (brand
name + primary colour) is now confirmed — **Elcarino**, brand red `#D81D1F` (the logo's own red), logo in
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

Bottom tab bar. **Built (`MainShell`): Discover · Explore · Likes · Chats · Profile** — all
five tabs of the target layout. Each tab keeps its own stack and state; Explore, Likes
and Chats reload whenever they are (re)selected.

| Tab | Screen | Notes |
|---|---|---|
| **Discover** | Card stack | Default tab on launch |
| **Chats** | Matches + inbox | Badge = unread conversations *(not built — needs a shared unread source)* |
| **Likes** | Who liked me / people you like | **Built.** "People who like you" is premium; a free user gets the count and a paywall, never the people (§3.4) |
| **Explore** | Interest categories | **Built (§3.4b).** Sits between Discover and Likes. |
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
| **Splash** | **Built.** The logo in white, centred (170 dp), on a **full-bleed logo-red** background (the brand red, `AppColors.primary`, `#D81D1F`), the same in light and dark mode. The native launch screen matches it exactly, so the hand-off is invisible. Decides authed vs not; ≤ 1.5 s then routes. States: checking / update-required / offline. |
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
| **Profile detail** | **Built (with Likes).** One vertical scroll: the main photo full-bleed under a translucent back button and `⋯` menu, then name + age + verified badge, distance, relationship-goal chip, bio, **Interests** (a shared interest is picked out in the brand tint, with "you have N in common"), then the remaining photos interleaved with prompt answers (prompt, photo, prompt, photo…, dropping neither). Pinned footer **Pass** / **Like** when it's opened from someone who liked you; none when read-only (People you like). Like uses the same swipe flow as the Discover deck, so a mutual like plays the match celebration; the screen pops `true` once someone is answered or blocked so the list can drop them. `⋯` → Report, Block. It renders a candidate the list already fetched — there is no "get any user's profile" endpoint. *Not built:* opening it from a Discover card tap (the card is still swipe-only). |
| **Filters** | **Redesigned (UI redesign); a full screen at `/discover/filters` (Discover's filter icon), not a sheet.** The same form as onboarding's Preferences step and Edit preferences (`Save`): *Interested in* chips, an *Age range* slider and a *Distance* slider with their live values in brand red, and a collapsible *Advanced filters* card (religion, politics — premium-gated in Phase 2 [TBD-13]; a non-subscriber sees a `Premium` pill, an Upgrade row and locked inputs, and can still remove a lapsed value). Primary action `Show people` is pinned at the bottom: it saves and returns to the feed, which reloads. `Reset` (app bar) appears only once the form has unsaved changes and reverts them to what was loaded — it never clears saved preferences and defines no "default" filter values. *Not built:* filters by interests, relationship goals and lifestyle — the form has no such fields today (the API accepts a relationship-goal filter, but no UI sets it). |
| **Match celebration** | **Built (UI redesign).** Full-screen and always dark (a moment, not a page): the viewer's and the match's portraits overlap as circles with a heart badge between them, on a soft red glow. Photos slide together, the heart pops, the text fades up, then it's still — no confetti or heart shower; honours reduce-motion. "It's a Match!" / "You both liked each other." · `Send a message` (opens the conversation) / `Keep discovering`. The viewer's own photo is a best-effort profile read; if it fails or there's no photo the celebration shows a placeholder rather than waiting on it. |
| **Out of likes** (free) | Replaces stack when the free daily like limit is hit [TBD-11/13]: countdown to reset + `Get unlimited likes` (paywall). |
| **Empty feed** | No candidates in range: illustration + `Widen your filters` / `Increase distance`. |

### 3.3 Matches & chat

| Screen | Spec |
|---|---|
| **Matches + inbox** | **Built (UI redesign) as the "Chats" tab.** Large "Chats" title. *New matches*: a horizontal row of avatars with a brand-red ring (no messages yet). *Messages*: rows of avatar, name, one-line preview, timestamp (time today · "Yesterday" · weekday · M/D) and a red **unread count badge** (99+ cap; unread rows get a bold name/preview and a red time), with hairline dividers aligned to the text. Unmatch is a long-press (and a screen-reader custom action) rather than a per-row icon; it is also in the conversation overflow. First load shows skeleton rows; later reloads refresh in place. Empty: "No matches yet" + `Keep discovering` (goes to Discover). *Not built:* the search field — there is no conversation-search API. |
| **Conversation** | **Redesigned (UI redesign).** Header: back, the other person's photo, name, a status line ("Online" with a green dot / "Typing…" in brand red), voice + video call icons, overflow (Unmatch, Report, Block) — under a hairline. Messages: **own = solid brand-red bubble, white text; incoming = neutral fill, theme text** (legible in dark mode); runs of consecutive messages from one person (within 5 min) sit tight and only the run's last bubble has the small tail corner and the time; "Read" is appended to the last own message's time when read; **day dividers** ("Today", "Yesterday", weekday, "Sep 1"). Voice notes: circular play button + progress + duration; GIF/photo: the image is the bubble. Composer: "+" (voice note / photo / GIF sheet — **only if those are in scope** [TBD-16/17/18]; for unmatched conversations only for subscribers, server-enforced — spec §12), a soft rounded field, and a send button that turns brand red once there's text. Empty: "You matched! Say hi to X." **plus opening lines** (Phase 4, #25): under the greeting, "Ideas to start the chat" — up to three tappable cards built from what you share (an interest, their prompt answer, their bio, or a warm generic question), a `More ideas` button for a fresh set, and a small `AI` tag when a model wrote them. **Tapping a card fills the composer; it never sends.** The whole empty state scrolls, so a tall set of suggestions and a multi-line draft can't squeeze the greeting. Shown only where the composer is enabled, and a failed load takes no space at all *Not built:* "View profile" in the overflow (no other-user profile screen exists). |
| **Unmatched-conversation banner** (free user) | Inline banner in the composer area: "Subscribe to message people you haven't matched with" → paywall. Composer disabled. |
| **Report from chat** | See §3.7. |

### 3.4 Likes (premium)

**Built.** A tab with a large "Likes" title and a red count badge (people who like you),
over two text tabs with a brand-red underline. Both lists stay alive when you switch, and
both reload when the Likes tab is re-selected (a like that arrived while you were elsewhere
is there when you come back). Pull to refresh.

| Screen | Spec |
|---|---|
| **People who like you** | Grid of photo tiles (name + age, distance, on a soft bottom fade), newest first. **Subscriber:** tap → Profile detail with **Like / Pass**; answering someone removes them from the grid and decrements the badge. **Free:** the API returns the *count* and `locked: true` and **no people at all** (`GET /likes/received`, docs/03) — the screen shows "N people like you", a blurred mosaic of *placeholder* tiles, and `See who likes you` → Subscription; on return it reloads, so subscribing there unlocks the grid in place. There is nothing real behind the blur to reveal or scrape. With no likes it's an ordinary empty state ("No likes yet"), not a paywall. |
| **People you like** | Free, read-only: the same grid of people you've liked who haven't matched with you yet; tap → Profile detail **without** Like / Pass. Empty: "Nothing waiting" + `Keep discovering`. |

*Not built:* the reference layout's "Recently liked you" strip on the free tab (it would
show identities, which is the paywalled data) and a Likes-tab unread badge on the bar.
The paywall's benefit list is plan data, so it only mentions "see who likes you" if the
plan's copy does.

### 3.4b Explore

**Built.** A large "Explore" title with a search icon, "Find people who share your
interests" beneath, then a row of category chips (**All** plus one per category that has a
tile) over a two-column grid of interest tiles: a brand-tinted icon circle (per category —
Sports, Arts, Food & drink, Lifestyle, Learning, a neutral one for anything else), the
name (up to two lines), and "N people" / "1 person". An interest already on your own
profile carries a small brand-red tick. Most popular first.

| Screen | Spec |
|---|---|
| **Explore** | The grid above. **Chips** narrow it by category; the **search** icon swaps the subtitle for a field that filters by name (case-insensitive) — both client-side, the list is a couple of dozen tiles, and they combine. Tile height follows the OS text size so a two-line name never overflows. Pull to refresh; it also reloads on tab re-select and on returning from a category, because every count moves as you swipe. Errors match Discover's: no location → "Set location", no preferences → "Set preferences", otherwise Retry; empty → "Nothing to explore yet". |
| **People in an interest** | A pushed screen titled with the interest: "N people share this" and the same photo grid as Likes (name + age, distance). Tap → Profile detail (§3.2) with **Like / Pass**; once answered or blocked the person leaves the grid and the count drops. Empty (everyone answered): "You've seen everyone here" + `Back to Explore`. |

The counts are *people you could actually be shown*, not everyone with the interest: they
come from the Discover deck's own eligibility (your filters, distance, blocks and earlier
swipes — docs/03 "Explore"), so a tile never opens onto someone the deck would hide.
*Not built:* the reference layout's photographic tiles (there is no imagery for an
interest; an icon on a tint stands in) and named "collections" such as "Binge Watchers" or
"New Friends" — the tiles are the interest catalogue itself, so any new collection is a
catalogue entry, not code.

### 3.5 Profile (own)

| Screen | Spec |
|---|---|
| **My profile** | **Redesigned (UI redesign), as the Profile tab.** Large title + settings gear. A circular portrait (green verified badge when verified), "Name, age", a Verified / Not verified pill, a **Profile completeness** card (percentage + bar — gamification, spec §17), then the CTAs: solid-red `Edit profile` and outlined `Edit preferences`. Below, the profile as others see it: *About me*, *Interests* (chips) and *Prompts* (cards) — sections are omitted when empty. Interests and prompts are best-effort reads of the existing edit-screen endpoints; if either fails the rest still shows. First load shows a skeleton; refreshes update in place; a load error has Retry. *Not built:* a `Verify` CTA (no verification flow yet — Phase 4) and a location line (the API deliberately exposes no location to the client — spec §9). |
| **Edit profile** | **Redesigned (UI redesign).** A grouped card of section rows (tinted icon, title, one-line description, chevron — the reusable `SectionCard`/`SectionRow`, which Settings also uses): **Photos · Basics & bio · Interests · Prompts**, each opening a focused editor with an explicit `Save`. *Not built as separate sections:* relationship goal and about-me live inside "Basics & bio" (one `PUT /profiles/me`, a disclosed simplification); there is no "Lifestyle" data in the schema. |
| **Edit photos** | **Redesigned; same screen as onboarding's Photos step.** A 3-column grid of 6 portrait slots: photos with a `Main` badge on the first and `In review` while moderation is pending, a remove (×) button (confirms first) and earlier/later arrows (dimmed at the ends; reorder stays buttons, not drag); empty slots are quiet, and only the next one is a highlighted `Add photo` (camera / gallery). Basics, Interests and Prompts editors: labelled form sections, chip-style gender / interests (with a live "Save (N selected)"), a pinned Save button, and prompts as cards with drag-to-reorder (press and hold), edit-on-tap and delete. |
| **Edit prompts** | Reorder answered prompts; swap a prompt; edit an answer — see above. |
| **Edit preferences** | Age, distance, interested-in, advanced filters. |

### 3.6 Verification — **[PROPOSED]**

**Built (Phase 4).** One screen (`/verification`, from the profile's **Get verified** card) that moves
through the four steps below. The profile shows a brand-tinted "Get verified" card under the
"Not verified" pill; once verified the card is gone and the avatar carries the badge.

| Step | Spec |
|---|---|
| **Intro** | A shield icon, "Show you're really you", one line on why, the **pose** to strike in a bordered card (chosen by the server, e.g. "Show a peace sign"), and three points: take a selfie showing the pose; we compare it with your profile photos; **your selfie is encrypted, used only for this check, deleted as soon as it's done, and never shown to other people.** `Take selfie`. If the last attempt was rejected, a short notice says why. |
| **Selfie** | The **front camera only** — deliberately no gallery option, because a verification selfie has to be taken now, showing the pose. Capped at 1600 px. Backing out of the camera submits nothing. |
| **Checking** | Spinner and "This usually takes just a moment." The server decides synchronously, so this is the wait for the answer. |
| **Result** | **Approved:** brand-tinted badge, "You're verified", `Done`. **In review:** "We're reviewing your selfie — a person is taking a look. We'll notify you as soon as there's an answer — you can leave this screen." (Never says *why* it went to a person, never a score.) **Rejected:** the reason in plain words and what to do differently, `Try again` (a new pose) / `Not now`. |

Opening it when **already verified**, **already in review**, or **out of attempts for today**
shows that state instead of inviting a doomed selfie; an expired pose prompt is replaced with a
fresh one and a snackbar says so. A `verification` push opens the profile.

*Deviation from the earlier sketch:* there is no `Request manual review` button. The AI never
rejects a non-match — it sends it to a person automatically — so the only rejection the user
can see from the AI is "no face detected", and the fix for that is retaking the photo. See
docs/03 "Verification" for the decision rules.

### 3.7 Safety

| Screen | Spec |
|---|---|
| **Block confirm** | Dialog: "Block <name>? They won't be able to see your profile or message you, and you won't see them." `Block` / `Cancel`. Blocking also unmatches. |
| **Report — category** | List: Harassment, Fake profile, Spam, Inappropriate content, Scam, Other (from `report-categories` endpoint). |
| **Report — detail** | Free-text (optional), option to also block, option to attach which messages/photos. `Submit`. |
| **Report — confirmation** | "Thanks — our team will review this." No status promises beyond what moderation SLA allows. |
| **Blocked users** (Settings child) | **Redesigned.** A list of avatar + name with a compact `Unblock` button per row; empty and error states use the shared `StateMessage`. |

### 3.8 Subscription — **[PROPOSED]**

| Screen | Spec |
|---|---|
| **Paywall** | Triggered contextually (out of likes, advanced filter, unmatched message, who-liked-me, call). Shows: the one benefit that triggered it, then the full benefit list, then plan(s) [TBD-11/12/13]. Store-billing disclaimer. `Subscribe` / `Restore purchases` / dismiss. |
| **Checkout** | Native store sheet (Apple/Google) [TBD-27/28], or gateway flow if a gateway is chosen. |
| **Manage subscription** (Settings child) | Current plan, renewal date, `Change plan` / `Cancel` (deep-links to store where required). |

### 3.9 Settings

**Redesigned (UI redesign).** A large "Settings" title over grouped cards (the shared
`SectionCard`/`SectionRow`), each row a tinted icon + title (+ description): **Account**
(Account, Profile preferences, Notifications) · **Privacy & safety** (Blocked users) ·
**Subscription** · **Support** (Help & support, Legal, About Elcarino). **Log out** and
**Delete account** sit apart in their own card at the bottom, Delete in danger red.

*Real today:* Profile preferences (the Edit preferences screen), Blocked users,
Subscription, About (wordmark, tagline and Flutter's built-in open-source licences page),
Log out (confirms first). *Not built yet* — shown with a "Soon" label and a "Coming soon"
notice rather than a dead navigation: Account (email/phone, password, connected accounts),
Notifications (per-type toggles need a preferences table that doesn't exist), Help &
Support, Legal (ToS/Privacy — placeholder links [TBD]) and Delete account (confirmation +
consequences + data export offer, per security doc §9 and §11). Show/hide distance,
discovery on/off and a read-receipts toggle are likewise not built.

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
| `color.primary` | `#D81D1F` (the logo's red; decision #2. White text on it is 5.1:1) | primary actions, like, selected tab, the splash |
| `color.primary.dark` | `#B0181A` | pressed / emphasis on light |
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

- **#2 brand name** — ✅ confirmed (Elcarino, `#D81D1F`, logo in `/branding`); still
  needed: splash artwork and store listing assets built from it.
- **#6 gender options** → Profile basics, Preferences, "interested in".
- **#4 age policy** → DOB picker constraints, onboarding gate.
- **State management choice** (spec §4) → how every screen's presentation layer is wired.
- **#11 / #13** (plan count, premium benefits) → what the paywall and "out of likes"
  screens actually say.
- **#16 / #17 / #18** (voice notes / GIFs / photo sharing) → the chat composer's
  attachment menu.
