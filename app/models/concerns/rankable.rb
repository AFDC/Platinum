module Rankable
    extend ActiveSupport::Concern

    included do
        field :player_strength
        field :self_rank, type: Float
        field :detailed_self_rank, type: Hash
        field :commish_rank, type: Float
        field :g_rank, type: Float

        belongs_to :g_rank_result

        validates :commish_rank, :numericality => { integer_only: false, greater_than: 0, less_than: 10, allow_blank: true }
        validate :has_valid_self_rank, :has_valid_primary_role
    end

    class_methods do
        def is_rankable?
            true
        end

        def self_rank_options(type)
            if type == "experience"
                return [
                    ["0 - Most experience is pick-up. No knowledge of strategy", 0],
                    [1,1],
                    ["2 - League experience. Understands vertical stack and person defense", 2],
                    [3,3],
                    ["4 - College/Club ultimate experience. Solid understanding of a couple basic offensive and defensive strategies", 4],
                    [5,5],
                    ["6 - Advanced college/club experience. Strong understanding of multiple different offensive and defensive strategies", 6],
                    [7,7],
                    [8,8],
                    ["9 - Many years of elite college/club experience. Advanced understanding of a wide variety of offensive and defensive strategies", 9]
                ]
            end
    
            if type == "athleticism"
                return [
                    ["0 - Below average pickup player", 0],
                    [1, 1],
                    [2, 2],
                    ["3 - Average league athlete",3],
                    [4, 4],
                    [5, 5],
                    ["6 - Average club athlete", 6],
                    [7, 7],
                    [8, 8],
                    ["9 - Exceptional elite/collegiate athlete", 9]
                ]
            end        
    
            if type == "skills"
                return [
                    ["0 - At most can dump the disc and catch sometimes", 0],
                    [1, 1],
                    [2, 2],
                    [3, 3],
                    ["4 - Can consistently throw a forehand & backhand, hold a force, and fill at least one role in a zone defense", 4],
                    [5, 5],
                    [6, 6],
                    [7, 7],
                    [8, 8],
                    ["9 - Can consistently throw & complete any throw and excel at any position in any offense or defense", 9]
                ]
            end           
    
            return (0..9)
        end
    end

    def copy_ranks_from(other)
        unless other.class.respond_to?(:is_rankable?) && other.class.is_rankable?
            raise ArgumentError, "Target #{other.class.name} is not Rankable"
        end

        %w(player_strength self_rank detailed_self_rank commish_rank g_rank g_rank_result).each do |field|
            self[field] = other[field]
        end
    end

    def populate_ranks_from_params(params, may_update_commish_rank=false)
        self.player_strength = params[:player_strength]

        if league.self_rank_type == "simple"
            self.self_rank = params[:self_rank]
        end


        if league.self_rank_type == "detailed"
            dsr = {
                "experience" => params[:self_rank_experience],
                "athleticism" => params[:self_rank_athleticism],
                "skills" => params[:self_rank_skills]
            }

            # Ensure these are numbers or nil
            dsr.keys.each do |k|
                if (dsr[k] == "")
                   dsr[k] = nil
                end

                dsr[k] = dsr[k].try(:to_i)
            end

            self.detailed_self_rank = dsr
        end

        if league.require_grank?
            self.g_rank_result = user.g_rank_results.first
            self.g_rank = self.g_rank_result.score
        end

        if may_update_commish_rank
            self.commish_rank = params[:commish_rank]
        end
    end

    def self_rank_experience
        detailed_self_rank['experience'].try(:to_i) if detailed_self_rank
    end

    def self_rank_athleticism
        detailed_self_rank['athleticism'].try(:to_i) if detailed_self_rank
    end

    def self_rank_skills
        detailed_self_rank['skills'].try(:to_i) if detailed_self_rank
    end

    def rank
        avg_detailed_rank = nil
        if detailed_self_rank && detailed_self_rank.values.count > 0
            avg_detailed_rank = (detailed_self_rank.values.map(&:to_i).sum.to_f / detailed_self_rank.values.count).round(1)
        end

        user_rank = self.g_rank || self.self_rank || avg_detailed_rank

        self.commish_rank || [user_rank, user.minimum_rank].compact.max
    end

    def core_rank
        return nil unless self.rank
        return nil unless self.league.core_options.type

        constant = self.league.core_options["#{self.gender}_rank_constant"] || 0.0
        coefficient = self.league.core_options["#{self.gender}_rank_coefficient"] || 1.0

        (coefficient*self.rank)+constant
    end

    # Validators
    def has_valid_self_rank
        validate_simple_self_rank if league.self_rank_type == "simple"
        validate_detailed_self_rank if league.self_rank_type == "detailed"
    end

    def validate_simple_self_rank
        max_rank = 9
        max_rank = 6 if league.sport == 'goaltimate' && user.gender == 'female'

        unless (1..max_rank).include?(self_rank)
            errors.add(:self_rank, "Please select a rank between 1 and #{max_rank}")
        end
    end

    def validate_detailed_self_rank
        unless (0..9).include?(self_rank_experience)
            errors.add(:self_rank_experience, "Please select a rank between 0 and 9")
        end

        unless (0..9).include?(self_rank_athleticism)
            errors.add(:self_rank_athleticism, "Please select a rank between 0 and 9")
        end

        unless (0..9).include?(self_rank_skills)
            errors.add(:self_rank_skills, "Please select a rank between 0 and 9")
        end
    end

    def has_valid_primary_role
        unless ['Runner', 'Thrower', 'Both'].include?(player_strength)
            errors.add(:player_strength, "Please select a primary role.")
        end        
    end

end