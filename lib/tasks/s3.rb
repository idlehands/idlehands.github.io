require_relative '../s3_client'

desc 'Upload the site to S3'
task :upload do
  raise 'Site is not prepared to upload' unless File.exists?('_site/index.html')
  client = S3Client.new(AWS_ACCESS_KEY_ID, AWS_SECRET_ACCESS_KEY, S3_TARGET_BUCKET)

  uploaded   = client.upload(Dir['_site/**/*'])
  difference = client.s3_filelist - uploaded

  unless difference.empty?
    puts "Files on remote that were not uploaded: #{difference.join(', ')}"
    client.delete(difference)
  end
end
