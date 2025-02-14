---
layout: post
title: "Bazel caching and compressed debug info"
date: 2025-02-14 10:00
---

One of bazel's most attractive features is the ability for it to
remotely cache artifacts to reduce unnecessary work for large builds.
Unfortunately users quickly discover this comes with non-trivial
financial and bandwidth implications.

There are many ways, of varying difficulty, to try and improve your
cache usage. From breaking unnecessary dependencies, to adding
larger local storage for CI workers, builds without the bytes, build
avoidance, etc.

For codebases with lots of C or C++ one of the potentially easiest wins
is to enable compressed debug information[^1]. Let's look at an example from
our codebase.

Looking at the size of a non-trivial C++ binary built with `-g -O2`
(similar to cmake's `RelWithDebInfo` configuration), or binary clocks in
at ~530mbs:

```
% du -sh bin
536M    bin
```

To get a sense of what percentage of this binary is debug info, we can
use `llvm-objcopy` to strip the debug info entirely:

```
% llvm-objcopy --strip-debug bin strippedbin
% du -sh strippedbin
159M    strippedbin
```

This shows us that almost 70%(!!) of the binary size is taken up with
debug info. In release configurations we can eliminate this entirely
with bazel's `--strip` argument, but for developer builds, or other use
cases where you need debug info, we can still improve this.

If we use `llvm-objcopy` again, this time to compress the debug info, we
can immediately see our potential gains:

```
% llvm-objcopy --compress-debug-sections bin compressedbin
% du -sh compressedbin
290M    compressedbin
```

This shows us we can get an almost 50%(!!) improvement in binary size in
this example.

To enable this in bazel, assuming you're using a relatively recent
version of `gcc` or `clang`, you can add something like this to your
`.bazelrc`[^2]:

```
build --enable_platform_specific_config
build:linux --copt=-gz --host_copt=-gz
build:linux --linkopt=-gz --host_linkopt=-gz
```

In practice we saw cache reads drop by nearly 60% when we rolled out
this change.

Reducing binary size with this approach has a lot of benefits, but it's
even more pronounced when using bazel and closely monitoring your cache
download sizes.

[^1]: [This post](https://maskray.me/blog/2022-01-23-compressed-debug-sections) goes into way more detail than I will
[^2]: Passing these flags on macOS likely doesn't have a downside, but they are ignored
