class SpiritReport
    include Mongoid::Document
    include ActiveModel::ForbiddenAttributesProtection

    before_save :strip_unnecessary_comments

    field :rules_score, type: Integer
    field :rules_comments
    validates :rules_score, numericality: { only_integer: true, greater_than_or_equal_to: 0, less_than_or_equal_to: 4 }

    field :fouls_score, type: Integer
    field :fouls_comments
    validates :fouls_score, numericality: { only_integer: true, greater_than_or_equal_to: 0, less_than_or_equal_to: 4 }

    field :fairness_score, type: Integer
    field :fairness_comments
    validates :fairness_score, numericality: { only_integer: true, greater_than_or_equal_to: 0, less_than_or_equal_to: 4 }

    field :attitude_score, type: Integer
    field :attitude_comments
    validates :attitude_score, numericality: { only_integer: true, greater_than_or_equal_to: 0, less_than_or_equal_to: 4 }

    field :communication_score, type: Integer
    field :communication_comments
    validates :communication_score, numericality: { only_integer: true, greater_than_or_equal_to: 0, less_than_or_equal_to: 4 }

    validate :has_all_comments

    belongs_to :league, index: true
    belongs_to :game, index: true
    belongs_to :team, index: true
    belongs_to :reporter, class_name: 'User'

    def composite
        count = 0
        total = 0.0
        self.class.categories.each do |c|
            score_sym    = "#{c[:name]}_score"
            total += self[score_sym]
            count += 1
        end

        total/count unless total == 0
    end

    def has_all_comments
        self.class.categories.each do |c|
            score_sym    = "#{c[:name]}_score"
            comments_sym = "#{c[:name]}_comments"
            if self[score_sym] == 0 || self[score_sym] == 4                
                errors.add(comments_sym, "You must explain why you chose a score of #{self[score_sym]}") if self[comments_sym].empty?
            end
        end
    end

    def strip_unnecessary_comments
        self.class.categories.each do |c|
            score_sym    = "#{c[:name]}_score"
            comments_sym = "#{c[:name]}_comments"
            self[comments_sym] = '' unless (self[score_sym] == 0 || self[score_sym] == 4)
        end
    end

    def self.categories
        [
            { name: 'rules', title: 'Rules Knowledge and Use', desc: 'They did not purposefully misinterpret the rules. They kept to time limits. When they didn’t know the rules they showed a real willingness to learn.'},
            { name: 'fouls', title: 'Fouls and Body Contact', desc: 'They avoided fouling, contact, and dangerous plays.'},
            { name: 'fairness', title: 'Fair-Mindedness', desc: 'They apologized in situations where it was appropriate, informed teammates about wrong/unnecessary calls. Only called significant breaches.' },
            { name: 'attitude', title: 'Positive Attitude and Self-Control', desc: 'They were polite. They played with appropriate intensity irrespective of the score. They left an overall positive impression during and after the game.' },
            { name: 'communication', title: 'Communication', desc: 'They communicated respectfully. They listened. They kept to discussion time limits.' }
        ]
    end
end
