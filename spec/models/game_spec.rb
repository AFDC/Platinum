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
