---
layout: post
title: "Bazel rule extensions"
date: 2025-10-31 10:00
---

One of Bazel's best features is being able to easily write custom rules
specific to your project. This is great for many use cases, but when
what you really want is to enhance the behavior of existing rules,
historically your options have been limited. What you would often do is
wrap the existing rule in a macro, and add some number of custom rules
to try and achieve the desired effect. When really what you want is to
edit the existing rule, without having to re-implement all of its
functionality (or maintain a fork).

With Bazel 8.0, Googlers added a few new ways to extend existing rules
that can help with this use case. In this post we will look at the aptly
named [rule extensions][] feature and some practical use cases I have
found for it.

[rule extensions]: https://docs.google.com/document/d/1p6z-shWf9sdqo_ep7dcjZCGvqN5r2jsPkJCqHHgfRp4/edit?tab=t.0#heading=h.5mcn15i0e1ch

# Basic rule extensions

Rule extensions allow you to inherit the behavior of an existing rule,
similar to class inheritance in object-oriented programming. Importantly
you can make a few modifications to augment the behavior of the rule to
your liking.

Let's say you have a rule that concatenates the given `srcs`:

```python
def _foo_impl(ctx):
    output = ctx.actions.declare_file("output.txt")
    ctx.actions.run_shell(
        inputs = ctx.files.srcs,
        outputs = [output],
        command = "cat {} > {}".format(" ".join([src.path for src in ctx.files.srcs]), output.path),
    )
    return [DefaultInfo(files = depset([output]))]

foo = rule(
    implementation = _foo_impl,
    attrs = {
        "srcs": attr.label_list(allow_files = True),
    },
)
```

Now let's assume in your project, you want the output file to be sorted.
If you own the original rule you could of course change `_foo_impl` to
handle that for you, but if you are relying on a more complex upstream
rule, you may not have that luxury. Here's how we can extend this to
post-process the file it produces:

```python
def _bar_impl(ctx):
    providers = ctx.super() # Invoke 'foo' and get the providers
    # NOTE: This assumes there's always only the provider we want.
    original_output = providers[0].files.to_list()[0]
    new_output = ctx.actions.declare_file("new_output.txt")
    ctx.actions.run_shell(
        inputs = [original_output],
        outputs = [new_output],
        command = "sort {} > {}".format(original_output.path, new_output.path),
    )

    return [DefaultInfo(files = depset([new_output]))]

bar = rule(
    implementation = _bar_impl,
    parent = foo,  # Inherit everything from 'foo'
)
```

This example illustrates the core new features of rule extensions. First
we inherit everything from `foo` with:

```python
    parent = foo,
```

Then we invoke the original implementation with:

```python
    providers = ctx.super()
```

At this point we have all of the original providers, and we can
post-process them however we want. In this example we choose to extract
what we need from them and return entirely different providers based on
our new action.

# Manipulating providers

As well as creating new providers, you can also manipulate the returned
providers for your use case. Recently I wanted to unify how debug info
was returned for `cc_binary` targets across macOS and Linux.
Specifically I wanted to be able to create a `filegroup` target pointing
to a specific `output_group` that would work on both platforms, where by
default you would have to fetch these from different output locations on
different platforms.

I was able to achieve this with a rule extension of `cc_binary`:

```python
load("@cc_compatibility_proxy//:proxy.bzl", _upstream_cc_binary = "cc_binary")

def _cc_binary_impl(ctx):
    providers = ctx.super()

    output_group_info = None
    debug_package_info = None
    passthrough_providers = []
    for provider in providers:
        if type(provider) == "OutputGroupInfo":
            output_group_info = provider
        elif type(provider) == "struct" and hasattr(provider, "unstripped_file"):  # NOTE: Will require an update when this provider moves to starlark
            debug_package_info = provider
            passthrough_providers.append(provider)
        else:
            passthrough_providers.append(provider)

    if not output_group_info:
        fail("No OutputGroupInfo provider found")
    if not debug_package_info:
        fail("No DebugPackageInfo provider found")

    dsyms = getattr(output_group_info, "dsyms", depset())
    new_output_group_info = {}
    if dsyms:
        new_output_group_info["debug_info"] = dsyms
    else:
        new_output_group_info["debug_info"] = depset([debug_package_info.unstripped_file])

    for group in dir(output_group_info):
        new_output_group_info[group] = getattr(output_group_info, group)

    return passthrough_providers + [
        OutputGroupInfo(**new_output_group_info),
    ]

cc_binary = rule(
    implementation = _cc_binary_impl,
    parent = _upstream_cc_binary,
)
```

