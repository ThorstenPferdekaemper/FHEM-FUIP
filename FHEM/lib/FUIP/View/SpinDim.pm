package FUIP::View::SpinDim;

use strict;
use warnings;
use lib::FUIP::View;
use parent -norequire, 'FUIP::View';
	
	
sub getHTML($){
	my ($self) = @_;
	return '<div 
				data-type="spinner" 
				data-device="'.$self->{dimmer}{device}.'"
				data-get="'.$self->{dimmer}{reading}.'"
				data-set="'.$self->{dimmer}{reading}.'"
				data-height="34"
				data-width="154" 
				class="value"
				data-icon-left="fa-caret-down"
				data-icon-right="fa-caret-up"
				data-gradient-color=\'["black","white"]\'>
			</div>';	

			
};


sub dimensions($;$$){
	# we ignore any settings
	return (160, 40);
};	
	
	
sub getStructure($) {
	# class method
	# returns general structure of the view without instance values
	my ($class) = @_;
	return [
		{ id => "class", type => "class", value => $class },
		{ id => "dimmer", type => "device-reading", 
			device => {},
			reading => { default => { type => "const", value => "level" } } },	
		{ id => "title", type => "text", default => { type => "field", value => "dimmer-device"} }
		];
};


# register me as selectable
$FUIP::View::selectableViews{"FUIP::View::SpinDim"}{title} = "Dimmer (as spinner)"; 

1;	