package FUIP::View::Brightness;

use strict;
use warnings;

    use lib::FUIP::View;
	use parent -norequire, 'FUIP::View';
	
	
	sub getHTML($){
		my ($self) = @_;
		return '<div data-type="volume"  
				 data-device="'.$self->{brightness}{device}.'" 
				 data-get="'.$self->{brightness}{reading}.'" 
				 data-set="dim" 
				 data-min="'.$self->{min}.'"
				 data-max="'.$self->{max}.'"
				 class="small dim-back readonly" 
			>
			<div style="position:absolute;top:80px;width:100%;color:#808080;" class="large">'.$self->{label}.'</div></div>';
	};

	
	sub dimensions($;$$){
		# we ignore any settings
		return (100, 100);
	};	
	
	
	sub getStructure($) {
	# class method
	# returns general structure of the view without instance values
	my ($class) = @_;
	return [
		{ id => "class", type => "class", value => $class },
		{ id => "brightness", type => "device-reading", 
			device => { },
			reading => { default => { type => "const", value => "brightness" } } },	
		{ id => "title", type => "text", default => { type => "field", value => "brightness-device"} },
		{ id => "label", type => "text", default => { type => "field", value => "title"} },
		{ id => "min", type => "text", default => { type => "const", value => "0"}},
		{ id => "max", type => "text", default => { type => "const", value => "250"}},
		{ id => "popup", type => "dialog", default=> { type => "const", value => "inactive"} }	
		];
};

# register me as selectable
$FUIP::View::selectableViews{"FUIP::View::Brightness"}{title} = "Brightness"; 
	
1;	