Most of this implementation is about collecting and re-propagating the
providers that I don't care about. The methods for doing this today are
pretty tedious but hopefully that will [improve in the
future](https://github.com/bazelbuild/bazel/issues/26960).

The core logic once I collect the original providers is this:

```python
    dsyms = getattr(output_group_info, "dsyms", depset())
    if dsyms:
        new_output_group_info["debug_info"] = dsyms
    else:
        new_output_group_info["debug_info"] = depset([debug_package_info.unstripped_file])
```

Here I decide that if the `OutputGroupInfo` provider from the upstream
`cc_binary` implementation includes `dsyms`, we propagate that,
otherwise we propagate the unstripped binary which contains all the
debug info for Linux. I am then able to create a single `filegroup` to
fetch whichever one is found:

```python
filegroup(
    name = "some_binary.debug_info",
    srcs = [":some_binary"],
    output_group = "debug_info",
)
```

# Extending rules with transitions

Let's look at another use case for extending rules. This time I want to
add a custom transition to an upstream rule. In our project we produce
python wheels that include native extensions. In order to distribute
these wheels we have to build them for each version of python we
support. `rules_python` has a `py_wheel` rule that creates the wheel for
us, but it does that targeting the "current python version" (this could
potentially be improved upstream). The current version depends on how
you setup python in your `MODULE.bazel` file, but we want to change it
when we build different targets so we can target multiple python
versions in a single build. Thankfully the way `rules_python` has
implemented version selection is with a flag that we can write a
transition for. To add a transition to an upstream rule, while otherwise
maintaining the original functionality, we can do this:

```python
py_wheel = rule(
    implementation = lambda ctx: ctx.super(),
    parent = py_wheel_rule,
    attrs = {
        "python_version": attr.string(),
    },
    cfg = python_version_transition,
)
```

This use case has a few interesting things to note. Since we don't want
to change the functionality or providers returned by this rule, we don't
even create an implementation function, instead opting to call super
directly in a lambda:

```python
    implementation = lambda ctx: ctx.super(),
```

Then we add an attribute the rule didn't have before. This is then read
by our transition to decide which python version to use:

```python
    attrs = {
        "python_version": attr.string(),
    },
```

If the original rule had an appropriate attribute we could use that
instead, but in this case we need to provide our own. Finally we add the
transition (the contents of which aren't necessary to understand for
this example, but can be found
[here](https://github.com/modular/rules_mojo/blob/87f860f96f73ce624d51fe8e836978888e14344c/mojo/private/transitions.bzl)):

```python
    cfg = python_version_transition,
```

Now with our new `py_wheel` rule we can set:

```python
    python_version = "3.13",
```

And all transitive dependencies will be built targeting the passed
version instead of the default version.

Previously to solve this same use case you potentially could have
created a custom rule that applied this transition, and made the
original `py_wheel` target depend on your custom rule's output, but that
is definitely more overhead to understand and maintain for the use cases
I commonly hit.

# Applying platform specific transitions

Another use case for adding a transition to an existing rule is for
platform specific builds. A longstanding frustration in the iOS
community is bare targets like `cc_library` or `swift_library`, don't
have any knowledge of the platform they are being built for, even if you
have written them in a way that only supports a single platform. This
means that if you tried to directly build a `swift_library` whose code
only supports iOS, you'll be greeted with a compiler error as Bazel
attempts to build it for macOS.

Developers have often worked around this by wrapping their libraries in
a macro that adds an underlying platform specific target, such as an
`ios_build_test`, that has the necessary platform transition. This adds
complexity and causes confusion for non-Bazel developers. It also adds
general overhead in your build when you're querying things or otherwise
inspecting what targets exist, as every library now has additional
underlying targets.

With rule extensions you can eliminate this overhead by applying the
Apple platform transition directly to `swift_library`:

```python
load("@rules_apple//apple/internal:transition_support.bzl", "transition_support")
load("@rules_swift//swift:swift.bzl", _upstream_swift_library = "swift_library")

swift_library = rule(
    implementation = lambda ctx: ctx.super(),
    parent = _upstream_swift_library,
    cfg = transition_support.apple_rule_transition,
    attrs = {
        "platform_type": attr.string(default = "ios"),
        # TODO: Extract to a constant that matches your ios_application targets
        "minimum_os_version": attr.string(default = "16.0"),
    },
)
```

This requires a bit of knowledge about how the transition works,
specifically we have to add 2 attributes the transition relies on, but
that's something that could potentially be improved.

Once you have this extended rule, building your `swift_library` targets
correctly builds for iOS, and they are not rebuilt when building them
from a platform specific target's dependency tree.

If your `swift_library` target supports multiple platforms, you can
still use something like this while respecting inherited platform from
your top level targets. The easiest way I found to do this would be to
`select()` on the current platform in a macro, and provide the correct
values given that target platform:

```python
load("@rules_apple//apple/internal:transition_support.bzl", "transition_support")
load("@rules_swift//swift:swift.bzl", _upstream_swift_library = "swift_library")

swift_library = rule(
    implementation = lambda ctx: ctx.super(),
    parent = _upstream_swift_library,
    cfg = transition_support.apple_rule_transition,
    attrs = {
        "platform_type": attr.string(mandatory = True),
        "minimum_os_version": attr.string(mandatory = True),
    },
)

def my_swift_library(**kwargs):
    swift_library(
        platform_type = select({
            "@platforms//os:tvos": "tvos",
            "//conditions:default": "ios",
        }),
        minimum_os_version = "16.0", # NOTE: Could select() here too if necessary
        **kwargs
    )
```

With this example building the library directly will default to iOS, but
if you have a top level tvOS target that depends on it, it will still
correctly compile for tvOS.

# Adding an attribute with aspects

Another powerful use case for this feature is to add aspects to
attributes on the rule. For example if you want a rule to collect custom
files from all of its dependencies and propagate those in its own
runfiles, you can override an attribute from the parent, adding your
custom aspect:

```python
bar = rule(
    implementation = _bar_impl,
    parent = foo,
    attrs = {
        "deps": attr.label_list(aspects = [custom_aspect]),
    },
)
```

Then in `_bar_impl` you can do whatever processing you need to collect
the outputs of the aspect.

# Other notes

- There are currently some limitations on what types of attributes can
  be overridden, for example you cannot override a
  `attr.label_keyed_string_dict` to add aspects. In some cases a quick
  workaround is to add a new attribute instead, and wrap your usage in a
  macro that populates the new attribute with the same value as the
  original attribute.
- While it may look confusing at first, I think there's some value in
  re-using the same rule name with your extended rules so `bazel query
  kind(cc_binary, ...)` continues to work as before. This way developers
  who are using queries like this don't have to know about this
  extension.
- You have to set `parent` to another Bazel rule, not a macro. This is
  sometimes difficult as many popular rulesets expose macros for their
  rules to perform pre-processing on the passed attributes. I hope as
  this feature becomes more widely used that pattern is reduced. In the
  cases where I am using this today I found I could skip the custom
  macro logic as long as I was careful about what it was trying to
  accomplish.
- I would like to see how an approach like this could augment existing
  rules to add outputs for actions that already exist. For example when
  passing `-ftime-trace` to clang ideally we could create that output in
  our rule implementation but use the existing action to create it, I
  couldn't find a way to modify the `copts` to do that today. It might
  be possible with a combination of this approach and a macro.
