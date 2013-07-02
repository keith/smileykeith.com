/* smileykeith.com/humans.txt for more info */
Mousetrap.bind('i', function() { instapaper(); return false; }, 'keyup');
Mousetrap.bind('j', function() { window.scrollBy(0, 100); return false; });
Mousetrap.bind('k', function() { window.scrollBy(0, -100); return false; });

Mousetrap.bind('1', function() { setActiveStyleSheet('default'); return false; })
Mousetrap.bind('2', function() { setActiveStyleSheet('slight'); hljs.initHighlighting(); return false; })
Mousetrap.bind('3', function() { setActiveStyleSheet('sdark'); hljs.initHighlighting(); return false; })

Mousetrap.bind("/", function() { document.getElementById('field').focus(); return false; }, 'keyup');
Mousetrap.bind('up up down down left right left right b a enter', function() {
    console.log(':0 Impressive');
	window.location = 'http://en.wikipedia.org/wiki/Konami_Code'
	// TODO
});

function instapaper() {
	window.location = 'http://www.instapaper.com/hello2?url=' + encodeURIComponent(window.location.href) + '&title=' + encodeURIComponent(document.title) + '&description=' + encodeURIComponent('Saved from SmileyKeith.com');
}
