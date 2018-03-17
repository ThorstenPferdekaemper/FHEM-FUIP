# class FUIP::View
package FUIP::View::Clock;

use strict;
use warnings;

use lib::FUIP::View;
use parent -norequire, 'FUIP::View';


	sub getHTML($){
		return "<div data-type=\"clock\" data-format=\"H:i\" class=\"container bigger\"></div> 
                <div data-type=\"clock\" data-format=\"d.M Y\" class=\"cell\"></div>"; 			
 	};
	
	
	sub getStructure($) {
	# class method
	# returns general structure of the view without instance values
	my ($class) = @_;
	return [
		{ id => "class", type => "class", value => $class },
		{ id => "title", type => "text", default => { type => "const", value => "Uhrzeit"} },
		{ id => "width", type => "internal", value => 120 },
		{ id => "height", type => "internal", value => 86 }
		];
};

	
1;	