namespace :paperclip do
  desc "migrage to DigitalOcean Spaces"
  task :migrate => :environment do
    AWS.config(
      access_key_id: ENV['S3_ACCESS_KEY_ID'],
      secret_access_key: ENV['S3_SECRET_ACCESS_KEY']
    )

    s3 = AWS::S3.new
    bucket = s3.buckets[ENV['S3_PAPERCLIP_BUCKET']]

    classes = [%w(Team avatar), %w(User avatar)]

    classes.each do |class_info|
      klass    = class_info[0].capitalize.constantize
      att_type = class_info[1].downcase

      puts "Migrating #{klass}:#{att_type}..."
      styles = klass.first.send(att_type).styles.map{|style| style[0]}

      klass.each do |instance|
        puts "\t#{instance.id} (#{instance.avatar.exists?})"
        next if instance.send(att_type).exists? == false
        next if instance.send(att_type).url.include?('digitaloceanspaces')

        styles.each do |style|
          puts "\t\t#{style}"
          extension = instance.send(att_type).path(style.to_sym).split(".").last
          file_path = instance.send(att_type).path(style.to_sym)
          new_path  = "#{klass.downcase.pluralize}/#{att_type.pluralize}/#{style}/#{instance.id}.#{extension}"
          file = File.open(file_path)

          attachment = bucket.objects[new_path].write(file, acl: :public_read)
          break
        end
        break
      end
      break
    end
  end
end
