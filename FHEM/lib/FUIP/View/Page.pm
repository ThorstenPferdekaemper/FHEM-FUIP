
# class FUIPViewPage
package FUIP::Page;

use strict;
use warnings;
use POSIX qw(ceil);

use lib::FUIP::View;
use parent -norequire, 'FUIP::View';

	
sub getStructure($) {
	# class method
	# returns general structure of the view without instance values
	my ($class) = @_;
	return [
		{ id => "class", type => "class", value => $class },
		{ id => "title", type => "text" },
		{ id => "autoReturn", type => "text", options => ["on","off"], 
			default => { type => "const", value => "off" } },
		{ id => "returnAfter", type => "text", 
			default => { type => "const", value => "30" }, 
			depends => { field => "autoReturn", value => "on" } },
		{ id => "returnTo", type => "pageid",  
			default => { type => "const", value => "home" }, 
			depends => { field => "autoReturn", value => "on" } }
		];
};


our %docu = (
	general => "Eine Seite in FUIP ist eine einzelne Webseite.",
	title => "&Uuml;berschrift der Seite.<br>
			Hier kann ein Titel für die Seite eingetragen werden. Das erscheint dann je nach Browser irgendwo oben. (Technisch ist es der Inhalt des &lt;title&gt; Tags in &lt;head&gt;.)"
);

1;	