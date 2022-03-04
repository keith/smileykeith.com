---
layout: post
title: "Supporting relative paths: XCTest failures in Xcode"
date: 2021-03-04 20:48
---

If you build your iOS app with an alternate build system such as
[bazel](https://www.bazel.build), it's likely that you use relative
paths, instead of absolute paths, for compilation.

Specifically, when building swift code, Xcode calls the compiler with
something like:

```
swiftc [ARGS] /path/to/srcroot/path/to/file1.swift /path/to/srcroot/path/to/file2.swift
```

Where bazel will call the compiler with something like:

```
swiftc [ARGS] path/to/file1.swift path/to/file2.swift
```

Normally, this difference is inconsequential, both compilations will
result in a similar enough output. So, the question is: Why would you
pick one over the other? For bazel, the answer lies in its core feature
of "hermeticity". In bazel's case, being hermetic means that given the
same inputs you always produce the same outputs. This means that
regardless of what machine you're building on, or what directory your
source is cloned in, the results should be the same. Because, those
details aren't considered important inputs in the build.

Unfortunately, in a few places, Xcode relies on paths being absolute.
Today, we'll look at how Xcode reports test failures in the UI.
Specifically the underlying
[`XCTIssue`](https://developer.apple.com/documentation/xctest/xctissue)
that `XCTest` creates is expected to be instantiated with an absolute
path. This absolute path is populated from the `#filePath` (previously
`#file`) keyword which is _supposed_ to reference the absolute path of
the current source file.

The first question is: How does the Swift compiler know what the
absolute path of the current file is? It's easy when Xcode passes an
absolute path to the compiler. But, what if you pass a relative path? In
this case, the Swift compiler uses the directory passed with the
`-working-directory` argument to make the path absolute. It turns out if
you don't pass this argument, the compiler has no choice but to use the
relative path. This means the `#filePath` keyword ends up translating to
a relative path, which means the `XCTIssue` is created with a relative
path.

With relative paths when you run your tests in Xcode and they
fail, clicking the failure in the issue navigator doesn't do anything.
But, it's supposed to jump you to the test case that failed (FB8451256,
FB8454623).

So, how do we fix this? Luckily, we know the core issue is `XCTIssue` is
created with a relative path. Since `XCTIssue` instances are created as
part of our process, we can
[swizzle](https://nshipster.com/method-swizzling) it to fix this.

Looking at the underlying [`XCTSourceCodeLocation`
docs](https://developer.apple.com/documentation/xctest/xctsourcecodelocation),
we can see there are 2 initializers we're potentially interested in.
Setting some quick breakpoints we can see that `XCTIssue` goes through
the `init(fileURL:lineNumber:)` initializer. When we inspect the
argument it receives in the debugger, we can see it's the relative path
we passed to the compiler. Knowing this, we can surmise that by
swizzling the initializer, and make the argument an absolute path, we
can satisfy Xcode's requirement. So, what path do we use? Using Xcode's
scheme environment variables, we can pass Xcode's `SRCROOT` through an
environment variable named the same thing:

![](/images/srcroot.png)

Make sure to have the "Expand Variables Based On" dropdown set to some
target (FB8454879) or the `$(SRCROOT)` string will be passed through
literally.

Now, for the swizzling:


```swift
import Foundation
import XCTest

// NOTE: This path has to start with a / for fileURLWithPath to resolve it correctly as an absolute path
public let kSourceRoot = ProcessInfo.processInfo.environment["SRCROOT"]!

private func remapFileURL(_ fileURL: URL) -> URL {
    if fileURL.path.hasPrefix(kSourceRoot) {
        return fileURL
    }

    return URL(fileURLWithPath: "\(kSourceRoot)/\(fileURL.relativePath)")
}

private extension XCTSourceCodeLocation {
    @objc
    convenience init(initWithRelativeFileURL relativeURL: URL, lineNumber: Int) {
        // NOTE: This call is not recursive because of swizzling
        self.init(initWithRelativeFileURL: remapFileURL(relativeURL), lineNumber: lineNumber)
    }
}

func swizzleXCTSourceCodeLocationIfNeeded() {
    // NOTE: Make sure our "Expand Variables Based On" is set correctly
    if kSourceRoot == "$(SRCROOT)" {
        fatalError("Got unsubstituted SRCROOT")
    }

    let originalSelector = #selector(XCTSourceCodeLocation.init(fileURL:lineNumber:))
    let swizzledSelector = #selector(XCTSourceCodeLocation.init(initWithRelativeFileURL:lineNumber:))

    guard let originalMethod = class_getInstanceMethod(XCTSourceCodeLocation.self, originalSelector),
        let swizzledMethod = class_getInstanceMethod(XCTSourceCodeLocation.self, swizzledSelector) else
    {
        fatalError("Failed to swizzle XCTSourceCodeLocation")
    }

    method_exchangeImplementations(originalMethod, swizzledMethod)
}
```

With this implementation, you need to call
`swizzleXCTSourceCodeLocationIfNeeded()` somewhere. Using the
[`NSPrincipalClass` plist
key](https://developer.apple.com/documentation/bundleresources/information_property_list/nsprincipalclass),
we can define a class that is initialized as soon as your test bundle
starts to run. This key must be set in your test bundle's plist, not any
host apps you are using for the test bundle. For bazel this means on the
`infoplists` key of your `ios_unit_test` rule. We can define a small
class to call our swizzling code:

```swift
import ObjectiveC

final class UnitTestMain: NSObject {
    override init() {
        super.init()

        swizzleXCTSourceCodeLocationIfNeeded()
    }
}
```

Disclaimer: this relies on a lot of implementation details in Xcode
which might break in the future. You should avoid this if possible.
