namespace :convert do
  desc "Convert secondary_rank_data to first-class rank data"
  task :secondary_rank_data => :environment do

    conversions = 0
    Registration.where({"secondary_rank_data" => {"$exists" => true}}).each do |r|
      next unless r.user
      r.commish_rank = r.secondary_rank_data['commish_rank']
      r.self_rank = r.secondary_rank_data['self_rank']
      r.g_rank = r.secondary_rank_data['grank']

      if r['gRank'] || r.secondary_rank_data['grank']
          grr = GRankResult.new

          grr.answers = r['gRank']['answers'] if r['gRank']
          if r['gRank'] && r['gRank']['score']
              grr.score = r['gRank']['score']
          else
              grr.score = r.secondary_rank_data['grank']
          end

          grr.timestamp = r.signup_timestamp
          grr.user = r.user

          grr.save

          r.g_rank_result = grr
      end

      r.unset(:secondary_rank_data)
      r.unset(:gRank)

      r.save

      conversions += 1
      print "." if (conversions % 100 == 0)
    end

    print "Converted #{conversions} records\n"
  end

  desc "Convert old gRank answers to new format"
  task :old_grank_answers => :environment do
    answer_map = {
      '' => nil,
      '0' => 'a',
      '1' => 'b',
      '2' => 'c',
      '3' => 'd',
      '4' => 'e',
      '5' => 'f',
      '6' => 'g',
      '7' => 'h'
    }
    GRankResult.each do |grr|
      answers = grr.answers
      next if answers.empty?


      answers['experience']      = 'afdc'                                 if grr.answers['experience'] == 'league'
      answers["athleticism"]     = answer_map[answers["athleticism"]]     if answer_map.keys.include?(answers["athleticism"])
      answers["level_of_play"]   = answer_map[answers["level_of_play"]]   if answer_map.keys.include?(answers["level_of_play"])
      answers["ultimate_skills"] = answer_map[answers["ultimate_skills"]] if answer_map.keys.include?(answers["ultimate_skills"])
      print "#{grr._id} #{answers}\n"
      grr.save
    end
  end

  desc "Convert password identities to passwords"
  task :identities => :environment do
    User.all.each do |u|
      i = u.identities.where({type: 'password'}).first
      if i
        u.password_digest = i.prv_secret
        i.delete
      else
        u.reset_password
      end
      u.save
    end
  end
end
