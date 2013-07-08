---
layout: post
title: "Raking Podspecs"
date: 2013-01-04 11:09
---

I spend a decent amount of time these days helping maintain the [CocoaPods](http://cocoapods.org/) [specs repo](http://github.com/cocoapods/specs) by managing pull requests and issues. CococaPods is an awesome dependency manager similar to [Rubygems](http://rubygems.org/) for Objective-C projects. Unfortunately a lot of submitted podspecs haven't been correctly formatted or they're missing required information. CocoaPods has an awesome build in command `pod spec lint` that allows you to make sure the spec is valid and complete. Understandably people who are new to CocoaPods trying to submit their libraries are unaware of this awesome tool. Therefore when I look through the pull requests, I like to lint them myself (CocoaPods does [utilize Travis](https://travis-ci.org/CocoaPods/Specs) but unfortunately it can't do everything).

Since CocoaPods supports multiple versions of Ruby (1.8.7 and 1.9.3) to be complete ideally you'd lint them on both versions. Tools like [RVM](https://rvm.io/) and [rbenv](https://github.com/sstephenson/rbenv)(my tool of choice) make it easy to quickly switch between different versions of Ruby using `.rvmrc` and `.rbenv-version` respectively. As you can probably assume I wanted to automate this. So I wrote a quick [Rakefile](http://rake.rubyforge.org/) to do this for me.

{% highlight ruby %}
#!/usr/bin/env rake

# NOTE: Must be using rbenv 4.0 to use `system` and `.ruby-version`
## Set your preferred ruby versions
$V18 = 'system'
$V19 = '1.9.3-p385'
$RBENV = '.ruby-version'

# The gem to use
$GEM = 'cocoapods'

task :default => :lint
task :c       => :clean

desc "Lint podspecs on multiple versions of ruby with rbenv"
task :lint do
  if Dir.glob('*.podspec').count < 1
    puts "No podspecs in #{ Dir.pwd }"
    exit
  end

  existed = versionFileExists?
  if existed
    old_version = currentVersion
  end

  # Loop through all podspecs
  Dir.glob('*.podspec').each do |file|
    # Loop through ruby versions
    2.times do |x|
      version = x == 0 ? $V18 : $V19
      writeVersion(version)

      puts "Linting #{ file } on Ruby version #{ currentVersion }"
      puts lint(file)
    end
  end

  # If the dotfile already existed rewrite the original code
  if existed
    writeVersion(old_version)
  else
    File.delete($RBENV) if versionFileExists?
  end
end

desc "Delete all podspec files"
task :clean do
  Dir.glob('*.podspec').each { |file| File.delete(file) }
  Dir.glob($RBENV).each { |file| File.delete(file) }
end

# Check to see if the current dotfile exists
def versionFileExists?
  File.exists?($RBENV)
end

# Retrieve the current version from the rbenv dotfile
def currentVersion
  File.open($RBENV, "r") { |io| io.read }
end

# Write out a version to .rbenv-version
def writeVersion(version)
  File.open($RBENV, 'w') { |file| file.write("#{ version }") }
end

# Run the lint
def lint(podspec)
  %x[pod spec lint "#{ podspec }"]
end
{% endhighlight %}

