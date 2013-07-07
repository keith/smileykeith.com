---
layout: post
title: "Terminal Shortcut in OS X"
date: 2013-02-08 09:59
---

One of my favorite defaults in some Linux distros is the ability to use <CTRL><ALT>T to open a new terminal window. I wanted to enable this same functionality in OS X using [Quicksilver](http://qsapp.com/). I did this using [iTerm 2](http://www.iterm2.com/) but you can do it with the default Terminal if that's what you want.

1. Enable the `Terminal` and `iTerm2` Quicksilver plugins.
![Quicksilver plugins](/images/qs-terminal/qs-plugins.png)

2. Create a new custom hotkey trigger. Using the `Home` directory with the action `Open Directory in Terminal`
![Quicksilver trigger](/images/qs-terminal/qs-triggers.png)

3. Set it's hotkey using the drawer to whatever you want.
![Quicksilver hotkey](/images/qs-terminal/qs-hotkey.png)

4. Set your default `Command Line Interface` `Trigger` to `iTerm` (if that's what you want)
![Quicksilver CLI](/images/qs-terminal/qs-cli.png)

You're done! Now you can easily press your hotkey and pull up a new iTerm/Terminal window whenever and wherever.
