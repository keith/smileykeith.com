---
layout: post
title: "Raking Podspecs"
date: 2013-01-04 11:09
---

I spend a decent amount of time these days helping maintain the [CocoaPods](http://cocoapods.org/) [specs repo](http://github.com/cocoapods/specs) by managing pull requests and issues. CococaPods is an awesome dependency manager similar to [Rubygems](http://rubygems.org/) for Objective-C projects. Unfortunately a lot of submitted podspecs haven't been correctly formatted or they're missing required information. CocoaPods has an awesome build in command `pod spec lint` that allows you to make sure the spec is valid and complete. Understandably people who are new to CocoaPods trying to submit their libraries are unaware of this awesome tool. Therefore when I look through the pull requests, I like to lint them myself (CocoaPods does [utilize Travis](https://travis-ci.org/CocoaPods/Specs) but unfortunately it can't do everything).

Since CocoaPods supports multiple versions of Ruby (1.8.7 and 1.9.3) to be complete ideally you'd lint them on both versions. Tools like [RVM](https://rvm.io/) and [rbenv](https://github.com/sstephenson/rbenv)(my tool of choice) make it easy to quickly switch between different versions of Ruby using `.rvmrc` and `.rbenv-version` respectively. As you can probably assume I wanted to automate this. So I wrote a quick [Rakefile](http://rake.rubyforge.org/) to do this for me.

{% gist 4453721 rakefile.rb %}
