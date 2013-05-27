class RequiredAgeValidator < ActiveModel::EachValidator
	def initialize(options)
		@@minimum_age = options[:with] # the options hash will be as {:attributes=>[:attachments], :with=>3}, where :with contains the desired limit passed
		super
	end

	def validate_each(record, attribute, value)
		begin
			birthday = Date.parse(value).beginning_of_day
		rescue
			birthday = Time.zone.now
		end

		record.errors[attribute] << "must be #{@@minimum_age} years of age" unless birthday <= @@minimum_age.years.ago
	end
end