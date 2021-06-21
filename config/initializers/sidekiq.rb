#initializers/sidekiq.rb
schedule_file = "config/schedule.yml"

if File.exists?(schedule_file) && Sidekiq.server?
  Sidekiq::Cron::Job.load_from_hash YAML.load_file(schedule_file)
end

if Sidekiq.server?
  Mongoid::QueryCache.enabled = false
end
