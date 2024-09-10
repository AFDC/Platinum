class Game
	include Mongoid::Document
	field :game_time, type: DateTime
	field :field
	field :round_number
	field :winner, type: BSON::ObjectId
	field :scores, type: Hash, default: {}
	field :old_scores, type: Array, default: []
	belongs_to :league, index: true
	belongs_to :field_site, foreign_key: :fieldsite_id
	has_and_belongs_to_many :teams, foreign_key: :teams

	attr_accessor :reporter

	after_save :queue_league_update

	def game_time
		self[:game_time].in_time_zone(LOCAL_TIMEZONE)
	end

	def team_ids
		self[:teams].to_a
	end

	def winning_team
		Team.find(self.winner) if self.winner
	end

	def rained_out?
		self.scores['rainout'].present?
	end

	def forfeited?
		self.scores['forfeit'].present?
	end

	def reporter
		unless self[:reporter]
			if self.scores['reporter_id']
				self[:reporter] = User.find(self.scores['reporter_id'])
			end
		end

		self[:reporter]
	end

	def opponent_for(subject_team)
		unless self[:teams].include?(subject_team._id)
			return nil
		end

		first_opponent_id = self[:teams].reject{|team_id| team_id == subject_team._id}.first

		Team.find(first_opponent_id) if first_opponent_id
	end

	def score_for(subject_team)
		unless self[:teams].include?(subject_team._id) && scores
			return nil
		end

		score = scores[subject_team._id.to_s]

		score.to_i if score
	end

	def spirit_report_for(subject_team)
		SpiritReport.find_by(game: self, team: subject_team)
	end

	def spirit_reporting_complete?
		teams.each do |t|
			return false if spirit_report_for(t).nil?
		end
		return true
	end

	private

	def queue_league_update
		if scores_changed? or winner_changed?
			LeagueStandingsUpdateWorker.perform_async(league._id.to_s)
		end
	end
end
