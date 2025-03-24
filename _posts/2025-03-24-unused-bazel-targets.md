---
layout: post
title: "Finding unused targets with bazel"
date: 2025-03-24 11:00
---

Once you've fully migrated a codebase to bazel, one of the many
advantages is that you can easily inspect your build graph using `bazel
query`.

One of the many things you can do with queries is write scripts to
enforce coding standards, or in today's example, find unused targets
that can lead to discovering unused code.

The simplest version of this query starts like this:

```
let all_targets = //... in
let top_level_targets = tests($all_targets) union kind("(.*_binary) rule", $all_targets)
$all_targest - deps($top_level_targets)
```

This initial version discovers all your first party targets, and then
subtracts the dependencies of all "top level" targets, so that any
remaining targets are considered unused.

The idea of "top level" targets is better defined as: anything that you
consider to be important enough that its dependencies are used.
Depending on your codebase you might want to exclude test targets from
this so that targets only in the dependencies of test targets are
diagnosed as unused (this won't work if you have intentional `testonly`
dependencies, although you could special case those as shown below).

Once you have this initial query, you can start iterating in order to
handle in edge cases. For example it's likely that you have some targets
that aren't binaries or tests, but are considered used. There are 2
approaches I would recommend to handle this. First you can continue to
build out the `kind` filter:

```
kind("(.*_binary|platform|test_suite) rule", $all_targets)
```

The downside with this approach is it can get unwieldy quickly. I like
adding rules here that have many uses, but for other one off cases
another approach you can use is to expand the query to look for special
tags:

```
let all_targets = //... in
let top_level_targets = tests($all_targets) union kind("(.*_binary|platform|test_suite) rule", $all_targets)
let allowed_unused = attr(tags, allow-unused, $all_targets) in
$all_targest - deps($top_level_targets) - $allowed_unused
```

Then you can add `tags = ["allow-unused"]` to whatever targets that you need.

Similarly if you want to special case targets that can be considered
"top level" you can use a tag for that case as well:

```
let all_targets = //... in
let top_level_targets = tests($all_targets) union kind("(.*_binary|platform|test_suite) rule", $all_targets) union attr(tags, top-level, $all_targets) in
let allowed_unused = attr(tags, allow-unused, $all_targets) in
$all_targest - deps($top_level_targets) - $allowed_unused
```

Now adding `tags = ["top-level"]` to various targets will ensure their
entire dependency tree is also considered used. This case is especially
useful for targets like CC toolchains which are used in your
`MODULE.bazel` but potentially don't appear as used by bazel query.

Hopefully this post was instructive and gives you some ideas for how you
can write more advanced queries for your use cases.
