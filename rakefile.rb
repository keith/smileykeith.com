#!/usr/bin/env rake

# sass --watch _sass:css --style=compressed
# jekyll server --watch
task :default => :build

desc "Build the site"
task :build do
  puts "Compiling sass..."
  puts %x[bundle exec sass _sass/style.scss css/style.css --style=compressed]

  puts "Building site..."
  puts %x[bundle exec jekyll build]
end
