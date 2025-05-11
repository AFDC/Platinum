# Pickup Player Management

## User Stories

### As a player, I...
 - want to sign up to be notified when a league needs players
 - want to be notified when I am assigned to a team
 - want to be able to see my game/assignment details on the homepage
 - want to be able to pay for my spot only when I'm selected

### As a captain, I...
 - want to indicate that I need pickups, and which players will be absent
 - want to be able to invite specific people to pickup

### As a commissioner, I...
 - want to see which pickups are available
 - want to see which teams need pickups
 - want to be able to easily match pickups to available spots
 - want to offer spots to pickups and get confirmation that they'll attend
 - want to track statistics on pickups to ensure nobody is playing too much
 - want to be able to set a per-league or per-game cost for picking up

## Development Phases

### Phase 1 (MVP)
 - Commissioner can set the per-day cost of picking up
 - Player can volunteer as a pickup candidate for a league
 - Commissioner can see list of pickup options
 - Commissioner can invite a pickup to a team/day combination
 - Commissioner can indicate that an invite is comped
 - Player can accept that invitation and pay
 - Commissioner, Captains, and Pickup are all notified of a successful assignment

### Phase 2
 - Captains can invite/request specific players
 - Captains can record their pickup needs

## Dev Specifics

### Objects
 - `PickupCandidate` - an indication that a particular user is interested in picking up for a particular league
 - `PickupRegistration` - a candidate's confirmation that they are playing in a particular league, for a particular team, on a particular day
 - `PickupSlot` - a team/date combination indicating an available opening for a pickup player; can reserve for a specific user

### Tasks
 1. ~~Create `PickupCandidate` model~~
 2. ~~Ensure candidate contains all ranking info from a registration~~
 3. ~~Create mechanism for a user to add themsevles as a candidate~~
 4. Create listing page for pickup candidates, visible to commissioners
 5. ~~Redirect if grank missing like registration does~~

### Future Tasks
 - [X] Update league show page to have better pickup CTA logic (currently will hide if registration is closed, for example)
 - [ ] Update homepage to show pickup availability and CTA
 - [ ] Update league summary to be relevant for pickup volunteering
 - [ ] Figure out how to get grank in here
 - [ ] Ensure a player can see their pickup status for a league

 ### Tests
  - Test both Registration and Pickups with:
    - ~~GRank required and present~~
    - ~~GRank required and missing~~
    - ~~Self Rank~~
    - ~~Detailed Self Rank~~
    - ~~Commish Rank~~