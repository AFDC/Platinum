
if defined?(Rails::Console)
    def usr_ph
        User.find_by_email_address('pete.holiday@gmail.com')
    end

    def usr_jb
        User.find('4f91e8bfec3e3052e0000ef0')
    end

    

    def lg_sum
        League.where(season: 'summer', pickup_registration: false).last
    end

    def lg_spr
        League.where(season: 'spring', pickup_registration: false).last
    end

    def lg_win
        League.where(season: 'winter', pickup_registration: false).last
    end

    def lg_fal
        League.where(season: 'fall', pickup_registration: false).last
    end
end
