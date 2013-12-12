---
layout: post
title: "Spawning iTerm Windows"
date: 2013-01-03 12:34
---

I've recently been searching around for a good way to 'spawn' an [iTerm](http://www.iterm2.com/) window (no I don't use tabs in iTerm), at the `pwd` in my current iTerm window. I couldn't find any good way to do it so I jumped in to AppleScript Editor and made something happen.

{% gist 4445138 SpawniTerm.applescript %}

I then added it to my [zsh](http://www.zsh.org/) aliases with:

`function spawn { osascript ~/Dropbox/Code/Applescript/Spawn/SpawniTerm.applescript $PWD }`

Now I can call `spawn` from any iTerm or Terminal window to open a new iTerm session wherever I called it from.
