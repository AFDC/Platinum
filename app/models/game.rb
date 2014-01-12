class Game
	include Mongoid::Document
	field :game_time, type: DateTime
	field :field
	field :round_number
	field :winner, type: Moped::BSON::ObjectId
	field :scores, type: Hash, default: {}
	belongs_to :league
	belongs_to :field_site, foreign_key: :fieldsite_id
	has_and_belongs_to_many :teams, foreign_key: :teams

	def game_time
		self[:game_time].in_time_zone(LOCAL_TIMEZONE)
	end

	def team_ids
		self[:teams].to_a
	end

	def winning_team
		Team.find(self.winner) if self.winner
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

		scores[subject_team._id.to_s]
	end

			# '_id'  => array('type' => 'id'), // required for Mongo
			# 'game_time' => array('type' => 'date'),
			# 'league_id' => array('type' => 'id'),
			# 'fieldsite_id' => array('type' => 'id'),
			# 'teams' => array('type' => 'id', 'array' => true),
			# 'field' => array('type' => 'string'),
			# 'round_number' => array('type' => 'integer'),
			# 'old_scores' => array('type' => 'object', 'array' => true),
			# 'scores' => array('type' => 'object'),
			#     'scores.report_time' => array('type' => 'date'),
			#     'scores.forfeit' => array('type' => 'boolean'),
			#     'scores.rainout' => array('type' => 'boolean'),
			#     'scores.reporter_id' => array('type' => 'id'),
			#     'scores.reporter_ip' => array('type' => 'string'),
			# 'winner' => array('type' => 'id')

end