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
