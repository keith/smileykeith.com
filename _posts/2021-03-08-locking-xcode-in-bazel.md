---
layout: post
title: "Locking Xcode versions in bazel"
date: 2021-03-08 08:40
---

When using [bazel](https://www.bazel.build) on a team, one of the
things you quickly want to do is stand up a [remote
cache](https://docs.bazel.build/versions/master/remote-caching.html).
This allows bazel to download build artifacts instead of spending CPU
cycles reproducing things that have already been built by someone else.

In order for bazel to guarantee that downloading the artifacts instead
of building them will produce the same results, it must ensure that all
the inputs of your build are the same as a previous build.[^1] For macOS
and iOS builds bazel's inputs include the version of Xcode you're using.
This means if developers on your team use different versions of Xcode,
they cannot share the same build cache.

Bazel discovers your currently installed Xcode versions by running
[`xcode_locator`](https://github.com/bazelbuild/bazel/blob/cd6724deb7dad05c477425fb09eff613659a5b3f/tools/osx/xcode_locator.m),
and then
[generating](https://github.com/bazelbuild/bazel/blob/cd6724deb7dad05c477425fb09eff613659a5b3f/tools/osx/xcode_configure.bzl)
a `BUILD` file that contains an entry for every version you currently
have installed. The result looks something like this:[^2]

```py
xcode_version(
    name = "version12_4_0_12D4e",
    version = "12.4.0.12D4e",
    aliases = ["12.4.0", "12.4", "12.4.0.12D4e"],
    default_ios_sdk_version = "14.4",
    default_tvos_sdk_version = "14.3",
    default_macos_sdk_version = "11.1",
    default_watchos_sdk_version = "7.2",
)

xcode_version(
    name = "version12_2_0_12B45b",
    version = "12.2.0.12B45b",
    aliases = ["12.2.0", "12", "12.2", "12.2.0.12B45b"],
    default_ios_sdk_version = "14.2",
    default_tvos_sdk_version = "14.2",
    default_macos_sdk_version = "11.0",
    default_watchos_sdk_version = "7.1",
)

xcode_config(
    name = "host_xcodes",
    versions = [":version12_4_0_12D4e", ":version12_2_0_12B45b"],
    default = ":version12_4_0_12D4e",
)
```

To fetch the contents of this file on your machine you can run:

```sh
cat bazel-$(basename $PWD)/external/local_config_xcode/BUILD
```

In order to enforce developers use the same version, you can short
circuit bazel's Xcode discovery and instead reference a local
[target](https://docs.bazel.build/versions/master/build-ref.html#targets)
that you provide.[^3]

To do this, you can setup your target in the `BUILD` file at the root of
your project (or somewhere else if you'd prefer). Using the contents
from the example above, but only including the Xcode versions you want
to support, it will contain:

```py
xcode_version(
    name = "version12_4_0_12D4e",
    version = "12.4.0.12D4e",
    aliases = ["12.4.0", "12.4", "12.4.0.12D4e"],
    default_ios_sdk_version = "14.4",
    default_tvos_sdk_version = "14.3",
    default_macos_sdk_version = "11.1",
    default_watchos_sdk_version = "7.2",
)

xcode_config(
    name = "host_xcodes",
    versions = [":version12_4_0_12D4e"],
    default = ":version12_4_0_12D4e",
)
```

Then you can add this to your
[`.bazelrc`](https://docs.bazel.build/versions/master/guide.html#bazelrc-the-bazel-configuration-file):

```
build --xcode_version_config=//:host_xcodes
```

This way if a developer tries to build with a version of Xcode that is
not explicitly supported, they see this error:

```
ERROR: /.../BUILD.bazel:31:11: Compiling something failed: I/O exception during sandboxed execution: Running '/.../xcode-locator 12.4.0.12D4e' failed with code 1.
This most likely indicates that xcode version 12.4.0.12D4e is not available on the host machine.
```

This is a simple solution _if_ you only want to support a single version
of Xcode at once. Often it's useful to support multiple Xcode versions
for testing, even if not all versions will get cache hits. In this
case, one solution is to include multiple versions in your `BUILD`
file:

```py
xcode_version(
    name = "version12_4_0_12D4e",
    version = "12.4.0.12D4e",
    aliases = ["12D4e"],
    default_ios_sdk_version = "14.4",
    default_tvos_sdk_version = "14.3",
    default_macos_sdk_version = "11.1",
    default_watchos_sdk_version = "7.2",
)

xcode_version(
    name = "version12_2_0_12B45b",
    version = "12.2.0.12B45b",
    aliases = ["12B45b"],
    default_ios_sdk_version = "14.2",
    default_tvos_sdk_version = "14.2",
    default_macos_sdk_version = "11.0",
    default_watchos_sdk_version = "7.1",
)

xcode_config(
    name = "host_xcodes",
    versions = [":version12_4_0_12D4e", ":version12_2_0_12B45b"],
    default = ":version12_4_0_12D4e",
)
```

Which is very similar to our first example, except we replaced the
`aliases` with the build numbers from each version. This is a perfect
unique value to differentiate between multiple versions during the Xcode
beta cycle. Now we can explicitly pass the
[`xcode_version`](https://docs.bazel.build/versions/4.0.0/command-line-reference.html#flag--xcode_version)
argument with the build number you want to use. You can retrieve the
build number from your current Xcode version like this:

```sh
% xcodebuild -version | tail -1 | cut -d " " -f3
12D4e
```

Using this method you can support multiple versions of Xcode, while
still respecting the user's `xcode-select` value (or `DEVELOPER_DIR`
environment variable).

[^1]: Debugging remote cache misses is something you'll need to get used
      to doing. [This documentation](https://docs.bazel.build/versions/master/remote-caching-debug.html)
      is very helpful.

[^2]: This example doesn't include the remote execution configuration,
      but it works similarity

[^3]: This also improves repository setup time. Otherwise it increases
      with the number of Xcode versions you have installed.
