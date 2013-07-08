#!/usr/bin/env rake

# sass --watch _sass:css --style=compressed
# jekyll server --watch
task :default => :build

desc "Build the site"
task :build do
  puts %x[git submodule update --init --recursive]
  puts %x[sass _sass/style.scss css/style.css --style=compressed]
  puts %x[sass _sass/sdark.scss css/sdark.css --style=compressed]
  puts %x[sass _sass/slight.scss css/slight.css --style=compressed]

  puts %x[jekyll build]
end

ssh_user       = "ksmiley@66.175.208.254"
ssh_port       = "22"
document_root  = "/srv/www/smileykeith.com/blog"
public_dir     = "_site" # compiled site directory

desc "Deploy website via rsync"
task :deploy do
  puts "Deploying via rsync"
  if !File.exists?('_site')
    puts "ERROR: You need to run 'rake build' first"
    exit
  end

  cmd = "rsync -avze 'ssh -p #{ ssh_port }' --delete #{ public_dir }/ #{ ssh_user }:#{ document_root }"

  if system(cmd)
    puts "Deployed!"
  else
    puts "Failed"
  end
end

