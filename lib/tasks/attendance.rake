namespace :attendance do
  desc 'Preview what AttendancePromptWorker would do on its next run'
  task preview: :environment do
    AttendancePromptWorker.preview.each { |line| puts line }
  end

  desc 'Run AttendancePromptWorker once, immediately'
  task run_now: :environment do
    AttendancePromptWorker.new.perform
    puts "Done."
  end
end
