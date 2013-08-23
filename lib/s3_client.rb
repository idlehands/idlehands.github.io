require 'aws-sdk'
require 'mime-types'

class S3Client
  def initialize(access_key, secret_access_key, bucket)
    AWS.config(
      access_key_id:     access_key,
      secret_access_key: secret_access_key,
    )
  
    @s3 = AWS::S3.new(s3_endpoint: 's3-us-west-2.amazonaws.com')
    @bucket = @s3.buckets[bucket]
  end

  def upload(file_list)
    puts "Bucket: #{@bucket}"
    file_list.inject([]) do |memo, file|
      unless Dir.exists?(file)
        print "uploading #{file}..."

        strip_leading_slashes(file).tap do |s3_filename|
          memo << s3_filename
          mime_type = mime_type_for(file)
          get_or_create_object(s3_filename).write(Pathname.new(file), content_type: mime_type)
        end

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
    @bucket.objects.map { |x| x.key }
  end

  private 

  def get_or_create_object(s3_filename)
    @bucket.objects[s3_filename] || @bucket.object.create(s3_filename)
  end

  def strip_leading_slashes(filename)
    filename.sub(/^.*?\//, '')
  end

  def mime_type_for(file)
    case (type = MIME::Types.type_for(file).first)
      when nil then 'text/html'
      when 'text/html' then 'text/html; charset=utf-8'
      else type
    end
  end
end
