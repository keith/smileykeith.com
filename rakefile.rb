#!/usr/bin/env rake

require 'stringex'

# sass --watch _sass:css --style=compressed
# jekyll server --watch
task :default => :build

desc "Build the site"
task :build do
  puts "Pulling down submodules..."
  puts %x[git submodule update --init --recursive]

  puts "Compiling sass..."
  puts %x[sass _sass/style.scss css/style.css --style=compressed]

  puts "Building site..."
  puts %x[jekyll build]
end

ssh_user       = "ksmiley@66.175.208.254"
ssh_port       = "22"
document_root  = "/sites/smileykeith.com/public"
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

# usage rake new_post[my-new-post] or rake new_post['my new post'] or rake new_post (defaults to "new-post")
posts_dir = "_posts"
desc "Begin a new post in #{posts_dir}"
task :new, :title do |t, args|
  if args.title
    title = args.title
  else
    print "Enter a title for your post: "
    title = STDIN.gets.chomp
  end
  filename = "#{posts_dir}/#{Time.now.strftime('%Y-%m-%d')}-#{title.to_url}.md"
  if File.exist?(filename)
    abort("rake aborted!") if ask("#{filename} already exists. Do you want to overwrite?", ['y', 'n']) == 'n'
  end
  puts "Creating new post: #{filename}"
  open(filename, 'w') do |post|
    post.puts "---"
    post.puts "layout: post"
    post.puts "title: \"#{title.gsub(/&/,'&amp;')}\""
    post.puts "date: #{Time.now.strftime('%Y-%m-%d %H:%M')}"
    post.puts "---"
  end
end
