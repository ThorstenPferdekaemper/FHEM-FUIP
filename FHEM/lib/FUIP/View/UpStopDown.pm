package FUIP::View::UpStopDown;

use strict;
use warnings;
    use lib::FUIP::View;
	use parent -norequire, 'FUIP::View';
	
	
	sub getHTML($){
		my ($self) = @_;
		return '<div class="triplebox-v left" >
					<div data-type="push" data-device="'.$self->{device}.'" data-icon="fa-chevron-up" data-background-icon="fa-square-o" data-set-on="up" class="readonly"> </div>
					<div data-type="push" data-device="'.$self->{device}.'" data-icon="fa-minus" data-background-icon="fa-square-o" data-set-on="stop" class="readonly"> </div>
					<div data-type="push" data-device="'.$self->{device}.'" data-icon="fa-chevron-down" data-background-icon="fa-square-o" data-set-on="down" class="readonly"> </div>
				</div> ';	 
	};

	
sub getStructure($) {
	# class method
	# returns general structure of the view without instance values
	my ($class) = @_;
	return [
		{ id => "class", type => "class", value => $class },
		{ id => "device", type => "device" },
		{ id => "title", type => "text", default => { type => "field", value => "device"} },
		{ id => "width", type => "internal", value => 52 },
		{ id => "height", type => "internal", value => 140 }
		];
};

1;	