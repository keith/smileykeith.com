---
layout: post
title: "Global htaccess"
date: 2013-08-14 13:12
---

When starting a new web project one of the first things I do is download
the most up to date [HTML5 Boilerplate](http://html5boilerplate.com/).
It provides a great starting point for the HTML you need in a project.
It also comes with an extremely complete [.htaccess](https://github.com/h5bp/html5-boilerplate/blob/master/.htaccess)
file. While this is very nice for a single site they recommend you do
something different for multiple sites at [the very top](https://github.com/h5bp/html5-boilerplate/blob/21c614849afc5b518685b68d81d2b0c8f7971f0a/.htaccess#L4-L6).

> (!) Using .htaccess files slows down Apache, therefore, if you have access
> to the main server config file (usually called httpd.conf), you should add
> this logic there: http://httpd.apache.org/docs/current/howto/htaccess.html.

This got me to their awesome collection of [server configs](https://github.com/h5bp/server-configs)
which has their, and in many ways the communities, recommended settings
depending on your webserver. The [apache configs](https://github.com/h5bp/server-configs-apache)
have the same `.htaccess` file so I decided to dig into how to do this.

They direct you to the [apache article](http://httpd.apache.org/docs/current/howto/htaccess.html)
about using `.htaccess` files which has a similar comment about their
use.

> You should avoid using .htaccess files completely if you have access to httpd main server config file
> Using .htaccess files slows down your Apache http server. Any directive that you can include in a
> .htaccess file is better set in a Directory block, as it will have the same effect with better performance.

So I decided to set this up on my [Linode VPS](http://www.linode.com/?r=c190426bf1ff0f144b48997675bae8b32d339824) which is running Ubuntu 10.04.
As stated in the original file comment they recommend using the
`httpd.conf` file for your custom configuration like this. But
[apparently](http://stackoverflow.com/a/11687212/902968) that file could be
overwritten on updates of Apache which would be pretty annoying. Luckily
the default Apache config file (`apache2.conf` on 10.04) includes the
contents of the `conf.d` folder which is in the same location. By
creating a `foo.conf` file in that directory Apache should immediately
load its contents. As mentioned in the comment from the Apache site the
custom configuration needs to be wrapped in a [Directory](http://httpd.apache.org/docs/current/mod/core.html#directory) block.
The block expects you to provide a path to the files you want to be
affected by the contained configuration. Since I wanted this to work for
all the sites being served by Apache I simply used `/srv/www/*/` which
includes my entire sites directory.

Besides the speed increased gained by using a global `.htaccess` file
this allows you to have much shorter custom files for site specific
configuration. For example only required configuration for one of my sites
was the `ErrorDocument`s. Now my `.htaccess` file went from 300+ lines
to

{% highlight apache %}
ErrorDocument 403 /403.php
ErrorDocument 404 /404.php
ErrorDocument 500 /500.php
{% endhighlight %}
