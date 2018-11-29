package FUIP::View::SimpleSwitch;

use strict;
use warnings;
    use lib::FUIP::View;
	use parent -norequire, 'FUIP::View';
	
	
	sub getHTML($){
		my ($self) = @_;
		my $result = 
			'<table cellpadding="0" width="100%">
				<tr><td>
					<div data-type="switch"   
						data-device="'.$self->{device}.'" 
						data-icon="'.$self->{icon}.'"';
		if($self->{set}) {
			$result .= '
						data-set="'.$self->{set}.'"';
		};
		if($self->{reading}) {
			$result .= '
						data-get="'.$self->{reading}.'"';
		};
		$result .= '
						data-get-on="on.*|ON.*|[1-9][0-9]*"
						data-get-off="off|OFF|0"
						data-set-on="on"
						data-set-off="off">
					</div>
				</td></tr>';
		$result .= '<tr><td class="fuip-color">'.$self->{label}.'</td></tr>' if($self->{label});
		$result .= '</table>';	 
	};

	
sub dimensions($;$$){
	my $self = shift;
	return (70, ($self->{label} ? 78 : 56));
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
		{ id => "set", type => "set", refdevice => "device", default => { type => "const", value => "" } },
		{ id => "reading", type => "reading", refdevice => "device", default => { type => "field", value => "set"}},
		{ id => "icon", type => "icon", default => { type => "const", value => "fa-lightbulb-o" } }
		];
};


# register me as selectable
$FUIP::View::selectableViews{"FUIP::View::SimpleSwitch"}{title} = "Simple Switch"; 

1;	