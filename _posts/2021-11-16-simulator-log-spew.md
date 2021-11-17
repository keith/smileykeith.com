---
layout: post
title: "Silencing iOS simulator log noise"
date: 2021-11-16 18:00
---

When Apple transitioned to using `os_log` for system logs it seemed they
also decided to open the floodgates for what logs were surfaced in our
apps.

This lead to a plethora of stackoverflow questions recommending you
disable `os_log` entirely by setting `OS_ACTIVITY_MODE=disable` in your
target's scheme. This is fine for some cases but might also silence some
actually useful logs, or your own logs if you want to use `os_log` for
its feature-set.

`os_log` has a nice set of categorization for logs, for example when
viewing streaming logs in `Console.app` you can show the process,
subsystem, and category for each log.

![Screenshot of Console.app UI](/images/console-categories.png)

Perhaps ideally we could use an environment variable with more granular
filtering based on this categorization, but that would likely get
complex quickly. Instead we can update OS log's configuration to disable
some specific types of logs. Here are a few examples I found useful for
Lyft's iOS project:

```
xcrun simctl spawn booted log config --subsystem com.apple.CoreBluetooth --mode level:off
xcrun simctl spawn booted log config --subsystem com.apple.CoreTelephony --mode level:off
xcrun simctl spawn booted log config --subsystem com.apple.network --category boringssl --mode level:off
```

You can replace `booted` here with a specific iOS simulator UDID, which
can be found by running `xcrun simctl list devices`. Since this is
simulator specific, you will have to re-run whatever commands you decide
on when you create new simulators.

More options for the `log` command can be found with [`man
log`](https://keith.github.io/xcode-man-pages/log.1.html)
