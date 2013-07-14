require 'aws-sdk'

S3_TARGET_BUCKET      = 'relistan.com'
AWS_ACCESS_KEY_ID     = 'AKIAIU2IM6277LBHFJFA'
AWS_SECRET_ACCESS_KEY = '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'

class S3Client
  def initialize(access_key, secret_access_key, bucket)
    AWS.config(
      access_key_id:     AWS_ACCESS_KEY_ID,
      secret_access_key: AWS_SECRET_ACCESS_KEY
    )
  
    @s3 = AWS::S3.new(s3_endpoint: 's3-us-west-2.amazonaws.com')
    @bucket = @s3.buckets[S3_TARGET_BUCKET]
  end

  def upload(file_list)
    file_list.inject([]) do |memo, file|
      unless Dir.exists?(file)
        print "uploading #{file}..."

        s3_filename = file.sub(/^.*?\//, '')
        memo << s3_filename
        if (obj = @bucket.objects[s3_filename])
          obj.write(Pathname.new(file))
        else
          @bucket.object.create(s3_filename).write(Pathname.new(file))
        end

        puts 'done'
      end
      memo
    end
  end

  def s3_filelist
    @s3.buckets[S3_TARGET_BUCKET].objects.map { |x| x.key }
  end
end

desc 'Upload the site to S3'
task :upload do

  raise 'Site is not prepared to upload' unless File.exists?('_site/index.html')
  client = S3Client.new(AWS_ACCESS_KEY_ID, AWS_SECRET_ACCESS_KEY, S3_TARGET_BUCKET)

  uploaded   = client.upload(Dir['_site/**/*'])
  difference = client.s3_filelist - uploaded

  unless difference.empty?
    puts "Files on remote that were not uploaded: #{difference.join(', ')}"
  end
end

desc 'build the site into the _site dir'
task :build do
  system "lessc assets/less/main.less > assets/css/main.css"
  system "jekyll build"
end
