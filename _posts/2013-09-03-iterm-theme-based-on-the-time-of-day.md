---
layout: post
title: "iTerm theme based on the time of day"
date: 2013-09-03 10:56
---

One of the great things about Vim's textual configuration is it's
ability to contain logic based on outside factors. For the purpose of
this post I'm referring to the ability to set your colorscheme based on
the time of day with something like
[this](https://github.com/Keithbsmiley/dotfiles/blob/a34e432b59e26225ebdb05737b30729b7ea670d9/vimrc#L102-L108).

Having this functionality in Vim with the
[Solarized](http://ethanschoonover.com/solarized) theme at night really
made me want this in [iTerm](http://www.iterm2.com/#/section/home) as
well. Unfortunately iTerm's conifguration doesn't allow anything similar
to this. The closest you get is profiles which you can assign keyboard
shortcuts to for quickly opening windows with different colorschemes.
Luckily, thanks to this [pull
request](https://github.com/gnachman/iTerm2/pull/10) two years ago from
[Piet Jaspers](https://twitter.com/junkiesxl), support was added for
scripting iTerm's entire colorscheme with AppleScript. Using these
AppleScript bindings I was able to create a
[script](https://github.com/Keithbsmiley/dotfiles/blob/master/scripts/itermcolors.applescript)
that changes the entire colorscheme of iTerm based on the time of day
between Solarized light and dark. As you can see the
[bulk](https://github.com/Keithbsmiley/dotfiles/blob/master/scripts/itermcolors.applescript#L27-L49)
of this script is just setting different color attributes based on the
theme you want. While you could do this conversion by hand to 65535
flavored RGB, I made a
tiny Objective-C app to automate the process which is [on
Github](https://github.com/Keithbsmiley/ColorConvert). You can download
the signed binary
[here](https://github.com/Keithbsmiley/ColorConvert/releases/tag/1.0).

Using this newly created AppleScript I then made a zsh
[function](https://github.com/Keithbsmiley/dotfiles/blob/master/functions/colorize) so that I could call `colorize` from anywhere to update the color scheme of the current terminal.
I also chose to do this at the end of my `.zshrc` [here](https://github.com/Keithbsmiley/dotfiles/blob/763e6f3f2bbcd93775c70e0d9ed9878ac99896a3/zshrc#L51).
This way everytime I open a new session my theme is automatically set.

If you have any input on how I could optimize this let me know.
