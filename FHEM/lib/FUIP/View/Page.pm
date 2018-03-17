
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
		];
};

	
1;	