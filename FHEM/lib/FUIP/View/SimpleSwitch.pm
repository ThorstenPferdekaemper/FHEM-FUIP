# class FUIP::View::SimpleSwitch
package FUIP::View::SimpleSwitch;

use strict;
use warnings;
    use lib::FUIP::View;
	use parent -norequire, 'FUIP::View';
	
	
	sub getHTML($){
		my ($self) = @_;
		return '<table width="100%">
					<tr><td>
		<div data-type="switch"   
			data-device="'.$self->{device}.'" 
			data-icon="'.$self->{icon}.'"
			data-get-on="on.*|[1-9][0-9]*"
			data-get-off="off|0"
			data-set-on="on"
			data-set-off="off">
		</div>
				</td></tr>
			<tr><td>'.$self->{label}.'</td></tr>
		</table>';	 
	};

	
sub getStructure($) {
	# class method
	# returns general structure of the view without instance values
	my ($class) = @_;
	return [
		{ id => "class", type => "class", value => $class },
		{ id => "device", type => "device" },
		{ id => "title", type => "text", default => { type => "field", value => "device"} },
		{ id => "label", type => "text", default => { type => "field", value => "title"} },
		{ id => "icon", type => "icon", default => { type => "const", value => "fa-lightbulb-o" } },
		{ id => "width", type => "internal", value => 70 },
		{ id => "height", type => "internal", value => 80 }
		];
};

1;	