# Game Attendance — Design

**Status:** approved 2026-05-04
**Author:** Pete Holiday (with Claude)

## 1. Goal & scope

Replace captain-run GroupMe attendance polls with an in-app system that automatically asks players "are you in?" per game-day and surfaces answers to captains and commissioners. Easy enough to need zero captain training. Per-league enable flag for the initial Spring → Summer 2026 rollout; eventually mandatory.

**In scope:** regular league rosters; SMS, email-link, and web channels; per-game-day attendance unit; captain + commissioner dashboards.

**Out of scope (parking lot):** pickup-player reminders, mobile-app push notifications, retroactive ground-truth UI (schema only), historical/seasonal analytics, broadcast messaging from inside Platinum.

## 2. Player journey

Three channels, layered. A given player only ever receives the prompt on one channel per dispatch (we don't double-prompt by SMS *and* email).

- **Primary — SMS.** Any player with a `NotificationMethod` of method `text` that is both `confirmed` and `enabled` gets the prompt by SMS. They reply with a 2-digit code (e.g., `11` = YES) optionally followed by a free-text note.
- **Backup — Email.** Players without a confirmed+enabled text method get an email at `user.email_address` with a tokenized link.
- **Tertiary — Web.** The tokenized link from the email lands on a no-login RSVP page with YES/NO/PARTIAL buttons and a notes field. Suffix-3 SMS replies (`13`) auto-reply with this same link so players can leave more nuanced answers.

Tokenized URLs are single-purpose: they RSVP exactly one (player, game-day) prompt, expire when the game-day is past, and do not authenticate the user into Platinum.

## 3. Cadence & timing

The unit of attendance is **(player, team, game-day)** — a team playing two back-to-back games on Tuesday gets one attendance prompt covering the day. Partial attendance (e.g., "second game only") is captured as a note, not a structured field. This is intentional: trying to model partial attendance as structured data is not worth the UX headache, and we're improving on GroupMe's binary poll.

- **Initial ping:** 4 days before the day's earliest game-time, fired at 9am Eastern (the existing `LOCAL_TIMEZONE` constant).
- **Reminder:** 2 days before, 9am Eastern. Only sent to players who have not yet answered (captain overrides count as answered).
- After the 2-day reminder, the system goes quiet. The captain dashboard surfaces non-responders for last-mile follow-up (in-person, GroupMe, etc. — we are not replacing the captain's last-mile nagging).
- **Make-up / late-added games:** any game-day inside either window that hasn't been prompted yet gets a single immediate ping when the cron next fires.
- An hourly Sidekiq cron handles dispatch.

### Same-day prompt collisions

For a Tue/Thu league, a player who hasn't answered Tuesday will receive (a) a Tuesday-game reminder *and* (b) a Thursday-game initial ping on the same Sunday morning. To avoid sending two SMS messages back-to-back, the dispatch worker batches all prompts going to the same player at the same hour into a single multi-game-day SMS message.

## 4. SMS protocol

**Codes are always 2 digits** in the format `<prefix><suffix>`:

- **Prefix** (`1`, `2`, `3`...) = ordinal of the game-day among this player's currently pending pings *within the current SMS message*. Resets per message.
- **Suffix** (`1`, `2`, `3`) = answer: `1` = YES, `2` = NO, `3` = PARTIAL/notes.

This convention is global (suffix `1` is always YES) which makes parsing a near-arithmetic operation and lets us extend to new answer types later without changing the parser.

### Single-game-day SMS template

> *"Hi Pete! Can you make your **Thursday 5/8** at Walker Park (7pm vs Sharks, 8:15 vs Wolves)? Reply 11 for YES, 12 for NO, 13 for partial/notes."*

### Multi-game-day SMS template

> *"Hi Pete! Two AFDC game days to confirm:*
>
> *(1) **Tue 5/13** 7pm at Walker Park vs Sharks — Reply 11 YES / 12 NO / 13 partial*
>
> *(2) **Thu 5/15** 7pm at Brookhaven vs Wolves — Reply 21 YES / 22 NO / 23 partial"*

### Reply parsing rules (in precedence order)

1. Tokenize the reply on whitespace; locate any 2-digit numeric tokens (`\d{2}`).
2. For each code, split into `(prefix, suffix)`. Look up the most-recent-pending `AttendancePrompt` for `(player, prefix)`. Apply the answer based on suffix.
3. Any text between a code and the next code is captured as the `note` for that prompt.
4. If no codes are found *and* the reply matches a fuzzy YES/NO variant (`y`, `yes`, `yep`, `yeah`, `in`, `coming`, `n`, `no`, `nope`, `out`, `cant`, `can't`) *and* the player has exactly one outstanding prompt, apply to that single prompt.
5. Anything else: save as a note on the most-recent outstanding prompt, status stays `pending`, send an auto-reply with the web link.

### Stale replies

Codes are scoped to the SMS message they were sent in. Stale replies (player answers a code from a 2-day-old message after a fresher message has gone out) resolve naturally: each `AttendancePromptDispatch` records its own prefix→prompt mapping, so the parser picks the prompt referenced in the original message regardless of newer messages. By the next week, the previous game-day has happened and its prompts are no longer pending, so the same code on a future message can't conflict.

## 5. Dashboards

### Captain view (per-team)

- Top of page: this week's upcoming game-days as cards, each showing the date, opponent(s), and headline counts (✅ Yes / ❌ No / ❓ Not Answered).
- Click a card → game-day detail: roster table, one row per player. Columns: name, status badge, note (inline, always visible), response method, override button.
- Manual override: select a player → set status (Yes/No/Partial) → optional note. Stored with `responded_by = captain user id`, `response_method = captain_override`. Visibly tagged in the row.
- **Scope:** at most this week's upcoming game-days. Historical/season views are v2.

### Commissioner / league-admin view (league-wide)

- Single table: rows = teams, columns = upcoming game-days, cells = ✅Y / ❌N / ❓? counts.
- Click a row → captain-style detail view for that team. Read-only by default; full overrides allowed for users with admin permissions.
- This is the **pickup coordination view**: surfaces "Sharks are missing 4 women on Thursday" so commissioners can match pickup-pool offers to teams who need them. They can drill into a team to see *who* is missing — important because a team missing their three best players needs different pickup quality than one missing their three worst.

## 6. Data model

Two new Mongoid documents and one field on `League`.

### `AttendancePrompt`

One per `(player, team, game-day)`.

| Field              | Type                | Notes                                                              |
| ------------------ | ------------------- | ------------------------------------------------------------------ |
| `user`             | belongs_to User     |                                                                    |
| `team`             | belongs_to Team     |                                                                    |
| `league`           | belongs_to League   | Denormalized for query convenience                                 |
| `game_ids`         | Array<BSON::ObjectId> | The day's games covered by this single prompt                    |
| `game_day`         | Date                | Anchor date for scheduling and lookup                              |
| `status`           | String              | `pending`, `yes`, `no`, `partial`                                  |
| `note`             | String              | Free text from player or captain                                   |
| `responded_by`     | belongs_to User     | The acting user (player, captain, or commissioner)                 |
| `response_method`  | String              | `sms`, `email`, `web`, `captain_override`                          |
| `responded_at`     | DateTime            |                                                                    |
| `created_at`       | DateTime            |                                                                    |
| `actually_attended`| Boolean (nullable)  | v2 ground-truth field; included now to avoid migration later       |
| `web_token`        | String              | Single-purpose URL key                                             |

### `AttendancePromptDispatch`

One per outbound SMS or email message. Records the prefix-to-prompt mapping for that specific message so reply parsing can resolve codes back to the right prompt even days later.

| Field                | Type             | Notes                                                       |
| -------------------- | ---------------- | ----------------------------------------------------------- |
| `user`               | belongs_to User  | Recipient                                                   |
| `channel`            | String           | `sms`, `email`                                              |
| `sent_at`            | DateTime         |                                                             |
| `prompts`            | Array<Hash>      | `[{ prompt_id:, prefix: 1 }, ...]`                          |
| `provider_message_id`| String           | Twilio Message SID or email Message-ID for debugging        |
| `kind`               | String           | `initial`, `reminder` (for channel-efficacy analysis)       |

### `League` (existing)

Add one field:

| Field                | Type    | Notes                                                          |
| -------------------- | ------- | -------------------------------------------------------------- |
| `attendance_enabled` | Boolean | Default false. Per-league flag during rollout; will eventually be removed when the feature is mandatory. |

## 7. Architecture & integration

- **Outbound dispatch.** New `AttendancePromptWorker` (Sidekiq), scheduled hourly via the existing `whenever`/`sidekiq-cron` setup. For each league with `attendance_enabled`, finds game-days entering either prompting window (4-day or 2-day) that haven't been prompted yet (or a fresh ping if they crossed the window late). For each player on each affected team, creates the appropriate `AttendancePrompt` record. Then batches per-recipient: all prompts going to the same user in this hour become one `AttendancePromptDispatch`. Dispatch sends SMS via the existing `NotificationMethod#send_text` (SMS-confirmed players) or email via `NotificationMailer.attendance_prompt(...)` (everyone else).
- **Inbound SMS.** New `AttendancePromptsController#sms_webhook` action, registered as the Twilio messaging webhook URL on the AFDC number. Parses `From` (phone) and `Body` (reply). Looks up the `User` via `NotificationMethod`, applies the parsing rules from §4, returns a Twilio TwiML response (text confirmation or follow-up link).
- **Web RSVP.** New `AttendancePromptsController#token_show` and `#token_update` actions for the no-login tokenized flow. Token is on the `AttendancePrompt`.
- **Captain & commissioner views.** Added under existing `teams_controller` (captain detail) and `leagues_controller` (commissioner overview), following existing HAML/Bootstrap 2.3 patterns.
- **Email template.** New `NotificationMailer.attendance_prompt(prompt_id)` action and matching HAML templates (text + HTML).
- **Twilio integration.** Reuses the existing `NotificationMethod#send_text` and `config/initializers/twilio.rb` plumbing — no new SDK setup required. Direct Twilio Ruby SDK only; **no Twilio Studio.** Studio's state model lives in the dashboard outside source control, requires webhooks back into Platinum for any real work, and adds a layer that doesn't earn its keep here.

## 8. Authorization

- Captains can view their own team's attendance and override player statuses on their team.
- Commissioners can view all teams in leagues they manage, and override on any of those teams.
- Admins can view and override anywhere.
- Players have no special "view attendance" permission — they answer their own prompts via SMS, email link, or tokenized URL. (The Platinum logged-in dashboard for a player is out of scope for v1; they don't need a list-all-prompts page.)

These rules slot into the existing `declarative_authorization` setup.

## 9. Error handling and edge cases

- **Twilio outbound failure:** caught and logged via Bugsnag (existing pattern). The `AttendancePromptDispatch` is still created but flagged with no `provider_message_id`; a follow-up can retry. Prompts are still considered sent for cron-scheduling purposes (we don't want infinite retries blowing up the queue).
- **Inbound from unknown phone:** auto-reply *"We don't recognize this number. Visit \[link to AFDC site\] to manage your notification methods."* and discard.
- **Inbound from a player with no pending prompts:** auto-reply *"No active attendance questions right now. Visit \[link\] to manage notifications or see your schedule."*
- **STOP / unsubscribe:** Twilio handles `STOP` keywords automatically at the carrier level. We rely on that for v1.
- **Player on multiple teams:** prompts are scoped to `(player, team, game-day)` so a player on two teams in different leagues simply gets multiple prompts. The prefix system disambiguates within an SMS.
- **Captain override after a player has already responded:** the override wins (most recent wins). The previous answer is overwritten; the prior `responded_by`/`response_method` are not preserved (we accept this for v1 simplicity — adding an audit log is v2 if anyone misses it).
- **Game cancelled / rained out before prompts go out:** the worker filters to game-days that have at least one non-rained-out game when scheduling prompts. A day where every game is already rained out gets no prompt.
- **Game cancelled / rained out** *after* prompts have been sent: no proactive cleanup; the prompt simply becomes irrelevant. The existing `GameCancellationWorker` already handles its own SMS messaging, separate from this system.

## 10. Testing approach

- **Model specs** for `AttendancePrompt` (status transitions, scopes, token generation, response_method recording) and `AttendancePromptDispatch`.
- **Worker spec** for `AttendancePromptWorker` covering: 4-day window, 2-day window, late-added games, batching multiple prompts to same user, skipping already-answered prompts, skipping leagues without `attendance_enabled`, choosing SMS vs email channel.
- **Parser spec** (likely a service object, e.g., `AttendanceReplyParser`) for the rules in §4: codes, fuzzy YES/NO, freeform notes, multi-code replies, notes-after-code, stale-message resolution.
- **Controller specs** for the SMS webhook (Twilio request signature verification, response TwiML) and the tokenized web flow (auth-bypass via valid token, expired tokens, invalid tokens).
- **Integration spec** end-to-end: cron fires → SMS goes out → reply comes in → status updates → captain dashboard reflects it.

## 11. Rollout

Full send, no global feature flag, but `League#attendance_enabled` is a per-league knob during the rollout window. Spring 2026 ends before this work completes; Summer 2026 hasn't started, so no in-flight league is disrupted. The per-league flag is documented as temporary — when summer leagues are stable, the flag is removed and attendance becomes mandatory for all leagues.

**Implementation sequencing.** The build is one cohesive feature, but commits are kept small and reviewable: one logical step per commit (schema → model → worker → templates → outbound dispatch → inbound webhook → parser → web flow → captain view → commissioner view → enable flag), each commit a sane step toward the final product even if not standalone-shippable. Squash-on-merge.

## 12. Open / deferred items

- **Pickup-player reminders.** May want a similar prompt system for the pickup-pool list. Out of scope here; revisit when pickups need it.
- **Retroactive ground-truth UI.** Schema field exists (`actually_attended`); UI for captains to mark "said yes, no-showed" / "said no, came anyway" is v2.
- **Historical / seasonal analytics.** Channel-efficacy analysis ("what % of SMS prompts get answered vs email?"), per-player attendance trends, captain-level reports — all v2.
- **Broadcast messaging from inside Platinum.** Not requested, not building.
- **Per-league prompt-timing override.** Hardcoded 4-day/2-day for v1. Add a knob if any commissioner asks.
- **Mobile app.** Eventually this will be a push notification + structured form. Out of scope; the SMS protocol design is informed by knowing this is coming so we don't overinvest in SMS UX.
