# Game Attendance Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build an in-app attendance system that automatically asks players "are you in?" per game-day via SMS (primary) and email (backup), surfaces answers on captain and commissioner dashboards, and replaces captain-run GroupMe attendance polls.

**Architecture:** New `AttendancePrompt` and `AttendancePromptDispatch` Mongoid documents represent the per-(player, team, game-day) ask and the outbound messages that referenced it. A Sidekiq cron worker (`AttendancePromptWorker`) runs hourly, generates prompts in 4-day and 2-day windows, and dispatches batched SMS/email via two service objects under `lib/afdc/`. Inbound SMS hits a Twilio webhook controller that delegates parsing to `AttendanceReplyParser`. A tokenized web flow on `AttendancePromptsController` lets emailed players RSVP without logging in. New views on `teams_controller#attendance` (captains) and `leagues_controller#attendance_overview` (commissioners) surface the data.

**Tech Stack:** Rails 4.2, Mongoid 4.0, Sidekiq + sidekiq-cron + whenever, Twilio Ruby SDK 5.10, RSpec 4.1 with FactoryGirl, declarative_authorization, HAML, Bootstrap 2.3.

**Source spec:** `docs/superpowers/specs/2026-05-04-game-attendance-design.md`. When a step references "the spec," that's where to look.

**Conventions to honor:**
- Service objects live under `lib/afdc/` (see `PlayerRegistrar`, `PairingCoordinator`).
- Existing tests use the older `.should` syntax (`spec/models/user_spec.rb`). Match it.
- Existing controllers use `before_filter` (Rails 4.2), not `before_action`. Match it.
- HAML files in this repo are indented with **tabs**. Match it.
- All persisted timestamps use `LOCAL_TIMEZONE` (Eastern). Use `Time.now.in_time_zone(LOCAL_TIMEZONE)` and `Date.current` carefully.
- Commit at the end of each task. Small, sane steps.

---

## File Structure

| Path | Status | Responsibility |
|---|---|---|
| `app/models/league.rb` | modify | Add `attendance_enabled` Boolean field |
| `app/models/attendance_prompt.rb` | new | Per-(player, team, game-day) ask record |
| `app/models/attendance_prompt_dispatch.rb` | new | One per outbound SMS/email; holds prefix→prompt mapping |
| `lib/afdc/attendance_reply_parser.rb` | new | Parses inbound SMS body into status updates |
| `lib/afdc/attendance_prompt_dispatcher.rb` | new | Builds + sends the SMS/email; creates Dispatch records |
| `app/workers/attendance_prompt_worker.rb` | new | Hourly cron; finds eligible game-days, creates prompts, calls dispatcher |
| `app/mailers/notification_mailer.rb` | modify | Add `attendance_prompt(dispatch_id)` method |
| `app/views/notification_mailer/attendance_prompt.html.haml` | new | HTML email body |
| `app/views/notification_mailer/attendance_prompt.text.haml` | new | Plain-text email body |
| `app/controllers/attendance_prompts_controller.rb` | new | Twilio webhook + tokenized web flow |
| `app/views/attendance_prompts/show.html.haml` | new | No-login web RSVP page |
| `app/controllers/teams_controller.rb` | modify | Add `attendance` action |
| `app/views/teams/attendance.html.haml` | new | Captain dashboard |
| `app/controllers/leagues_controller.rb` | modify | Add `attendance_overview` action |
| `app/views/leagues/attendance_overview.html.haml` | new | Commissioner overview |
| `app/views/leagues/_form.html.haml` | modify | Add `attendance_enabled` checkbox |
| `config/routes.rb` | modify | Add new routes |
| `config/schedule.rb` | modify | Add hourly attendance cron |
| `config/authorization_rules.rb` | modify | Permission rules for attendance views |
| `spec/factories.rb` | modify | Add factories for League, Team, Game, NotificationMethod, AttendancePrompt, AttendancePromptDispatch |
| `spec/models/attendance_prompt_spec.rb` | new | Model spec |
| `spec/models/attendance_prompt_dispatch_spec.rb` | new | Model spec |
| `spec/lib/afdc/attendance_reply_parser_spec.rb` | new | Parser spec |
| `spec/lib/afdc/attendance_prompt_dispatcher_spec.rb` | new | Dispatcher spec |
| `spec/workers/attendance_prompt_worker_spec.rb` | new | Worker spec |
| `spec/controllers/attendance_prompts_controller_spec.rb` | new | Controller spec |
| `spec/mailers/notification_mailer_attendance_prompt_spec.rb` | new | Mailer spec |
| `spec/integration/attendance_flow_spec.rb` | new | End-to-end |

---

## Task 1: Add `attendance_enabled` flag to League + base factories

**Goal:** Tiny, verifiable schema change. Default `false`. Add factories we'll need throughout.

**Files:**
- Modify: `app/models/league.rb`
- Modify: `spec/factories.rb`
- Test: `spec/models/league_spec.rb` (create if absent)

- [ ] **Step 1: Read the current `League` model** to find a good insertion point near other Boolean fields.

Run: `head -50 app/models/league.rb`

- [ ] **Step 2: Write the failing test** — append to `spec/models/league_spec.rb` (create if missing). Match the `.should` style used in `user_spec.rb`.

```ruby
require 'spec_helper'

describe League do
  it "defaults attendance_enabled to false" do
    league = FactoryGirl.create(:league)
    league.attendance_enabled.should eq(false)
  end

  it "persists attendance_enabled when set" do
    league = FactoryGirl.create(:league, attendance_enabled: true)
    League.find(league._id).attendance_enabled.should eq(true)
  end
end
```

- [ ] **Step 3: Run the test, expect failure** ("undefined method `attendance_enabled`" or factory error).

Run: `bundle exec rspec spec/models/league_spec.rb`
Expected: FAIL.

- [ ] **Step 4: Add the field to `app/models/league.rb`**.

Find the block of `field` declarations (around lines with `field :name`, `field :age_division`, etc.). Add:

```ruby
field :attendance_enabled, type: Boolean, default: false
```

Place it near the other Boolean flags (`track_spirit_scores`, `display_spirit_scores`, etc.).

- [ ] **Step 5: Add `:league` factory to `spec/factories.rb`**.

Append (after the existing `:user` factory):

```ruby
  factory :league do
    name 'Test League'
    age_division 'adult'
    season 'spring'
    sport 'ultimate'
    start_date Date.today
    end_date Date.today + 60
  end
```

- [ ] **Step 6: Run the test again, expect pass**.

Run: `bundle exec rspec spec/models/league_spec.rb`
Expected: PASS, 2 examples, 0 failures.

- [ ] **Step 7: Commit**.

```bash
git add app/models/league.rb spec/factories.rb spec/models/league_spec.rb
git commit -m "Add attendance_enabled flag to League"
```

---

## Task 2: AttendancePrompt model + active_pending scope

**Goal:** The core attendance record. Per (player, team, game-day). Includes the `active_pending` scope on which parser correctness depends (spec §4 / §6).

**Files:**
- Create: `app/models/attendance_prompt.rb`
- Modify: `spec/factories.rb`
- Test: `spec/models/attendance_prompt_spec.rb`

- [ ] **Step 1: Add factories** for `:team`, `:game`, `:notification_method`, `:attendance_prompt` to `spec/factories.rb`.

Append:

```ruby
  factory :team do
    name 'Test Team'
    league
  end

  factory :game do
    game_time { Time.now.in_time_zone(LOCAL_TIMEZONE) + 3.days }
    field 'Field 1'
    league
  end

  factory :notification_method do
    method 'text'
    target { '4045551212' }
    confirmed true
    enabled true
    user
  end

  factory :attendance_prompt do
    user
    team
    league
    game_day { Date.current + 3 }
    status 'pending'
    web_token { SecureRandom.hex(16) }
  end
```

- [ ] **Step 2: Write failing model spec** at `spec/models/attendance_prompt_spec.rb`.

```ruby
require 'spec_helper'

describe AttendancePrompt do
  let(:user)   { FactoryGirl.create(:user) }
  let(:league) { FactoryGirl.create(:league) }
  let(:team)   { FactoryGirl.create(:team, league: league) }

  describe "validations" do
    it "is valid with required fields" do
      ap = FactoryGirl.build(:attendance_prompt, user: user, team: team, league: league)
      ap.should be_valid
    end

    it "requires status to be one of pending/yes/no/partial" do
      ap = FactoryGirl.build(:attendance_prompt, user: user, team: team, league: league, status: 'maybe')
      ap.should_not be_valid
    end

    it "auto-generates a web_token if not set" do
      ap = AttendancePrompt.create!(user: user, team: team, league: league, game_day: Date.current + 2, status: 'pending')
      ap.web_token.should_not be_blank
      ap.web_token.length.should be >= 16
    end
  end

  describe "scopes" do
    it "active_pending includes today and future pending prompts" do
      future = FactoryGirl.create(:attendance_prompt, user: user, team: team, league: league, game_day: Date.current + 1, status: 'pending')
      today  = FactoryGirl.create(:attendance_prompt, user: user, team: team, league: league, game_day: Date.current, status: 'pending')
      AttendancePrompt.active_pending.to_a.should include(future, today)
    end

    it "active_pending excludes past-game-day prompts even if status is pending" do
      past = FactoryGirl.create(:attendance_prompt, user: user, team: team, league: league, game_day: Date.current - 1, status: 'pending')
      AttendancePrompt.active_pending.to_a.should_not include(past)
    end

    it "active_pending excludes resolved prompts even if game_day is future" do
      resolved = FactoryGirl.create(:attendance_prompt, user: user, team: team, league: league, game_day: Date.current + 3, status: 'yes')
      AttendancePrompt.active_pending.to_a.should_not include(resolved)
    end

    it "for_user filters by user" do
      mine  = FactoryGirl.create(:attendance_prompt, user: user, team: team, league: league)
      other = FactoryGirl.create(:attendance_prompt, team: team, league: league)
      AttendancePrompt.for_user(user).to_a.should include(mine)
      AttendancePrompt.for_user(user).to_a.should_not include(other)
    end
  end

  describe "#record_response!" do
    let(:prompt) { FactoryGirl.create(:attendance_prompt, user: user, team: team, league: league) }

    it "sets status, responded_by, response_method, responded_at" do
      prompt.record_response!(status: 'yes', responded_by: user, response_method: 'sms', note: 'lets go')
      prompt.reload
      prompt.status.should eq('yes')
      prompt.responded_by.should eq(user)
      prompt.response_method.should eq('sms')
      prompt.note.should eq('lets go')
      prompt.responded_at.should_not be_nil
    end

    it "rejects invalid statuses" do
      lambda { prompt.record_response!(status: 'banana', responded_by: user, response_method: 'sms') }.should raise_error(ArgumentError)
    end
  end
end
```

