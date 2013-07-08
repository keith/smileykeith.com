---
layout: post
title: "NSTableView vim keys"
date: 2013-01-08 16:19
---

I'm currently working on a OS X application that uses a few different NSTableViews to display user data. I was testing them out a bit to make sure multiple deletions worked correctly from my database and I found myself pressing 'j' and 'k' to try and move down and up. I decided it would be pretty cool to implement those two vim shortcuts into my table view just in case anyone else thinks like me.

This functionality already exists in [The Hit List](http://www.potionfactory.com/thehitlist/) an awesome GTD app that has a lot of baggage with me, and I'm sure it exists in other applications as well.

In my `NSTableView` subclass' `keyDown:` method I tried a few things.

Attempt 1: First I tried to re implement the functionality myself. In retrospect this doesn't make any sense but at first it was pretty simple. It looked something like this.

{% highlight objc %}
NSUInteger flags = [theEvent modifierFlags] & NSDeviceIndependentModifierFlagsMask;
NSNumber *shiftPressed = (flags & NSShiftKeyMask);
 
if ([theEvent keyCode] == 38) { // j
    NSUInteger index = [[self selectedRowIndexes] lastIndex] + 1;
    if ([shiftPressed boolValue]) {
        [self selectRowIndexes:[NSIndexSet indexSetWithIndex:index] byExtendingSelection:YES];
    } else {
        [self selectRowIndexes:[NSIndexSet indexSetWithIndex:index] byExtendingSelection:NO];
    }
} else if ([theEvent keyCode] == 40) { // k
    NSUInteger index = [[self selectedRowIndexes] lastIndex] - 1;
    if ([shiftPressed boolValue]) {
        [self selectRowIndexes:[NSIndexSet indexSetWithIndex:index] byExtendingSelection:YES];
    } else {
        [self selectRowIndexes:[NSIndexSet indexSetWithIndex:index] byExtendingSelection:NO];
    }
}
{% endhighlight %}

The issue with this is the way `NSTableView` typically expands it's selection. I think of it as a pivot point where you start. Then you go up and down relative to that point. So if you start at index 2 and go down till index 4, you should have 2 rows selected. Then when you go back up you should deselect the rows and indexes 3 and 4 and select the rows and index 1 and 0. At this point I realized it was more difficult than I realized at first and went in search on another solution.

Attempt 2: The next solution I discovered used the [Quartz Event Services](https://developer.apple.com/library/mac/#documentation/Carbon/Reference/QuartzEventServicesRef/Reference/reference.html) APIs.

{% highlight objc %}
if ([theEvent keyCode] == 38) { // The letter 'j'
    CGEventRef e = CGEventCreateKeyboardEvent(NULL, (CGKeyCode)125, true);
    CGEventPost(kCGSessionEventTap, e);
    CFRelease(e);
} else if ([theEvent keyCode] == 40) { // The letter 'k'
    CGEventRef e = CGEventCreateKeyboardEvent(NULL, (CGKeyCode)126, true);
    CGEventPost(kCGSessionEventTap, e);
    CFRelease(e);
}
{% endhighlight %}

This solution worked perfectly, at first. This mainly emulates a key press with a different key code. So as you can see I was catching j and k and spitting them out as down and up. I spent a few minutes testing this before I remembered that I had sandboxing disabled so I could more easily delete my application support folder while messing with my Core Data stack. There went that solution.

Attempt 3: Before I used the weird `CGEventRef` solution I tried to create my own `NSEvent` passing it all the same attributes from the original event (all this code is being used in the `keyDown:` function of my subclass) but I couldn't figure out how to get the correct character string for the up and down arrows. I typically use [Key Codes](http://manytricks.com/keycodes/) to get all the possible information you could want about each key you press. But for some keys, including the arrow keys, it returns garbage for the character code. Then I discovered [this answer](http://stackoverflow.com/a/4434934/902968) on StackOverflow where there is a brief mention of `NSUpArrowFunctionKey`. With that I came up with this.

{% highlight objc %}
if ([theEvent keyCode] == 38) { // j
    unichar down = NSDownArrowFunctionKey;
    NSString *downString = [NSString stringWithCharacters:&down length:1];
    NSEvent *newEvent =[NSEvent keyEventWithType:NSKeyDown
                                        location:theEvent.locationInWindow
                                   modifierFlags:theEvent.modifierFlags
                                       timestamp:theEvent.timestamp
                                    windowNumber:theEvent.windowNumber
                                         context:nil
                                      characters:downString
                     charactersIgnoringModifiers:downString
                                       isARepeat:theEvent.isARepeat
                                         keyCode:down];
    
    [super keyDown:newEvent];
} else if ([theEvent keyCode] == 40) { // k
    unichar up = NSUpArrowFunctionKey;
    NSString *upString = [NSString stringWithCharacters:&up length:1];
    NSEvent *newEvent =[NSEvent keyEventWithType:NSKeyDown
                                        location:theEvent.locationInWindow
                                   modifierFlags:theEvent.modifierFlags
                                       timestamp:theEvent.timestamp
                                    windowNumber:theEvent.windowNumber
                                         context:nil
                                      characters:upString
                     charactersIgnoringModifiers:upString
                                       isARepeat:theEvent.isARepeat
                                         keyCode:up];
    
    [super keyDown:newEvent];
} else {
    [super keyDown:theEvent];
}
{% endhighlight %}

Not the prettiest solution I but one that seems to work perfectly, even sandboxed, to provide the expected behavior in an `NSTableView` subclass.
