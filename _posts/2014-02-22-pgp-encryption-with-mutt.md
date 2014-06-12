---
layout: post
title: "PGP encryption with Mutt"
date: 2014-02-22 18:25
---

Modern email protocols were [never
meant](https://en.wikipedia.org/wiki/Email_privacy#Risks_to_user) to be
secure.

While there is some theoretical benefit from interacting with your email
over HTTPS, if the recipient happens to be have the same email provider
and the email never leaves the encrypted server, true

Unfortunately just interacting with your email over HTTPS doesn't
secure your communications as much as you should probably want.

The idea that by interacting with your email over HTTPS your
communications are more secure is an absolute fallacy.

When it comes to encrypting your email
[PGP](https://en.wikipedia.org/wiki/Pretty_Good_Privacy) seems like the
only option worth mentioning. The major downside to PGP is the setup and
the general complexity of how it works. While this makes it a great
cryptographic solution, it makes it difficult for it to become widely
used.

While this guide will focus on PGP usage with mutt, there is probably
some extension for your native email client of choice. If you are not
familiar with mutt I would recommend [The Homely
Mutt](http://stevelosh.com/blog/2012/10/the-homely-mutt/) to set it up
on your system. There are other, possibly easier, ways to get everything
setup but having used Mutt's native IMAP support previously I would
definitely recommend Steve's method.
