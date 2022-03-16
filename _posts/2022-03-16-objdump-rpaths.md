---
layout: post
title: "Printing rpaths with objdump"
date: 2022-03-16 10:00
---

MachO binaries contain load commands to indicate to dyld where it should
search for the libraries the binary depends on.

These paths are often useful to inspect when debugging why your binary
isn't discovering the libraries you'd expect.

Previously you could discover these with:

```
% otool -l `xcrun -f swiftc` \
  | grep -A2 LC_RPATH \
  | grep "^\s*path" \
  | cut -d " " -f 11
@executable_path/../lib/swift/macosx
@executable_path/../lib/swift/macosx
```

This example is quite verbose and fragile for such a common action, so
recently I [committed a change][diff] to add an easier option with
LLVM's `objdump`. This change shipped with LLVM 13 or Xcode 13.3 on
macOS, allowing you to run:

```
% objdump --macho --rpaths `xcrun -f swiftc`
/Applications/Xcode-13.3.0.app/Contents/Developer/Toolchains/XcodeDefault.xctoolchain/usr/bin/swiftc:
@executable_path/../lib/swift/macosx
```

This is much more succinct and memorable, but also has slightly
different output. This is because `objdump` automatically detects the
current machine's architecture, and only prints the rpaths for that
slice of the fat binary. It also outputs the path of the binary being
run on, which you can disable with `--no-leading-headers`.

Hopefully you find this as useful as I do!

[diff]: https://reviews.llvm.org/D100681
