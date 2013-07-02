#!/usr/bin/env rake

task :default => :build

task :build do
  puts %x[sass _sass/style.scss css/style.css --style=compressed]
  puts %x[sass _sass/sdark.scss css/sdark.css --style=compressed]
  puts %x[sass _sass/slight.scss css/slight.css --style=compressed]
end

