---
layout: post
title: "Vim TagBar with Objective-C"
date: 2014-02-14 13:53
---

When working with large files in Vim,
[Tagbar](http://majutsushi.github.io/tagbar/) has become an invaluable
part of my workflow. It provides a succinct list of methods, modules,
variables and other language specific constructs. When I started trying
to spend more time in Vim writing Objective-C I was disappointed to see
that, out of the box, it was not supported.

Hopefully in the future it won't be difficult to set this up in Vim.
Currently ctags [already
has](https://svn.code.sf.net/p/ctags/code/trunk/objc.c) built in support
for Objective-C. Unfortunately there hasn't been a release of ctags
since 2009. As recommended in the [canonical how to
article](http://bastibe.de/2011-12-04-how-to-make-tagbar-work-with-objective-c.html)
you can attempt to use the trunk version of ctags and just define the
Tagbar settings. For me, this ended up producing a ton of
mis-categorized duplicates. I also opened and closed [an
issue](https://github.com/majutsushi/tagbar/issues/193) on the Tagbar
Github repo hoping that Objective-C support will be added by default in
the future.

The only other resource I could find about this issue was [this
gist](https://gist.github.com/yamaya/5598909). It uses regex to define
Objective-C to ctags and then match it with Tagbar. I improved it a
little bit and came up with this. Put this file anywhere you want, you
will define its path in your vimrc.

```
--langdef=objc
--langmap=objc:.m..mm
--regex-objc=/\@interface[[:space:]]+([[:alnum:]_]+)/\1/i,interface/
--regex-objc=/\@implementation[[:space:]]+([[:alnum:]_]+)/\1/I,implementation/
--regex-objc=/\@protocol[[:space:]]+([[:alnum:]_]+)/\1/P,protocol/
--regex-objc=/\@property[[:space:]]+\([[:alnum:],[:space:]]+\)[[:space:]]+[[:alnum:]_]+[[:space:]]+\*?([[:alnum:]_]+)/\1/p,property/
--regex-objc=/([-+])[[:space:]]*\([[:alpha:]_][^)]*\)[[:space:]]*([[:alpha:]_][^:]+)[^;]*[[:space:]]*;[[:space:]]*$/\1\2/N,method declaration/
--regex-objc=/([-+])[[:space:]]*\([[:alpha:]_][^)]*\)[[:space:]]*([[:alpha:]_][^:]+)[^;]*[[:space:]]*$/\1\2/M,method definition/
--regex-objc=/^[^#@[:space:]][^=]*[[:space:]]([[:alpha:]_][[:alnum:]_]*)[[:space:]]*=/\1/c,constant/
--regex-objc=/^[[:space:]]*typedef[[:space:]][^;]+[[:space:]]([[:alpha:]_][[:alnum:]]*)[[:space:]]*;/\1/t,typedef/
```

Then in your vimrc:

{% highlight vim %}
let g:tagbar_type_objc = {
  \ 'ctagstype': 'objc',
  \ 'ctagsargs': [
    \ '-f',
    \ '-',
    \ '--excmd=pattern',
    \ '--extra=',
    \ '--format=2',
    \ '--fields=nksaSmt',
    \ '--options=' . expand('~/.vim/objctags'),
    \ '--objc-kinds=-N',
  \ ],
  \ 'sro': ' ',
  \ 'kinds': [
    \	'i:interface',
    \	'I:implementation',
    \	'P:protocol',
    \	'p:property',
    \	'M:method',
    \	't:typedef',
    \	'c:constant',
  \ ],
\ }
{% endhighlight %}

Replace the `~/.vim/objctags` with the path where you chose to put the
first file. Please let me know if you see any way that this could be
improved.
