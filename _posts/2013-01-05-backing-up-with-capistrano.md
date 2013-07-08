---
layout: post
title: "Backing up with Capistrano"
date: 2013-01-05 12:12
---

We all know not backing up has [consequences](http://www.wired.com/gadgetlab/2012/08/apple-amazon-mat-honan-hacking/). While losing sentimental files would definitely ruin your day, losing your web server's data could be even worse. I've mentioned [before](http://smileykeith.com/2013/01/02/linode-setup/) that I use [Linode](http://www.linode.com/?r=c190426bf1ff0f144b48997675bae8b32d339824) for my server hosting, and while they do offer an [automated backup service](http://library.linode.com/backup-service) I decided I'd rather setup my own solution to back up periodically to my local machine.

Many people use [rsync](http://en.wikipedia.org/wiki/Rsync) to do their server backups. In fact Linode even has a [guide](http://library.linode.com/linux-tools/utilities/rsync#sph_use-rsync-to-back-up-production-environments) on how to set it up (there's a better one [here](http://feross.org/how-to-setup-your-linode/)). I decided that instead of a 1 for 1 directory backup, I would prefer to have a [tarball](http://en.wikipedia.org/wiki/Tar_(file_format)) of the contents. While I could've easily done this with a few bash commands from the server that's not particular ideal for my setup. My local machines don't run 24/7 so if I set it up on the server to automate the backup every week, it may try to initiate the backup when my machine was off (I could try to guess when it's on every week but that's not ideal either).

The obvious solution to this is run it from my local machine instead every week. That way once a week when it's powered up it would log in to the server, create the tarball and pull it down. Insert [Capistrano](https://github.com/capistrano/capistrano) (`[sudo] gem install capistrano`) a [RubyGem](http://rubygems.org/) for 'Remote multi-server automation.' So I wrote a very basic `Capfile` to automate this for me (replace the path to your `www` folder accordingly).

{% highlight ruby %}
load 'deploy'

$SERVER_USER = "username"
$SERVER_IP   = "1.1.1.1"

desc "Backs up server www files"
task :backup, :hosts => $SERVER_IP do
  run "cd /srv; tar -pvczf ~/backup.tar.gz www/"
  run_locally "scp #{ $SERVER_USER }@#{ $SERVER_IP }:~/backup.tar.gz ~/Dropbox/Backups/Server"
end
{% endhighlight %}

Then I added this to my crontab on my local machine by running `crontab -e` and adding the line:

{% highlight bash %}
@weekly /Users/ksmiley/.rbenv/shims/cap -f ~/path/to/Capfile backup
{% endhighlight %}

I included the path to the Capistrano executable since cron (on OS X) executes tasks with `sh`, which isn't setup with my `$PATH`. 