- [ ] **Step 3: Run the test, expect failure** (model doesn't exist).

Run: `bundle exec rspec spec/models/attendance_prompt_spec.rb`
Expected: FAIL with "uninitialized constant AttendancePrompt".

- [ ] **Step 4: Create `app/models/attendance_prompt.rb`**.

```ruby
class AttendancePrompt
  include Mongoid::Document
  include Mongoid::Timestamps

  STATUSES = %w(pending yes no partial).freeze
  RESPONSE_METHODS = %w(sms email web captain_override).freeze

  field :game_ids, type: Array, default: []
  field :game_day, type: Date
  field :status, type: String, default: 'pending'
  field :note, type: String
  field :response_method, type: String
  field :responded_at, type: DateTime
  field :actually_attended, type: Boolean
  field :web_token, type: String

  belongs_to :user
  belongs_to :team
  belongs_to :league
  belongs_to :responded_by, class_name: 'User', inverse_of: nil, optional: true

  validates :status, inclusion: { in: STATUSES }
  validates :response_method, inclusion: { in: RESPONSE_METHODS, allow_nil: true }
  validates :user, :team, :league, :game_day, presence: true

  before_validation :ensure_web_token

  scope :active_pending, -> { where(status: 'pending', :game_day.gte => Date.current) }
  scope :for_user,       ->(u) { where(user_id: u._id) }
  scope :for_team,       ->(t) { where(team_id: t._id) }
  scope :for_game_day,   ->(d) { where(game_day: d) }

  def record_response!(status:, responded_by:, response_method:, note: nil)
    raise ArgumentError, "invalid status #{status}" unless STATUSES.include?(status)
    raise ArgumentError, "invalid response_method #{response_method}" unless RESPONSE_METHODS.include?(response_method)

    self.status = status
    self.responded_by = responded_by
    self.response_method = response_method
    self.note = note if note
    self.responded_at = Time.now.in_time_zone(LOCAL_TIMEZONE)
    save!
  end

  private

  def ensure_web_token
    self.web_token ||= SecureRandom.hex(16)
  end
end
```

- [ ] **Step 5: Run the test, expect pass**.

Run: `bundle exec rspec spec/models/attendance_prompt_spec.rb`
Expected: PASS, all examples green. If `:game_day.gte` syntax fails (Mongoid version), use the hash form: `where(status: 'pending').where(:game_day.gte => Date.current)` is fine — just verify.

- [ ] **Step 6: Commit**.

```bash
git add app/models/attendance_prompt.rb spec/models/attendance_prompt_spec.rb spec/factories.rb
git commit -m "Add AttendancePrompt model with active_pending scope"
```

---

## Task 3: AttendancePromptDispatch model

**Goal:** The outbound-message record. One per SMS or email send. Holds the prefix→prompt mapping needed by the parser (spec §4 / §6).

**Files:**
- Create: `app/models/attendance_prompt_dispatch.rb`
- Modify: `spec/factories.rb`
- Test: `spec/models/attendance_prompt_dispatch_spec.rb`

- [ ] **Step 1: Append a factory** to `spec/factories.rb`:

```ruby
  factory :attendance_prompt_dispatch do
    user
    channel 'sms'
    sent_at { Time.now }
    kind 'initial'
    prompts { [] }
  end
```

- [ ] **Step 2: Write failing spec** at `spec/models/attendance_prompt_dispatch_spec.rb`:

```ruby
require 'spec_helper'

describe AttendancePromptDispatch do
  let(:user)   { FactoryGirl.create(:user) }
  let(:league) { FactoryGirl.create(:league) }
  let(:team)   { FactoryGirl.create(:team, league: league) }
  let(:p1)     { FactoryGirl.create(:attendance_prompt, user: user, team: team, league: league) }
  let(:p2)     { FactoryGirl.create(:attendance_prompt, user: user, team: team, league: league, game_day: Date.current + 5) }

  describe "validations" do
    it "requires channel to be sms or email" do
      d = FactoryGirl.build(:attendance_prompt_dispatch, channel: 'pigeon')
      d.should_not be_valid
    end

    it "requires kind to be initial or reminder" do
      d = FactoryGirl.build(:attendance_prompt_dispatch, kind: 'whenever')
      d.should_not be_valid
    end
  end

  describe "#prompt_for_prefix" do
    it "returns the prompt with the matching prefix" do
      d = AttendancePromptDispatch.create!(
        user: user, channel: 'sms', sent_at: Time.now, kind: 'initial',
        prompts: [{ 'prompt_id' => p1._id.to_s, 'prefix' => 1 }, { 'prompt_id' => p2._id.to_s, 'prefix' => 2 }]
      )
      d.prompt_for_prefix(1).should eq(p1)
      d.prompt_for_prefix(2).should eq(p2)
      d.prompt_for_prefix(3).should be_nil
    end
  end

  describe ".latest_active_for_user" do
    it "returns the most recent SMS dispatch with at least one active-pending prompt" do
      old_d = AttendancePromptDispatch.create!(user: user, channel: 'sms', sent_at: 2.days.ago, kind: 'initial',
                                               prompts: [{ 'prompt_id' => p1._id.to_s, 'prefix' => 1 }])
      new_d = AttendancePromptDispatch.create!(user: user, channel: 'sms', sent_at: 1.hour.ago, kind: 'reminder',
                                               prompts: [{ 'prompt_id' => p2._id.to_s, 'prefix' => 1 }])
      AttendancePromptDispatch.latest_active_for_user(user).should eq(new_d)
    end

    it "skips dispatches whose prompts are all resolved or past" do
      p1.record_response!(status: 'yes', responded_by: user, response_method: 'sms')
      stale = AttendancePromptDispatch.create!(user: user, channel: 'sms', sent_at: 1.hour.ago, kind: 'initial',
                                               prompts: [{ 'prompt_id' => p1._id.to_s, 'prefix' => 1 }])
      AttendancePromptDispatch.latest_active_for_user(user).should be_nil
    end

    it "ignores email dispatches" do
      email_d = AttendancePromptDispatch.create!(user: user, channel: 'email', sent_at: 1.hour.ago, kind: 'initial',
                                                 prompts: [{ 'prompt_id' => p1._id.to_s, 'prefix' => 1 }])
      AttendancePromptDispatch.latest_active_for_user(user).should be_nil
    end
  end
end
```

- [ ] **Step 3: Run, expect failure**.

Run: `bundle exec rspec spec/models/attendance_prompt_dispatch_spec.rb`
Expected: FAIL with "uninitialized constant AttendancePromptDispatch".

- [ ] **Step 4: Create `app/models/attendance_prompt_dispatch.rb`**.

```ruby
class AttendancePromptDispatch
  include Mongoid::Document
  include Mongoid::Timestamps

  CHANNELS = %w(sms email).freeze
  KINDS    = %w(initial reminder).freeze

  field :channel, type: String
  field :sent_at, type: DateTime
  field :prompts, type: Array, default: []  # [{ 'prompt_id' => '...', 'prefix' => 1 }, ...]
  field :provider_message_id, type: String
  field :kind, type: String
  field :target, type: String  # phone or email actually used

  belongs_to :user

  validates :channel, inclusion: { in: CHANNELS }
  validates :kind,    inclusion: { in: KINDS }
  validates :user, :sent_at, presence: true

  def prompt_for_prefix(prefix)
    prefix = prefix.to_i
    entry = prompts.detect { |p| p['prefix'].to_i == prefix }
    return nil unless entry
    AttendancePrompt.where(_id: entry['prompt_id']).first
  end

  def active_pending_prompts
    ids = prompts.map { |p| p['prompt_id'] }
    return [] if ids.empty?
    AttendancePrompt.active_pending.where(:_id.in => ids).to_a
  end

  def self.latest_active_for_user(user, channel: 'sms')
    where(user_id: user._id, channel: channel).order_by(sent_at: :desc).each do |dispatch|
      return dispatch if dispatch.active_pending_prompts.any?
    end
    nil
  end
end
```

- [ ] **Step 5: Run, expect pass**.

Run: `bundle exec rspec spec/models/attendance_prompt_dispatch_spec.rb`
Expected: PASS.

- [ ] **Step 6: Commit**.

```bash
git add app/models/attendance_prompt_dispatch.rb spec/models/attendance_prompt_dispatch_spec.rb spec/factories.rb
git commit -m "Add AttendancePromptDispatch with prefix lookup helpers"
```

---

## Task 4: AttendanceReplyParser — single code, fuzzy YES/NO

**Goal:** First slice of the parser. Handles single-code replies and fuzzy YES/NO when there's exactly one active-pending prompt. Spec §4 rules 1-6.

**Files:**
- Create: `lib/afdc/attendance_reply_parser.rb`
- Test: `spec/lib/afdc/attendance_reply_parser_spec.rb`
- Modify: `config/application.rb` if `lib/` autoload isn't already enabled — check first.

- [ ] **Step 1: Confirm `lib/` autoload behavior**. Run:

`grep -n "lib" config/application.rb`

If `lib` is not in `config.autoload_paths`, you'll need to require explicitly in the parser file (`require_dependency` or top-of-file require) — match what `lib/afdc/player_registrar.rb` does. Do whatever is necessary so that `Afdc::AttendanceReplyParser` (or unnamespaced — match the existing convention) loads.

- [ ] **Step 2: Inspect existing service convention**. Run:

`head -20 lib/afdc/player_registrar.rb`

Note the namespacing (likely `module Afdc` or unnamespaced under the `Afdc` module — match it). The rest of this plan assumes `Afdc::AttendanceReplyParser`. Adjust if the local convention differs.

- [ ] **Step 3: Write failing parser spec** at `spec/lib/afdc/attendance_reply_parser_spec.rb`:

```ruby
require 'spec_helper'

describe Afdc::AttendanceReplyParser do
  let(:user)   { FactoryGirl.create(:user) }
  let(:league) { FactoryGirl.create(:league) }
  let(:team)   { FactoryGirl.create(:team, league: league) }

  def make_dispatch(user:, prompts:)
    AttendancePromptDispatch.create!(
      user: user, channel: 'sms', sent_at: Time.now, kind: 'initial',
      prompts: prompts.each_with_index.map { |p, i| { 'prompt_id' => p._id.to_s, 'prefix' => i + 1 } }
    )
  end

  describe "single-code single-prompt" do
    let!(:prompt) { FactoryGirl.create(:attendance_prompt, user: user, team: team, league: league) }
    before { make_dispatch(user: user, prompts: [prompt]) }

    it "parses '11' as YES" do
      Afdc::AttendanceReplyParser.parse(user: user, body: "11")
      prompt.reload
      prompt.status.should eq('yes')
      prompt.response_method.should eq('sms')
    end

    it "parses '12' as NO" do
      Afdc::AttendanceReplyParser.parse(user: user, body: "12")
      prompt.reload.status.should eq('no')
    end

    it "parses '13' as PARTIAL" do
      Afdc::AttendanceReplyParser.parse(user: user, body: "13")
      prompt.reload.status.should eq('partial')
    end

    it "captures a note after the code" do
      Afdc::AttendanceReplyParser.parse(user: user, body: "11 LETS GO")
      prompt.reload
      prompt.status.should eq('yes')
      prompt.note.should eq('LETS GO')
    end
  end

  describe "fuzzy YES/NO with single pending" do
    let!(:prompt) { FactoryGirl.create(:attendance_prompt, user: user, team: team, league: league) }
    before { make_dispatch(user: user, prompts: [prompt]) }

    %w(yes y yep yeah in coming YES Yes).each do |body|
      it "treats #{body.inspect} as YES" do
        Afdc::AttendanceReplyParser.parse(user: user, body: body)
        prompt.reload.status.should eq('yes')
      end
    end

    %w(no n nope out cant can't NO).each do |body|
      it "treats #{body.inspect} as NO" do
        Afdc::AttendanceReplyParser.parse(user: user, body: body)
        prompt.reload.status.should eq('no')
      end
    end
  end

  describe "no anchor dispatch" do
    it "returns a no_pending result without raising" do
      result = Afdc::AttendanceReplyParser.parse(user: user, body: "11")
      result.kind.should eq(:no_pending)
    end
  end

  describe "freeform without recognizable intent" do
    let!(:prompt) { FactoryGirl.create(:attendance_prompt, user: user, team: team, league: league) }
    before { make_dispatch(user: user, prompts: [prompt]) }

    it "captures the full body as a note and leaves status pending" do
      Afdc::AttendanceReplyParser.parse(user: user, body: "depends on weather")
      prompt.reload
      prompt.status.should eq('pending')
      prompt.note.should eq('depends on weather')
    end

    it "returns kind :note_only" do
      result = Afdc::AttendanceReplyParser.parse(user: user, body: "??")
      result.kind.should eq(:note_only)
    end
  end
end
```

- [ ] **Step 4: Run, expect failure** (constant not defined).

Run: `bundle exec rspec spec/lib/afdc/attendance_reply_parser_spec.rb`
Expected: FAIL.

- [ ] **Step 5: Implement `lib/afdc/attendance_reply_parser.rb`**.

```ruby
module Afdc
  class AttendanceReplyParser
    SUFFIX_TO_STATUS = { 1 => 'yes', 2 => 'no', 3 => 'partial' }.freeze
    FUZZY_YES = %w(yes y yep yeah in coming).freeze
    FUZZY_NO  = %w(no n nope out cant can't).freeze

    Result = Struct.new(:kind, :resolved_prompts, :note_only_prompt, keyword_init: true)

    def self.parse(user:, body:)
      new(user: user, body: body.to_s.strip).parse
    end

    def initialize(user:, body:)
      @user = user
      @body = body
    end

    def parse
      anchor = AttendancePromptDispatch.latest_active_for_user(@user, channel: 'sms')
      return Result.new(kind: :no_pending, resolved_prompts: [], note_only_prompt: nil) unless anchor

      codes = extract_codes(@body)

      if codes.any?
        return resolve_codes(anchor, codes)
      end

      fuzzy = fuzzy_status(@body)
      pending = anchor.active_pending_prompts
      if fuzzy && pending.size == 1
        prompt = pending.first
        prompt.record_response!(status: fuzzy, responded_by: @user, response_method: 'sms')
        return Result.new(kind: :resolved, resolved_prompts: [prompt], note_only_prompt: nil)
      end

      # Freeform / ambiguous: save as a note on most recent active-pending in this dispatch
      target = pending.sort_by(&:created_at).last
      if target
        target.update_attributes!(note: @body)
        return Result.new(kind: :note_only, resolved_prompts: [], note_only_prompt: target)
      end

      Result.new(kind: :no_pending, resolved_prompts: [], note_only_prompt: nil)
    end

    private

    # Returns ordered array of [{ code: "11", prefix: 1, suffix: 1, note: "..." }, ...]
    def extract_codes(body)
      tokens = body.scan(/\d{2}|\S+/)  # 2-digit codes OR any non-space chunk; we'll re-scan order
      result = []
      i = 0
      while i < tokens.size
        if tokens[i] =~ /\A(\d)(\d)\z/
          prefix = $1.to_i
          suffix = $2.to_i
          note_parts = []
          j = i + 1
          while j < tokens.size && tokens[j] !~ /\A\d{2}\z/
            note_parts << tokens[j]
            j += 1
          end
          result << { code: tokens[i], prefix: prefix, suffix: suffix, note: note_parts.join(' ').presence }
          i = j
        else
          i += 1
        end
      end
      result
    end

    def resolve_codes(anchor, codes)
      resolved = []
      codes.each do |c|
        next unless SUFFIX_TO_STATUS.key?(c[:suffix])
        prompt = anchor.prompt_for_prefix(c[:prefix])
        next unless prompt
        next unless AttendancePrompt.active_pending.where(_id: prompt._id).exists?
        prompt.record_response!(
          status: SUFFIX_TO_STATUS[c[:suffix]],
          responded_by: @user,
          response_method: 'sms',
          note: c[:note]
        )
        resolved << prompt
      end
      Result.new(kind: resolved.any? ? :resolved : :unresolved_codes, resolved_prompts: resolved, note_only_prompt: nil)
    end

    def fuzzy_status(body)
      stripped = body.downcase.gsub(/[!.?,]/, '').strip
      return 'yes' if FUZZY_YES.include?(stripped)
      return 'no'  if FUZZY_NO.include?(stripped)
      nil
    end
  end
end
```

- [ ] **Step 6: Run, expect pass**.

Run: `bundle exec rspec spec/lib/afdc/attendance_reply_parser_spec.rb`
Expected: PASS, all examples green. Watch for the `keyword_init` Struct flag — it requires Ruby 2.5+. The Rails 4.2 app may run an older Ruby; if so, replace with positional Struct: `Struct.new(:kind, :resolved_prompts, :note_only_prompt) do ... end` and adjust callers.

- [ ] **Step 7: Commit**.

```bash
git add lib/afdc/attendance_reply_parser.rb spec/lib/afdc/attendance_reply_parser_spec.rb
git commit -m "Add AttendanceReplyParser for single-code and fuzzy replies"
```

---

## Task 5: AttendanceReplyParser — multi-code, stale codes, multi-note

**Goal:** Cover the multi-prompt cases. Add tests; the implementation from Task 4 should already handle most of this, but verify and patch.

**Files:**
- Modify: `lib/afdc/attendance_reply_parser.rb` (only if needed)
- Modify: `spec/lib/afdc/attendance_reply_parser_spec.rb`

- [ ] **Step 1: Add multi-code tests** to `spec/lib/afdc/attendance_reply_parser_spec.rb`:

```ruby
  describe "multi-code multi-prompt" do
    let(:user)   { FactoryGirl.create(:user) }
    let(:league) { FactoryGirl.create(:league) }
    let(:team)   { FactoryGirl.create(:team, league: league) }
    let!(:p1) { FactoryGirl.create(:attendance_prompt, user: user, team: team, league: league, game_day: Date.current + 2) }
    let!(:p2) { FactoryGirl.create(:attendance_prompt, user: user, team: team, league: league, game_day: Date.current + 4) }
    before do
      AttendancePromptDispatch.create!(
        user: user, channel: 'sms', sent_at: Time.now, kind: 'initial',
        prompts: [{ 'prompt_id' => p1._id.to_s, 'prefix' => 1 }, { 'prompt_id' => p2._id.to_s, 'prefix' => 2 }]
      )
    end

    it "applies both codes" do
      Afdc::AttendanceReplyParser.parse(user: user, body: "11 22")
      p1.reload.status.should eq('yes')
      p2.reload.status.should eq('no')
    end

    it "applies notes between codes to their preceding prompt" do
      Afdc::AttendanceReplyParser.parse(user: user, body: "11 sounds good 22 cant make it")
      p1.reload
      p2.reload
      p1.status.should eq('yes')
      p1.note.should eq('sounds good')
      p2.status.should eq('no')
      p2.note.should eq('cant make it')
    end

    it "ignores codes that don't resolve" do
      Afdc::AttendanceReplyParser.parse(user: user, body: "11 99")
      p1.reload.status.should eq('yes')
      p2.reload.status.should eq('pending')
    end

    it "ignores codes whose suffix isn't 1/2/3" do
      Afdc::AttendanceReplyParser.parse(user: user, body: "14")
      p1.reload.status.should eq('pending')
    end
  end

  describe "stale code resolution" do
    let(:user)   { FactoryGirl.create(:user) }
    let(:league) { FactoryGirl.create(:league) }
    let(:team)   { FactoryGirl.create(:team, league: league) }

    it "resolves to the most recent dispatch's mapping when a newer dispatch exists" do
      old_p = FactoryGirl.create(:attendance_prompt, user: user, team: team, league: league, game_day: Date.current + 1)
      new_p = FactoryGirl.create(:attendance_prompt, user: user, team: team, league: league, game_day: Date.current + 5)
      AttendancePromptDispatch.create!(user: user, channel: 'sms', sent_at: 2.days.ago, kind: 'initial',
                                       prompts: [{ 'prompt_id' => old_p._id.to_s, 'prefix' => 1 }])
      AttendancePromptDispatch.create!(user: user, channel: 'sms', sent_at: 1.hour.ago, kind: 'initial',
                                       prompts: [{ 'prompt_id' => new_p._id.to_s, 'prefix' => 1 }])

      Afdc::AttendanceReplyParser.parse(user: user, body: "11")
      new_p.reload.status.should eq('yes')
      old_p.reload.status.should eq('pending')
    end
  end
```

- [ ] **Step 2: Run the spec — most should pass already**. Patch the parser if any fails. Likely failure: `extract_codes` token splitting may not preserve order correctly for "11 sounds good 22". Test it.

Run: `bundle exec rspec spec/lib/afdc/attendance_reply_parser_spec.rb`
Expected: most pass. If the multi-note test fails, the issue is likely in `extract_codes` — check that it walks tokens in order and accumulates non-code tokens as the previous code's note.

- [ ] **Step 3: Patch as needed; rerun until green.**

- [ ] **Step 4: Commit**.

```bash
git add lib/afdc/attendance_reply_parser.rb spec/lib/afdc/attendance_reply_parser_spec.rb
git commit -m "Cover multi-code, multi-note, and stale-dispatch cases in parser"
```

---

## Task 6: AttendancePromptDispatcher service

**Goal:** Builds the SMS body (single vs multi-game-day templates), resolves recipients per the channel rules in spec §2, and persists `AttendancePromptDispatch` records. Sending the actual SMS uses `NotificationMethod#send_text`.

**Files:**
- Create: `lib/afdc/attendance_prompt_dispatcher.rb`
- Test: `spec/lib/afdc/attendance_prompt_dispatcher_spec.rb`

- [ ] **Step 1: Write failing dispatcher spec** at `spec/lib/afdc/attendance_prompt_dispatcher_spec.rb`:

```ruby
require 'spec_helper'

describe Afdc::AttendancePromptDispatcher do
  let(:user)    { FactoryGirl.create(:user) }
  let(:league)  { FactoryGirl.create(:league) }
  let(:team)    { FactoryGirl.create(:team, league: league) }
  let!(:sms_nm) { FactoryGirl.create(:notification_method, user: user, method: 'text', target: '4045551111', confirmed: true, enabled: true) }
  let(:p1)      { FactoryGirl.create(:attendance_prompt, user: user, team: team, league: league, game_day: Date.current + 4, game_ids: [BSON::ObjectId.new]) }

  before do
    # Stub send_text on every NotificationMethod globally to avoid hitting Twilio.
    NotificationMethod.any_instance.stub(:send_text).and_return(true)
  end

  describe "channel selection" do
    it "selects SMS when user has confirmed+enabled text method" do
      dispatcher = Afdc::AttendancePromptDispatcher.new(user: user, prompts: [p1], kind: 'initial')
      dispatcher.dispatch!
      AttendancePromptDispatch.where(user_id: user._id).first.channel.should eq('sms')
    end

    it "creates one Dispatch per SMS target" do
      FactoryGirl.create(:notification_method, user: user, method: 'text', target: '4045552222', confirmed: true, enabled: true)
      dispatcher = Afdc::AttendancePromptDispatcher.new(user: user, prompts: [p1], kind: 'initial')
      dispatcher.dispatch!
      AttendancePromptDispatch.where(user_id: user._id).count.should eq(2)
    end

    it "selects email when no SMS target available" do
      sms_nm.update_attributes!(enabled: false)
      dispatcher = Afdc::AttendancePromptDispatcher.new(user: user, prompts: [p1], kind: 'initial')
      mock_mail = double('mail', deliver: true)
      NotificationMailer.should_receive(:attendance_prompt).and_return(mock_mail)
      dispatcher.dispatch!
      AttendancePromptDispatch.where(user_id: user._id, channel: 'email').count.should eq(1)
    end

    it "skips email when user has email NMs but all disabled (opt-out)" do
      sms_nm.update_attributes!(enabled: false)
      FactoryGirl.create(:notification_method, user: user, method: 'email', target: 'optout@example.com', confirmed: true, enabled: false)
      dispatcher = Afdc::AttendancePromptDispatcher.new(user: user, prompts: [p1], kind: 'initial')
      NotificationMailer.should_not_receive(:attendance_prompt)
      dispatcher.dispatch!
      AttendancePromptDispatch.where(user_id: user._id).count.should eq(0)
    end

    it "falls back to user.email_address when no email NMs exist" do
      sms_nm.destroy
      dispatcher = Afdc::AttendancePromptDispatcher.new(user: user, prompts: [p1], kind: 'initial')
      mock_mail = double('mail', deliver: true)
      NotificationMailer.should_receive(:attendance_prompt).and_return(mock_mail)
      dispatcher.dispatch!
      d = AttendancePromptDispatch.where(user_id: user._id, channel: 'email').first
      d.target.should eq(user.email_address)
    end
  end

  describe "SMS body" do
    it "produces the single-game-day template when only one prompt" do
      body = Afdc::AttendancePromptDispatcher.new(user: user, prompts: [p1], kind: 'initial').sms_body
      body.should match(/Reply 11 for YES/i)
      body.should_not match(/^.{0,200}21 YES/m)
    end

    it "produces the multi-game-day template when 2+ prompts" do
      p2 = FactoryGirl.create(:attendance_prompt, user: user, team: team, league: league, game_day: Date.current + 6)
      body = Afdc::AttendancePromptDispatcher.new(user: user, prompts: [p1, p2], kind: 'initial').sms_body
      body.should match(/11 YES/)
      body.should match(/21 YES/)
    end
  end

  describe "Dispatch persistence" do
    it "stores prompt-id/prefix mapping in order" do
      p2 = FactoryGirl.create(:attendance_prompt, user: user, team: team, league: league, game_day: Date.current + 6)
      Afdc::AttendancePromptDispatcher.new(user: user, prompts: [p1, p2], kind: 'initial').dispatch!
      d = AttendancePromptDispatch.where(user_id: user._id).first
      d.prompts.size.should eq(2)
      d.prompts[0]['prefix'].should eq(1)
      d.prompts[0]['prompt_id'].should eq(p1._id.to_s)
      d.prompts[1]['prefix'].should eq(2)
    end
  end
end
```

- [ ] **Step 2: Run, expect failure**.

Run: `bundle exec rspec spec/lib/afdc/attendance_prompt_dispatcher_spec.rb`
Expected: FAIL.

- [ ] **Step 3: Implement `lib/afdc/attendance_prompt_dispatcher.rb`**.

```ruby
module Afdc
  class AttendancePromptDispatcher
    def initialize(user:, prompts:, kind:)
      raise ArgumentError, "kind must be initial or reminder" unless %w(initial reminder).include?(kind)
      @user = user
      @prompts = prompts.sort_by(&:game_day)  # earlier game-day = lower prefix
      @kind = kind
    end

    def dispatch!
      sms_targets = confirmed_sms_targets
      if sms_targets.any?
        sms_targets.each { |nm| send_sms_via(nm) }
        return
      end

      email_target = resolve_email_target
      send_email_to(email_target) if email_target
    end

    def sms_body
      header = "Hi #{@user.firstname}!"
      if @prompts.size == 1
        "#{header} #{single_line(@prompts.first, 1)} Reply 11 for YES, 12 for NO, 13 for partial/notes."
      else
        lines = @prompts.each_with_index.map { |p, i| "(#{i + 1}) #{single_line(p, i + 1)}" }
        "#{header} #{@prompts.size} AFDC game days to confirm: " + lines.join(' ')
      end
    end

    private

    def single_line(prompt, index)
      games = Game.where(:_id.in => prompt.game_ids).to_a.sort_by(&:game_time)
      day = prompt.game_day.strftime('%a %-m/%-d')
      first = games.first
      time = first ? first.game_time.strftime('%-l%P').sub('m', '') : ''
      site = first && first.field_site ? first.field_site.name : ''
      opp_team = first ? first.opponent_for(prompt.team) : nil
      opp = opp_team ? opp_team.name : ''
      base = "#{day} #{time} at #{site} vs #{opp}"
      if @prompts.size > 1
        "#{base} — Reply #{index}1 YES / #{index}2 NO / #{index}3 partial."
      else
        base
      end
    end

    def confirmed_sms_targets
      @user.notification_methods.where(method: 'text', confirmed: true, enabled: true).to_a
    end

    def confirmed_email_targets
      @user.notification_methods.where(method: 'email', confirmed: true, enabled: true).to_a
    end

    def all_email_methods
      @user.notification_methods.where(method: 'email').to_a
    end

    def resolve_email_target
      cems = confirmed_email_targets
      return cems if cems.any?
      return :opt_out if all_email_methods.any?  # signals "skip"
      [@user.email_address]  # default fallback
    end

    def send_sms_via(notification_method)
      dispatch = AttendancePromptDispatch.create!(
        user: @user, channel: 'sms', sent_at: Time.now,
        kind: @kind, target: notification_method.target,
        prompts: prompts_payload
      )
      notification_method.send_text(sms_body)
      dispatch
    rescue StandardError => e
      Rails.logger.error("AttendancePromptDispatcher SMS failure for user #{@user._id}: #{e.message}")
      Bugsnag.notify(e) if defined?(Bugsnag)
      nil
    end

    def send_email_to(targets)
      return if targets == :opt_out
      Array(targets).each do |email|
        dispatch = AttendancePromptDispatch.create!(
          user: @user, channel: 'email', sent_at: Time.now,
          kind: @kind, target: email,
          prompts: prompts_payload
        )
        NotificationMailer.attendance_prompt(dispatch._id.to_s).deliver
      end
    rescue StandardError => e
      Rails.logger.error("AttendancePromptDispatcher email failure for user #{@user._id}: #{e.message}")
      Bugsnag.notify(e) if defined?(Bugsnag)
    end

    def prompts_payload
      @prompts.each_with_index.map { |p, i| { 'prompt_id' => p._id.to_s, 'prefix' => i + 1 } }
    end
  end
end
```

- [ ] **Step 4: Run, expect pass**.

Run: `bundle exec rspec spec/lib/afdc/attendance_prompt_dispatcher_spec.rb`
Expected: PASS. If the SMS-body specs fail because `prompt.game_ids` is empty in the factory, the body falls through to "" for time/site/opp — that's fine for the tests as written; they only check the "Reply 11" / "Reply 21" suffix.

- [ ] **Step 5: Commit**.

```bash
git add lib/afdc/attendance_prompt_dispatcher.rb spec/lib/afdc/attendance_prompt_dispatcher_spec.rb
git commit -m "Add AttendancePromptDispatcher for SMS/email send + body templating"
```

---

## Task 7: AttendancePromptWorker

**Goal:** Hourly cron. For each league with `attendance_enabled`, finds game-days hitting the 4-day or 2-day windows, creates `AttendancePrompt` records for each (player, team, game-day), batches per-user, and calls the dispatcher.

**Files:**
- Create: `app/workers/attendance_prompt_worker.rb`
- Test: `spec/workers/attendance_prompt_worker_spec.rb`

**Algorithm reminder (from spec §3 / §7):**

- For each `attendance_enabled` league: find games whose `game_time` falls inside any window relative to "now in Eastern":
  - Initial window: today + 4 days (specifically: any game-day where today_eastern == game_day - 4 days)
  - Reminder window: today + 2 days (game_day - 2 days == today_eastern)
- For each such game-day-and-team pair, find players still needing a prompt:
  - For initial: any player on the team without an `AttendancePrompt` for that game-day.
  - For reminder: any player on the team with an `AttendancePrompt` for that game-day in `pending` status, AND no SMS/email dispatch exists yet for that prompt with `kind = 'reminder'`.
- For initial: create the `AttendancePrompt` if missing; gather alongside any other initial prompts for the same user this hour; dispatch.
- For reminder: gather pending prompts; dispatch with `kind = 'reminder'`.
- Skip game-days where every game is rained out (no scores `rainout: true` on **all** games for the day) — see spec §9.
- Skip prompts for users with no notification methods at all (no SMS, no email, AND no `user.email_address`) — log and continue.
- The worker is intended to run every hour; idempotency comes from "have we already prompted/reminded this user for this game-day?" checks.

- [ ] **Step 1: Write failing worker spec** at `spec/workers/attendance_prompt_worker_spec.rb`. Tests cover: initial prompt creation, skip when too early, reminder for unanswered, skip reminder for answered, skip rainouts, skip leagues without flag, batching same-user prompts, idempotency.

```ruby
require 'spec_helper'

describe AttendancePromptWorker do
  let(:user1)   { FactoryGirl.create(:user) }
  let(:user2)   { FactoryGirl.create(:user) }
  let(:league)  { FactoryGirl.create(:league, attendance_enabled: true) }
  let(:team)    { FactoryGirl.create(:team, league: league) }

  before do
    # Make user1 and user2 part of the team
    team.players = [user1._id, user2._id]
    team.save!
    FactoryGirl.create(:notification_method, user: user1)
    FactoryGirl.create(:notification_method, user: user2, target: '4045552222')
    NotificationMethod.any_instance.stub(:send_text).and_return(true)
  end

  def make_game(game_day, time = '7:00pm', league_arg = league)
    Game.create!(
      league: league_arg,
      game_time: Time.zone.parse("#{game_day} #{time}"),
      teams: [team._id]
    )
  end

  describe "initial window (4 days out)" do
    it "creates AttendancePrompt records for each team player" do
      future_day = (Date.current + 4)
      make_game(future_day)
      AttendancePromptWorker.new.perform
      AttendancePrompt.where(team_id: team._id, game_day: future_day).count.should eq(2)
    end

    it "does nothing for game-days outside the window" do
      make_game(Date.current + 6)
      AttendancePromptWorker.new.perform
      AttendancePrompt.count.should eq(0)
    end

    it "skips leagues without attendance_enabled" do
      league.update_attributes!(attendance_enabled: false)
      make_game(Date.current + 4)
      AttendancePromptWorker.new.perform
      AttendancePrompt.count.should eq(0)
    end

    it "is idempotent across runs" do
      make_game(Date.current + 4)
      AttendancePromptWorker.new.perform
      AttendancePromptWorker.new.perform
      AttendancePrompt.where(team_id: team._id).count.should eq(2)
    end
  end

  describe "reminder window (2 days out)" do
    it "creates a reminder dispatch for users who haven't responded" do
      day = Date.current + 2
      make_game(day)
      # Simulate that initial prompts already exist (created previously)
      FactoryGirl.create(:attendance_prompt, user: user1, team: team, league: league, game_day: day, status: 'pending')
      FactoryGirl.create(:attendance_prompt, user: user2, team: team, league: league, game_day: day, status: 'yes', responded_at: 1.day.ago)
      AttendancePromptWorker.new.perform
      AttendancePromptDispatch.where(user_id: user1._id, kind: 'reminder').count.should eq(1)
      AttendancePromptDispatch.where(user_id: user2._id, kind: 'reminder').count.should eq(0)
    end

    it "is idempotent — does not double-send reminders" do
      day = Date.current + 2
      make_game(day)
      FactoryGirl.create(:attendance_prompt, user: user1, team: team, league: league, game_day: day, status: 'pending')
      AttendancePromptWorker.new.perform
      AttendancePromptWorker.new.perform
      AttendancePromptDispatch.where(user_id: user1._id, kind: 'reminder').count.should eq(1)
    end
  end

  describe "rainout filtering" do
    it "skips game-days where every game is rained out" do
      day = Date.current + 4
      g = make_game(day)
      g.scores = { 'rainout' => true, 'reporter_id' => user1._id }
      g.save!
      AttendancePromptWorker.new.perform
      AttendancePrompt.where(team_id: team._id, game_day: day).count.should eq(0)
    end
  end

  describe "batching" do
    it "creates one Dispatch per user covering both same-day prompts" do
      # Tue/Thu collision: a player has Tue at 2-day window AND Thu at 4-day window,
      # both fire today (same hour).
      tue = Date.current + 2
      thu = Date.current + 4
      make_game(tue)
      make_game(thu)
      # Pre-create the Tue prompt (initial would have been earlier; it's in reminder window now)
      FactoryGirl.create(:attendance_prompt, user: user1, team: team, league: league, game_day: tue, status: 'pending')
      AttendancePromptWorker.new.perform
      # Single dispatch covering both prompts:
      ds = AttendancePromptDispatch.where(user_id: user1._id)
      ds.count.should eq(1)
      ds.first.prompts.size.should eq(2)
    end
  end
end
```

- [ ] **Step 2: Run, expect failure**.

Run: `bundle exec rspec spec/workers/attendance_prompt_worker_spec.rb`
Expected: FAIL with "uninitialized constant AttendancePromptWorker".

- [ ] **Step 3: Implement `app/workers/attendance_prompt_worker.rb`**.

```ruby
class AttendancePromptWorker
  include Sidekiq::Worker

  INITIAL_LEAD_DAYS  = 4
  REMINDER_LEAD_DAYS = 2

  def perform
    today = Date.current
    initial_day  = today + INITIAL_LEAD_DAYS
    reminder_day = today + REMINDER_LEAD_DAYS

    League.where(attendance_enabled: true).each do |league|
      process_initial_for(league, initial_day)
      process_reminder_for(league, reminder_day)
    end

    dispatch_pending_per_user!
  end

  private

  def process_initial_for(league, game_day)
    games = league.games.where(:game_time.gte => game_day.beginning_of_day,
                               :game_time.lte => game_day.end_of_day).to_a
    teams_for_day = group_games_by_team(games)
    teams_for_day.each do |team_id, day_games|
      next if all_rained_out?(day_games)
      team = Team.find(team_id)
      team.players.each do |player|
        next if AttendancePrompt.where(user_id: player._id, team_id: team_id, game_day: game_day).exists?
        prompt = AttendancePrompt.create!(
          user: player, team: team, league: league,
          game_day: game_day, game_ids: day_games.map(&:_id),
          status: 'pending'
        )
        queue_for_dispatch(player, prompt, kind: 'initial')
      end
    end
  end

  def process_reminder_for(league, game_day)
    games = league.games.where(:game_time.gte => game_day.beginning_of_day,
                               :game_time.lte => game_day.end_of_day).to_a
    teams_for_day = group_games_by_team(games)
    teams_for_day.each do |team_id, day_games|
      next if all_rained_out?(day_games)
      AttendancePrompt.where(team_id: team_id, game_day: game_day, status: 'pending').each do |prompt|
        already_reminded = AttendancePromptDispatch.where(
          user_id: prompt.user_id, kind: 'reminder',
          'prompts.prompt_id' => prompt._id.to_s
        ).exists?
        next if already_reminded
        queue_for_dispatch(prompt.user, prompt, kind: 'reminder')
      end
    end
  end

  def group_games_by_team(games)
    grouping = {}
    games.each do |g|
      g.team_ids.each do |tid|
        grouping[tid] ||= []
        grouping[tid] << g
      end
    end
    grouping
  end

  def all_rained_out?(games)
    games.all? { |g| g.rained_out? }
  end

  def queue_for_dispatch(user, prompt, kind:)
    @pending ||= {}
    @pending[user._id] ||= { user: user, kind: kind, prompts: [] }
    @pending[user._id][:prompts] << prompt
    # Promote kind: if any in batch is initial, batch overall is mixed → still log as initial
    # for analysis; reminder-only batches keep kind='reminder'. Pick the "stronger" label:
    if @pending[user._id][:kind] == 'reminder' && kind == 'initial'
      @pending[user._id][:kind] = 'initial'
    end
  end

  def dispatch_pending_per_user!
    return unless @pending
    @pending.each_value do |entry|
      Afdc::AttendancePromptDispatcher.new(
        user: entry[:user], prompts: entry[:prompts], kind: entry[:kind]
      ).dispatch!
    end
  ensure
    @pending = nil
  end
end
```

- [ ] **Step 4: Run, expect pass**.

Run: `bundle exec rspec spec/workers/attendance_prompt_worker_spec.rb`
Expected: PASS. If `Time.zone.parse` returns nil because `Time.zone` isn't set, set it via `Time.zone = LOCAL_TIMEZONE` in test setup or use `ActiveSupport::TimeZone[LOCAL_TIMEZONE].parse(...)`.

- [ ] **Step 5: Commit**.

```bash
git add app/workers/attendance_prompt_worker.rb spec/workers/attendance_prompt_worker_spec.rb
git commit -m "Add AttendancePromptWorker for 4-day initial and 2-day reminder cadence"
```

---

## Task 8: Whenever schedule entry

**Goal:** Wire the worker to run hourly via the existing whenever/sidekiq-cron setup.

**Files:**
- Modify: `config/schedule.rb`

- [ ] **Step 1: Add to `config/schedule.rb`** below the existing `every 1.hours` block:

```ruby
every 1.hours do
    runner "AttendancePromptWorker.new.perform"
end
```

(Use `runner` rather than queuing to Sidekiq directly so that the existing whenever-driven approach is preserved.)

- [ ] **Step 2: Manually validate the crontab dump**.

Run: `bundle exec whenever`
Expected: prints a `0 * * * * /bin/bash -l -c 'cd ... && bundle exec rails runner -e production "\''AttendancePromptWorker.new.perform'\''"'` line. No errors.

- [ ] **Step 3: Commit**.

```bash
git add config/schedule.rb
git commit -m "Schedule AttendancePromptWorker hourly via whenever"
```

---

## Task 9: NotificationMailer.attendance_prompt + email views

**Goal:** Email channel implementation. The mailer takes a dispatch ID, fetches its prompts, renders an email with the same per-game-day info as the SMS, plus tokenized RSVP links per prompt.

**Files:**
- Modify: `app/mailers/notification_mailer.rb`
- Create: `app/views/notification_mailer/attendance_prompt.html.haml`
- Create: `app/views/notification_mailer/attendance_prompt.text.haml`
- Test: `spec/mailers/notification_mailer_attendance_prompt_spec.rb`

- [ ] **Step 1: Write failing mailer spec**:

```ruby
require 'spec_helper'

describe NotificationMailer do
  describe "#attendance_prompt" do
    let(:user)   { FactoryGirl.create(:user, firstname: 'Pete') }
    let(:league) { FactoryGirl.create(:league) }
    let(:team)   { FactoryGirl.create(:team, league: league) }
    let(:p1)     { FactoryGirl.create(:attendance_prompt, user: user, team: team, league: league, game_day: Date.current + 4) }
    let(:dispatch) {
      AttendancePromptDispatch.create!(
        user: user, channel: 'email', sent_at: Time.now, kind: 'initial', target: 'pete@example.com',
        prompts: [{ 'prompt_id' => p1._id.to_s, 'prefix' => 1 }]
      )
    }

    it "renders the user's first name and game date" do
      mail = NotificationMailer.attendance_prompt(dispatch._id.to_s)
      mail.to.should eq(['pete@example.com'])
      mail.subject.should match(/AFDC/i)
      mail.body.encoded.should match(/Pete/)
      mail.body.encoded.should match(p1.game_day.strftime('%-m/%-d'))
    end

    it "includes a tokenized RSVP link per prompt" do
      mail = NotificationMailer.attendance_prompt(dispatch._id.to_s)
      mail.body.encoded.should match(p1.web_token)
    end
  end
end
```

- [ ] **Step 2: Run, expect failure** (method not defined).

Run: `bundle exec rspec spec/mailers/notification_mailer_attendance_prompt_spec.rb`
Expected: FAIL.

- [ ] **Step 3: Add the mailer method** to `app/mailers/notification_mailer.rb`:

```ruby
def attendance_prompt(dispatch_id)
  @dispatch = AttendancePromptDispatch.find(dispatch_id)
  @user     = @dispatch.user
  @prompts  = @dispatch.prompts.map { |entry|
    AttendancePrompt.find(entry['prompt_id'])
  }
  @target   = @dispatch.target

  mail(to: @target, subject: "AFDC: please confirm your attendance")
end
```

- [ ] **Step 4: Create `app/views/notification_mailer/attendance_prompt.text.haml`** (use tabs, matching existing files):

```haml
Hi #{@user.firstname}!

We need to confirm your attendance for the following AFDC game day#{@prompts.size > 1 ? 's' : ''}:

- @prompts.each do |prompt|
	= prompt.game_day.strftime('%A %-m/%-d')
	- games = Game.where(:_id.in => prompt.game_ids).to_a.sort_by(&:game_time)
	- games.each do |g|
		\  - #{g.game_time.strftime('%-l:%M%P').sub('m','')} at #{g.field_site ? g.field_site.name : ''}#{g.opponent_for(prompt.team) ? " vs #{g.opponent_for(prompt.team).name}" : ''}
	RSVP: #{rsvp_url(prompt.web_token)}

If you have questions, contact your captain.

— AFDC
```

- [ ] **Step 5: Create `app/views/notification_mailer/attendance_prompt.html.haml`** (HTML version using the existing zurb_ink_basic layout):

```haml
%h2 Hi #{@user.firstname}!

%p We need to confirm your attendance for the following AFDC game day#{'s' if @prompts.size > 1}:

- @prompts.each do |prompt|
	%h3= prompt.game_day.strftime('%A %-m/%-d')
	%ul
		- games = Game.where(:_id.in => prompt.game_ids).to_a.sort_by(&:game_time)
		- games.each do |g|
			%li= "#{g.game_time.strftime('%-l:%M%P').sub('m','')} at #{g.field_site ? g.field_site.name : ''}#{g.opponent_for(prompt.team) ? " vs #{g.opponent_for(prompt.team).name}" : ''}"
	%p= link_to "RSVP for this day", rsvp_url(prompt.web_token), style: 'background: #2c5282; color: white; padding: 10px 16px; text-decoration: none; border-radius: 4px;'

%p If you have questions, contact your captain.
%p — AFDC
```

- [ ] **Step 6: Add the URL helper** for `rsvp_url(token)`. We will define a route `attendance_token GET /attendance/:token` in Task 10. For now, define a temporary helper if needed:

In `app/helpers/notification_mailer_helper.rb` (create if absent):

```ruby
module NotificationMailerHelper
  def rsvp_url(token)
    Rails.application.routes.url_helpers.attendance_token_url(token: token, host: ENV['MAILER_HOST'] || 'leagues.afdc.com')
  end
end
```

- [ ] **Step 7: Run the mailer spec**. It will fail with "missing route" because the route comes in Task 10. **Stub the route helper for this task** so the mailer spec is green. Add to the spec:

```ruby
before do
  Rails.application.routes.url_helpers.stub(:attendance_token_url).and_return('https://leagues.afdc.com/attendance/STUBBED')
end
```

OR — preferably — implement Task 10 and Task 9 close together. Either order is fine; if doing Task 9 first, use the stub. The plan as written assumes Task 10 will provide the real route shortly after.

- [ ] **Step 8: Run, expect pass**.

Run: `bundle exec rspec spec/mailers/notification_mailer_attendance_prompt_spec.rb`
Expected: PASS.

- [ ] **Step 9: Commit**.

```bash
git add app/mailers/notification_mailer.rb app/views/notification_mailer/attendance_prompt.html.haml app/views/notification_mailer/attendance_prompt.text.haml app/helpers/notification_mailer_helper.rb spec/mailers/notification_mailer_attendance_prompt_spec.rb
git commit -m "Add attendance_prompt mailer with text and HTML views"
```

---

## Task 10: AttendancePromptsController — SMS webhook + tokenized web flow

**Goal:** Inbound endpoints. `POST /attendance_prompts/sms` handles Twilio inbound. `GET /attendance/:token` shows the no-login RSVP page. `PATCH /attendance/:token` records the response.

**Files:**
- Create: `app/controllers/attendance_prompts_controller.rb`
- Create: `app/views/attendance_prompts/show.html.haml`
- Modify: `config/routes.rb`
- Modify: `config/authorization_rules.rb`
- Test: `spec/controllers/attendance_prompts_controller_spec.rb`

- [ ] **Step 1: Add routes** in `config/routes.rb` (near the top, outside any resource block):

```ruby
post '/attendance_prompts/sms' => 'attendance_prompts#sms_webhook'
get  '/attendance/:token'      => 'attendance_prompts#show',  as: :attendance_token
patch '/attendance/:token'     => 'attendance_prompts#update', as: :attendance_token_update
```

- [ ] **Step 2: Add authorization rules** in `config/authorization_rules.rb`. Inside the `:guest` role, add:

```ruby
has_permission_on :attendance_prompts, to: [:sms_webhook, :show, :update]
```

This is a tokenized public flow; auth via the token, not via login.

- [ ] **Step 3: Write controller spec** at `spec/controllers/attendance_prompts_controller_spec.rb`:

```ruby
require 'spec_helper'

describe AttendancePromptsController do
  let(:user)   { FactoryGirl.create(:user) }
  let(:league) { FactoryGirl.create(:league) }
  let(:team)   { FactoryGirl.create(:team, league: league) }
  let!(:nm)    { FactoryGirl.create(:notification_method, user: user, target: '4045551111') }
  let(:prompt) { FactoryGirl.create(:attendance_prompt, user: user, team: team, league: league) }

  describe "POST #sms_webhook" do
    before do
      AttendancePromptDispatch.create!(
        user: user, channel: 'sms', sent_at: Time.now, kind: 'initial', target: '4045551111',
        prompts: [{ 'prompt_id' => prompt._id.to_s, 'prefix' => 1 }]
      )
    end

    it "applies a YES code from a known phone" do
      post :sms_webhook, From: '+14045551111', Body: '11'
      response.should be_successful
      prompt.reload.status.should eq('yes')
    end

    it "responds with TwiML acknowledging unknown numbers" do
      post :sms_webhook, From: '+19999999999', Body: 'YES'
      response.body.should match(%r{<Response>})
      response.body.should match(/don't recognize/i)
    end

    it "responds with TwiML when no pending prompts" do
      AttendancePromptDispatch.delete_all
      post :sms_webhook, From: '+14045551111', Body: 'YES'
      response.body.should match(/no active attendance/i)
    end
  end

  describe "GET #show" do
    it "renders the RSVP page for a valid token" do
      get :show, token: prompt.web_token
      response.should be_successful
      assigns(:prompt).should eq(prompt)
    end

    it "404s on an unknown token" do
      get :show, token: 'bogus'
      response.status.should eq(404)
    end

    it "shows a passed-game state for past game-days" do
      prompt.update_attributes!(game_day: Date.current - 1)
      get :show, token: prompt.web_token
      response.body.should match(/has already happened/i)
    end
  end

  describe "PATCH #update" do
    it "records a YES from the web" do
      patch :update, token: prompt.web_token, status: 'yes', note: 'pumped'
      prompt.reload
      prompt.status.should eq('yes')
      prompt.response_method.should eq('web')
      prompt.note.should eq('pumped')
    end

    it "rejects invalid status" do
      patch :update, token: prompt.web_token, status: 'banana'
      response.status.should eq(422)
      prompt.reload.status.should eq('pending')
    end
  end
end
```

- [ ] **Step 4: Run, expect failure**.

Run: `bundle exec rspec spec/controllers/attendance_prompts_controller_spec.rb`
Expected: FAIL.

- [ ] **Step 5: Implement the controller** at `app/controllers/attendance_prompts_controller.rb`:

```ruby
class AttendancePromptsController < ApplicationController
  skip_before_filter :verify_authenticity_token, only: [:sms_webhook]
  before_filter :load_prompt_from_token, only: [:show, :update]

  def sms_webhook
    phone = digits_only(params[:From])
    body  = params[:Body].to_s

    nm = NotificationMethod.where(method: 'text', target: phone).first
    if nm.nil? || nm.user.nil?
      return render_twiml("We don't recognize this number. Visit https://leagues.afdc.com to manage your notifications.")
    end

    user = nm.user
    result = Afdc::AttendanceReplyParser.parse(user: user, body: body)

    case result.kind
    when :no_pending
      render_twiml("No active attendance questions right now. Visit https://leagues.afdc.com for your schedule.")
    when :resolved
      render_twiml("Got it — thanks! (#{result.resolved_prompts.size} answered.)")
    when :unresolved_codes
      render_twiml("Sorry, I couldn't match that. Reply with the codes from the most recent message, or visit https://leagues.afdc.com.")
    when :note_only
      link = url_for(controller: 'attendance_prompts', action: 'show', token: result.note_only_prompt.web_token, only_path: false)
      render_twiml("Got your note — to set yes/no/partial, visit #{link}.")
    end
  end

  def show
    if @prompt.game_day < Date.current
      render :show_passed and return
    end
    @games = Game.where(:_id.in => @prompt.game_ids).to_a.sort_by(&:game_time)
  end

  def update
    status = params[:status].to_s
    unless AttendancePrompt::STATUSES.include?(status) && status != 'pending'
      return render text: 'Invalid status', status: 422
    end
    @prompt.record_response!(
      status: status, responded_by: @prompt.user,
      response_method: 'web', note: params[:note]
    )
    redirect_to attendance_token_path(@prompt.web_token), notice: 'Thanks — your response is recorded.'
  end

  private

  def load_prompt_from_token
    @prompt = AttendancePrompt.where(web_token: params[:token]).first
    head 404 unless @prompt
  end

  def digits_only(s)
    s.to_s.gsub(/\D/, '').sub(/\A1/, '').slice(-10..-1) # strip + and country code
  end

  def render_twiml(text)
    twiml = "<?xml version=\"1.0\" encoding=\"UTF-8\"?><Response><Message>#{ERB::Util.html_escape(text)}</Message></Response>"
    render text: twiml, content_type: 'text/xml'
  end
end
```

- [ ] **Step 6: Create `app/views/attendance_prompts/show.html.haml`** (use tabs):

```haml
.container
	%h2= "AFDC Attendance — #{@prompt.game_day.strftime('%A %-m/%-d')}"
	%h4 #{@prompt.team.name}
	%ul
		- @games.each do |g|
			%li= "#{g.game_time.strftime('%-l:%M%P').sub('m','')} at #{g.field_site ? g.field_site.name : ''}#{g.opponent_for(@prompt.team) ? " vs #{g.opponent_for(@prompt.team).name}" : ''}"

	= form_tag attendance_token_update_path(@prompt.web_token), method: :patch, class: 'form-horizontal' do
		.row
			.span4
				%button.btn.btn-large.btn-success{name: 'status', value: 'yes', style: 'width:100%'} YES, I'll be there
			.span4
				%button.btn.btn-large.btn-danger{name: 'status', value: 'no', style: 'width:100%'} NO, can't make it
			.span4
				%button.btn.btn-large.btn-warning{name: 'status', value: 'partial', style: 'width:100%'} It's complicated
		.row{style: 'margin-top: 16px;'}
			.span12
				%label Notes (optional)
				= text_area_tag :note, '', class: 'span12', rows: 3, placeholder: "e.g., 'second game only', 'running 30 min late'"
```

- [ ] **Step 7: Create `app/views/attendance_prompts/show_passed.html.haml`**:

```haml
.container
	%h2 This game has already happened.
	%p RSVPing is no longer possible for this date.
```

- [ ] **Step 8: Run, expect pass**.

Run: `bundle exec rspec spec/controllers/attendance_prompts_controller_spec.rb`
Expected: PASS.

- [ ] **Step 9: Update `MAILER_HOST` env var note**. The mailer URL helper needs `ENV['MAILER_HOST']`. If not already configured, add to `sample.env`:

```
MAILER_HOST=leagues.afdc.com
```

- [ ] **Step 10: Commit**.

```bash
git add app/controllers/attendance_prompts_controller.rb app/views/attendance_prompts/ config/routes.rb config/authorization_rules.rb spec/controllers/attendance_prompts_controller_spec.rb sample.env
git commit -m "Add AttendancePromptsController for SMS webhook and tokenized web RSVP"
```

---

## Task 11: Captain dashboard

**Goal:** `teams_controller#attendance` action lists this week's upcoming game-days for the team and lets captains drill into details. Spec §5.

**Files:**
- Modify: `app/controllers/teams_controller.rb`
- Create: `app/views/teams/attendance.html.haml`
- Modify: `config/routes.rb`
- Modify: `config/authorization_rules.rb`
- Test: `spec/controllers/teams_controller_attendance_spec.rb`

- [ ] **Step 1: Add the route** in `config/routes.rb`. Inside `resources :teams do ... end` (find the existing block), add:

```ruby
resources :teams do
  member do
    get 'attendance'
    patch 'attendance_override'
  end
end
```

(If `resources :teams` doesn't already exist, add it.)

- [ ] **Step 2: Add authorization rules** in `config/authorization_rules.rb`. In the `:user` role, add two blocks (one for captains, one for league managers/commissioners):

```ruby
# Captain access to their own team's attendance
has_permission_on :teams, to: [:attendance, :attendance_override] do
  if_attribute captains: contains { user }
end

# League manager / commissioner access to any team's attendance in leagues they manage
has_permission_on :teams, to: [:attendance, :attendance_override] do
  if_permitted_to :manage, :league
end
```

- [ ] **Step 3: Write controller spec** at `spec/controllers/teams_controller_attendance_spec.rb`:

```ruby
require 'spec_helper'

describe TeamsController do
  let(:captain) { FactoryGirl.create(:user) }
  let(:league)  { FactoryGirl.create(:league, attendance_enabled: true) }
  let(:team)    { FactoryGirl.create(:team, league: league) }
  let(:player)  { FactoryGirl.create(:user) }

  before do
    team.captains = [captain._id]
    team.players  = [captain._id, player._id]
    team.save!
    session[:user_id] = captain._id
    controller.stub(:current_user).and_return(captain)
  end

  describe "GET #attendance" do
    it "lists upcoming game-days within this week" do
      Game.create!(league: league, game_time: Time.now + 2.days, teams: [team._id])
      Game.create!(league: league, game_time: Time.now + 9.days, teams: [team._id])
      get :attendance, id: team._id
      response.should be_successful
      assigns(:upcoming_days).map(&:to_date).should include((Date.current + 2))
      assigns(:upcoming_days).map(&:to_date).should_not include((Date.current + 9))
    end

    it "provides per-day status counts" do
      day = Date.current + 3
      Game.create!(league: league, game_time: Time.zone.parse("#{day} 7pm"), teams: [team._id])
      FactoryGirl.create(:attendance_prompt, user: captain, team: team, league: league, game_day: day, status: 'yes')
      FactoryGirl.create(:attendance_prompt, user: player, team: team, league: league, game_day: day, status: 'pending')
      get :attendance, id: team._id
      counts = assigns(:counts_by_day)[day]
      counts[:yes].should eq(1)
      counts[:not_answered].should eq(1)
    end
  end

  describe "PATCH #attendance_override" do
    let(:prompt) { FactoryGirl.create(:attendance_prompt, user: player, team: team, league: league) }

    it "lets a captain set a player's status with response_method captain_override" do
      patch :attendance_override, id: team._id, prompt_id: prompt._id, status: 'no', note: 'told me in person'
      prompt.reload
      prompt.status.should eq('no')
      prompt.response_method.should eq('captain_override')
      prompt.responded_by.should eq(captain)
      prompt.note.should eq('told me in person')
    end
  end
end
```

- [ ] **Step 4: Run, expect failure**.

Run: `bundle exec rspec spec/controllers/teams_controller_attendance_spec.rb`
Expected: FAIL.

- [ ] **Step 5: Add the controller actions** to `app/controllers/teams_controller.rb`:

```ruby
def attendance
  @team   = Team.find(params[:id])
  @league = @team.league
  @upcoming_days = upcoming_game_days(@team)
  @prompts_by_day = {}
  @counts_by_day  = {}
  @upcoming_days.each do |day|
    prompts = AttendancePrompt.where(team_id: @team._id, game_day: day).to_a
    @prompts_by_day[day] = prompts
    @counts_by_day[day] = {
      yes:          prompts.count { |p| p.status == 'yes' || p.status == 'partial' },
      no:           prompts.count { |p| p.status == 'no' },
      not_answered: prompts.count { |p| p.status == 'pending' } + (@team.players.count - prompts.size),
    }
  end
end

def attendance_override
  @team   = Team.find(params[:id])
  prompt  = AttendancePrompt.where(team_id: @team._id, _id: params[:prompt_id]).first
  head 404 and return unless prompt
  prompt.record_response!(
    status: params[:status],
    responded_by: current_user,
    response_method: 'captain_override',
    note: params[:note]
  )
  redirect_to attendance_team_path(@team), notice: "Updated #{prompt.user.firstname}'s response."
end

private

def upcoming_game_days(team)
  end_of_week = Date.current.end_of_week + 1  # include Sunday games of this rolling week
  Game.where(:teams => team._id, :game_time.gte => Date.current.beginning_of_day, :game_time.lte => end_of_week.end_of_day)
      .map { |g| g.game_time.in_time_zone(LOCAL_TIMEZONE).to_date }
      .uniq
      .sort
end
```

- [ ] **Step 6: Create the view** at `app/views/teams/attendance.html.haml`:

```haml
.container
	%h2= "Attendance — #{@team.name}"
	%p= link_to "← Back to team", team_path(@team)

	- if @upcoming_days.empty?
		%p No upcoming games this week.
	- else
		- @upcoming_days.each do |day|
			.well
				%h3= day.strftime('%A %-m/%-d')
				- counts = @counts_by_day[day]
				%p
					%span.label.label-success= "✅ #{counts[:yes]}"
					%span.label.label-important= "❌ #{counts[:no]}"
					%span.label= "❓ #{counts[:not_answered]}"

				%table.table.table-striped
					%thead
						%tr
							%th Player
							%th Status
							%th Note
							%th Method
							%th Override
					%tbody
						- @team.players.each do |player|
							- prompt = @prompts_by_day[day].detect { |p| p.user_id == player._id }
							%tr
								%td= "#{player.firstname} #{player.lastname}"
								%td
									- if prompt && prompt.status != 'pending'
										= prompt.status.upcase
									- else
										%em Not answered
								%td= prompt && prompt.note
								%td= prompt && prompt.response_method
								%td
									- if prompt
										= form_tag attendance_override_team_path(@team), method: :patch, style: 'display:inline' do
											= hidden_field_tag :prompt_id, prompt._id
											= select_tag :status, options_for_select([['Yes','yes'],['No','no'],['Partial','partial']], prompt.status), prompt: 'Override...'
											= text_field_tag :note, '', placeholder: 'note', size: 12
											= submit_tag 'Set', class: 'btn btn-mini'
```

- [ ] **Step 7: Run, expect pass**.

Run: `bundle exec rspec spec/controllers/teams_controller_attendance_spec.rb`
Expected: PASS. Adjust `current_user` stubbing in the spec to match how `ApplicationController` actually exposes it (could be a method, could be a helper).

- [ ] **Step 8: Commit**.

```bash
git add app/controllers/teams_controller.rb app/views/teams/attendance.html.haml config/routes.rb config/authorization_rules.rb spec/controllers/teams_controller_attendance_spec.rb
git commit -m "Add captain attendance dashboard with manual override"
```

---

## Task 12: Commissioner / league-admin overview

**Goal:** League-wide table showing per-team counts for upcoming game-days. Drill-down reuses the captain view.

**Files:**
- Modify: `app/controllers/leagues_controller.rb`
- Create: `app/views/leagues/attendance_overview.html.haml`
- Modify: `config/routes.rb`
- Modify: `config/authorization_rules.rb`
- Test: `spec/controllers/leagues_controller_attendance_spec.rb`

- [ ] **Step 1: Add route** inside the existing `resources :leagues do ... end` block in `config/routes.rb`:

```ruby
member do
  ...
  get 'attendance_overview'
end
```

- [ ] **Step 2: Add auth rule** in `config/authorization_rules.rb`. Find the existing block (in the `:user` role) that begins:

```ruby
has_permission_on :leagues, :to => [
    :manage_roster, :finances, :players, :reg_list, :team_list, :cancel_registration, 
    :promote_waitlisted_registration, :add_player_to_team, :update_invites, :edit, :update, 
    :setup_schedule_import, :upload_schedule, :import_schedule, :remove_future_games, :rainout_games, :process_rainout, 
    :upload_roster, :setup_roster_import, :import_roster, :pickup_list, :invite_pickup, :cancel_pickup_registration] do
    if_permitted_to :manage
end
```

Add `:attendance_overview` to the array (e.g., at the end). The full edit:

```ruby
has_permission_on :leagues, :to => [
    :manage_roster, :finances, :players, :reg_list, :team_list, :cancel_registration, 
    :promote_waitlisted_registration, :add_player_to_team, :update_invites, :edit, :update, 
    :setup_schedule_import, :upload_schedule, :import_schedule, :remove_future_games, :rainout_games, :process_rainout, 
    :upload_roster, :setup_roster_import, :import_roster, :pickup_list, :invite_pickup, :cancel_pickup_registration,
    :attendance_overview] do
    if_permitted_to :manage
end
```

- [ ] **Step 3: Write spec** at `spec/controllers/leagues_controller_attendance_spec.rb`:

```ruby
require 'spec_helper'

describe LeaguesController do
  let(:commish) { FactoryGirl.create(:user) }
  let(:league)  { FactoryGirl.create(:league, attendance_enabled: true) }
  let(:team_a)  { FactoryGirl.create(:team, league: league, name: 'Sharks') }
  let(:team_b)  { FactoryGirl.create(:team, league: league, name: 'Wolves') }

  before do
    league.commissioners = [commish._id]
    league.save!
    session[:user_id] = commish._id
    controller.stub(:current_user).and_return(commish)
  end

  describe "GET #attendance_overview" do
    it "shows a row per team for each upcoming game-day" do
      day = Date.current + 3
      Game.create!(league: league, game_time: Time.zone.parse("#{day} 7pm"), teams: [team_a._id])
      Game.create!(league: league, game_time: Time.zone.parse("#{day} 7pm"), teams: [team_b._id])
      get :attendance_overview, id: league._id
      response.should be_successful
      assigns(:rows).size.should eq(2)
    end
  end
end
```

- [ ] **Step 4: Run, expect failure**.

- [ ] **Step 5: Add `attendance_overview` action** to `app/controllers/leagues_controller.rb`:

```ruby
def attendance_overview
  @league = League.find(params[:id])
  end_of_week = Date.current.end_of_week + 1
  upcoming = @league.games.where(:game_time.gte => Date.current.beginning_of_day,
                                 :game_time.lte => end_of_week.end_of_day).to_a
  game_days = upcoming.map { |g| g.game_time.in_time_zone(LOCAL_TIMEZONE).to_date }.uniq.sort
  @rows = []
  @league.teams.each do |team|
    counts_per_day = {}
    game_days.each do |day|
      day_games = upcoming.select { |g| g.game_time.in_time_zone(LOCAL_TIMEZONE).to_date == day && g.team_ids.include?(team._id) }
      next if day_games.empty?
      prompts = AttendancePrompt.where(team_id: team._id, game_day: day).to_a
      counts_per_day[day] = {
        yes:          prompts.count { |p| p.status == 'yes' || p.status == 'partial' },
        no:           prompts.count { |p| p.status == 'no' },
        not_answered: prompts.count { |p| p.status == 'pending' } + (team.players.count - prompts.size),
      }
    end
    next if counts_per_day.empty?
    @rows << { team: team, counts_per_day: counts_per_day }
  end
  @game_days = game_days
end
```

- [ ] **Step 6: Create view** at `app/views/leagues/attendance_overview.html.haml`:

```haml
.container
	%h2= "Attendance — #{@league.name}"
	- if @rows.empty?
		%p No upcoming games for this league.
	- else
		%table.table.table-bordered
			%thead
				%tr
					%th Team
					- @game_days.each do |d|
						%th= d.strftime('%a %-m/%-d')
			%tbody
				- @rows.each do |row|
					%tr
						%td= link_to row[:team].name, attendance_team_path(row[:team])
						- @game_days.each do |d|
							%td
								- counts = row[:counts_per_day][d]
								- if counts
									%span.label.label-success= counts[:yes]
									%span.label.label-important= counts[:no]
									%span.label= counts[:not_answered]
								- else
									—
```

- [ ] **Step 7: Run, expect pass**.

- [ ] **Step 8: Commit**.

```bash
git add app/controllers/leagues_controller.rb app/views/leagues/attendance_overview.html.haml config/routes.rb config/authorization_rules.rb spec/controllers/leagues_controller_attendance_spec.rb
git commit -m "Add commissioner league-wide attendance overview"
```

---

## Task 13: Per-league enable flag UI

**Goal:** Surface the `attendance_enabled` flag on the league edit form so commissioners can opt their league in.

**Files:**
- Modify: `app/views/leagues/_form.html.haml`
- Modify: `app/controllers/leagues_controller.rb` (permit the new param)

- [ ] **Step 1: Permit `attendance_enabled` in `league_params`** in `app/controllers/leagues_controller.rb`. Find the `league_params` method and add `:attendance_enabled` to the permitted list.

- [ ] **Step 2: Add a checkbox** to `app/views/leagues/_form.html.haml`. After the existing `pickup_registration` checkbox block, add:

```haml
            .control-group
                .controls
                    %label.checkbox
                        = f.check_box :attendance_enabled
                        Enable attendance prompts (SMS/email)
```

(Use tabs matching surrounding indentation.)

- [ ] **Step 3: Manually verify** by viewing a league edit page in development. The checkbox should appear, and toggling it should persist.

- [ ] **Step 4: Commit**.

```bash
git add app/controllers/leagues_controller.rb app/views/leagues/_form.html.haml
git commit -m "Add attendance_enabled toggle to league edit form"
```

---

## Task 14: End-to-end integration spec

**Goal:** A single integration test that runs the worker, simulates an inbound SMS, and verifies the captain dashboard reflects it.

**Files:**
- Create: `spec/integration/attendance_flow_spec.rb`

- [ ] **Step 1: Write the integration spec**:

```ruby
require 'spec_helper'

describe "Attendance end-to-end" do
  let(:captain) { FactoryGirl.create(:user) }
  let(:player)  { FactoryGirl.create(:user, firstname: 'Pete') }
  let(:league)  { FactoryGirl.create(:league, attendance_enabled: true) }
  let(:team)    { FactoryGirl.create(:team, league: league) }

  before do
    team.captains = [captain._id]
    team.players  = [captain._id, player._id]
    team.save!
    FactoryGirl.create(:notification_method, user: captain, target: '4045551111')
    FactoryGirl.create(:notification_method, user: player, target: '4045552222')
    NotificationMethod.any_instance.stub(:send_text).and_return(true)
  end

  it "creates prompts on the worker run, applies a SMS reply, and surfaces it on the dashboard" do
    day = Date.current + 4
    Game.create!(league: league, game_time: Time.zone.parse("#{day} 7pm"), teams: [team._id])

    # Run the worker — should create AttendancePrompts and Dispatches.
    AttendancePromptWorker.new.perform
    AttendancePrompt.where(team_id: team._id, game_day: day).count.should eq(2)
    AttendancePromptDispatch.where(user_id: player._id).count.should eq(1)

    # Simulate Twilio inbound: player replies "11"
    Afdc::AttendanceReplyParser.parse(user: player, body: "11")
    pl_prompt = AttendancePrompt.where(user_id: player._id, game_day: day).first
    pl_prompt.status.should eq('yes')
    pl_prompt.response_method.should eq('sms')
  end
end
```

- [ ] **Step 2: Run, expect pass**.

Run: `bundle exec rspec spec/integration/attendance_flow_spec.rb`
Expected: PASS.

- [ ] **Step 3: Run the full test suite**. Verify no regressions elsewhere.

Run: `bundle exec rspec`
Expected: ALL GREEN. Investigate any failures before considering this task done.

- [ ] **Step 4: Commit**.

```bash
git add spec/integration/attendance_flow_spec.rb
git commit -m "Add end-to-end attendance flow integration spec"
```

---

## Task 15: Twilio webhook URL configuration (manual / docs)

**Goal:** Document the production rollout step that's outside the codebase: pointing the Twilio number's inbound webhook at the new endpoint.

**Files:**
- Modify: `wip/docs/08-external-integrations.md` (add a section on attendance webhook).

- [ ] **Step 1: Append to `wip/docs/08-external-integrations.md`** under the Twilio section:

```markdown
### Inbound — Attendance Replies

The AFDC Twilio number's "A Message Comes In" webhook should be set to:

`POST https://leagues.afdc.com/attendance_prompts/sms`

Configured in the Twilio Console → Phone Numbers → (the AFDC number) → Messaging → "A message comes in" webhook URL.

The endpoint accepts standard Twilio message webhook params (`From`, `Body`, `MessageSid`, ...) and returns TwiML.
```

- [ ] **Step 2: Commit**.

```bash
git add wip/docs/08-external-integrations.md
git commit -m "Document Twilio inbound webhook URL for attendance replies"
```

- [ ] **Step 3: Manually verify in production / staging** when deploying:
  - Set `MAILER_HOST` env var.
  - Configure the Twilio webhook URL.
  - Toggle `attendance_enabled = true` on one volunteer league.
  - Watch the cron and dispatch logs for the first run.

---

## Self-Review Checklist (run after writing the plan)

This is for the plan author; do not execute as a task.

- [x] **Spec coverage.** Every section of `2026-05-04-game-attendance-design.md` has a corresponding task: §1 goal/scope (whole plan), §2 channels (Tasks 6, 9, 10), §3 cadence (Task 7), §4 SMS protocol (Tasks 4, 5, 10), §5 dashboards (Tasks 11, 12), §6 data model (Tasks 1, 2, 3), §7 architecture (Tasks 6, 7, 9, 10), §8 authorization (Tasks 10, 11, 12), §9 error/edge cases (covered in dispatcher rescue blocks, controller TwiML responses, and the worker's rainout filter), §10 testing (every task ships with specs), §11 rollout (Task 13), §12 deferred (out of plan by design).

- [x] **Placeholder scan.** No "TBD," "TODO," "implement later," or "similar to Task N" without code.

- [x] **Type / name consistency.** `AttendancePrompt`, `AttendancePromptDispatch`, `Afdc::AttendanceReplyParser`, `Afdc::AttendancePromptDispatcher`, `AttendancePromptWorker`, `AttendancePromptsController` — used consistently. Codes are 2-digit `<prefix><suffix>` throughout. Statuses `pending/yes/no/partial`. Channels `sms/email`. Kinds `initial/reminder`. Response methods `sms/email/web/captain_override`.
