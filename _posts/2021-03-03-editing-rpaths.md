---
layout: post
title: "Editing rpaths for _InternalSwiftSyntaxParser"
date: 2021-03-03 19:48
---

One of the issues with shipping a tool that depends on
[SwiftSyntax](https://github.com/apple/swift-syntax) is that it depends
on a dynamic library that is provided with Xcode called
`_InternalSwiftSyntaxParser`. This library provides some of Swift's
logic for how to parse Swift code. When you run a command line tool that
was built with a different version of Xcode than what you have installed
locally, you hit this issue:

```
<unknown>:0:0: error: The loaded '_InternalSwiftSyntaxParser' library is from a toolchain that is not compatible with this version of SwiftSyntax
```

Ideally, this library would be statically linked to your executable (and
I'm hoping we can find [a
solution](https://github.com/apple/swift/pull/36151) to this) so you
would no longer have to worry about this. In the meantime, we can work
around this issue by shipping the version of the library from Xcode
alongside your executable, and loading that instead. This will increase
your distribution archive's size, but make it easier to support multiple
versions of Xcode at once.

The key to this workaround relies on how
[`dyld`](https://keith.github.io/xcode-man-pages/dyld.1.html) works.
`dyld` is responsible for loading the dynamic libraries your binary
depends on. First, it's useful for you to see what libraries you depend
on with
[`otool`](https://keith.github.io/xcode-man-pages/llvm-otool.1.html).
For example:

```
% otool -L ./.build/debug/drstring-cli
./.build/debug/drstring-cli:
  ...
  /usr/lib/swift/libswiftObjectiveC.dylib (compatibility version 1.0.0, current version 1.0.0, weak)
  /usr/lib/swift/libswiftXPC.dylib (compatibility version 1.0.0, current version 1.1.0, weak)
  @rpath/lib_InternalSwiftSyntaxParser.dylib (compatibility version 1.0.0, current version 17013.0.0)
```

Here you can see many libraries are directly referenced with their
absolute paths while `lib_InternalSwiftSyntaxParser.dylib`, the library
we're specifically interested in, is referenced via a
[`rpath`](https://en.wikipedia.org/wiki/Rpath). You can run this command
to see your binary's `rpaths` (yours may differ depending on your
absolute path to Xcode):

```
% otool -l ./.build/debug/drstring-cli \
  | grep -A2 LC_RPATH \
  | grep "^\s*path" | cut -d " " -f 11
@loader_path
/Applications/Xcode-12.4.0.app/Contents/Developer/Toolchains/XcodeDefault.xctoolchain/usr/lib/swift/macosx
```

Here we can see that `dyld` is instructed to look in 2 directories to
find `lib_InternalSwiftSyntaxParser.dylib`. First, it looks in the
directory specified by `@loader_path`, which in our case is likely
irrelevant since it is the directory that contains our executable. Then,
it looks inside a directory within my absolute path to Xcode (which
isn't very portable), which we can see this includes the library we
expect (you'll have to change this path to your local Xcode path):

```
% ls /Applications/Xcode-12.4.0.app/Contents/Developer/Toolchains/XcodeDefault.xctoolchain/usr/lib/swift/macosx
layouts-x86_64.yaml                  libswiftCompatibilityDynamicReplacements.a
lib_InternalSwiftSyntaxParser.dylib  libswiftRemoteMirror42.dylib
libswiftCompatibility50.a            libswiftRemoteMirrorLegacy.dylib
libswiftCompatibility51.a            prebuilt-modules
```

Given this information, our goal is to replace the default locations
`dyld` searches, and replace those with the directory we want. There are
a few ways we can do this, but first we need to decide what directory we
will ship the library in. Typically, the directory structure for a
command line tool that includes a dynamic library looks something
like this:

```
<prefix>
├── bin
│   └── drstring-cli
└── lib
    └── lib_InternalSwiftSyntaxParser.dylib
```

We can use this for our example. First, we need to copy the library
from Xcode using (this might change with future Xcode releases):


```
cp "$(xcode-select -p)"/Toolchains/XcodeDefault.xctoolchain/usr/lib/swift/macosx/lib_InternalSwiftSyntaxParser.dylib .
```

Then, using
[`install_name_tool`](https://keith.github.io/xcode-man-pages/install_name_tool.1.html),
we can edit the `rpaths` in our binary. In this case, since we only have
2 `rpaths`, and neither of them are what we want, lets delete them both
(you'll have to change the Xcode path for your local installation):

```
% install_name_tool \
  -delete_rpath @loader_path \
  -delete_rpath /Applications/Xcode-12.4.0.app/Contents/Developer/Toolchains/XcodeDefault.xctoolchain/usr/lib/swift/macosx \
  bin/drstring-cli
```

Now, when we run our binary, we see it crashes immediately because it
cannot find  the libraries it needs:

```
% bin/drstring-cli
dyld: Library not loaded: @rpath/lib_InternalSwiftSyntaxParser.dylib
  Referenced from: /Users/ksmiley/dev/DrString/bin/drstring-cli
  Reason: image not found
```

At this point we have 2 options. We can either launch our binary with
some special environment variables that `dyld` reads, or encode the
`rpath` we want into the binary. Since adding the `rpath` to the binary
is destructive, lets try the environment variable approach first as an
example. Using `DYLD_LIBRARY_PATH` we can instruct `dyld` to discover
the libraries we want:

```
% DYLD_LIBRARY_PATH=lib bin/drstring-cli
OVERVIEW: A Swift docstring linter, formatter, nitpicky assistant...
...
```

There is also `DYLD_FALLBACK_LIBRARY_PATH`, which unlike
`DYLD_LIBRARY_PATH`, has a default of `/usr/local/lib:/usr/lib`. This
means if your library doesn't exist in the binary's `rpaths`, but then
happens to be in `/usr/local/lib`, it will still run as expected. This
is useful to know, because [homebrew](https://brew.sh/) installs
libraries to `/usr/local/lib` on Intel based Macs. This can be
surprising if you install an unrelated tool that depends on the same
library and then your binary discovers this unrelated installation when
you don't want it to. If you want to disable this fallback, you can set
the value to `/dev/null`. In our example, using
`DYLD_FALLBACK_LIBRARY_PATH` results in same behavior:

```
% DYLD_FALLBACK_LIBRARY_PATH=lib bin/drstring-cli
OVERVIEW: A Swift docstring linter, formatter, nitpicky assistant...
...
```

Instead of setting environment variables every time we run the binary,
we can edit our binary to instruct `dyld` to search the correct
directory. Again, we use `install_name_tool` for this:

```
% install_name_tool -add_rpath @executable_path/../lib bin/drstring-cli
```

In this case we rely on a relative path, based on the executable's
current path, to find our library. Now, as long as we ship the library
alongside our binary, we can run it without setting any environment
variables.

To check that this worked as expected you can launch your executable
with `DYLD_PRINT_LIBRARIES` set and `grep` for the library:

```
% DYLD_PRINT_LIBRARIES=yesplz bin/drstring-cli 2>&1 | grep _Internal
dyld: loaded: <A1954DF6-6F32-3A7C-A50E-0B7942D95F99> /Users/ksmiley/dev/DrString/bin/../lib/lib_InternalSwiftSyntaxParser.dylib
```

To use this method with Swift Package Manager you'll have to run a
post-processing script that alters your `rpaths` using what we've
learned.

Overall this is more work than if we could produce a statically linked
binary, but it's better than having to force your users on to a specific
version of Xcode.
