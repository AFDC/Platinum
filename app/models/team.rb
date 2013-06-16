class Team
  include Mongoid::Document
  include Mongoid::Paperclip
  include ActiveModel::ForbiddenAttributesProtection

  field :name
  field :stats, type: Hash
  has_and_belongs_to_many :reporters, class_name: "User", foreign_key: :reporters, inverse_of: nil
  has_and_belongs_to_many :captains, class_name: "User", foreign_key: :captains, inverse_of: nil
  has_and_belongs_to_many :players, class_name: "User", foreign_key: :players
  has_many :games, foreign_key: :teams
  belongs_to :league

  has_mongoid_attached_file :avatar,
    default_url: lambda {|attachment| "http://www.gravatar.com/avatar/#{Digest::MD5.hexdigest(attachment.instance._id)}?d=identicon&s=330"},
    styles: {profile: '330x330>', roster: '160x160#', thumbnail: '64x64#'}

  def winning_percentage
  	if stats['wins'] && stats['losses']
  		if stats['wins']+stats['losses'] > 0
  			('%.3f' % (stats['wins'].to_f/(stats['wins']+stats['losses']))).gsub('0.', '.')
  		else
  			'.000'
  		end
  	else 
  		nil
  	end
  end

  def formatted_record
    if stats['wins'] && stats['losses']
      if stats['wins']+stats['losses'] > 0
        "#{stats['wins']}-#{stats['losses']}"
      else
        '0-0'
      end
    else
      'n/a'
    end      
  end

  def formatted_rank
    stats['rank'] ? stats['rank'].ordinalize : 'n/a'
  end

  def captains=(user_list)
    self['captains'] = user_list
  end
  
  def reporters=(user_list)
    self['reporters'] = user_list
  end
end