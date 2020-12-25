---
layout: post
title: "Cross compiling for Apple Silicon with Swift Package Manager"
date: 2020-12-24 14:32
---

If you distribute binaries for command line tools built with [Swift
Package Manager](https://swift.org/package-manager), you might have
previously built your distribution binary with:

```sh
% swift build --configuration release
```

If you inspect the binary, you can see it was built for the current
machine's architecture by default:

```none
% file .build/release/package
.build/release/package: Mach-O 64-bit executable x86_64
```

Previously, this was sufficient since macOS only supported one
architecture. Now, in order to fully utilize the native performance of
Apple Silicon chips, we need to produce a [fat
binary](https://en.wikipedia.org/wiki/Fat_binary) that contains a slice
for both `x86_64` and `arm64`.

Swift Package Manager has a few different ways to achieve this. The
easiest way, as far as I can tell, is to pass the hidden `--arch` flag
once for each architecture:

```sh
% swift build --configuration release --arch arm64 --arch x86_64
```

This goes through a [different code
path](https://github.com/apple/swift-package-manager/blob/ec407ac14738bf132b23441aa9435a919124eda6/Sources/XCBuildSupport/XcodeBuildSystem.swift)
in Swift Package Manager, and utilizes Xcode's underlying XCBuild tool.
This results in the built binary being in a different path than usual.
Inspecting the new artifact, we can see we have a binary containing both
requested architectures:

```none
% file .build/apple/Products/Release/package
.build/apple/Products/Release/package: Mach-O universal binary with 2 architectures: [x86_64:Mach-O 64-bit executable x86_64] [arm64:Mach-O 64-bit executable arm64]
.build/apple/Products/Release/package (for architecture x86_64):        Mach-O 64-bit executable x86_64
.build/apple/Products/Release/package (for architecture arm64): Mach-O 64-bit executable arm64
```

Another option is to build once for each architecture, and then combine
the binaries using
[`lipo`](https://keith.github.io/xcode-man-pages/lipo.1.html). Unlike
the `--arch` option, this approach also works on Linux. Here's an
example:

```sh
% swift build --configuration release --triple arm64-apple-macosx
% swift build --configuration release --triple x86_64-apple-macosx
% lipo -create -output package .build/arm64-apple-macosx/release/package .build/x86_64-apple-macosx/release/package
```

Inspecting our final binary we can see it correctly has both
architectures:

```none
% file package
package: Mach-O universal binary with 2 architectures: [x86_64:Mach-O 64-bit executable x86_64] [arm64:Mach-O 64-bit executable arm64]
package (for architecture x86_64):      Mach-O 64-bit executable x86_64
package (for architecture arm64):       Mach-O 64-bit executable arm64
```
