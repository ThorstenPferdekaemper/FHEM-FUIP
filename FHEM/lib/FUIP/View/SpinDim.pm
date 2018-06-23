package FUIP::View::SpinDim;

use strict;
use warnings;
use lib::FUIP::View;
use parent -norequire, 'FUIP::View';
	
	
sub getHTML($){
	my ($self) = @_;
	my (undef,$height) = $self->dimensions();
	my $result = '<table style="width:100%;height:'.$height.'px !important;border-collapse: collapse;">
					<tr>
					<td style="padding:0;">
			<div 
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
			</div></td></tr>';	
	if($self->{label}) {
		$result .= '<tr><td  style="padding:0;" class="fuip-color">'.$self->{label}.'</td></tr>';
	};	
	$result .= '</table>';	
	return $result;
};


sub dimensions($;$$){
    my $self = shift;
	my $height = 40;
	$height += 17 if($self->{label});
	return (160, $height);
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
		{ id => "title", type => "text", default => { type => "field", value => "dimmer-device"} },
		{ id => "label", type => "text" }
		];
};

# register me as selectable
$FUIP::View::selectableViews{"FUIP::View::SpinDim"}{title} = "Dimmer (as spinner)"; 

1;	