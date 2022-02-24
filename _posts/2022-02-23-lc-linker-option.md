---
layout: post
title: "Auto linking with Mach-O binaries"
date: 2022-02-23 18:00
---

Auto linking is a feature that embeds information in your binaries' at
compile time which is then used at link time to automatically link your
dependencies. This allows you to reduce the duplication of flags between
the different phases of your (or your consumers') builds.

For example, with this Objective-C file:

```objc
#include <Foundation/Foundation.h>

int main() {
    NSLog(@"Hello, World!");
    return 1;
}
```

Compiled with:

```
$ clang -fmodules -c foo.m -o foo.o
```

You can then inspect the options added for use at link time:

```
$ otool -l foo.o | grep LC_LINKER_OPTION -A3
     cmd LC_LINKER_OPTION
 cmdsize 40
   count 2
  string #1 -framework
  string #2 Foundation
...
```

Now when linking this binary you don't have to pass any extra flags to
the linker to make sure you link `Foundation`:

```
$ ld foo.o -syslibroot `xcrun --show-sdk-path`
```

For comparison contrast, if you compile the binary without
`-fmodules`[^1]:

```
$ clang -c foo.m -o foo.o
```

You don't get any `LC_LINKER_OPTION`s, and when linking the binary with
the same command as before, it fails with these errors:

```
$ ld foo.o -syslibroot `xcrun --show-sdk-path`
Undefined symbols for architecture arm64:
  "_NSLog", referenced from:
      _main in foo.o
  "___CFConstantStringClassReference", referenced from:
      CFString in foo.o
ld: symbol(s) not found for architecture arm64
```

To make it succeed you must explicitly link `Foundation` through an
argument to your linker invocation:

```
$ ld foo.o -syslibroot `xcrun --show-sdk-path` -framework Foundation
```

Auto linking is also applied when using module maps that use the `link`
directive:

```
// module.modulemap
module foo {
 link "foo"
 link framework "Foundation"
}
```

Then including `foo` as a module:

```objc
@import foo;

int main() {
    return 1;
}
```

And compiling this file with an include path to the `module.modulemap`
file:

```
$ clang -fmodules -c foo.m -o foo.o -I.
```

The produced object depends on `foo` and `Foundation`. This is useful
for handwriting module map files for prebuilt libraries. You can read
about this file format in [the docs][docs].

You can also see auto linking with Swift code:

```swift
print("Hello, World!")
```

Compiled with:

```
$ swiftc foo.swift -o foo.o -emit-object
```

You can see it requires the Swift standard libraries:

```
$ otool -l foo.o | grep LC_LINKER_OPTION -A3
     cmd LC_LINKER_OPTION
 cmdsize 24
   count 1
  string #1 -lswiftCore
...
```

For Swift this is especially useful since there are some underlying
libraries like `libswiftSwiftOnoneSupport.dylib` that need to be linked,
but should be treated as implementation details that Swift developers
are never exposed to.

In general, this is more than you'll ever need to know about auto
linking. But there are some situations where you might want to force
binaries to include `LC_LINKER_OPTION`s when they don't automatically.
For example, if your build system builds without `-fmodules` (like bazel
and cmake by default) and for some reason you cannot enable it[^1].

There are 2 different ways you can explicitly add `LC_LINKER_OPTION`s
during your builds. First you can pass a flag when compiling your
sources with clang:

```
$ clang -c foo.m -o foo.o -Xclang --linker-option=-lfoo
```

Or verbosely with swiftc:

```
$ swiftc foo.swift -o foo.o -emit-object -Xcc -Xclang -Xcc --linker-option=-lfoo
```

This case works perfectly for libraries you depend on, but for
frameworks you need to pass multiple flags, and because of the space
between them, it doesn't seem like there is a way to pass this with the
current clang flags (although it seems reasonable to add support for
this). Luckily the second option supports spaces in options. Instead of
passing a flag, you can add an assembly directive to one of your source
files you're compiling with clang:

```objc
#include <Foundation/Foundation.h>

asm(".linker_option \"-lfoo\"");
asm(".linker_option \"-framework\", \"Foundation\"");

int main() {
    NSLog(@"Hello, World!");
    return 1;
}
```

Compiling this results in a binary that automatically links `Foundation`
and `foo`:

```
$ clang -c foo.m -o foo.o
```

To see a real world example where this was helpful, check out [this
change][change] for building a static library from a C++ library that
requires some dependencies, but doesn't build with `-fmodules`.

[^1]: You should try to enable modules if possible, this flag just shows
      the difference in behavior.

[change]: https://github.com/keith/StaticIndexStore/blob/a2158c3419a7591bb4a89283abe7a8183d9596d9/example.patch
[docs]: https://clang.llvm.org/docs/Modules.html
