class DateStringValidator < ActiveModel::EachValidator
	def validate_each(record, attribute, value)
		begin
			Date.parse(value)
		rescue => e
			record.errors[attribute] << "must be a valid date string" 
		end
	end
end