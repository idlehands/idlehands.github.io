require 'aws-sdk'

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
        (@bucket.objects[s3_filename] || @bucket.object.create(s3_filename)).write(Pathname.new(file))

        puts 'done'
      end
      memo
    end
  end

  def delete(file_list)
    file_list.each do |file|
      print "removing #{file}..."
      @bucket.objects[file].delete
      puts 'done'
    end
  end

  def s3_filelist
    @s3.buckets[S3_TARGET_BUCKET].objects.map { |x| x.key }
  end
end

