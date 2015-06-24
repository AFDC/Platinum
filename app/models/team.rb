class Team
  include Mongoid::Document
  include Mongoid::Paperclip
  include ActiveModel::ForbiddenAttributesProtection

  field :name

  # Stats Fields
  field :wins, type: Integer, default: 0
  field :losses, type: Integer, default: 0
  field :ties, type: Integer, default: 0
  field :point_diff, type: Integer, default: 0
  field :league_rank, type: Integer
  field :spirit_average, type: Float

  has_and_belongs_to_many :reporters, class_name: "User", foreign_key: :reporters, inverse_of: nil
  has_and_belongs_to_many :captains, class_name: "User", foreign_key: :captains, inverse_of: nil
  has_and_belongs_to_many :players, class_name: "User", foreign_key: :players
  has_many :games, foreign_key: :teams
  belongs_to :league, inverse_of: :teams

  has_mongoid_attached_file :avatar,
    default_url: lambda {|attachment| "https://www.gravatar.com/avatar/#{Digest::MD5.hexdigest(attachment.instance._id)}?d=identicon&s=330"},
    styles: {profile: '330x330>', roster: '160x160#', thumbnail: '64x64#'}

  def winning_percentage
    return 0 unless wins > 0
    return wins.to_f / games_played.to_f
  end

  def games_played
    wins+losses+ties
  end

  def update_stats
    self.wins           = 0
    self.losses         = 0
    self.ties           = 0
    self.point_diff     = 0
    self.spirit_average = nil

    spirit_report_count = 0
    spirit_report_sum   = 0

    games.where({game_time: {'$lte' => Time.now}}).each do |game|
      next if game.rained_out?
      next if game.scores.count <= 0

      opponent = game.opponent_for(self)
      next unless opponent

      team_score = game.score_for(self)
      opnt_score = game.score_for(opponent)
      next if team_score.nil? || opnt_score.nil?

      game_point_diff = game.score_for(self) - game.score_for(opponent)

      if game_point_diff > 0
        self.wins += 1
      elsif game_point_diff < 0
        self.losses += 1
      else
        self.ties += 1
      end

      self.point_diff += game_point_diff

      # Spirit Score
      if league.track_spirit_scores
        if spirit_report = game.spirit_report_for(self)
          spirit_report_count += 1
          spirit_report_sum   += spirit_report.composite
        end
      end
    end

    self.spirit_average = spirit_report_sum / spirit_report_count if spirit_report_count > 0
    true
  end

  def update_stats!
    update_stats and save
  end

  def <=>(other_team)
    # Test 1: Winning Percentage
    wp_diff = self.winning_percentage <=> other_team.winning_percentage
    return wp_diff unless wp_diff == 0

    # Test 2: Head to Head Record
    self_wins = 0
    other_team_wins = 0
    h2h_point_diff = 0
    Game.where({game_time: {'$lte' => Time.now}, '$and' => [{teams: self.id},{teams: other_team.id}]}).each do |g|
      self_wins += 1 if g.winning_team == self
      other_team_wins += 1 if g.winning_team == other_team
      h2h_point_diff += g.score_for(self).to_i - g.score_for(other_team).to_i
    end

    h2h_win_diff = self_wins <=> other_team_wins
    return h2h_win_diff unless h2h_win_diff == 0

    # Test 3: Head-to-head point diff
    return h2h_point_diff <=> 0 unless h2h_point_diff == 0

    # Test 4: Overall point differential
    pd_diff = self.point_diff <=> other_team.point_diff
    return pd_diff unless pd_diff == 0

    return 0
  end

  def record
    "#{wins}-#{losses}" + (ties > 0 ? "-#{ties}" : '')
  end

  def formatted_rank
    league_rank ? league_rank.ordinalize : 'n/a'
  end

  def captains=(user_list)
    self['captains'] = user_list
  end

  def players=(user_list)
    self['players'] = user_list
  end

  def reporters=(user_list)
    self['reporters'] = user_list
  end
end
