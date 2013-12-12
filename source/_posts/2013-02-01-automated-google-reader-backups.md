---
layout: post
title: "Automated Google Reader Backups"
date: 2013-02-01 12:30
---

I spend a lot of time in my RSS [Reeder](http://reederapp.com/) (see what I did there?). I still find Google Reader to be the best and easiest way to manage my subscriptions, although I've been wanting to switch to [Fever](http://feedafever.com/) for a while.

One thing I wanted to do when I launched my new site (the one you're reading) was to have a downloadable up to date export of my Google Reader OPML file (which of course I never did). I looked around for good ways to automate this and I found a simple Python script to do it with (sorry I couldn't find it again for this post). I decided to rewrite it in Ruby and set it up on my server as an automated cron job.

To run the script I came up with use something like:

{% codeblock %}
ruby path/to/googleReaderOPML.rb username@gmail.com SekretPassword
{% endcodeblock %}

To add it to your crontab (to run every Sunday at 1:01am) use something like:
{% codeblock %}
1 1 * * 7 ruby path/to/googleReaderOPML.rb username@gmail.com SekretPassword
{% endcodeblock %}

{% gist 4692741 googleReaderOPML.rb lang:ruby %}
