---
layout: post
title: "Objective-C on Travis-CI"
date: 2013-04-11 15:58
---

Recently [Travis](https://travis-ci.org/) added support for Objective-C and there for OS X and iOS projects for continuous integration testing. I gather that people have previously done this with self-hosted dedicated [Jenkins](http://jenkins-ci.org/) machines but since Apple is so aggressive about dropping support for previous versions of the OS it seems like a pain to have to replace your build server every few years. Enter Travis, a great hosted [continuous integration](http://en.wikipedia.org/wiki/Continuous_integration) server that hosts a huge amount of open source projects. I figured with this new support I could host some of my [smaller](https://github.com/Keithbsmiley/KSADNTwitterFormatter) libraries just to set how well it worked. The initial setup process was a bit tedious but I eventually got it to work.

### Assumtions:

+ You have a test framework already integrated with your project (I like [Specta](https://github.com/petejkim/specta)/[Expecta](https://github.com/petejkim/expecta))
+ You have your project on Github in a public repository. Travis offers a [pro](http://about.travis-ci.org/docs/user/travis-pro/) account if you'd rather

### Steps

- Create a `.travis.yml` file in the root of your repository (leading dot is intentional). For many projects a file may just look like:

{% highlight yaml %}
language: objective-c
{% endhighlight %}

<del>By default Travis runs [this script](https://gist.github.com/henrikhodne/73151fccea7af3201f63) for Objective-C projects</del> I was informed [on Twitter](https://twitter.com/henrikhodne/status/322665896806060032) that the current script that runs Objective-C projects is actually located [here](https://github.com/travis-ci/travis-cookbooks/blob/osx/ci_environment/travis_build_environment/files/default/ci_user/travis-utils/osx-cibuild.sh). It was originally created by [Justin Spahr-Summers](https://github.com/jspahrsummers) [here](https://github.com/jspahrsummers/objc-build-scripts). This script seems to run my projects without any issue, they just occasionally require more initial setup (we'll get to that).

- Enable your repository in Travis' settings. From your [Travis profile page](https://travis-ci.org/profile) (after signing in with Github) you should see a list of your repositories, you may have to press 'Sync now', where you can switch on the repository you're planning on adding.

- Configure your project within Xcode. As I assumed above you already have a test target setup. You do have to do a few things in Xcode to make everything work correctly.

  1. Go to 'Manage Schemes' in Xcode. ![Manage Schemes](/images/travis/manageschemes.png)
  2. Check the 'Shared' box for the scheme that needs to be run. ![Shared Scheme](/images/travis/shareschemes.png)
  3. Click 'Edit...' in the bottom left and go to your build action. ![Edit Scheme](/images/travis/editscheme.png)
  4. On the row of your Tests target check the box in the 'Run' column. ![Run Test](/images/travis/runtest.png)

- At this point for a simple project or a project using [CocoaPods](http://cocoapods.org/) you should be good to go. If Travis finds a `Podfile` in the root of your repository it automatically runs `pod install` to get your dependencies (from their [docs](http://about.travis-ci.org/docs/user/languages/objective-c/)). Otherwise there are a ton of [configuration options](http://about.travis-ci.org/docs/user/build-configuration/) for your `.travis.yml` depending on how your repo is setup.

For one of my projects I created a `setup.sh` file at the root of my repo that looks like this:

{% highlight bash %}
#!/usr/bin/env bash

git submodule update --init --recursive
echo "Setting up test frameworks..."
cd Example/Vendor/Specta; rake > /dev/null
cd ../Expecta; rake > /dev/null
echo "Done"
cd ../../../
{% endhighlight %}

This script which I run using the `before_install: ./setup.sh` option in my `.travis.yml` gets all my submodules, sets up Specta and Expecta and then goes back to the root directory for running. If you just have a few simple steps you can also have multiple `before_install` actions like:

{% highlight yaml %}
before_install:
  - cd Example
  - make
{% endhighlight %}

You can read more about other Travis configuration options in their [documentation](http://about.travis-ci.org/docs/user/build-configuration/).

