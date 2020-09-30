---
layout: post
title: "LLDB Reproducers"
date: 2020-09-29 19:39
---

Swift developers love to complain about LLDB. While there are many
reasaonable complaints, the important question is what can we do to make
it better.

Enter [reproducers][reproducers]. Reproducers provide a way to run LLDB
while also capturing information about your debugging session. Then you
can [submit][radar] the session to Apple to reproduce the bug you've
experienced.

# How?

While the steps to use reproducers are mostly straight forward, the
problem is launching LLDB from Xcode does not enable `--capture` mode
(FB7878562). This means if you want to provide a reproducer for an issue
you've experienced in a Xcode debugging session you need to reproduce
it outside of Xcode instead.

Note: to provide a useful reproducer, LLDB bundles all files the
debugging session touched. This will include binaries with debug info
that you may consider sensitive. Be sure to verify what you're sharing
with Apple before you [send it][radar].


## CLI / macOS app

If you're debugging a program on your Mac, there are a few steps:

1. Run the app in Xcode and stop it (so you know it's up to date).
2. In Terminal.app navigate to your DerivedData directory (you can find
   this by right clicking on your app in the "Products" section of
   Xcode's project navigator, and clicking "Show in Finder").
3. Run `lldb --capture /path/to/Your.app`.
4. In the LLDB session run `process launch --stop-at-entry`.
5. Now you're in a paused LLDB session. Here you can set whatever
   breakpoints you need to reproduce your issue. Often for me this means
   breaking at a specific place, and running some version of `po foo`
   that causes an issue.
6. Once you're done reproducing the issue, run `reproducer generate` in
   LLDB. This will print the path the information was written to.
7. Verify the contents of the output directory doesn't include anything
   you're not comfortable sharing with Apple, zip it, and [submit a
   radar][radar]!

## iOS app on the simulator

Running apps directly from LLDB on the iOS simulator does [not
work](https://forums.swift.org/t/using-lldb-with-ios-simulator-from-cli/33990/6)
the same way as running a macOS app. Because of this the steps differ.

1. Run the app in Xcode and stop it. This way it's updated and installed
   on the iOS simulator.
2. Run `lldb --capture --wait-for --attach-name YOUR_APP_NAME`.
3. Manually launch your app in the Simulator.
4. Now you're in a paused LLDB session. Here you can set whatever
   breakpoints you need to reproduce your issue. Often for me this means
   breaking at a specific place, and running some version of `po foo`
   that causes an issue.
5. Once you're done reproducing the issue, run `reproducer generate` in
   LLDB. This will print the path the information was written to.
6. Verify the contents of the output directory doesn't include anything
   you're not comfortable sharing with Apple, zip it, and [submit a
   radar][radar]!

## iOS app on device

Unfortunately, I haven't yet figured out the right incantation to launch
LLDB directly and attach to a process on device. If anyone has a good
workflow for this please [let me know](https://twitter.com/SmileyKeith).

# Tips

- Checkout the [reproducers][reproducers] info for more details.
- `man lldb` is very helpful.
- Run `reproducer status` to verify you're in capture mode.
- Run `help COMMAND [SUBCOMMAND]` in LLDB to get info on the commands
  you're running.
- Run `help b` to see examples of how to set breakpoints from the
  command line interface.
- See the [LLDB tutorial](https://lldb.llvm.org/use/tutorial.html) for
  more breakpoint examples.
- Try out `lldb --replay /path/to/your/reproducer` to see what Apple
  will see.

[radar]: https://feedbackassistant.apple.com
[reproducers]: https://lldb.llvm.org/resources/reproducers.html
