import 'lib/tasks/s3.rb'

S3_TARGET_BUCKET      = 'relistan.com'
AWS_ACCESS_KEY_ID     = 'AKIAIU2IM6277LBHFJFA'
AWS_SECRET_ACCESS_KEY = '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'

def safe_system(cmd)
  raise "Error executing #{cmd}!" unless system(cmd) 
end

desc 'build the site into the _site dir'
task :build do
  safe_system 'bundle exec lessc assets/less/main.less > assets/css/main.css'
  safe_system 'bundle exec jekyll build'
end
