namespace :user do
  desc 'Clean up user accounts'
  task :clean => :environment do
    nulls = []
    dupes = {}

    User.where({email_address: {"$exists" => false}}).each do |u|
        print "#{u._id} #{u.name}\n"
    end

    User.all.each do |u|
        unless u.email_address
            nulls << u._id.to_s
            next
        end
        email = u.email_address.downcase
        next if dupes.include? email

        c = User.where({email_address: /^#{Regexp.escape(email)}$/i}).count

        dupes[email] = c if c > 1
    end

    print "Dupes: #{dupes.count}\n"
    print "Nulls: #{nulls.count}\n"

    # print "Total users:      #{total}\n"
    # print "Invalid:          #{invalid.count}\n"
    # print "No Registrations: #{no_regs.count} (#{(invalid & no_regs).count})\n\n"

  end

  desc 'Create a new admin user'
  task :create_admin, [:email, :password] => :environment do |t, args|
    args.with_defaults(email: 'admin@leagues.afdc.local', password: 'password')
    unless Rails.env.development?
        raise "This command is only available in development mode."
    end

    u = User.new()
    u.email_address = args.email
    u.firstname     = 'Dev'
    u.lastname      = 'Admin'
    u.password      = args.password
    if (u.save(validate: false))
        print "A new admin has been created with username #{args.email} and password #{args.password}\n"
    else
        raise "Command failed"
    end
  end

  desc 'Find Numbers for Calendar Year'
  task :demographic, [:year] => :environment do |t, args|
    args.with_defaults(:year => Time.now.year)

    players_seen  = {}
    junior_count  = 0
    adult_count   = 0
    unknown       = {}

    year_start = DateTime.new(args.year.to_i).beginning_of_year
    year_end   = DateTime.new(args.year.to_i).end_of_year

    League.where({start_date: {'$lte' => year_end}, end_date: {'$gte' => year_start}}).each do |l|
        print "#{l.name} (#{l._id})\n"
        league_juniors = 0
        league_adults  = 0
        league_unknown = {}
        league_total   = 0
        l.registrations.each do |r|
            seen = players_seen[r.user._id.to_s].present?
            players_seen[r.user._id.to_s] = true
            league_total += 1
            unless r.user.birthdate
                league_unknown[r.user._id.to_s] = r.user.name
                unknown[r.user._id.to_s] = r.user.name
                next
            end
            birthyear = r.user.birthdate.split('-').first.to_i
            age = (args.year.to_i - birthyear) - 1

            if age < 18
                league_juniors += 1
                junior_count += 1 unless seen
            else
                league_adults += 1
                adult_count += 1 unless seen
            end
        end
        print "\t- Adults:  #{league_adults}\n"
        print "\t- Juniors: #{league_juniors}\n"
        print "\t- Unknown: #{league_unknown.count}\n"
        print "\tTotal:     #{league_total}\n\n"
    end

    print "\nAnnual Totals: (unique players only)\n"
    print "Adults:  #{adult_count}\n"
    print "Juniors: #{junior_count}\n"
    print "Unknown: #{unknown.count}\n"
    print "Total:   #{players_seen.count}\n"
  end
end
