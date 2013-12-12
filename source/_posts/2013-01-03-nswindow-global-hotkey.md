---
layout: post
title: "NSWindow Global Hotkey"
date: 2013-01-03 10:44
---

For quite a while I was having trouble dealing with a global show/hide hotkey for windows in Objective-C. Global hotkeys are already [hard](http://stackoverflow.com/questions/4807319/register-hotkey) [enough](https://github.com/Keithbsmiley/PTHotKeyTest). Although [MASShortcut](https://github.com/shpakovski/MASShortcut) has solved that. Yes I know of [ShortcutRecorder](http://wafflesoftware.net/shortcut/) but it's very dated (MASShortcut even uses blocks!).

I found that once I had the shortcut working I was having a hard time dealing with opening and closing, showing and hiding the application. What seemed to happen was when the method was called and `[[NSRunningApplication currentApplication] isActive]` was evaluated in an `if` statement along with an `else` clause, if the application was hidden using `[[NSApplication sharedApplication] hide:self];` it was reevaluated and it hit the `else` case. This also happened with an `if` statement checking if the window was already visible with `[myWindow isVisible]` even with `return;` statements inserted in appropriate places.

My solution was adding `NSNumber`s acting as booleans to keep track of the value allowing me to avoid `else` statements altogether and use `else if`s instead.

{% gist 4390897 showHideMainWindow.m %}
