# Day-of-Week Registration — Design

**Status:** drafted 2026-05-05
**Author:** Pete Holiday (with Claude)

## 1. Goal & scope

Let commissioners declare which day(s) of the week a league plays on, and let players in two-day leagues register as either a **two-day** player or a **one-day** player (with the specific day they're choosing). The primary goal is accurate data about players who can only attend one night a week, framed in a way that feels dignified — a "type" of registration, not an attendance problem.

**In scope:**
- League-level config of game days (0–2 days).
- An interstitial step in the registration flow for two-day leagues that asks the player to pick a registration type.
- Separate single-day pricing per gender.
- Captain/commissioner visibility of the chosen type, including the drafting view.
- Suppressing attendance prompts for game-days a one-day player didn't sign up for.
- Player-initiated change of registration type before the league starts.

**Out of scope (parking lot):**
- Backfilling historical leagues' `game_days`.
- Day-choice for pickup registrations.
- Automatic charge/refund when a player switches between two-day and one-day after paying.
- League configurations with 3+ play days per week.
- Cap-by-type roster limits (single-day registrations count against the same gender limit as two-day).

## 2. Player-facing flow

For a league with `game_days.length == 2`, registration becomes a four-step path:

1. Player clicks **Register** somewhere in the app.
2. Player completes their gRank survey if it's stale (existing redirect).
3. **New:** Player lands on the day-choice interstitial and picks a registration type.
4. Player fills out the standard registration form (availability, ranks, pair, waiver) and proceeds to payment.

For a league with 0 or 1 game day, the interstitial is skipped — the flow is identical to today.

The interstitial is reachable later (via a "Change my registration type" link on the registration's show page) any time `league.started?` is false. Once the league has started, the link is hidden and any direct hit to the route redirects with a flash explaining that the league has already started and changes need to go through a commissioner.

The interstitial is presented as a *type-of-registration* decision, not a "can you make it" question. Two cards, one for each type, with explicit copy that frames the one-day option as a first-class registration choice. People choose one-day for many reasons — schedules, wear and tear, anything — and the page does not assume a reason.

## 3. League configuration

### 3.1 New fields on `League`

| Field | Type | Notes |
|---|---|---|
| `game_days` | `Array<String>` | Lowercase day names (`monday`…`sunday`). Optional. Length 0–2. Saved in canonical Mon→Sun order. |
| `price_single_day` | `Integer` | Optional. Used when a player registers as one-day. |
| `price_women_single_day` | `Integer` | Optional. Women's override, parallel to the existing `price_women`. |

Validations:
- Each entry of `game_days` must be one of the seven canonical day names.
- `game_days` length is at most 2.
- Entries in `game_days` are unique.

### 3.2 Helper methods

- `League#requires_day_choice?` — `game_days.length == 2`.
- `League#get_price(gender, single_day: false)` — extends today's signature. Falls back to the regular price if a single-day price isn't configured.

### 3.3 Form

In `app/views/leagues/_form.html.haml`, near the existing Competition Dates / Registration Price block:

- A **Game Days** control: seven checkboxes labeled Mon–Sun, name `league[game_days][]`, with help text `"Select up to 2. Leave all unchecked if the league doesn't run on fixed weekly days."` Light JS disables additional checkboxes once two are checked; the server-side validation is the source of truth.
- Two new price fields, **Single-day Price** and **Women's Single-day Price**, with help text `"Used when a player registers for one day only. Leave blank to charge full price."` Visible only when at least 2 days are checked, but always present in the DOM and validated server-side.

Permitted params on `LeaguesController#league_params`: `game_days: []`, `price_single_day`, `price_women_single_day`.

### 3.4 Editing `game_days` after registrations exist

The form allows changes, but if any `Registration.attending_days` references a day no longer in `game_days`, the league save shows a non-blocking warning listing the affected players. The commissioner is responsible for following up. We do not auto-correct existing registrations. This is a recovery path, not a normal workflow.

## 4. Registration data

### 4.1 New field on `Registration`

| Field | Type | Notes |
|---|---|---|
| `attending_days` | `Array<String>` | Subset of `league.game_days`. Length 1 or 2. `nil` for registrations on leagues that don't `requires_day_choice?`. |

Validation: when `league.requires_day_choice?` is true, `attending_days` must be present, must be a subset of `league.game_days`, and must have length 1 or 2.

The early-flow saves (`PlayerRegistrar#initialize_registration!`, `submit_day_choice`) already use `save(validate: false)` to write placeholder/intermediate state, so they're unaffected. The validation fires the next time the registration is saved through the standard `update` path (the main registration form), at which point `attending_days` must be set.

### 4.2 Helper methods

- `Registration#single_day?` → `attending_days.present? && attending_days.length == 1`
- `Registration#chosen_day` → `attending_days.first` when single-day, else `nil`
- `Registration#registration_type_label` → `"Two-day"` / `"{Day} only"` / `nil` (driven by the league's `requires_day_choice?` and the registration's `attending_days`).
- `Registration#participates_on?(day_name)` — the predicate the attendance system calls. See §7.
- `Registration#day_choice_editable?` — true when `league.started?` is false.

### 4.3 Pricing

`Registration#ensure_price` (existing `before_save` callback) is updated to call `league.get_price(gender, single_day: single_day?)`. The existing callback only assigns `price` when `price` is currently blank, so it works correctly on first registration: `attending_days` is set in the interstitial *before* the form-submit that triggers the first `ensure_price`.

To handle later changes correctly, `submit_day_choice` is responsible for re-pricing when appropriate:

- If the registration's `paid` is false **and** `status` is in `["queued", "registering", "registering_waitlisted"]`: clear `price` (set to `nil`) before the save. `ensure_price` then recomputes from the new `attending_days`.
- Otherwise (registration is `active`, `waitlisted`, or `paid`): leave `price` as-is. **The spec does not auto-charge or auto-refund.** The `attending_days` change persists; the player sees a flash on confirmation reminding them to contact `help@afdc.com` if they expect a price adjustment. The commissioner handles money via the existing refund flow.

## 5. Registration flow & routes

### 5.1 New routes

```
get  '/leagues/:id/choose_days'  → leagues#choose_days
post '/leagues/:id/choose_days'  → leagues#submit_day_choice
```

### 5.2 Controller behavior

`LeaguesController#register` (existing): the day-choice gate fires whenever the action *would* otherwise show the registration edit form. Concretely, the redirect to `choose_days` is inserted in **both** of the existing render-edit paths:

- The early branch where an `existing_registration.is_registering?` is being resumed (today this immediately renders `registrations/edit`).
- The fresh-registration path after `registrar.initialize_registration!`.

The condition in both places is the same:

- `@league.requires_day_choice?` is true
- The (existing or freshly-created) registration's `attending_days.blank?`

When both hold, the action redirects to `choose_days_league_path(@league)` instead of rendering edit. Otherwise the existing behavior runs unchanged.

`LeaguesController#choose_days`:
- Renders the interstitial.
- Pre-selects the current `attending_days` value if present (the change-later path).
- Refuses (redirect with flash) when `@league.started?` is true.
- Refuses when `@league.requires_day_choice?` is false.
- Refuses when there is no in-progress or active registration for the user (no placeholder to update).

`LeaguesController#submit_day_choice`:
- Validates the submitted `attending_days[]` against `league.game_days` (subset, non-empty, length ≤ 2).
- Persists with `save(validate: false)` (matches the early-flow saves elsewhere in the registrar).
- On success: if the registration is still in `registering` / `registering_waitlisted` (i.e., the new-registration flow), redirect to `register_league_path(@league)` — which now skips the interstitial because `attending_days` is set, and falls through to `registrations/edit`. Otherwise (change-later path) redirect to `registration_path(@registration)` with a confirmation flash.

After `league.started?`, both `choose_days` and `submit_day_choice` redirect with a flash: `"This league has already started. Please contact a commissioner if your registration type needs to change."`

### 5.3 Existing routes that don't change

- `register` keeps its existing branching for already-registered, already-active, profile-incomplete, and grank-stale users.
- `registrations#update`, `pay`, `donate`, etc., are unchanged. The interstitial sits cleanly in front of them.

## 6. Interstitial UI

`app/views/leagues/choose_days.html.haml`. Three regions, top to bottom:

### 6.1 Header

- Title: `Choose your registration type`
- Subhead: `{LeagueName} plays on {Day1} and {Day2}. Two registration types are available.`

### 6.2 Two cards

Each card is a clickable label so the entire surface is the click target. A radio input is hidden under the label.

- **Card 1 — Two-day registration**
  - Heading: `Two-day registration`
  - Body: `Drafted as a regular two-night player on {Day1} and {Day2}.`
  - Price line: `${full price for this player's gender}`

- **Card 2 — One-day registration**
  - Heading: `One-day registration`
  - Eyebrow: `Only able to play one night a week?`
  - Body:
    > A one-day registration is its own thing — you're signing up to be a one-night-a-week player, full stop. Captains will know that going into the draft and build their roster accordingly. If you happen to be free for an extra game on the other night, you're welcome to come, but nothing about your team will be counting on it.
  - When chosen, the card reveals two prominent buttons: `{Day1} only` / `{Day2} only`.
  - Price line: `${single-day price}` (or the full price if single-day price isn't configured).

### 6.3 Footer

- **Continue** button. Disabled until the choice is complete (two-day, or one-day with a specific day picked).
- Muted helper text: `You can change this at any point before the draft.`

### 6.4 Behavior notes

- Form posts `attending_days[]` with both league days (two-day) or one of them (one-day).
- Change-later path pre-selects the current value; a Cancel link returns to `registration_path`.
- Server validates membership / length and re-renders on error.
- After `league.started?`, this view isn't reachable.

## 7. Attendance prompt suppression

The attendance dispatch worker (`AttendancePromptWorker`) currently walks each team's roster for upcoming game-days. We add one filter inside that loop, sourced from a single new predicate:

```ruby
roster.each do |player|
  reg = league.registration_for(player)
  next unless reg.present?
  next unless reg.participates_on?(game.day_name)
  enqueue_prompt_for(player, game)
end
```

`Registration#participates_on?(day_name)`:

- Returns `true` if `attending_days` is `nil` or empty — legacy data, leagues without `game_days`, and leagues with only one game day all fall into this bucket and behave as today.
- Returns `true` if `attending_days.include?(day_name.downcase)`.
- Returns `false` otherwise.

`day_name` is the lowercase day-of-week name for the game in `LOCAL_TIMEZONE` — the existing constant the attendance system already uses for date math.

### 7.1 Captain dashboard

The captain attendance dashboard already shows pending / yes / no per player per game-day. Players filtered out by `participates_on?` do **not** silently disappear: they're rendered in a muted, separate row labeled `Single-day registration — not playing this night`. This is the explicit-record affordance — the captain confirms with their own eyes that the player is intentionally absent, not forgotten.

The dashboard reads this via the same `participates_on?` predicate to keep the truth in one place.

### 7.2 Out of scope for attendance

- Pickup-player prompts and ad-hoc make-up prompts follow their own enqueue paths and are not affected.
- Manual captain overrides (mark someone present after the fact) are unchanged — captains can still record actual attendance, even on nights the player wasn't expected.

## 8. Captain & commissioner visibility

For two-day leagues, the chosen registration type surfaces in every player-management context. For zero- or one-day leagues there's nothing to surface and no badge appears.

### 8.1 Per-row presence

Wherever player lists render for management:

- `app/views/leagues/players.html.erb` (the league-manager player list) — add a **Days** column. Values: `{Day1} + {Day2}` for two-day, `{Day} only` for one-day. The one-day case uses a visually distinct pill/badge color so it can't be missed while skimming.
- `app/views/leagues/registrations.html.erb` and the CSV export `registrations.csv.haml` — same column, same labels. CSV gets the literal text values in two extra columns: `attending_days` (raw, comma-joined) and `registration_type` (`two-day` / `one-day`).
- `app/views/leagues/manage_roster.html.haml` (the drafting view) — same per-row badge next to each player's name. This is the most important location — it's where the draft happens and where the brief's "feel comfortable knowing they were drafted with that limitation in mind" goal pays off.
- `reg_list.json` (the AJAX feed for player views) — include `attending_days` and a derived `day_label` so JS-driven views render consistently.

### 8.2 Filter / sort

- On player-management views with existing client-side filtering, add filter chips: `All`, `Two-day`, `{Day1} only`, `{Day2} only`.
- On the drafting view, add at minimum a chip-filter so a captain can isolate "{Day1} only" players in one click.

### 8.3 Commissioner edit

A commissioner can change a player's registration type from the player-management UI (a small editable control on the badge) — this is the recovery path for "the player asked me to change it for them." Same `league.started?` gate applies; after the league starts, the control is read-only.

### 8.4 Player's own view

`app/views/registrations/show.html.haml` shows the chosen registration type in the existing summary block, with a `Change my registration type` link visible while `league.started?` is false.

## 9. Mutability summary

| Subject | When editable |
|---|---|
| `league.game_days` | Always (with non-blocking warning when changes orphan player choices). |
| `league.price_single_day` / `price_women_single_day` | Always. Existing prices already follow this pattern. |
| `registration.attending_days` (player-initiated) | While `league.started?` is false. |
| `registration.attending_days` (commissioner-initiated) | While `league.started?` is false. |

Once the league has started, `attending_days` is frozen for everyone. Edge cases (real-life schedule changes, refund decisions) are handled out-of-band by commissioners through the existing cancel/refund flow.

## 10. Edge cases

- **Pairs:** independent of day choice. No validation, no warning. A two-day player can pair with a one-day player; the day-choice info shows on both registrations and captains see both badges.
- **Comped players:** same flow. Day choice still required; comp logic is orthogonal — single-day comp = single-day, free.
- **Waitlist:** a waitlisted player completes the day-choice interstitial before being moved to `registering_waitlisted`. By the time a registration is in any "registering" state, `attending_days` is set.
- **Pickup registrations:** untouched. Pickup is per-game by design.
- **League with 0 days configured:** identical to today's behavior. No interstitial, no badge, no attendance suppression.
- **League with 1 day configured:** same as 0 days from the player flow's perspective (no choice to make). The single day is informational on the league page only.
- **Commissioner removes a day from `game_days` after registrations:** affected `attending_days` arrays now contain a stray value. The league form warns. Attendance suppression still works (the day simply no longer matches a real game). Commissioner is on the hook for follow-up.

## 11. Migration & rollout

- No data backfill. Existing leagues keep `game_days = []` and existing registrations keep `attending_days = nil`. The new flow is invisible until a commissioner sets `game_days.length == 2` on a future league.
- The `Registration#participates_on?` predicate's "nil/empty → true" behavior is the compatibility shim — every existing registration continues to receive attendance prompts exactly as today.
- No feature flag. The presence of `game_days` on a league *is* the flag.

## 12. Testing notes

- `League` validation specs for `game_days` (length, day-name set, uniqueness).
- `League#requires_day_choice?` and the extended `get_price` signature.
- `Registration` validation specs for `attending_days` against `league.game_days`.
- `Registration#participates_on?` covering the nil/empty/include/exclude cases.
- Controller specs for `choose_days` / `submit_day_choice` covering: the new-registration flow redirect, the change-later flow, the `league.started?` rejection, and validation failure re-render.
- Attendance dispatch spec confirming a one-day player is filtered out for the other day's games and surfaced (muted) on the captain dashboard.
- Pricing spec confirming two-day vs one-day price selection in `ensure_price`, and that post-payment switches do not auto-recompute.
