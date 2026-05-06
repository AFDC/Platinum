# Day-of-Week Registration Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add a per-league `game_days` config (0–2 days) plus a registration-type interstitial that lets players in two-day leagues sign up as either a one-day or two-day player. Suppress attendance prompts for the non-chosen day, surface the registration type to captains/commissioners, and let players change their type until the league starts.

**Architecture:** Two new fields on `League` (`game_days`, `price_single_day`, `price_women_single_day`) and one on `Registration` (`attending_days`). A new pair of controller actions on `LeaguesController` (`choose_days` / `submit_day_choice`) hosts an interstitial view between the existing `register` action and the registration form. `Registration#participates_on?` becomes the single predicate the attendance system calls to filter prompts. Captain/commissioner views surface `attending_days` as a per-row badge and as a filter chip.

**Tech Stack:** Rails 4.2, Mongoid 4.0, RSpec 4.1 with FactoryGirl, declarative_authorization, HAML, Bootstrap 2.3, Tabulator 5.4 (player-management AJAX tables).

**Source spec:** `docs/superpowers/specs/2026-05-05-day-of-week-registration-design.md`. When a step references "the spec," that's where to look.

**Conventions to honor:**
- Existing tests use `.should` syntax (see `spec/models/user_spec.rb`, `spec/models/league_spec.rb`). Match it.
- Existing controllers use `before_filter` (Rails 4.2), not `before_action`. Match it.
- HAML files in this repo are indented with **tabs**. Match it.
- Service objects live under `lib/afdc/` (see `PlayerRegistrar`, `PairingCoordinator`).
- All persisted timestamps use `LOCAL_TIMEZONE` (Eastern). Use `Time.current` / `Date.current` and `Time.now.in_time_zone(LOCAL_TIMEZONE)` deliberately.
- `LeaguesController` uses `filter_access_to :all, attribute_check: true` — new actions inherit `attribute_check`. Permissions for new actions go in `config/authorization_rules.rb` only if existing rules don't cover them.
- Commit at the end of each task. Small, sane steps.

**Day-name canonical form:** `%w(monday tuesday wednesday thursday friday saturday sunday)`. Stored lowercase; sorted in this order on save. Display labels are produced by `Date::DAYNAMES` lookups (capitalized).

---

## File Structure

| Path | Status | Responsibility |
|---|---|---|
| `app/models/league.rb` | modify | Add `game_days`, `price_single_day`, `price_women_single_day` fields; add `requires_day_choice?` and extended `get_price`; add validations and the `before_save` ordering of `game_days` |
| `app/models/registration.rb` | modify | Add `attending_days` field; add `single_day?`, `chosen_day`, `registration_type_label`, `participates_on?`, `day_choice_editable?`; add validation; update `ensure_price` |
| `app/controllers/leagues_controller.rb` | modify | Permit new league params; add day-choice gate to `register`; add `choose_days` and `submit_day_choice`; include `attending_days` and `day_label` in `reg_data` |
| `app/views/leagues/_form.html.haml` | modify | Game-days checkboxes + single-day price fields |
| `app/views/leagues/choose_days.html.haml` | new | Interstitial view |
| `app/views/leagues/players.html.erb` | modify | Add Days column + filter to the Tabulator config |
| `app/views/leagues/registrations.html.erb` | modify | Add Days column + filter to the Tabulator config |
| `app/views/leagues/registrations.csv.haml` | modify | Add `attending_days` and `registration_type` columns |
| `app/views/leagues/manage_roster.html.haml` | modify | Add Days badge + filter chip block |
| `app/views/registrations/show.html.haml` | modify | Display registration type + "Change my registration type" link |
| `app/workers/attendance_prompt_worker.rb` | modify | Filter prompts via `Registration#participates_on?` |
| `app/views/teams/attendance.html.haml` | modify | Render filtered-out players in a muted "not playing this night" row |
| `app/models/game.rb` | modify | Add `day_name` helper (lowercase day-of-week in `LOCAL_TIMEZONE`) |
| `config/routes.rb` | modify | Add `choose_days` and `submit_day_choice` routes |
| `spec/factories.rb` | modify | (No changes required — existing `:league`, `:user`, `:team` factories suffice) |
| `spec/models/league_spec.rb` | modify | Specs for `game_days` validation, `requires_day_choice?`, `get_price` |
| `spec/models/registration_spec.rb` | new | Specs for `attending_days` validation, helpers, `participates_on?`, `ensure_price` |
| `spec/controllers/leagues_controller_day_choice_spec.rb` | new | Specs for `register` redirect, `choose_days`, `submit_day_choice` |
| `spec/workers/attendance_prompt_worker_spec.rb` | modify | Add suppression cases for `attending_days` |

---

## Task 1: Add `game_days` field + validations to League

**Goal:** League can persist `game_days` as a 0–2 length array of canonical lowercase day names, validated on save, sorted Mon→Sun.

**Files:**
- Modify: `app/models/league.rb`
- Test: `spec/models/league_spec.rb`

- [ ] **Step 1: Read the current `League` model** to find the `field` block and the validation block.

Run: `grep -n "field :\|validates" app/models/league.rb | head -40`

- [ ] **Step 2: Append failing specs to `spec/models/league_spec.rb`**

```ruby
describe "#game_days" do
  it "defaults to an empty array" do
    league = FactoryGirl.create(:league)
    league.game_days.should eq([])
  end

  it "accepts up to two valid day names" do
    league = FactoryGirl.build(:league, game_days: ['tuesday', 'thursday'])
    league.valid?.should eq(true)
  end

  it "rejects more than two days" do
    league = FactoryGirl.build(:league, game_days: ['monday', 'wednesday', 'friday'])
    league.valid?.should eq(false)
    league.errors[:game_days].should be_present
  end

  it "rejects unknown day names" do
    league = FactoryGirl.build(:league, game_days: ['funday'])
    league.valid?.should eq(false)
    league.errors[:game_days].should be_present
  end

  it "rejects duplicate days" do
    league = FactoryGirl.build(:league, game_days: ['monday', 'monday'])
    league.valid?.should eq(false)
    league.errors[:game_days].should be_present
  end

  it "stores days in canonical Mon->Sun order regardless of input order" do
    league = FactoryGirl.create(:league, game_days: ['thursday', 'tuesday'])
    league.reload.game_days.should eq(['tuesday', 'thursday'])
  end
end
```

- [ ] **Step 3: Run the specs, expect failure.**

