#!/usr/bin/env rake

# sass --watch _sass:css --style=compressed
# jekyll server --watch
task :default => :build

task :build do
  puts %x[sass _sass/style.scss css/style.css --style=compressed]
  puts %x[sass _sass/sdark.scss css/sdark.css --style=compressed]
  puts %x[sass _sass/slight.scss css/slight.css --style=compressed]

  puts %x[jekyll build]
end

