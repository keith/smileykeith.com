---
layout: post
title: "Switching Xcode versions without a password"
date: 2021-08-12 13:40
---

When switching between multiple Xcode versions one way to globally
update the version you want to use is by running
[`xcode-select`][xcode-select] like this:

```sh
sudo xcode-select -s /Applications/Xcode-12.5.1.app
```

Then, if you want to automatically accept Xcode's license, and install
any extra packages it requires (which should only be required the for
the first time you run a new version), you can run:

```sh
sudo xcodebuild -runFirstLaunch
```

This works fine locally, but when updating remote CI machines, entering
the password can be troublesome. Furthermore if you want to support
having CI machines automatically switch between Xcode versions when
testing upcoming changes, you may not have the opportunity to be
prompted at all. Lucky for us, the [`sudoers`][sudoers] file format,
which configures the `sudo` command, allows us to skip password entry
for specific commands with a bit of configuration.

The easiest way to edit this configuration is by running:

```sh
sudo visudo
```

This opens the default `/etc/sudoers` configuration file in vim. While
we could add our custom configuration here, we can also see the default
configuration that ships with macOS contains this line:

```
#includedir /private/etc/sudoers.d
```

This tells `sudo` to load all the files in `/etc/sudoers.d`[^1] as
configuration as well. Using this knowledge we can nicely separate our
custom configuration, making it easier to overwrite, or remove, in the
future. Separating our custom configuration also makes us less likely to
break the default configuration, potentially leading to major issues.

To setup our custom configuration we can run this command:

```sh
echo "%admin ALL=NOPASSWD: /usr/bin/xcode-select,/usr/bin/xcodebuild -runFirstLaunch" | sudo tee /etc/sudoers.d/xcode
```

Let's break this down[^2]. The `%admin` component makes this
configuration apply to all users that are in the `admin` group[^3].
Using this group is probably good enough for this use case, but if you'd
like to restrict this more, you can change this to a your account's
specific username such as `ksmiley`.

The second component `ALL` makes this rule apply to all hosts, I'm not
sure in what context any host besides the current one would take these
rules into account, but `ALL` ignores that.

The third component `NOPASSWD` is the key piece of this functionality.
This enables us to run the following commands without being prompted for
our password.

The last component is the commands we want to allow to be run without a
password. There are 2 things to note here.

1. We specify just the `xcode-select` binary, using the absolute path.
   This allows all subcommands handled by `xcode-select` to be run
   without a password.
2. The `xcodebuild` command also contains the one subcommand we want to
   be able to run without a password. Limiting this is important because
   otherwise you could run `sudo xcodebuild build` without a password,
   which could execute malicious run scripts or do other terrible
   things. With this argument specified any other invocation of `sudo
   xcodebuild` will still require a password.

Just like that we no longer have to enter our password when swapping
between Xcode versions.

[^1]: `/etc` is actually a symlink to `/private/etc`, which is why we
      can use them interchangeably in this case

[^2]: For many more format examples checkout the [man page][sudoers]

[^3]: You can see what groups the current user is in by running
      `groups`, but for macOS all administrator accounts are part of
      this group.

[sudoers]: https://keith.github.io/xcode-man-pages/sudoers.5.html
[xcode-select]: https://keith.github.io/xcode-man-pages/xcode-select.1.html