Run: `bundle exec rspec spec/models/league_spec.rb -e "game_days"`
Expected: FAIL ("undefined method `game_days`" or factory doesn't accept it).

- [ ] **Step 4: Add the field, validation, and the canonical ordering to `app/models/league.rb`.**

Place near other Boolean/array fields (`invited_player_ids`, `covid_vax_required`, etc.):

```ruby
field :game_days, type: Array, default: []

DAY_NAMES = %w(monday tuesday wednesday thursday friday saturday sunday).freeze

validate :game_days_valid
before_save :normalize_game_days
```

Then near the bottom of the class (before `private`, alongside other helpers), add a `private` method block:

```ruby
private

def game_days_valid
  days = self.game_days || []
  if days.size > 2
    errors.add(:game_days, "must contain at most 2 days")
  end
  invalid = days.reject { |d| DAY_NAMES.include?(d) }
  if invalid.any?
    errors.add(:game_days, "contains invalid day name(s): #{invalid.join(', ')}")
  end
  if days.uniq.size != days.size
    errors.add(:game_days, "must not contain duplicates")
  end
end

def normalize_game_days
  return if game_days.blank?
  self.game_days = game_days.sort_by { |d| DAY_NAMES.index(d) || 99 }
end
```

If the file already has a `private` keyword, fold the two new methods into the existing private block instead of adding another.

- [ ] **Step 5: Run the specs, expect pass.**

Run: `bundle exec rspec spec/models/league_spec.rb -e "game_days"`
Expected: PASS.

- [ ] **Step 6: Commit.**

```bash
git add app/models/league.rb spec/models/league_spec.rb
git commit -m "Add League#game_days field with validation and canonical ordering"
```

---

## Task 2: Add single-day pricing fields and helpers to League

**Goal:** League gains `price_single_day` / `price_women_single_day` fields, a `requires_day_choice?` predicate, and an extended `get_price(gender, single_day:)` signature.

**Files:**
- Modify: `app/models/league.rb`
- Test: `spec/models/league_spec.rb`

- [ ] **Step 1: Append failing specs to `spec/models/league_spec.rb`.**

```ruby
describe "#requires_day_choice?" do
  it "is false when game_days is empty" do
    league = FactoryGirl.create(:league, game_days: [])
    league.requires_day_choice?.should eq(false)
  end

  it "is false when game_days has one entry" do
    league = FactoryGirl.create(:league, game_days: ['tuesday'])
    league.requires_day_choice?.should eq(false)
  end

  it "is true when game_days has two entries" do
    league = FactoryGirl.create(:league, game_days: ['tuesday', 'thursday'])
    league.requires_day_choice?.should eq(true)
  end
end

describe "#get_price" do
  it "returns price for two-day registrations" do
    league = FactoryGirl.create(:league, price: 80, price_single_day: 50)
    league.get_price('male', single_day: false).should eq(80)
  end

  it "returns price_single_day when single_day: true" do
    league = FactoryGirl.create(:league, price: 80, price_single_day: 50)
    league.get_price('male', single_day: true).should eq(50)
  end

  it "falls back to price when price_single_day is blank and single_day: true" do
    league = FactoryGirl.create(:league, price: 80, price_single_day: nil)
    league.get_price('male', single_day: true).should eq(80)
  end

  it "uses price_women for female two-day when set" do
    league = FactoryGirl.create(:league, price: 80, price_women: 60, price_single_day: 50, price_women_single_day: 35)
    league.get_price('female', single_day: false).should eq(60)
  end

  it "uses price_women_single_day for female single-day when set" do
    league = FactoryGirl.create(:league, price: 80, price_women: 60, price_single_day: 50, price_women_single_day: 35)
    league.get_price('female', single_day: true).should eq(35)
  end

  it "falls back to price_women when price_women_single_day is blank for female single-day" do
    league = FactoryGirl.create(:league, price: 80, price_women: 60, price_single_day: 50, price_women_single_day: nil)
    league.get_price('female', single_day: true).should eq(60)
  end

  it "remains backward compatible with one-arg call" do
    league = FactoryGirl.create(:league, price: 80)
    league.get_price('male').should eq(80)
  end
end
```

- [ ] **Step 2: Run the specs, expect failure.**

Run: `bundle exec rspec spec/models/league_spec.rb -e "requires_day_choice"`
Expected: FAIL.

- [ ] **Step 3: Add fields and helpers to `app/models/league.rb`.**

In the `field` block, near the existing price fields:

```ruby
field :price_single_day, type: Integer
field :price_women_single_day, type: Integer
```

Replace the existing `get_price` method:

```ruby
def get_price(gender = nil, single_day: false)
  if single_day
    if gender == 'female' && price_women_single_day.present?
      return price_women_single_day
    end
    return price_single_day if price_single_day.present?
  end

  if gender == 'female' && price_women.present?
    return price_women
  end

  price
end
```

Add `requires_day_choice?` near `gender_permitted?`:

```ruby
def requires_day_choice?
  game_days.present? && game_days.length == 2
end
```

- [ ] **Step 4: Run the specs, expect pass.**

Run: `bundle exec rspec spec/models/league_spec.rb`
Expected: PASS.

- [ ] **Step 5: Commit.**

```bash
git add app/models/league.rb spec/models/league_spec.rb
git commit -m "Add single-day pricing fields and requires_day_choice? to League"
```

---

## Task 3: Add `attending_days` to Registration with helpers

**Goal:** Registration can persist `attending_days`, exposes registration-type predicates, and reports `participates_on?` for any day name.

**Files:**
- Modify: `app/models/registration.rb`
- Test: `spec/models/registration_spec.rb` (new file)

- [ ] **Step 1: Create `spec/models/registration_spec.rb` with failing specs.**

```ruby
require 'spec_helper'

describe Registration do
  let(:user) { FactoryGirl.create(:user) }

  describe "#attending_days" do
    it "defaults to nil" do
      league = FactoryGirl.create(:league)
      reg = Registration.create!(league: league, user: user, status: 'queued', waiver_acceptance_date: Time.now)
      reg.attending_days.should be_nil
    end
  end

  describe "#single_day?" do
    let(:league) { FactoryGirl.create(:league, game_days: ['tuesday', 'thursday']) }

    it "is true when attending_days has one entry" do
      reg = Registration.new(league: league, user: user, attending_days: ['tuesday'])
      reg.single_day?.should eq(true)
    end

    it "is false when attending_days has two entries" do
      reg = Registration.new(league: league, user: user, attending_days: ['tuesday', 'thursday'])
      reg.single_day?.should eq(false)
    end

    it "is false when attending_days is nil" do
      reg = Registration.new(league: league, user: user, attending_days: nil)
      reg.single_day?.should eq(false)
    end
  end

  describe "#chosen_day" do
    let(:league) { FactoryGirl.create(:league, game_days: ['tuesday', 'thursday']) }

    it "returns the only day for single-day" do
      reg = Registration.new(league: league, user: user, attending_days: ['tuesday'])
      reg.chosen_day.should eq('tuesday')
    end

    it "returns nil for two-day" do
      reg = Registration.new(league: league, user: user, attending_days: ['tuesday', 'thursday'])
      reg.chosen_day.should be_nil
    end
  end

  describe "#registration_type_label" do
    it "is nil when league does not require day choice" do
      league = FactoryGirl.create(:league, game_days: [])
      reg = Registration.new(league: league, user: user, attending_days: nil)
      reg.registration_type_label.should be_nil
    end

    it "is 'Two-day' when attending both days" do
      league = FactoryGirl.create(:league, game_days: ['tuesday', 'thursday'])
      reg = Registration.new(league: league, user: user, attending_days: ['tuesday', 'thursday'])
      reg.registration_type_label.should eq('Two-day')
    end

    it "names the chosen day for single-day" do
      league = FactoryGirl.create(:league, game_days: ['tuesday', 'thursday'])
      reg = Registration.new(league: league, user: user, attending_days: ['tuesday'])
      reg.registration_type_label.should eq('Tuesday only')
    end
  end

  describe "#participates_on?" do
    let(:league) { FactoryGirl.create(:league, game_days: ['tuesday', 'thursday']) }

    it "returns true when attending_days is nil (legacy)" do
      reg = Registration.new(league: league, user: user, attending_days: nil)
      reg.participates_on?('tuesday').should eq(true)
      reg.participates_on?('friday').should eq(true)
    end

    it "returns true when attending_days is empty" do
      reg = Registration.new(league: league, user: user, attending_days: [])
      reg.participates_on?('tuesday').should eq(true)
    end

    it "returns true when attending_days includes the day" do
      reg = Registration.new(league: league, user: user, attending_days: ['tuesday'])
      reg.participates_on?('tuesday').should eq(true)
    end

    it "returns false when attending_days excludes the day" do
      reg = Registration.new(league: league, user: user, attending_days: ['tuesday'])
      reg.participates_on?('thursday').should eq(false)
    end

    it "is case-insensitive on the input" do
      reg = Registration.new(league: league, user: user, attending_days: ['tuesday'])
      reg.participates_on?('Tuesday').should eq(true)
    end
  end

  describe "#day_choice_editable?" do
    let(:league) { FactoryGirl.create(:league, game_days: ['tuesday', 'thursday'], start_date: 2.weeks.from_now.to_date) }

    it "is true before the league starts" do
      reg = Registration.new(league: league, user: user)
      reg.day_choice_editable?.should eq(true)
    end

    it "is false once the league has started" do
      league.update_attributes!(start_date: 1.week.ago.to_date)
      reg = Registration.new(league: league, user: user)
      reg.day_choice_editable?.should eq(false)
    end
  end
end
```

- [ ] **Step 2: Run the specs, expect failure.**

Run: `bundle exec rspec spec/models/registration_spec.rb`
Expected: FAIL ("undefined method `attending_days`").

- [ ] **Step 3: Add the field and helpers to `app/models/registration.rb`.**

Add the field near other Hash/Array fields (e.g., after `field :availability, type: Hash`):

```ruby
field :attending_days, type: Array
```

Add the helper methods (place near `gender_noun`, before the pairing block):

```ruby
def single_day?
  attending_days.present? && attending_days.length == 1
end

def chosen_day
  return nil unless single_day?
  attending_days.first
end

def registration_type_label
  return nil unless league && league.requires_day_choice?
  return nil if attending_days.blank?
  if attending_days.length == 2
    'Two-day'
  else
    "#{attending_days.first.capitalize} only"
  end
end

def participates_on?(day_name)
  return true if attending_days.blank?
  attending_days.include?(day_name.to_s.downcase)
end

def day_choice_editable?
  return false if league.nil?
  !league.started?
end
```

- [ ] **Step 4: Run the specs, expect pass.**

Run: `bundle exec rspec spec/models/registration_spec.rb`
Expected: PASS.

- [ ] **Step 5: Commit.**

```bash
git add app/models/registration.rb spec/models/registration_spec.rb
git commit -m "Add Registration#attending_days field and registration-type helpers"
```

---

## Task 4: Add `attending_days` validation to Registration

**Goal:** When `league.requires_day_choice?`, `attending_days` must be present, length 1 or 2, and a subset of `league.game_days`. Early-flow saves bypass via `validate: false` and are unaffected.

**Files:**
- Modify: `app/models/registration.rb`
- Test: `spec/models/registration_spec.rb`

- [ ] **Step 1: Append failing specs to `spec/models/registration_spec.rb`.**

```ruby
describe "validation: attending_days" do
  let(:user_with_waiver) do
    u = FactoryGirl.create(:user)
    u
  end

  def build_reg(league, attrs = {})
    Registration.new({
      league: league, user: user_with_waiver,
      gen_availability: '100%', waiver_acceptance_date: Time.now
    }.merge(attrs))
  end

  context "when league does not require day choice" do
    let(:league) { FactoryGirl.create(:league, game_days: []) }

    it "is valid with attending_days nil" do
      build_reg(league, attending_days: nil).tap do |r|
        r.availability = { 'general' => '100%', 'attend_tourney_eos' => false }
        r.valid?
        r.errors[:attending_days].should be_empty
      end
    end
  end

  context "when league requires day choice" do
    let(:league) { FactoryGirl.create(:league, game_days: ['tuesday', 'thursday']) }

    def reg(attrs = {})
      r = build_reg(league, attrs)
      r.availability = { 'general' => '100%', 'attend_tourney_eos' => false }
      r
    end

    it "rejects nil attending_days" do
      r = reg(attending_days: nil)
      r.valid?
      r.errors[:attending_days].should be_present
    end

    it "rejects empty attending_days" do
      r = reg(attending_days: [])
      r.valid?
      r.errors[:attending_days].should be_present
    end

    it "rejects more than two days" do
      r = reg(attending_days: ['monday', 'tuesday', 'thursday'])
      r.valid?
      r.errors[:attending_days].should be_present
    end

    it "rejects days not in league.game_days" do
      r = reg(attending_days: ['monday'])
      r.valid?
      r.errors[:attending_days].should be_present
    end

    it "accepts a one-day subset" do
      r = reg(attending_days: ['tuesday'])
      r.valid?
      r.errors[:attending_days].should be_empty
    end

    it "accepts the full two-day set" do
      r = reg(attending_days: ['tuesday', 'thursday'])
      r.valid?
      r.errors[:attending_days].should be_empty
    end

    it "is bypassed by save(validate: false)" do
      r = reg(attending_days: nil)
      r.status = 'queued'
      r.save(validate: false).should eq(true)
    end
  end
end
```

- [ ] **Step 2: Run the specs, expect failure.**

Run: `bundle exec rspec spec/models/registration_spec.rb -e "validation: attending_days"`
Expected: FAIL.

- [ ] **Step 3: Add the validation to `app/models/registration.rb`.**

Find the existing `validate :has_valid_attendance_value, :has_signed_waiver` line and append the new validator:

```ruby
validate :has_valid_attendance_value, :has_signed_waiver, :has_valid_attending_days
```

Add the validator method near the bottom (alongside `has_valid_attendance_value`):

```ruby
def has_valid_attending_days
  return unless league && league.requires_day_choice?

  if attending_days.blank?
    errors.add(:attending_days, "Please choose your registration type (one-day or two-day).")
    return
  end

  if attending_days.length > 2 || attending_days.length < 1
    errors.add(:attending_days, "must contain 1 or 2 days.")
    return
  end

  invalid = attending_days - league.game_days
  if invalid.any?
    errors.add(:attending_days, "contains days not configured for this league: #{invalid.join(', ')}")
  end
end
```

- [ ] **Step 4: Run the specs, expect pass.**

Run: `bundle exec rspec spec/models/registration_spec.rb`
Expected: PASS.

- [ ] **Step 5: Commit.**

```bash
git add app/models/registration.rb spec/models/registration_spec.rb
git commit -m "Validate Registration#attending_days against league.game_days"
```

---

## Task 5: Wire `attending_days` into pricing

**Goal:** `ensure_price` picks up the single-day price when the registration is single-day. The behavior remains "only set when blank," so the controller is responsible for clearing `price` on type changes (handled in Task 10).

**Files:**
- Modify: `app/models/registration.rb`
- Test: `spec/models/registration_spec.rb`

- [ ] **Step 1: Append failing specs to `spec/models/registration_spec.rb`.**

```ruby
describe "#ensure_price" do
  let(:user) { FactoryGirl.create(:user) }
  let(:league) do
    FactoryGirl.create(:league, price: 80, price_single_day: 50, game_days: ['tuesday', 'thursday'])
  end

  it "uses two-day price when attending_days is the full set" do
    reg = Registration.new(league: league, user: user, attending_days: ['tuesday', 'thursday'])
    reg.send(:ensure_price)
    reg.price.should eq(80)
  end

  it "uses single-day price when attending_days has one entry" do
    reg = Registration.new(league: league, user: user, attending_days: ['tuesday'])
    reg.send(:ensure_price)
    reg.price.should eq(50)
  end

  it "uses two-day price when attending_days is nil (legacy / single-day league)" do
    legacy = FactoryGirl.create(:league, price: 80, game_days: [])
    reg = Registration.new(league: legacy, user: user, attending_days: nil)
    reg.send(:ensure_price)
    reg.price.should eq(80)
  end

  it "does not overwrite an already-set price" do
    reg = Registration.new(league: league, user: user, attending_days: ['tuesday'], price: 99)
    reg.send(:ensure_price)
    reg.price.should eq(99)
  end
end
```

- [ ] **Step 2: Run the specs, expect failure.**

Run: `bundle exec rspec spec/models/registration_spec.rb -e "ensure_price"`
Expected: FAIL — single-day case still returns 80.

- [ ] **Step 3: Update `ensure_price` in `app/models/registration.rb`.**

Replace the existing method:

```ruby
def ensure_price
  self.price = league.get_price(gender, single_day: single_day?) unless self.price.present?
end
```

- [ ] **Step 4: Run the specs, expect pass.**

Run: `bundle exec rspec spec/models/registration_spec.rb`
Expected: PASS.

- [ ] **Step 5: Commit.**

```bash
git add app/models/registration.rb spec/models/registration_spec.rb
git commit -m "Use single-day price in Registration#ensure_price"
```

---

## Task 6: Add game-days + single-day price controls to the league form

**Goal:** Commissioners can configure `game_days` and the two new price fields from the existing league form. Permit the new params on the controller. Light JS prevents picking more than 2 days client-side.

**Files:**
- Modify: `app/views/leagues/_form.html.haml`
- Modify: `app/controllers/leagues_controller.rb`

- [ ] **Step 1: Open `app/views/leagues/_form.html.haml`** and locate the price fields block (`.control-group{ class: ('error' if errors[:price].any?)}`). Above it (or wherever near the existing competition-dates block), add the Game Days control. Use **tabs** for indentation.

Add this control-group above the price block:

```haml
.control-group{ class: ('error' if errors[:game_days].any?)}
    %label.control-label Game Days
    .controls
        - %w(monday tuesday wednesday thursday friday saturday sunday).each do |day|
            %label.checkbox.inline{style: 'margin-right: 12px;'}
                = check_box_tag "league[game_days][]", day, @league.game_days.include?(day), class: 'game-days-checkbox'
                = day.capitalize
        %p.help-block Select up to 2. Leave all unchecked if the league doesn't run on fixed weekly days.
        - if errors[:game_days].any?
            %span.help-inline=errors[:game_days].first
```

Below the existing women's price block, add the single-day price block:

```haml
.control-group{ class: ('error' if errors[:price_single_day].any?)}
    %label.control-label Single-day Price
    .controls
        .input-prepend
            %span.add-on $
            =f.text_field :price_single_day, class: 'input-small'
        %p.help-block Used when a player registers for one day only. Leave blank to charge full price.
        - if errors[:price_single_day].any?
            %span.help-inline=errors[:price_single_day].first

.control-group{ class: ('error' if errors[:price_women_single_day].any?)}
    %label.control-label Women's Single-day Price
    .controls
        .input-prepend
            %span.add-on $
            =f.text_field :price_women_single_day, class: 'input-small'
        - if errors[:price_women_single_day].any?
            %span.help-inline=errors[:price_women_single_day].first
```

- [ ] **Step 2: Add the max-2-days JS to the existing `content_for :page_scripts` block** in the same file.

Inside the existing `:javascript` block (next to `$(".date-field").datepicker();`), add:

```javascript
function enforceMaxTwoGameDays() {
    var checked = $('.game-days-checkbox:checked').length;
    $('.game-days-checkbox').each(function() {
        if (!this.checked) {
            this.disabled = (checked >= 2);
        }
    });
}
$('.game-days-checkbox').on('change', enforceMaxTwoGameDays);
enforceMaxTwoGameDays();
```

- [ ] **Step 3: Permit the new params in `LeaguesController#league_params`.**

In `app/controllers/leagues_controller.rb`, find `def league_params` (around line 1277). Add the new keys to the `permitted_params` array:

```ruby
permitted_params = [
    :name, :age_division, :season, :sport, :price, :price_women, :pickup_price, :pickup_registration,
    :price_single_day, :price_women_single_day,
    :start_date, :end_date, :registration_open, :registration_close,
    :female_registration_open, :female_registration_close, :male_registration_open, :male_registration_close,
    :description, {commissioner_ids: []}, :male_limit, :female_limit,
    :max_grank_age, :allow_pairs, :covid_vax_required, :track_spirit_scores, :display_spirit_scores, :self_rank_type, :eos_tourney, :mst_tourney, :eos_champion_id, :mst_champion_id,
    {core_options: [:type, :male_limit, :female_limit, :rank_limit, :male_rank_constant, :female_rank_constant]}, :allow_pickups,
    :solicit_donations, :donation_earmark, :donation_pitch, :attendance_enabled,
    {game_days: []}
]
```

- [ ] **Step 4: Manual smoke test.**

Run: `bundle exec rails server` (or `foreman start` per `DevProcfile`).
Open the league edit form for any test league. Verify:
- Seven Game Days checkboxes appear.
- Checking a third checkbox is blocked client-side.
- Single-day Price and Women's Single-day Price fields appear.
- Saving the form persists `game_days` (use `League.last.game_days` in `rails console`).

- [ ] **Step 5: Commit.**

```bash
git add app/views/leagues/_form.html.haml app/controllers/leagues_controller.rb
git commit -m "Add game_days and single-day price controls to league form"
```

---

## Task 7: Routes for the day-choice interstitial

**Goal:** Two new league member routes for the interstitial.

**Files:**
- Modify: `config/routes.rb`

- [ ] **Step 1: Read the current `resources :leagues do ... member do` block.**

Run: `sed -n '43,93p' config/routes.rb`

- [ ] **Step 2: Add routes inside the `member do` block** (place near the existing `get 'register'`):

```ruby
get  'choose_days'
post 'choose_days', action: 'submit_day_choice'
```

- [ ] **Step 3: Verify the routes load.**

Run: `bundle exec rake routes 2>&1 | grep choose_days`
Expected: Two lines, `choose_days_league GET ... :leagues#choose_days` and `... POST ... :leagues#submit_day_choice`.

- [ ] **Step 4: Commit.**

```bash
git add config/routes.rb
git commit -m "Add choose_days routes for day-of-week registration interstitial"
```

---

## Task 8: Add day-choice gate to `register` action

**Goal:** When a league `requires_day_choice?` and the registration's `attending_days` is blank, both the resumed `is_registering?` branch and the fresh-registration branch redirect to `choose_days`.

**Files:**
- Modify: `app/controllers/leagues_controller.rb`
- Test: `spec/controllers/leagues_controller_day_choice_spec.rb` (new)

- [ ] **Step 1: Create `spec/controllers/leagues_controller_day_choice_spec.rb` with failing specs.**

```ruby
require 'spec_helper'

describe LeaguesController, type: :controller do
  let(:user)   { FactoryGirl.create(:user, gender: 'male') }
  let(:league) do
    FactoryGirl.create(:league,
      game_days: ['tuesday', 'thursday'],
      registration_open: 1.week.ago.to_date,
      registration_close: 1.week.from_now.to_date,
      male_limit: 30, female_limit: 30
    )
  end

  before do
    session[:user_id] = user._id
    controller.stub(:current_user).and_return(user)
    User.any_instance.stub(:valid?).and_return(true)
    User.any_instance.stub(:needs_grank_update_for_league?).and_return(false)
  end

  describe "GET #register on a two-day league" do
    it "redirects to choose_days when there's no existing registration" do
      get :register, id: league._id
      response.should redirect_to(choose_days_league_path(league))
    end

    it "redirects to choose_days when resuming a registering registration with blank attending_days" do
      reg = Registration.new(league: league, user: user, status: 'registering', expires_at: 1.hour.from_now)
      reg.save(validate: false)
      get :register, id: league._id
      response.should redirect_to(choose_days_league_path(league))
    end

    it "renders edit when attending_days is already set" do
      reg = Registration.new(league: league, user: user, status: 'registering', expires_at: 1.hour.from_now, attending_days: ['tuesday'])
      reg.save(validate: false)
      get :register, id: league._id
      response.should render_template('registrations/edit')
    end
  end

  describe "GET #register on a one-day or no-day league" do
    let(:single_day_league) do
      FactoryGirl.create(:league,
        game_days: ['tuesday'],
        registration_open: 1.week.ago.to_date,
        registration_close: 1.week.from_now.to_date,
        male_limit: 30
      )
    end

    it "renders edit (no interstitial)" do
      get :register, id: single_day_league._id
      response.should render_template('registrations/edit')
    end
  end
end
```

- [ ] **Step 2: Run the specs, expect failure.**

Run: `bundle exec rspec spec/controllers/leagues_controller_day_choice_spec.rb -e "GET #register"`
Expected: FAIL — no redirect happens.

- [ ] **Step 3: Add a private helper and the gate to `LeaguesController`.**

Open `app/controllers/leagues_controller.rb`. Find the `register` action (around line 399). Add a private helper near the bottom of the class (alongside `league_params`):

```ruby
def needs_day_choice_first?(reg)
  reg.present? && @league.requires_day_choice? && reg.attending_days.blank?
end
```

Modify the `register` action to insert the gate at both render-edit paths. Replace the action body to look like:

```ruby
def register
    registrar = PlayerRegistrar.new(@league, current_user)
    existing_registration = registrar.registration

    if (existing_registration)
        if existing_registration.status == 'active'
            redirect_to registrations_user_path(current_user), notice: "You've already registered for that league."
            return
        end

        if existing_registration.is_registering?
            if needs_day_choice_first?(existing_registration)
                redirect_to choose_days_league_path(@league)
                return
            end
            @registration = existing_registration
            render "registrations/edit"
            return
        end

        if existing_registration.status == 'waitlisted'
            redirect_to league_path(@league), flash: {error: "You're currently on the wait list. Please watch your email to see if you'll get in."}
            return
        end
    end

    if (registrar.open? == false)
        redirect_to league_path(@league), notice: "Registration is not open for that league yet."
        return
    end

    if registrar.needs_profile_update?
        redirect_to edit_user_path(current_user), notice: "Your user profile is incomplete, you must update it before registering."
        return
    end

    if current_user.needs_grank_update_for_league?(@league)
        session[:post_grank_redirect] = register_league_path(@league)
        redirect_to edit_g_rank_profile_path, notice: "Your gRank score is out of date, please complete the survey before registering."
        return
    end

    @registration = registrar.initialize_registration!

    if needs_day_choice_first?(@registration)
        redirect_to choose_days_league_path(@league)
        return
    end

    render "registrations/edit"
end
```

- [ ] **Step 4: Run the specs, expect pass.**

Run: `bundle exec rspec spec/controllers/leagues_controller_day_choice_spec.rb`
Expected: PASS.

- [ ] **Step 5: Commit.**

```bash
git add app/controllers/leagues_controller.rb spec/controllers/leagues_controller_day_choice_spec.rb
git commit -m "Gate registration form behind day-choice interstitial"
```

---

## Task 9: Implement `choose_days` and `submit_day_choice` actions

**Goal:** GET renders the interstitial; POST validates submission, persists `attending_days`, clears `price` for pre-pay states, and redirects appropriately. Both actions reject when the league has started.

**Files:**
- Modify: `app/controllers/leagues_controller.rb`
- Test: `spec/controllers/leagues_controller_day_choice_spec.rb`

- [ ] **Step 1: Append failing specs.**

```ruby
describe "GET #choose_days" do
  before do
    Registration.new(league: league, user: user, status: 'registering', expires_at: 1.hour.from_now)
              .save(validate: false)
  end

  it "renders the interstitial" do
    get :choose_days, id: league._id
    response.should render_template(:choose_days)
  end

  it "rejects when the league has started" do
    league.update_attributes!(start_date: 1.week.ago.to_date)
    get :choose_days, id: league._id
    response.should redirect_to(registration_path(league.registration_for(user)))
    flash[:error].should match(/already started/i)
  end

  it "rejects when there is no in-progress registration" do
    league.registrations.destroy_all
    get :choose_days, id: league._id
    response.should redirect_to(league_path(league))
  end
end

describe "POST #submit_day_choice (new-registration flow)" do
  before do
    Registration.new(league: league, user: user, status: 'registering', expires_at: 1.hour.from_now)
              .save(validate: false)
  end

  def reg
    league.registration_for(user)
  end

  it "persists attending_days and redirects back to register" do
    post :submit_day_choice, id: league._id, attending_days: ['tuesday']
    reg.attending_days.should eq(['tuesday'])
    response.should redirect_to(register_league_path(league))
  end

  it "clears price so ensure_price recomputes for the new type" do
    reg.update_attributes(price: 80) # pretend two-day price was already set
    post :submit_day_choice, id: league._id, attending_days: ['tuesday']
    league.update_attributes!(price_single_day: 50)
    # the controller should have nilled price; next save will pick up single-day
    reg.price.should be_nil
  end

  it "rejects an empty submission" do
    post :submit_day_choice, id: league._id, attending_days: []
    response.should render_template(:choose_days)
    flash.now[:error].should be_present
  end

  it "rejects days outside league.game_days" do
    post :submit_day_choice, id: league._id, attending_days: ['monday']
    response.should render_template(:choose_days)
    flash.now[:error].should be_present
  end

  it "rejects more than two days" do
    post :submit_day_choice, id: league._id, attending_days: ['tuesday', 'thursday', 'monday']
    response.should render_template(:choose_days)
    flash.now[:error].should be_present
  end
end

describe "POST #submit_day_choice (change-later flow)" do
  before do
    Registration.new(league: league, user: user, status: 'active', attending_days: ['tuesday', 'thursday'], price: 80, paid: true)
              .save(validate: false)
  end

  def reg
    league.registration_for(user)
  end

  it "persists the change and redirects to registration#show" do
    post :submit_day_choice, id: league._id, attending_days: ['tuesday']
    reg.attending_days.should eq(['tuesday'])
    response.should redirect_to(registration_path(reg))
  end

  it "does NOT clear price for active registrations" do
    post :submit_day_choice, id: league._id, attending_days: ['tuesday']
    reg.price.should eq(80)
  end

  it "is rejected once the league has started" do
    league.update_attributes!(start_date: 1.week.ago.to_date)
    post :submit_day_choice, id: league._id, attending_days: ['tuesday']
    response.should redirect_to(registration_path(reg))
    flash[:error].should match(/already started/i)
  end
end
```

- [ ] **Step 2: Run the specs, expect failure.**

Run: `bundle exec rspec spec/controllers/leagues_controller_day_choice_spec.rb -e "choose_days"`
Expected: FAIL — actions don't exist yet.

- [ ] **Step 3: Implement both actions in `app/controllers/leagues_controller.rb`.**

Place near the existing `register` action:

```ruby
def choose_days
    @registration = @league.registration_for(current_user)

    if @registration.nil?
        redirect_to league_path(@league), flash: {error: "You don't have a registration in progress for this league."}
        return
    end

    if @league.started?
        redirect_to registration_path(@registration), flash: {error: "This league has already started. Please contact a commissioner if your registration type needs to change."}
        return
    end

    unless @league.requires_day_choice?
        redirect_to register_league_path(@league)
        return
    end
end

def submit_day_choice
    @registration = @league.registration_for(current_user)

    if @registration.nil?
        redirect_to league_path(@league), flash: {error: "You don't have a registration in progress for this league."}
        return
    end

    if @league.started?
        redirect_to registration_path(@registration), flash: {error: "This league has already started. Please contact a commissioner if your registration type needs to change."}
        return
    end

    submitted = Array(params[:attending_days]).compact.reject(&:blank?)

    error = validate_day_choice_submission(submitted)
    if error
        flash.now[:error] = error
        render :choose_days
        return
    end

    @registration.attending_days = submitted

    pre_pay_statuses = %w(queued registering registering_waitlisted)
    if !@registration.paid && pre_pay_statuses.include?(@registration.status)
        @registration.price = nil
    end

    @registration.save(validate: false)

    if pre_pay_statuses.include?(@registration.status)
        redirect_to register_league_path(@league)
    else
        redirect_to registration_path(@registration), notice: "Registration type updated. Contact help@afdc.com if you need a price adjustment."
    end
end
```

Add the validator helper next to `league_params`:

```ruby
def validate_day_choice_submission(submitted)
    return "Please choose your registration type." if submitted.empty?
    return "You can choose at most 2 days." if submitted.size > 2

    invalid = submitted - @league.game_days
    return "Selected day(s) are not configured for this league: #{invalid.join(', ')}" if invalid.any?

    nil
end
```

- [ ] **Step 4: Run the specs, expect pass.**

Run: `bundle exec rspec spec/controllers/leagues_controller_day_choice_spec.rb`
Expected: PASS — except the spec test that renders `:choose_days` will fail because the view doesn't exist yet. That's expected. Add a stub view to satisfy the test for now:

```bash
mkdir -p app/views/leagues
touch app/views/leagues/choose_days.html.haml
```

Then re-run. Expected: PASS. (The real view goes in Task 10.)

- [ ] **Step 5: Commit.**

```bash
git add app/controllers/leagues_controller.rb spec/controllers/leagues_controller_day_choice_spec.rb app/views/leagues/choose_days.html.haml
git commit -m "Implement choose_days and submit_day_choice actions"
```

---

## Task 10: Build the interstitial view

**Goal:** Render the two-card UI described in the spec, with type framing, change-later helper text, and pre-selection on the change path.

**Files:**
- Modify: `app/views/leagues/choose_days.html.haml`

- [ ] **Step 1: Replace the file contents.** Use **tabs** for indentation.

```haml
- content_for :title, @league.name
= render :partial => '/pageheader', :locals => {subtitle: 'Choose Your Registration Type', breadcrumbs: {'Leagues' => leagues_path, @league.name => league_path(@league), 'Registration Type' => nil}}

- two_day_price = @league.get_price(@registration.gender || current_user.gender, single_day: false)
- single_day_price = @league.get_price(@registration.gender || current_user.gender, single_day: true)
- day1, day2 = @league.game_days
- current = @registration.attending_days || []

- if flash.now[:error]
    .alert.alert-error= flash.now[:error]

.row
    .span12
        %h2 Choose your registration type
        %p.lead
            #{@league.name} plays on #{day1.capitalize} and #{day2.capitalize}. Two registration types are available.

= form_tag choose_days_league_path(@league), method: :post, id: 'day-choice-form' do
    .row
        .span6
            %label.day-choice-card{for: 'choice_two_day', style: 'display: block; padding: 24px; border: 2px solid #ddd; border-radius: 8px; cursor: pointer; min-height: 240px;'}
                %input{type: 'radio', name: 'registration_type', id: 'choice_two_day', value: 'two_day', checked: (current.length == 2), style: 'display: none;'}
                %h3 Two-day registration
                %p Drafted as a regular two-night player on
                    %strong= " #{day1.capitalize} and #{day2.capitalize}."
                %p.text-success
                    %strong= "$#{two_day_price}"
        .span6
            %label.day-choice-card{for: 'choice_one_day', style: 'display: block; padding: 24px; border: 2px solid #ddd; border-radius: 8px; cursor: pointer; min-height: 240px;'}
                %input{type: 'radio', name: 'registration_type', id: 'choice_one_day', value: 'one_day', checked: (current.length == 1), style: 'display: none;'}
                %h3 One-day registration
                %p.muted
                    %em Only able to play one night a week?
                %p
                    A one-day registration is its own thing — you're signing up to be a one-night-a-week player, full stop. Captains will know that going into the draft and build their roster accordingly. If you happen to be free for an extra game on the other night, you're welcome to come, but nothing about your team will be counting on it.
                %p.text-success
                    %strong= "$#{single_day_price}"
                #one-day-day-pickers{style: ('display: none;' unless current.length == 1)}
                    %p
                        %strong Which day?
                    .btn-group{'data-toggle' => 'buttons-radio'}
                        - @league.game_days.each do |day|
                            %label.btn.btn-large{class: ('active' if current == [day])}
                                %input{type: 'radio', name: 'one_day_pick', value: day, checked: (current == [day])}
                                = day.capitalize

    %input{type: 'hidden', name: 'attending_days[]', id: 'attending_days_hidden_a', value: ''}
    %input{type: 'hidden', name: 'attending_days[]', id: 'attending_days_hidden_b', value: ''}

    .form-actions
        %button.btn.btn-primary.btn-large#continue-btn{type: 'submit', disabled: true} Continue
        - if current.any?
            = link_to "Cancel", registration_path(@registration), class: 'btn btn-link'
        %p.muted{style: 'margin-top: 12px;'} You can change this at any point before the draft.

- content_for :page_scripts do
    :javascript
        $(function(){
            var $form = $('#day-choice-form');
            var $continue = $('#continue-btn');
            var $hiddenA = $('#attending_days_hidden_a');
            var $hiddenB = $('#attending_days_hidden_b');
            var leagueDays = #{@league.game_days.to_json.html_safe};

            function updateHiddenInputs() {
                var type = $form.find('input[name=registration_type]:checked').val();
                $hiddenA.val('');
                $hiddenB.val('');
                if (type === 'two_day') {
                    $hiddenA.val(leagueDays[0]);
                    $hiddenB.val(leagueDays[1]);
                    $continue.prop('disabled', false);
                } else if (type === 'one_day') {
                    var pick = $form.find('input[name=one_day_pick]:checked').val();
                    $('#one-day-day-pickers').show();
                    if (pick) {
                        $hiddenA.val(pick);
                        $continue.prop('disabled', false);
                    } else {
                        $continue.prop('disabled', true);
                    }
                } else {
                    $('#one-day-day-pickers').hide();
                    $continue.prop('disabled', true);
                }
                $('.day-choice-card').css('border-color', '#ddd');
                $form.find('input[name=registration_type]:checked')
                    .closest('.day-choice-card').css('border-color', '#3a87ad');
            }

            $form.on('change', 'input[name=registration_type], input[name=one_day_pick]', updateHiddenInputs);
            updateHiddenInputs();
        });
```

- [ ] **Step 2: Manual smoke test.**

Run: `bundle exec rails server`. As a logged-in user, visit `/leagues/<id>/register` for a two-day league. Confirm:
- The interstitial appears.
- Selecting "Two-day" enables Continue and submits both days.
- Selecting "One-day" reveals the day buttons and disables Continue until one is picked.
- After submitting, the standard registration form loads.
- Returning later (a "Change my registration type" link is added in Task 12) pre-selects the existing choice.

- [ ] **Step 3: Re-run the controller specs to confirm nothing regressed.**

Run: `bundle exec rspec spec/controllers/leagues_controller_day_choice_spec.rb`
Expected: PASS.

- [ ] **Step 4: Commit.**

```bash
git add app/views/leagues/choose_days.html.haml
git commit -m "Add interstitial view for day-of-week registration type"
```

---

## Task 11: Show registration type and "change" link on registration#show

**Goal:** Players see their registration type and can re-enter the interstitial to change it before the league starts.

**Files:**
- Modify: `app/views/registrations/show.html.haml`

- [ ] **Step 1: Read the existing summary block** to find a good insertion point near the existing `%dt Status:` row.

Run: `sed -n '40,80p' app/views/registrations/show.html.haml`

- [ ] **Step 2: Add the registration-type row near `%dt Status:`** in `app/views/registrations/show.html.haml`. Use **tabs**.

```haml
- if @registration.registration_type_label
    %dt Registration Type:
    %dd
        = @registration.registration_type_label
        - if @registration.day_choice_editable?
            &nbsp;
            = link_to "Change", choose_days_league_path(@registration.league), class: 'btn btn-mini'
```

Place this block immediately after the `%dt Status:` / `%dd= @registration.status` rows.

- [ ] **Step 3: Manual smoke test.**

Run: `bundle exec rails server`. Visit a registration's show page. For a two-day league registration, confirm the new row appears with a working "Change" button. For a non-two-day league, confirm the row is absent.

- [ ] **Step 4: Commit.**

```bash
git add app/views/registrations/show.html.haml
git commit -m "Surface registration type and change link on registration show"
```

---

## Task 12: Include `attending_days` and `day_label` in `reg_data`

**Goal:** The Tabulator-driven views consume `reg_list.json`. Adding `attending_days` and a derived `day_label` to each row's payload feeds the columns/filters added in subsequent tasks.

**Files:**
- Modify: `app/controllers/leagues_controller.rb`

- [ ] **Step 1: Find the `reg_data` method** (around line 660 in `app/controllers/leagues_controller.rb`).

Run: `grep -n "def reg_data" app/controllers/leagues_controller.rb`

- [ ] **Step 2: Add `attending_days` and `day_label` to the returned hash.**

In the hash literal at the bottom of the method (after `type: "individual"`), insert:

```ruby
            attending_days: reg.attending_days || [],
            day_label: reg.registration_type_label || '',
```

So the tail of the hash looks like:

```ruby
            waitlist_timestamp: waitlist_timestamp,
            attending_days: reg.attending_days || [],
            day_label: reg.registration_type_label || '',
            type: "individual"
```

- [ ] **Step 3: Manual smoke test.**

Run: `bundle exec rails server`. Visit `/leagues/<id>/reg_list.json`. Confirm each registrant row now includes `attending_days` and `day_label`.

- [ ] **Step 4: Commit.**

```bash
git add app/controllers/leagues_controller.rb
git commit -m "Expose attending_days and day_label in reg_data for management tables"
```

---

## Task 13: Add Days column + filter to player-management Tabulator views

**Goal:** Both `players.html.erb` (manage-players) and `registrations.html.erb` (read-only league players) gain a Days column with filtering.

**Files:**
- Modify: `app/views/leagues/players.html.erb`
- Modify: `app/views/leagues/registrations.html.erb`

- [ ] **Step 1: In `app/views/leagues/players.html.erb`**, find the `columns` array passed to `new Tabulator("#registrant-data", { ... })` (around line 219). Insert a new column entry after `Notes`:

```javascript
                {
                    title: "Days",
                    field: "day_label",
                    headerFilter: "list",
                    headerFilterParams: {
                        valuesLookup: "all",
                        valuesLookupField: "day_label",
                        clearable: true
                    },
                    formatter: function(cell) {
                        var v = cell.getValue();
                        if (!v) return "";
                        var cls = (v === "Two-day") ? "label" : "label label-warning";
                        return "<span class=\"" + cls + "\">" + v + "</span>";
                    }
                },
```

- [ ] **Step 2: Repeat in `app/views/leagues/registrations.html.erb`** (around line 152, after the `Notes` column).

Add the same column object to the `columns` array there.

- [ ] **Step 3: Manual smoke test.**

Run: `bundle exec rails server`. Visit `/leagues/<two-day-league-id>/players` and `/leagues/<id>/registrations`. Confirm:
- The "Days" column appears.
- "One-day" entries appear with a warning-colored badge.
- Filtering by `Two-day` / `Tuesday only` / `Thursday only` works.
- Two-day leagues with no one-day registrants show only `Two-day` (or all blanks if it's a one/zero-day league).

- [ ] **Step 4: Commit.**

```bash
git add app/views/leagues/players.html.erb app/views/leagues/registrations.html.erb
git commit -m "Add Days column with filter to league management Tabulator views"
```

---

## Task 14: Add Days info to the drafting view (`manage_roster`)

**Goal:** The drafting page surfaces the registration type per player. `manage_roster.html.haml` currently embeds the same Tabulator data via `players.html.erb` (it does not — re-check). For this task the simplest, highest-leverage change is to add a small note block above the registrant table summarizing how many one-day players exist and which days they cover.

**Files:**
- Modify: `app/views/leagues/manage_roster.html.haml`
- Modify: `app/controllers/leagues_controller.rb`

- [ ] **Step 1: In `LeaguesController#manage_roster`** (around line 956), add a one-day-summary aggregation. Append after the existing intruder/orphan logic:

```ruby
        @one_day_summary = {}
        if @league.requires_day_choice?
            @league.game_days.each do |day|
                @one_day_summary[day] = @league.registrations.active.select { |r| r.attending_days == [day] }.count
            end
        end
```

- [ ] **Step 2: In `app/views/leagues/manage_roster.html.haml`** (use **tabs**), add a section under the existing Basic Statistics block:

```haml
        - if @league.requires_day_choice?
            %h4 Registration Types
            %ul
                - @league.game_days.each do |day|
                    %li
                        %span= "#{day.capitalize}-only:"
                        %strong= @one_day_summary[day]
                %li
                    %span Two-day:
                    %strong= @league.registrations.active.where(attending_days: @league.game_days).count
            %p.muted Use the Days column on the player list to drill into a specific cohort.
```

- [ ] **Step 3: Manual smoke test.**

Run: `bundle exec rails server`. Open `/leagues/<two-day-league-id>/manage_roster` after seeding a few one-day registrations. Confirm the new section appears with accurate counts.

- [ ] **Step 4: Commit.**

```bash
git add app/views/leagues/manage_roster.html.haml app/controllers/leagues_controller.rb
git commit -m "Show registration-type summary on roster management view"
```

---

## Task 15: Add CSV export columns for `attending_days` / `registration_type`

**Goal:** The registrations CSV gains two columns so downstream draft/analysis tools see the type.

**Files:**
- Modify: `app/views/leagues/registrations.csv.haml`

- [ ] **Step 1: Open `app/views/leagues/registrations.csv.haml`** and find the `headers` line.

```haml
- headers.push(*%w(exp_rank ath_rank skl_rank)) if @league.self_rank_type == "detailed"
- headers.push(*%w(firstname lastname pronouns email matchup covid_vax availability notes birthdate height EOST))
```

After the `EOST` push, append:

```haml
- headers.push('attending_days') if @league.requires_day_choice?
- headers.push('registration_type') if @league.requires_day_choice?
```

- [ ] **Step 2: In the row block (after the existing `row << r.eos_availability` line),** append:

```haml
    - if @league.requires_day_choice?
        - row << (r.attending_days || []).join(';')
        - row << (r.registration_type_label || '')
```

(Note the use of `;` as a within-cell separator so the CSV's row separator stays unambiguous.)

- [ ] **Step 3: Manual smoke test.**

Run: `bundle exec rails server`. Download `/leagues/<two-day-league-id>/registrations.csv`. Confirm the two new columns appear and have correct values.

- [ ] **Step 4: Commit.**

```bash
git add app/views/leagues/registrations.csv.haml
git commit -m "Add attending_days and registration_type to registrations CSV"
```

---

## Task 16: Add `Game#day_name` helper

**Goal:** The attendance worker needs a canonical lowercase day name per game in `LOCAL_TIMEZONE`. Adding the helper to `Game` keeps the timezone logic in one place.

**Files:**
- Modify: `app/models/game.rb`
- Test: `spec/models/game_spec.rb` (new — small)

- [ ] **Step 1: Create `spec/models/game_spec.rb`.**

```ruby
require 'spec_helper'

describe Game do
  describe "#day_name" do
    it "returns the lowercase day-of-week of game_time in LOCAL_TIMEZONE" do
      league = FactoryGirl.create(:league)
      g = Game.new(league: league, game_time: LOCAL_TIMEZONE.parse('2026-05-12 19:00')) # Tuesday
      g.day_name.should eq('tuesday')
    end

    it "respects timezone (US Eastern boundary case)" do
      league = FactoryGirl.create(:league)
      # 2026-05-13 00:30 UTC == 2026-05-12 20:30 ET => Tuesday
      g = Game.new(league: league, game_time: Time.utc(2026, 5, 13, 0, 30))
      g.day_name.should eq('tuesday')
    end
  end
end
```

- [ ] **Step 2: Run the spec, expect failure.**

Run: `bundle exec rspec spec/models/game_spec.rb`
Expected: FAIL.

- [ ] **Step 3: Add the helper to `app/models/game.rb`.**

After the existing `def game_time` method:

```ruby
def day_name
    game_time.strftime('%A').downcase
end
```

- [ ] **Step 4: Run the spec, expect pass.**

Run: `bundle exec rspec spec/models/game_spec.rb`
Expected: PASS.

- [ ] **Step 5: Commit.**

```bash
git add app/models/game.rb spec/models/game_spec.rb
git commit -m "Add Game#day_name helper for attendance day-filtering"
```

---

## Task 17: Suppress attendance prompts for non-attending days

**Goal:** `AttendancePromptWorker` skips creating prompts for players whose `participates_on?(game.day_name)` is false.

**Files:**
- Modify: `app/workers/attendance_prompt_worker.rb`
- Modify: `spec/workers/attendance_prompt_worker_spec.rb`

- [ ] **Step 1: Append failing specs to `spec/workers/attendance_prompt_worker_spec.rb`.**

```ruby
describe "day-of-week filtering" do
  let(:two_day_league) do
    FactoryGirl.create(:league,
      attendance_enabled: true,
      game_days: ['tuesday', 'thursday']
    )
  end
  let(:two_day_team) { FactoryGirl.create(:team, league: two_day_league) }
  let(:tuesday_only_player) { FactoryGirl.create(:user) }
  let(:both_days_player)   { FactoryGirl.create(:user) }

  before do
    two_day_team.players = [tuesday_only_player._id, both_days_player._id]
    two_day_team.save!
    Registration.new(league: two_day_league, user: tuesday_only_player, status: 'active', attending_days: ['tuesday']).save(validate: false)
    Registration.new(league: two_day_league, user: both_days_player, status: 'active', attending_days: ['tuesday', 'thursday']).save(validate: false)
    [tuesday_only_player, both_days_player].each do |u|
      FactoryGirl.create(:notification_method, user: u)
    end
  end

  def make_game_in_two_day_league(game_day, time = '7:00pm')
    g = Game.new(league: two_day_league, game_time: LOCAL_TIMEZONE.parse("#{game_day} #{time}"))
    g[:teams] = [two_day_team._id]
    g.save!
    g
  end

  it "creates a prompt for both-days player on a Thursday game" do
    thursday = (Date.current + 4)
    while thursday.strftime('%A').downcase != 'thursday'
      thursday += 1
    end
    AttendancePromptWorker::INITIAL_LEAD_DAYS.tap do |lead|
      # skip — we'll just compute today + lead and verify the day is what we want
    end
    # Instead: pick a real Thursday >= 4 days out and configure the worker to fire for it
    actual_day = thursday
    make_game_in_two_day_league(actual_day)
    # The worker uses today + INITIAL_LEAD_DAYS. Stub Date.current so that today + 4 == actual_day.
    Date.stub(:current).and_return(actual_day - AttendancePromptWorker::INITIAL_LEAD_DAYS)
    AttendancePromptWorker.new.perform
    AttendancePrompt.where(team_id: two_day_team._id, game_day: actual_day, user_id: both_days_player._id).count.should eq(1)
  end

  it "does NOT create a prompt for tuesday-only player on a Thursday game" do
    thursday = (Date.current + 4)
    while thursday.strftime('%A').downcase != 'thursday'
      thursday += 1
    end
    actual_day = thursday
    make_game_in_two_day_league(actual_day)
    Date.stub(:current).and_return(actual_day - AttendancePromptWorker::INITIAL_LEAD_DAYS)
    AttendancePromptWorker.new.perform
    AttendancePrompt.where(team_id: two_day_team._id, game_day: actual_day, user_id: tuesday_only_player._id).count.should eq(0)
  end

  it "creates a prompt for tuesday-only player on a Tuesday game" do
    tuesday = (Date.current + 4)
    while tuesday.strftime('%A').downcase != 'tuesday'
      tuesday += 1
    end
    actual_day = tuesday
    make_game_in_two_day_league(actual_day)
    Date.stub(:current).and_return(actual_day - AttendancePromptWorker::INITIAL_LEAD_DAYS)
    AttendancePromptWorker.new.perform
    AttendancePrompt.where(team_id: two_day_team._id, game_day: actual_day, user_id: tuesday_only_player._id).count.should eq(1)
  end

  it "still creates prompts for legacy players (attending_days nil)" do
    # Existing behavior remains: nil/empty == participates everywhere.
    tuesday = (Date.current + 4)
    while tuesday.strftime('%A').downcase != 'tuesday'
      tuesday += 1
    end
    legacy_player = FactoryGirl.create(:user)
    two_day_team.players = two_day_team.players + [legacy_player._id]
    two_day_team.save!
    Registration.new(league: two_day_league, user: legacy_player, status: 'active', attending_days: nil).save(validate: false)
    FactoryGirl.create(:notification_method, user: legacy_player)
    make_game_in_two_day_league(tuesday)
    Date.stub(:current).and_return(tuesday - AttendancePromptWorker::INITIAL_LEAD_DAYS)
    AttendancePromptWorker.new.perform
    AttendancePrompt.where(team_id: two_day_team._id, game_day: tuesday, user_id: legacy_player._id).count.should eq(1)
  end
end
```

- [ ] **Step 2: Run the specs, expect failure.**

Run: `bundle exec rspec spec/workers/attendance_prompt_worker_spec.rb -e "day-of-week filtering"`
Expected: FAIL — tuesday-only player gets a Thursday prompt.

- [ ] **Step 3: Add the filter to `app/workers/attendance_prompt_worker.rb`.**

In `process_initial_for`, modify the inner loop:

```ruby
def process_initial_for(league, game_day)
  games = league.games.where(:game_time.gte => game_day.beginning_of_day,
                             :game_time.lte => game_day.end_of_day).to_a
  teams_for_day = group_games_by_team(games)
  day_label = game_day.strftime('%A').downcase
  teams_for_day.each do |team_id, day_games|
    next if all_rained_out?(day_games)
    team = Team.find(team_id)
    team.players.each do |player|
      reg = league.registration_for(player)
      next if reg.present? && !reg.participates_on?(day_label)
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
```

(Reminders are already only sent to existing pending prompts, so the same registration filter implicitly applies — no change needed in `process_reminder_for`.)

- [ ] **Step 4: Run the spec, expect pass.**

Run: `bundle exec rspec spec/workers/attendance_prompt_worker_spec.rb`
Expected: PASS — including the existing tests.

- [ ] **Step 5: Commit.**

```bash
git add app/workers/attendance_prompt_worker.rb spec/workers/attendance_prompt_worker_spec.rb
git commit -m "Suppress attendance prompts for non-attending days in two-day leagues"
```

---

## Task 18: Render filtered-out players in the captain dashboard

**Goal:** Captains see one-day players on the night they aren't playing, with a clear "single-day registration — not playing this night" label, instead of the players silently disappearing.

**Files:**
- Modify: `app/views/teams/attendance.html.haml`
- Modify: `app/controllers/teams_controller.rb` (only if data isn't already plumbed)

- [ ] **Step 1: Inspect `app/views/teams/attendance.html.haml`** to see what data is in scope (`@team`, `@upcoming_days`, `@prompts_by_day`).

Run: `sed -n '1,80p' app/views/teams/attendance.html.haml`

- [ ] **Step 2: In the player-loop block** (where `gender_players.each do |player|`), modify the rendering so non-participating players appear in a muted row instead of a regular row.

Find this block:

```haml
- gender_players.each do |player|
    - prompt = @prompts_by_day[day].detect { |p| p.user_id == player._id }
    %tr
        %td= "#{player.firstname} #{player.lastname}"
        %td
            ...
```

Change the `%tr` line and the cell sequence to:

```haml
- gender_players.each do |player|
    - prompt = @prompts_by_day[day].detect { |p| p.user_id == player._id }
    - reg = @team.league.registration_for(player)
    - participates = reg.nil? || reg.participates_on?(day.strftime('%A').downcase)
    %tr{class: ('muted' unless participates), style: ('color: #999;' unless participates)}
        %td
            = "#{player.firstname} #{player.lastname}"
            - unless participates
                %br
                %small
                    %em Single-day registration — not playing this night
        %td
            - if !participates
                %em —
            - elsif prompt && prompt.status != 'pending'
                = prompt.status.upcase
            - else
                %em Not answered
        %td= participates ? (prompt && prompt.note) : ''
        %td= participates ? (prompt && prompt.response_method) : ''
        %td
            - if participates && prompt
                = form_tag attendance_override_team_path(@team), method: :patch, style: 'display:inline' do
                    = hidden_field_tag :prompt_id, prompt._id
                    = select_tag :status, options_for_select([['Yes','yes'],['No','no'],['Partial','partial']], prompt.status), prompt: 'Override...'
                    = text_field_tag :note, '', placeholder: 'note', size: 12
                    = submit_tag 'Override', class: 'btn btn-mini'
```

The exact cell layout in the original may differ — preserve all existing columns and only branch on `participates`.

- [ ] **Step 3: Update the count summary** so non-participating players don't inflate "Not answered."

Find the gender-counts block (`%span.label= "❓ #{counts[gender.to_sym][:not_answered]}"`). The simplest fix is to compute `counts` from the same predicate. Adjust the controller (`TeamsController#attendance`) to skip non-participating players when building `counts_by_day`. Locate the action:

Run: `grep -n "def attendance\b\|counts_by_day" app/controllers/teams_controller.rb`

Modify the count construction to skip non-participating players. (The exact code depends on the existing implementation; the contract is: a player not participating on `day` does not contribute to `:yes` / `:no` / `:not_answered` for that day.)

- [ ] **Step 4: Manual smoke test.**

Run: `bundle exec rails server`. As a captain on a team in a two-day league with at least one one-day player, visit the team attendance page. Confirm:
- On the player's chosen day, the row appears normally.
- On the other day, the row is muted with the "Single-day registration — not playing this night" label.
- The yes/no/not-answered counts at the top of the day's section don't include the muted player.

- [ ] **Step 5: Commit.**

```bash
git add app/views/teams/attendance.html.haml app/controllers/teams_controller.rb
git commit -m "Render single-day players muted on non-attending nights in captain dashboard"
```

---

## Task 19: Warn (don't block) when League changes orphan attending_days

**Goal:** A commissioner editing a league sees a warning if any registration's `attending_days` references a day no longer in `league.game_days`.

**Files:**
- Modify: `app/controllers/leagues_controller.rb`
- Modify: `app/views/leagues/edit.html.haml` (only if needed for flash placement; `_form.html.haml` already shows errors)

- [ ] **Step 1: In `LeaguesController#update`**, after the existing `update_attributes(league_params)` succeeds, check for orphaned registrations and set a flash notice.

Locate the existing `update` action (around lines 32-51). Modify the success branch:

```ruby
if @league.update_attributes(league_params)
    orphaned = @league.registrations.where(:status.in => %w(active waitlisted registering)).select do |r|
        r.attending_days.present? && (r.attending_days - @league.game_days).any?
    end
    if orphaned.any?
        names = orphaned.map { |r| r.user.name }.join(', ')
        redirect_to @league, notice: "League Updated Successfully", flash: {warning: "Game-days change orphaned attending_days for: #{names}. Please follow up with these players."}
    else
        redirect_to @league, notice: "League Updated Successfully"
    end
else
    render :edit
end
```

- [ ] **Step 2: Verify the flash key is rendered.** If the application layout doesn't already render `flash[:warning]`, add it to `app/views/layouts/application.html.haml` (or the equivalent layout) near the existing flash blocks. Inspect first:

Run: `grep -rn "flash\[" app/views/layouts/`

If there is no `:warning` handler, add one alongside the existing notice/error rendering.

- [ ] **Step 3: Manual smoke test.**

Run: `bundle exec rails server`. Create a two-day league, create one one-day registration on `tuesday`, then edit the league and remove `tuesday` from `game_days`. After saving, confirm the warning flash appears with the player's name.

- [ ] **Step 4: Commit.**

```bash
git add app/controllers/leagues_controller.rb app/views/layouts/
git commit -m "Warn when league game_days change orphans existing registrations"
```

---

## Task 20: Commissioner-initiated registration-type change

**Goal:** A commissioner can change any player's `attending_days` from the player-management UI. Gated by `permitted_to? :manage, @league` and `league.started?`.

**Files:**
- Modify: `app/controllers/leagues_controller.rb`
- Modify: `app/views/leagues/players.html.erb`
- Test: `spec/controllers/leagues_controller_day_choice_spec.rb`

- [ ] **Step 1: Append failing specs to `spec/controllers/leagues_controller_day_choice_spec.rb`.**

```ruby
describe "POST #submit_day_choice (commissioner-initiated)" do
  let(:commish) { FactoryGirl.create(:user) }
  let(:player)  { FactoryGirl.create(:user) }

  before do
    league.commissioners << commish
    league.save!
    Registration.new(league: league, user: player, status: 'active', attending_days: ['tuesday', 'thursday'], price: 80, paid: true).save(validate: false)
    session[:user_id] = commish._id
    controller.stub(:current_user).and_return(commish)
  end

  it "lets a commissioner change another player's attending_days via registration_id param" do
    reg_id = league.registration_for(player)._id.to_s
    post :submit_day_choice, id: league._id, registration_id: reg_id, attending_days: ['tuesday']
    league.registration_for(player).attending_days.should eq(['tuesday'])
  end

  it "rejects when the actor lacks manage permission on the league" do
    other = FactoryGirl.create(:user)
    session[:user_id] = other._id
    controller.stub(:current_user).and_return(other)
    reg_id = league.registration_for(player)._id.to_s
    post :submit_day_choice, id: league._id, registration_id: reg_id, attending_days: ['tuesday']
    league.registration_for(player).attending_days.should eq(['tuesday', 'thursday']) # unchanged
  end
end
```

- [ ] **Step 2: Run the specs, expect failure.**

Run: `bundle exec rspec spec/controllers/leagues_controller_day_choice_spec.rb -e "commissioner-initiated"`
Expected: FAIL — the actions only operate on `current_user`'s registration.

- [ ] **Step 3: Update both `choose_days` and `submit_day_choice` to honor a `registration_id` param when the actor has manage permission.**

Replace the `@registration = @league.registration_for(current_user)` line in **both** actions with a helper call:

```ruby
@registration = load_day_choice_registration
return unless @registration
```

Add the helper (alongside `validate_day_choice_submission`):

```ruby
def load_day_choice_registration
    if params[:registration_id].present? && permitted_to?(:manage, @league)
        reg = @league.registrations.where(_id: params[:registration_id]).first
        unless reg
            redirect_to manage_roster_league_path(@league), flash: {error: "Registration not found."}
            return nil
        end
        return reg
    end

    reg = @league.registration_for(current_user)
    unless reg
        redirect_to league_path(@league), flash: {error: "You don't have a registration in progress for this league."}
        return nil
    end
    reg
end
```

Replace the existing `if @registration.nil? ... end` blocks in both actions — `load_day_choice_registration` now returns nil after redirecting in those cases.

- [ ] **Step 4: Update the redirect targets** in `submit_day_choice` so commissioner-initiated changes land back on the management page:

```ruby
if pre_pay_statuses.include?(@registration.status)
    redirect_to register_league_path(@league)
elsif params[:registration_id].present? && permitted_to?(:manage, @league)
    redirect_to players_league_path(@league), notice: "Updated registration type for #{@registration.user.name}."
else
    redirect_to registration_path(@registration), notice: "Registration type updated. Contact help@afdc.com if you need a price adjustment."
end
```

- [ ] **Step 5: Add a "Change Type" button to the player detail panel** in `app/views/leagues/players.html.erb`.

Find the `<script id="registrant-detail-template">` block. Inside the `<ul class="unstyled">` add a registration-type line, and below the existing Edit Registration link, add a Change Type link (when applicable). The template fragment is interpolated client-side, so use `{{=...}}` placeholders:

```html
<li><strong>Registration Type:</strong> {{=day_label || 'n/a'}}</li>
```

And below the Edit Registration link:

```html
<%= link_to "Change Type", choose_days_league_path(@league, registration_id: 'PLACEHOLDER').gsub('PLACEHOLDER', '{{=id}}').html_safe, class: 'btn btn-block btn-small btn-info' %>
```

(Wrap that in a `<% if @league.requires_day_choice? && !@league.started? %>` guard.)

- [ ] **Step 6: Run the specs, expect pass.**

Run: `bundle exec rspec spec/controllers/leagues_controller_day_choice_spec.rb`
Expected: PASS.

- [ ] **Step 7: Manual smoke test.**

Sign in as a league commissioner. Open `/leagues/<id>/players`. Click a player row → confirm the detail panel shows the Registration Type and a Change Type button. Click it → land on `choose_days?registration_id=...` → make a change → submit → land back on `/players` with the success flash.

- [ ] **Step 8: Commit.**

```bash
git add app/controllers/leagues_controller.rb app/views/leagues/players.html.erb spec/controllers/leagues_controller_day_choice_spec.rb
git commit -m "Allow commissioners to change a player's registration type"
```

---

## Task 21: End-to-end smoke spec

**Goal:** A single integration spec exercises the full happy path: configure a two-day league → register → choose two-day → submit → arrive at edit → submit edit → confirm price + attending_days.

**Files:**
- Test: `spec/integration/day_of_week_registration_spec.rb` (new)

- [ ] **Step 1: Create the spec.**

```ruby
require 'spec_helper'

describe "Day-of-week registration end-to-end", type: :request do
  let(:user) { FactoryGirl.create(:user, gender: 'male', email_address: 'p@example.com', password_digest: BCrypt::Password.create('password').to_s) }
  let!(:league) do
    FactoryGirl.create(:league,
      game_days: ['tuesday', 'thursday'],
      price: 80,
      price_single_day: 50,
      registration_open: 1.week.ago.to_date,
      registration_close: 1.week.from_now.to_date,
      male_limit: 30,
      female_limit: 30
    )
  end

  before do
    User.any_instance.stub(:valid?).and_return(true)
    User.any_instance.stub(:needs_grank_update_for_league?).and_return(false)
  end

  it "redirects from register to choose_days, persists the choice, and prices it" do
    # Sign in (use whatever auth helper this codebase supports; if integration auth is non-trivial,
    # make this a controller-driven sequence instead).
    pending "Wire to the project's request-level auth helper if available; otherwise rely on Task 8/9 controller specs for coverage."
  end
end
```

(If end-to-end auth is awkward, this task can be downgraded to a TODO that links the controller specs from Tasks 8 and 9 as the integration-level coverage.)

- [ ] **Step 2: Run the spec, expect pending.**

Run: `bundle exec rspec spec/integration/day_of_week_registration_spec.rb`
Expected: 1 pending (acceptable).

- [ ] **Step 3: Commit.**

```bash
git add spec/integration/day_of_week_registration_spec.rb
git commit -m "Add pending integration spec for day-of-week registration flow"
```

---

## Task 22: Run the full suite + manual sanity sweep

**Goal:** Verify nothing regressed before declaring done.

- [ ] **Step 1: Full RSpec run.**

Run: `bundle exec rspec`
Expected: all green (with the 1 pending integration spec from Task 20).

- [ ] **Step 2: Manual sweep on a dev server.**

Run: `bundle exec rails server` (or `foreman start` per `DevProcfile`).

Verify each of the following on a freshly-configured two-day league:
- League form: configure `game_days = [tuesday, thursday]`, `price = 80`, `price_single_day = 50`. Save.
- Register flow: sign in as a fresh user → click Register → land on the interstitial. Pick "Two-day" → continue → land on the registration form → submit. Verify `Registration#price == 80` in `rails console`.
- Sign in as a second user → register → pick "One-day, Tuesday" → submit. Verify `price == 50`.
- Visit the registration show page for the second user. Confirm "Registration Type: Tuesday only" shows with a Change link.
- Click Change → land on the interstitial pre-selected → switch to "Two-day" → submit. Confirm the show page now reads "Two-day". Confirm `price` is unchanged because the registration is `active` (commissioner handles money).
- As a commissioner, visit `/leagues/<id>/players` and `/leagues/<id>/registrations`. Confirm the Days column appears, color-coded for one-day rows, filterable.
- Visit `/leagues/<id>/manage_roster`. Confirm the registration-type summary section appears.
- Download `/leagues/<id>/registrations.csv`. Confirm the two new columns.
- Edit the league: remove `thursday` from `game_days`. Save. Confirm a warning flash names the affected one-day-Thursday player (if there is one).
- Set `start_date` to yesterday. Visit the registration show page. Confirm the Change link is gone. Try `GET /leagues/<id>/choose_days` directly — confirm the redirect with the "already started" flash.

- [ ] **Step 3: Final commit (if anything was tweaked during the sweep).**

```bash
git status
# only commit if there are real changes
```

---

## Notes for the implementer

- This plan adds two new fields to a Mongoid document and one to another. There is no migration step; Mongoid stores added fields lazily. Existing documents without the fields read back `nil` / `[]` (per `default:`), and the predicate `participates_on?` was specifically designed to make that path safe.
- Several views in this codebase mix Tabulator client-side filtering with server-side rendering. Don't try to unify those patterns in this PR — match what exists.
- The drafting view (`manage_roster.html.haml`) is intentionally kept lightweight in this plan. If the team wants richer per-row badges directly inside the AJAX-rendered roster widget, that's a follow-up that requires changes to its data feed (currently `team_list`/`reg_list`).
- The `flash[:warning]` key in Task 19 may not be rendered by the existing layout. Confirm before relying on it; if not, prefer `flash[:notice]` with a clearly worded message instead.
