class User
  include Mongoid::Document
  include Mongoid::Paperclip

  field :address
  field :birthdate
  field :city
  field :email_address
  field :firstname
  field :gender
  field :handedness
  field :height
  field :lastname
  field :middlename
  field :occupation
  field :phone
  field :postal_code
  field :privacy
  field :state
  field :weight
  field :permission_groups, type: Array, default: ['user']

  has_mongoid_attached_file :avatar,
    default_url: lambda {|attachment| "http://robohash.org/#{attachment.instance._id}.png?bgset=bg2&size=330x330"},
    styles: {profile: '330x330>'}

  has_many :identities
  has_and_belongs_to_many :teams, foreign_key: :teams

  validates :firstname, :presence => true
  validates :lastname, :presence => true
  validates :email_address, :presence => true, :uniqueness => { case_sensitive: false }
  validates :height, :numericality => { integer_only: true, greater_than: 30, less_than: 96, allow_blank: true  }
  validates :weight, :numericality => { integer_only: true, greater_than: 60, less_than: 400, allow_blank: true }
  validates :handedness, :inclusion => { in: %w(left right both), message: "%{value} is not a valid option", allow_blank: true }
  validates :gender, :presence => true, :inclusion => { in: %w(male female) }
  validates :birthdate, :required_age => 13, :date_string => true

  before_save :downcase_email

  def downcase_email
  	self.email_address = self.email_address.downcase
  end

  def height_in_feet_and_inches
    self.height ? "#{self.height/12}\'#{self.height%12}\"" : 'n/a'
  end

  def age
    begin
      dob = Date.parse(self.birthdate)
      today = Date.today
      d = Date.new(today.year, dob.month, dob.day)
      age = d.year - dob.year - (d > today ? 1 : 0)
    rescue
      nil
    end
  end

  def role_symbols
    self.permission_groups.map(&:to_sym)
  end
end
