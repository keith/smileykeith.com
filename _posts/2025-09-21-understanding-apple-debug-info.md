---
layout: post
title: "Understanding Apple Debug Info"
date: 2025-09-21 10:00
---

Apple platforms (macOS, iOS, etc), and specifically Mach-O binaries,
have a slightly different approach to debug info than ELF binaries for
Linux. If you are familiar with Xcode, you might have seen a few related
settings that control what is produced and wondered what the trade-offs
are. The goal of this post is to help you debug cases where these
differences lead to a degraded debugging experience in `lldb` so that
you can fix them.

If you have a particularly complex build, potentially managed by
Bazel[^1] or another tool, especially if you are using distributed
builds, you are even more likely to hit issues.

[^1]: Using a modern version of Bazel and the
    [`apple_support`](https://github.com/bazelbuild/apple_support) CC
    toolchain handles all of this for you

Let's dive in to how the pieces fit together.

# A brief explanation of debug info

Debug info is metadata produced by the compiler that is consumed by
debuggers (like `lldb`), profilers, and other tools. It is used to map
runtime information, like addresses, function arguments, and stack
traces, back to the source that was used to produce the binary. Without
this information debugging in `lldb` shows primarily raw instructions
and addresses, which is rarely acceptable for common debugging
workflows.

# Inspecting debug info

When building for Apple platforms debug info isn't contained in the
final binary (this is the primary difference from the default Linux
workflows). Instead the binary contains references to the files where
`lldb` can find it (this is conceptually similar to if you use
`-gsplit-dwarf` on Linux).

Let's inspect some binaries to see what this really means. First we
create a small binary:

```bash
$ cat main.c
int main() {
  return 0;
}

$ clang main.c -g -c -o main.o
$ clang main.o -o main
```

If we attempt to inspect the debug info contained in `main`, we find
nothing:

```bash
$ dwarfdump main  # use llvm-dwarfdump if not on macOS
main:   file format Mach-O arm64

.debug_info contents:
```

However when we debug this binary in `lldb`, you will correctly see the
source file and line number information:

```bash
$ lldb -- main
(lldb) target create "main"
Current executable set to '/tmp/demo/main' (arm64).
(lldb) b main
Breakpoint 1: where = main`main + 12 at main.c:2:3, address = 0x0000000100000334
(lldb) r
Process 33357 launched: '/tmp/demo/main' (arm64)
Process 33357 stopped
* thread #1, queue = 'com.apple.main-thread', stop reason = breakpoint 1.1
    frame #0: 0x0000000100000334 main`main at main.c:2:3
   1    int main() {
-> 2      return 0;
   3    }
Target 0: (main) stopped.
```

Let's trace back how `lldb` discovers the debug info. First the `main`
binary has a reference to the intermediate `main.o` object file. We can
see the references by looking for the `N_OSO` entries in the binary:

```bash
$ dsymutil -s main | grep N_OSO  # use llvm-dsymutil if not on macOS
[     3] 0000002e 66 (N_OSO        ) 00     0001   0000000068d03443 '/private/tmp/demo/main.o'
```

Then `lldb` loads the debug info directly from the `main.o` object file.
We can see the debug info it contains:

```bash
$ dwarfdump main.o
0x0000000c: DW_TAG_compile_unit
              DW_AT_producer    ("Apple clang version 17.0.0 (clang-1700.3.19.1)")
              DW_AT_language    (DW_LANG_C11)
              DW_AT_name        ("main.c")
              DW_AT_LLVM_sysroot        ("/Applications/Xcode.app/Contents/Developer/Platforms/MacOSX.platform/Developer/SDKs/MacOSX.sdk")
              DW_AT_APPLE_sdk   ("MacOSX.sdk")
              DW_AT_str_offsets_base    (0x00000008)
              DW_AT_stmt_list   (0x00000000)
              DW_AT_comp_dir    ("/tmp/demo")
              DW_AT_low_pc      (0x0000000000000000)
              DW_AT_high_pc     (0x0000000000000014)
              DW_AT_addr_base   (0x00000008)

0x00000025:   DW_TAG_subprogram
                DW_AT_low_pc    (0x0000000000000000)
                DW_AT_high_pc   (0x0000000000000014)
                DW_AT_APPLE_omit_frame_ptr      (true)
                DW_AT_frame_base        (DW_OP_reg31 WSP)
                DW_AT_name      ("main")
                DW_AT_decl_file ("/tmp/demo/main.c")
                DW_AT_decl_line (1)
                DW_AT_type      (0x00000034 "int")
                DW_AT_external  (true)

0x00000034:   DW_TAG_base_type
                DW_AT_name      ("int")
                DW_AT_encoding  (DW_ATE_signed)
                DW_AT_byte_size (0x04)

0x00000038:   NULL
```

We can also see the object file contains specific `__debug*` sections
when debug info is present that are absent in our main binary:

```bash
$ size -m main  # use llvm-size if not on macOS
Segment __PAGEZERO: 4294967296 (zero fill)
Segment __TEXT: 16384
        Section __text: 20
        Section __unwind_info: 88
        total 108
Segment __LINKEDIT: 16384
total 4295000064

$ size -m main.o
Segment : 628
  Section (__TEXT, __text): 20
  Section (__DWARF, __debug_abbrev): 65
  Section (__DWARF, __debug_info): 57
  Section (__DWARF, __debug_str_offs): 36
  Section (__DWARF, __debug_str): 179
  Section (__DWARF, __debug_addr): 16
  Section (__DWARF, __debug_names): 112
  Section (__LD, __compact_unwind): 32
  Section (__DWARF, __debug_line): 91
  Section (__DWARF, __debug_line_str): 17
  total 625
total 628
```

The same pattern holds when you depend on static libraries:

```
$ ar cr libmain.a main.o
$ ar t libmain.a
__.SYMDEF SORTED
main.o

$ clang -lmain -L. -o main
$ dsymutil -s main | grep N_OSO
[     3] 0000002e 66 (N_OSO        ) 00     0001   0000000068d03443 '/private/tmp/demo/./libmain.a(main.o)'
```

This is almost everything we need to know for where to find debug info,
so now let's try to understand where this can go wrong.

# Common Issues

## 1. Invalid absolute paths

So far we've been looking at an isolated example outside of Bazel. If
you've debugged Bazel issues before you may have rightfully felt some
alarm bells go off when you saw the absolute paths in the debug info. In
Bazel, if we are not being careful, those absolute paths would point to
ephemeral locations that only exist during the Bazel link action, and
not exist during debug time. This can also be the case if you are using
distributed builds with other tools. For example if I break
`apple_support` today, this is what you would see:

```bash
$ bazel build main --compilation_mode=dbg
...

$ dsymutil -s bazel-bin/main | grep N_OSO
[     3] 0000008d 66 (N_OSO        ) 00     0001   0000000000000000 '/private/var/tmp/_bazel_ksmiley/14bc203d9bd4089231ecb78dafab0640/sandbox/darwin-sandbox/4/execroot/_main/bazel-out/darwin_arm64-dbg/bin/_objs/main/main.o'
```

In this case you can see the `.../darwin-sandbox/4` directory is where
the final binary recorded the object file existed during link time.
While this was valid during the link action, these directories are wiped
after the build completes, so if you try to `dwarfdump` this file
afterwards, you will see it doesn't exist.

You could potentially workaround this issue with `--sandbox_debug`,
which will keep those directories around, but instead of doing that we
use the
[`-oso_prefix`](https://keith.github.io/xcode-man-pages/ld.1.html#oso_prefix)
linker argument. This argument tells the linker to strip the given
prefix from the final `N_OSO` entries, and replace it with `.` so that
it is relative to the current directory. With this applied, the `N_OSO`
entries look like this:

```bash
$ dsymutil -s bazel-bin/main | grep N_OSO
[     3] 00000026 66 (N_OSO        ) 00     0001   0000000068d039ba 'bazel-out/darwin_arm64-dbg/bin/_objs/main/main.o'
```

This path now exists relative to the root of the repository, so as long
as you are launching `lldb` from the root of the repository, it will
correctly discover this object file.

Now that these paths are reproducible and valid, let's shift our
attention to the paths in the object file itself (again by breaking
`apple_support`):

```bash
$ dwarfdump bazel-out/darwin_arm64-dbg/bin/_objs/main/main.o | grep '"/'
  DW_AT_LLVM_sysroot        ("/Applications/Xcode.app/Contents/Developer/Platforms/MacOSX.platform/Developer/SDKs/MacOSX26.0.sdk")
  DW_AT_comp_dir    ("/private/var/tmp/_bazel_ksmiley/14bc203d9bd4089231ecb78dafab0640/sandbox/darwin-sandbox/12/execroot/_main")
  DW_AT_decl_file ("/private/var/tmp/_bazel_ksmiley/14bc203d9bd4089231ecb78dafab0640/sandbox/darwin-sandbox/12/execroot/_main/main.c")
```

Here we can see 3 different absolute paths which might affect our
ability to debug, and undoubtedly affects the reproducibility of our
build. In this case if I debug the binary, while it can find the debug
info, it cannot find the source files to display inline when it hits a
breakpoint:

```bash
$ lldb bazel-bin/main
(lldb) target create "bazel-bin/main"
Current executable set to '/tmp/demo/bazel-bin/main' (arm64).
(lldb) b main
Breakpoint 1: 17 locations.
(lldb) b
Current breakpoints:
1: name = 'main', locations = 1
  1.1: where = main`main + 12 at main.c:2:3, address = main[0x0000000100000334], unresolved, hit count = 0
(lldb) r
Process 38440 launched: '/tmp/demo/bazel-bin/main' (arm64)
1 location added to breakpoint 1
Process 38440 stopped
* thread #1, queue = 'com.apple.main-thread', stop reason = breakpoint 1.1
    frame #0: 0x00000001000013ec main`main at main.c:2:3
Target 0: (main) stopped.
```

Notably `lldb` knows that the breakpoint is set at `main.c:2:3` which is
pulled from the debug info, even though the source file cannot be found
to be displayed. If it didn't have the debug info at all, that output
would be subtly different and instead show no specific file location:

```
(lldb) b
Current breakpoints:
1: name = 'main', locations = 1
  1.1: where = main`main, address = 0x0000000100000328, unresolved, hit count = 0
```

To solve this clang has a few different arguments, similar to
`-oso_prefix`, to rewrite the absolute paths in the object files. The
most modern and comprehensive version of this flag is
`-ffile-compilation-dir=.`. This flag remaps all known paths that can be
embedded in the binary (not only debug info, but also coverage info, and
`__FILE__` macros, which otherwise won't be covered in this post) to be
relative to the current directory.

Once we apply this flag, we see the source file paths are fixed:

```bash
$ dwarfdump bazel-out/darwin_arm64-dbg/bin/_objs/main/main.o | grep -e sysroot -e comp_dir -e decl_file
  DW_AT_LLVM_sysroot        ("/Applications/Xcode.app/Contents/Developer/Platforms/MacOSX.platform/Developer/SDKs/MacOSX26.0.sdk")
  DW_AT_comp_dir    (".")
  DW_AT_decl_file ("./main.c")
```

The `DW_AT_LLVM_sysroot` path is still absolute, but this likely doesn't
affect debugging since `lldb` rediscovers the SDK if this path is
invalid. In this case for reproducibility in Bazel we still rewrite this
to:

```
DW_AT_LLVM_sysroot ("/PLACEHOLDER_DEVELOPER_DIR/Platforms/MacOSX.platform/Developer/SDKs/MacOSX26.0.sdk")
```

By passing
`-fdebug-prefix-map=$DEVELOPER_DIR=/PLACEHOLDER_DEVELOPER_DIR`, which
works similar to `-ffile-compilation-dir` but instead affects a single
prefix, not only relative paths.

With these 3 flags applied, our final binary is debuggable, and
reproducible!

## 2. Missing object or source Files

Since we're relying on `lldb` reading the `N_OSO` entries in our final
binary, tracing those back to the object files, and then finally tracing
those back to the source files, all of those files must exist on the
machine running `lldb` at the time you are debugging the binary.

For simple local builds, this should always be the case, but in Bazel
there are a few potential times where you would break this assumption.

### 2.1. Pulling from the Bazel cache

If you are using a remote cache or remote execution in Bazel, along with
`--remote_download_toplevel` (also known as BwtB or Builds Without The
Bytes which is enabled by default in modern Bazel versions), then Bazel
will avoid downloading as much as possible to speed up build time.

In this case if you didn't compile something locally, the intermediate
files may never be downloaded to your local machine, and therefore might
be missing when you go to debug. This can be pretty subtle since if you
do make changes that result in a local recompile (specifically if you
are only using the remote cache, or are using dynamic mode with
remote execution), the intermediate object files will be present and
your ability to debug will appear to be flaky.

To fix this you can instruct Bazel to always download the intermediate
files with something like this in your `.bazelrc`:

```
build --enable_platform_specific_config
# Specify the relevant extensions, likely only needed on macOS
build:macos --remote_download_regex='.*\.(a|lo|o)$'
```

### 2.2. Bazel `external` symlink

Another subtle case in Bazel is that while all first party code is
valid with the flags above, third party code is compiled from a separate
directory (since it isn't in your source tree), and therefore requires
more paths to be available at debug time.

For example building a binary that depends on `boringssl` has valid
`N_OSO` paths:

```bash
$ dsymutil -s bazel-bin/third_party_dep | grep N_OSO | tail -1
[ 49167] 00062e25 66 (N_OSO        ) 00     0001   0000000000000000 'bazel-out/darwin_arm64-dbg/bin/external/boringssl+/libcrypto_cxx.a(mlkem.o)'
```

But if you inspect that archive's debug info, you see the source file
paths are nested under a directory called `external`:

```bash
$ dwarfdump bazel-out/darwin_arm64-dbg/bin/external/boringssl+/libcrypto_cxx.a | grep decl_file | head -1
  DW_AT_decl_file ("./external/boringssl+/crypto/mlkem/mlkem.cc")
```

Unfortunately this path doesn't exist in the root of your repository
like `bazel-out` does. The common workaround to solve this is to create
a symlink in the root of your repository manually with:

```bash
$ ln -s bazel-out/../../../external .
```

Then you can validate that this path exists so that `lldb` can find it:

```bash
$ head -5 external/boringssl+/crypto/mlkem/mlkem.cc
/* Copyright (c) 2024, Google Inc.
 *
 * Permission to use, copy, modify, and/or distribute this software for any
 * purpose with or without fee is hereby granted, provided that the above
 * copyright notice and this permission notice appear in all copies.
```

If you don't often debug third party code in your project you can choose
to skip this, but it is also required for producing valid
`compile_commands.json` files for IDEs, so you might want it for that
too. You should add this symlink to your `gitignore` after creating it.

## 3. Using `rules_cc` or `toolchains_llvm` over `apple_support`

Currently only `apple_support` handles all the flags above for Apple
platforms. That isn't an inherent limitation of `rules_cc` or
`toolchains_llvm` (which uses the config from `rules_cc`), but would
require some work to implement. Because of this you have to make sure
that you are getting the correct CC toolchain when building for
everything to work correctly.

If you think Bazel isn't choosing the correct toolchain you can pass
`--toolchain_resolution_debug=".*"` while building and you should see a
line like this:

```
INFO: ToolchainResolution: Target platform @@platforms//host:host: Selected execution platform @@platforms//host:host, type @@bazel_tools//tools/cpp:toolchain_type -> toolchain @@apple_support++apple_cc_configure_extension+local_config_apple_cc//:cc-compiler-darwin_arm64
```

Where the important part is that the toolchain on the right hand side is
from `@apple_support`, if it instead looks like this:

```
INFO: ToolchainResolution: Target platform @@platforms//host:host: Selected execution platform @@platforms//host:host, type @@bazel_tools//tools/cpp:toolchain_type -> toolchain @@rules_cc++cc_configure_extension+local_config_cc//:cc-compiler-darwin_arm64
```

You are getting the toolchain from `@rules_cc`.

When using `bzlmod` you must be sure to have `apple_support` _above_
`rules_cc` in your `MODULE.bazel` file to ensure this happens (this
won't affect non-Apple platforms):

```bzl
# Has to be above rules_cc
bazel_dep(name = "apple_support", version = "1.23.1")
bazel_dep(name = "rules_cc", version = "0.2.8")
```

## 4. Bazel producing no debug info

By default only the `dbg` compilation mode produces debug info.
Therefore you must make sure to pass `--compilation_mode=dbg` in order
to get debug info. Otherwise the final binary will have no `N_OSO`
entries at all, which you can verify with `dsymutil -s <binary>`.
Alternatively you could manually pass `--copt=-g` in your build.

## 5. Bazel stripping produced debug info

If you pass `--strip=always` or `--strip=sometimes` (the default) to
Bazel, it will strip the `N_OSO` references from the produced binary.
Therefore you must make sure you don't do this in the cases where you
want debug info. Bazel also attempts to warn you in this case:

```bash
$ bazel build main -c fastbuild --copt=-g
WARNING: Stripping enabled, but '--copt=-g' (or --per_file_copt=...@-g) specified. Debug information will be generated and then stripped away. This is probably not what you want! Use '-c dbg' for debug mode, or use '--strip=never' to disable stripping
...
```

## 6. Debugging Bazel exec tools

By default Bazel doesn't produce debug info for tools built in the exec
configuration (because the default exec compilation mode is `opt`).
Instead of debugging a tool built for the exec configuration, you should
likely rebuild it directly (for the target configuration) and debug that
instead. This issue most commonly happens if you are debugging a bazel
rule and copy a command from Bazel's `--subcommands` output. You could
also pass `--host_copt=-g` if building the target directly doesn't work
for you.

## 7. Temporary files

If you use a single `clang` command to both compile and link a binary,
the intermediate object files referenced by the `N_OSO` entries are
temporary and deleted after the build:

```bash
$ clang main.c -o main -g
$ dsymutil -s main | grep N_OSO
[     3] 0000002e 66 (N_OSO        ) 00     0001   0000000068d059de '/var/folders/68/rn88yggx76bdgkj66fnxc1hc0000gn/T/main-637516.o'
```

In this case you should likely split these commands apart to ensure the
object files are kept around. Alternatively as a quick workaround you
can pass `-save-temps` to `clang` to keep the intermediate object file
around.

# Using `dSYM`s

An entirely separate option for how to produce debug info for Apple
platforms is to use `dSYM` bundles. A `dSYM` is created from a linked
binary and accumulates the debug info for all transitive dependencies,
so you don't have to keep the other intermediate files around.

All of the same concerns stated above around absolute paths still apply,
but this can potentially simplify downloading intermediates or
redistributing debug info alongside a binary.

You can produce a `dSYM` from a binary with:

```bash
$ dsymutil -o main.dSYM main
```

If you are missing intermediates when creating a `dSYM`, you will see
relevant warnings (I would love a `dsymutil` flag to be able to make
this an error):

```
$ dsymutil -o main.dSYM main
warning: (arm64) /private/tmp/demo/main.o unable to open object file: No such file or directory
warning: no debug symbols in executable (-arch arm64)
```

After you have the `dSYM` you can delete the intermediate files and
still debug as expected.

Bazel can automatically produce `dSYM`s for you if you pass
`--apple_generate_dsym --output_groups=+dsyms` when building (with any
`--compilation_mode`, but the `--strip` concerns above still apply).
Previously this wasn't supported for `cc_binary` targets but that has
recently been added in Bazel.

In Bazel, after producing the `dSYM`, the `N_OSO` entries in the binary
are stripped, and all debug info can be inspected in the `dSYM`:

```bash
$ bazel build main --apple_generate_dsym --output_groups=+dsyms
...
  bazel-bin/main
  bazel-bin/main.dSYM

$ dsymutil -s bazel-bin/main | grep N_OSO  # No output because they were stripped
$ dwarfdump bazel-bin/main.dSYM
bazel-bin/main.dSYM/Contents/Resources/DWARF/main:      file format Mach-O arm64

.debug_info contents:
0x00000000: Compile Unit: length = 0x00000035, format = DWARF32, version = 0x0005, unit_type = DW_UT_compile, abbr_offset = 0x0000, addr_size = 0x08 (next unit at 0x00000039)
...
```

Since there are no `N_OSO` entries in the binary, `lldb` uses a
different mechanism to discover the `dSYM`. This is done by looking up
the UUID of the binary, and then looking for a matching `dSYM`. You can
inspect the UUIDs to make sure you have the appropriate `dSYM` locally:

```bash
$ dwarfdump -u bazel-bin/main bazel-bin/main.dSYM
UUID: 152D8F32-5A7E-31DF-9BF2-2F48E32450AE (arm64) bazel-bin/main
UUID: 152D8F32-5A7E-31DF-9BF2-2F48E32450AE (arm64) bazel-bin/main.dSYM/Contents/Resources/DWARF/main
```

If `lldb` isn't correctly discovering the `dSYM`, you can manually add
it with:

```bash
(lldb) target symbols add bazel-bin/main.dSYM
```

You can also verify that `lldb` is correctly discovering the `dSYM` by
enabling the host logging by adding this to your `~/.lldbinit` file:

```
log enable -f /tmp/host.log lldb host
```

After running `lldb` you will see that log should be populated with a
line like:

```
$ head -1 /tmp/host.log
dSYM with matching UUID & arch found at /tmp/demo/bazel-bin/main.dSYM/Contents/Resources/DWARF/main
```

If the `dSYM` isn't found, there will be no related log entry. If you are
using other macOS tools like `Instruments.app` and it cannot find the
`dSYM`, you should try using the `symbolscache` CLI to manually add it.
See `symbolscache --help` for usage.

Generally the downside of using `dSYM`s is the (potentially small)
amount of time it takes to produce them, especially if you don't end up
debugging the binary. On the other hand if you use a crash reporting
service, you likely need to produce them anyway to symbolicate crash
reports, so it might be worth unifying the debug workflows.

Another benefit of using `dSYMs` is that you can fully `strip` the final
binary and still debug it. This is useful for making sure to produce the
smallest possible binary for release and test the same artifacts so you
know that the stripped binary works correctly (primarily risky if you are
using aggressive `strip` flags to heavily optimize binary size).

In Bazel, because producing the `dSYM` requires all the intermediate
files from the entire transitive dependency tree of the binary, it must
be done at the same time as the linking of the binary. This is done with
custom logic in `apple_support`'s CC toolchain, which doesn't exist in
`rules_cc`. You cannot run `dsymutil` manually on a Bazel binary unless
you have also downloaded all the intermediate files.

# Other considerations

## Launching `lldb` from other directories

Many of the recommendations above are about using relative paths for the
files that `lldb` is attempting to load. This works great as long as you
always launch `lldb` from the same directory (usually the root of your
repository). In some cases you might want to launch `lldb` from another
directory (especially in Bazel where runfiles discovery might require a
different PWD). In this case you can set the processes' working
directory separately from `lldb`'s working directory by still launching
`lldb` from the root of the repository (so that the relative debug info
paths are still valid), but then passing the other directory as a
setting:

```bash
$ lldb --one-line-before-file 'settings set target.launch-working-dir some/other/directory' -- main
```

Or once you've launched `lldb` itself:

```
(lldb) platform settings -w some/other/directory
```

## Partially missing debug info

If you are linking pre-built artifacts, such as 3rd party static
libraries, it's possible they are built without debug info. In this case
if you are debugging and stop in their code, you might see no useful
information. You can use the commands outlined above to try and
understand if they have any information at all, but it is common
that closed source libraries ship stripped of debug info. If their
code is open source it's possible that you could pull it locally in
order to debug it, even while using the prebuilt artifact (if you
attempt this make sure to use the same sha the prebuilt artifact is
built from).

## `lldb` source maps

If you have prebuilt artifacts as outlined above which have absolute
paths in their debug info that you cannot change, you can attempt to use
`lldb`'s source mapping feature to rewrite those paths at debug time to
something that exists locally. In that case once you've identified the
path you need to rewrite by inspecting the binary with `dwarfdump`, you
can add a mapping in `lldb` like this:

```
(lldb) settings set target.source-map /absolute/path/in/binary /local/path/on/machine
```

You can have multiple of these paths which can be useful if you have
multiple prebuilt artifacts with different debug locations:

```
(lldb) settings set target.source-map /absolute/path/in/binary1 /local/path/on/machine1
(lldb) settings append target.source-map /absolute/path/in/binary2 /local/path/on/machine2
```

You could also use this instead of the `clang` flags, or the `external`
symlink mentioned above, but often this is harder to manage since the
paths could differ between different developer's machines and requires
injecting `lldb` settings.

Note that `-oso_prefix` is not affected by these mappings, and there can
only be 1 of them. If this is an issue for you, you could potentially
create your own symlink tree to solve this. I imagine it would also be
possible to rewrite the `N_OSO` entries in the binary but I don't think
any of the related tools do this today.

## Shared libraries

If you are debugging a binary that depends on shared libraries
(`dylib`s), the same principles that apply to the main binary apply to
every individual shared library. The shared libraries will have their
own `N_OSO` entries that must be valid, and their own `dSYMs` (if you go
that route). In this case the main binary won't have `N_OSO` entries for
the shared libraries (or their transitive dependencies), but instead
`lldb` will discover them as they are loaded by `dyld`.

In `lldb` you can see all of the loaded shared libraries with `image
list` (the first field is the same UUID discussed above):

```
(lldb) image list
[  0] 503338F7-DF39-3284-9927-7BF3F9E07F94 0x0000000100000000 /tmp/demo/main
[  1] 072C7C60-2B6C-3E07-AA56-FD1750EADC2F 0x000000018e6cf000 /usr/lib/libSystem.B.dylib
[  2] 25DE2C92-147C-3AC7-91BA-51B8F7EDC72B 0x0000000000000000 libfoo.dylib
[  3] 3247E185-CED2-36FF-9E29-47A77C23E004 0x00000001800cc000 /usr/lib/dyld
```

## Symlinks versus actual paths

In the past there have been multiple bugs around how `-oso_prefix` and
`-ffile-compilation-dir` handle symlinks in paths. If your build heavily
uses symlinks, as Bazel does, and you're getting unexpected absolute
path behavior, this is something to consider. The typical bugs arise
from whether the path is remapped before or after the symlinks are
resolved.

# Thanks for reading!

Hopefully all this information helps you the next time you need to debug
something related to debug info!

If you have any questions or feedback please reach out to me on the
Bazel slack or Mastodon. Feel free to cc me on any relevant Bazel
issues.
