---
layout: post
title: "Spawning iTerm Windows"
date: 2013-01-03 12:34
---

I've recently been searching around for a good way to 'spawn' an [iTerm](http://www.iterm2.com/) window (no I don't use tabs in iTerm), at the `pwd` in my current iTerm window. I couldn't find any good way to do it so I jumped in to AppleScript Editor and made something happen.

{% highlight applescript %}
on run argv
	tell application "iTerm"
		set t to make new terminal
		tell t
			activate current session
			launch session "Default Session"
			tell the last session
				write text "cd \"" & item 1 of argv & "\"; clear; pwd"
			end tell
		end tell
	end tell
end run
{% endhighlight %}

I then added it to my [zsh](http://www.zsh.org/) aliases with:

{% highlight bash %}
function spawn {
  osascript ~/Dropbox/Code/Applescript/Spawn/SpawniTerm.applescript $PWD
}
{% endhighlight %}

Now I can call `spawn` from any iTerm or Terminal window to open a new iTerm session wherever I called it from.
