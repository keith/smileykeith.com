---
layout: post
title: "Debugging bazel actions"
date: 2022-03-02 18:00
---

When working on bazel build infrastructure, something I often need to do
is reproduce an action outside of bazel's infrastructure in order to
debug it further. This debugging often involves changing flags or
swapping out the tool itself for a custom built version.

In many cases updating your bazel configuration as normal should work
well enough. But sometimes when you're iterating on things that
invalidate a significant portion of your build it can be faster to work
on things outside of bazel first, and then update your bazel
configuration based on your discoveries. Another case where this is
useful is if you want to benchmark a specific action by running it many
times individually without the contention caused by bazel parallelizing
other actions.

Since bazel has a lot of infrastructure for keeping builds hermetic,
there are a few steps you need to take to _roughly_ reproduce what bazel
is doing so your debugging is as close to what it runs as possible.

# 1. Build and disable sandboxing

In order for bazel to setup your build environment (including your
downloaded dependencies), and leave it intact for you to muck around
with, you must run a normal build and also either disable sandboxing by
passing `--spawn_strategy=standalone`, or make it leave the sandbox base
around by passing `--sandbox_debug`.

# 2. Grab your action's command line

Once bazel has run and left its environment intact, you need to grab the
command line being run for the action you want to debug. I find that
passing bazel's `-s` flag (also known as [`--subcommands`][subcommands])
is the easiest way to do this. You just have to make sure that the
action you're interested in actually runs. There are a few different
ways you can force bazel to run an action:

- Invalidate the inputs for the action. Unlike other build systems
  `touch`ing input files isn't enough, I often add newlines or comments
  to files to force actions to re-run.
- Change the flags for a command line. For some actions such as C++
  compiles, or native binary linking, there are easy command line flags
  you can pass to invalidate the actions, specifically things like
  `--copt=-v` and `--linkopt=-v` respectively. Another useful thing to
  know is bazel doesn't have any semantics around the contents of these
  flags, so if you need to invalidate the action a second time, you can
  often append the same option again, repeating it, to make bazel re-run
  it. For example `--linkopt=-v --linkopt=-v`, often the underlying tool
  won't care about the repetition. This works best when changing flags
  will only invalidate a small number of actions so you don't have to
  rebuild a ton of things before you get to the action you care about.
- Change flags on the specific target. If changing flags globally is too
  invasive for your build, you can often edit the `copts` attribute of
  the specific target you care about to invalid the action. Again
  passing `-v` is often a useful way to get it to re-run without
  changing semantics of the build. You can also do this with
  [`--per_file_copt`][perfilecopt] so you don't have to change any BUILD
  files. Thanks to Tom Rybka for pointing this out.
- Make it fail. Change the inputs or flags to something that is invalid,
  then your bazel invocation will stop after hitting the action in
  question.

Once you have forcibly re-run your action with `-s`, you should see some
output like this (specifics will vary based on your platform and the
action you're debugging):

```
SUBCOMMAND: # //some_target:some_target [action 'Compiling Swift module //some_target:some_target', configuration: 725a049b28caa74d2a9605a6748b603bdab9e977931b2d02c0bb07b9a06575b2, execution platform: //:macos_x86_64]
(cd /private/var/tmp/_bazel_ksmiley/751b7cfc481e6eb168e92ffcfb919baa/execroot/someworkspace && \
  exec env - \
    APPLE_SDK_PLATFORM=iPhoneSimulator \
    APPLE_SDK_VERSION_OVERRIDE=15.2 \
    XCODE_VERSION_OVERRIDE=13.2.1.13C100 \
  bazel-out/darwin_x86_64-opt-exec-8F99CFCD-ST-41e1ca5c471d/bin/external/build_bazel_rules_swift/tools/worker/universal_worker swiftc @bazel-out/ios-sim_arm64-min12.0-applebin_ios-ios_sim_arm64-fastbuild-ST-40c63e007684/bin/some_target/some_target.swiftmodule-0.params
```

# 3. Reproduce bazel's environment and run

Now that you have the environment and command line bazel ran, you can
roughly reproduce what it did in a few steps:

1. Switch to the directory it built in using the `cd` command it prints:
   `cd /private/var/tmp/_bazel_ksmiley/751b7cfc481e6eb168e92ffcfb919baa/execroot/someworkspace`
2. Reproduce the environment variables it sets for the action:

    ```
    export APPLE_SDK_PLATFORM=iPhoneSimulator
    export APPLE_SDK_VERSION_OVERRIDE=15.2
    export XCODE_VERSION_OVERRIDE=13.2.1.13C100
    ```

3. Run the command line:

    ```
    bazel-out/darwin_x86_64-opt-exec-8F99CFCD-ST-41e1ca5c471d/bin/external/build_bazel_rules_swift/tools/worker/universal_worker \
      swiftc \
      @bazel-out/ios-sim_arm64-min12.0-applebin_ios-ios_sim_arm64-fastbuild-ST-40c63e007684/bin/some_target/some_target.swiftmodule-0.params
    ```

# Gotchas

At this point you're likely very close to reproducing what bazel was
running, but there are a few other things to keep in mind:

- Bazel has some implicit environment variable manipulation in some
  cases that you need to reproduce. For example for builds that rely on
  Xcode on macOS, the Xcode discovery logic is done implicitly by bazel,
  requiring you to approximate that logic yourself. To reproduce this
  specific case you need to make sure to set `DEVELOPER_DIR` and
  `SDKROOT` with something like[^1]:

```
export DEVELOPER_DIR=$(xcode-select -p)
export SDKROOT=$(xcrun --show-sdk-path --sdk iphonesimulator)
```

- Some actions in bazel use a number of wrappers before getting down to
  the actual command being run. In the example above `universal_worker`
  is a pre-processor for the Swift command line. Sometimes you might
  want to go a bit deeper in the stack. I often pass `-v` as an extra
  argument to the wrapper invocation to get the final command line it
  runs, and then iterate on that instead of the one bazel invokes.
- Other environment variables can impact behavior. Depending on how you
  run bazel normally and what you're debugging, this might matter as the
  action may have access the environment variables that it wouldn't have
  inside of bazel. This often doesn't make a difference if your build is
  hermetic, but is worth keeping in mind (especially for `PATH`).
- These steps may change over time. Ideally there would be a more
  straightforward way to reproduce actions like this, potentially by
  parsing bazel's execution log, but in the meantime this approach works
  well in my experience.

[^1]: I use [a script][a script] for this

[a script]: https://github.com/keith/dotfiles/blob/main/functions/set-bazel-env
[perfilecopt]: https://bazel.build/reference/command-line-reference#flag--per_file_coptg
[subcommands]: https://bazel.build/reference/command-line-reference#flag--subcommands
