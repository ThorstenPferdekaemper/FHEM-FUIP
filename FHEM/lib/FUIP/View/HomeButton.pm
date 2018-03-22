# class FUIP::View
package FUIP::View::HomeButton;

# a HomeButton is a special MenuItem

use strict;
use warnings;

use lib::FUIP::View;
use parent -norequire, 'FUIP::View::MenuItem';


sub getStructure($) {
	# class method
	# returns general structure of the view without instance values
	my ($class) = @_;
	my $structure = $class->SUPER::getStructure();
	for my $field (@$structure) {
		if($field->{id} eq "text") {
			$field->{default} = { type => "const", value => "Home" };
		}elsif($field->{id} eq "link"){
			$field->{default} = { type => "const", value => "home" };
		}elsif($field->{id} eq "icon"){
			$field->{default} = { type => "const", value => "oa-control_building_s_all" };
		};	
	};	
	return $structure;
};

1;	