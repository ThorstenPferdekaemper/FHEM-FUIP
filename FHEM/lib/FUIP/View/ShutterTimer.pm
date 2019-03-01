package FUIP::View::ShutterTimer;

use strict;
use warnings;

use lib::FUIP::View;
use parent -norequire, 'FUIP::View';


sub getHTML($){
	my ($self) = @_;
	my (undef,$height) = $self->dimensions();
	my $left = "";
	$left = 'left:-31px;' unless $self->{label}; 
	my $result = '
				<div style="width:100px;height:38px">	
				<div style="position:absolute;top:-11px;'.$left.'width:100px;height:38px"
					data-type="fuip_wdtimer" 
					data-device="'.$self->{device}.'"    
					data-width="450"
					data-style="round noicons" 
					data-theme="dark" 
					data-title="'.$self->{title}.'"  
					data-sortcmdlist="MANUELL"
					data-cmdlist=\'{"Zu":"0","Auf":"100","10%":"10","20%":"20","30%":"30","40%":"40","50%":"50","60%":"60","70%":"70","80%":"80","90%":"90"}\'>
					<div data-type="button" class="cell small readonly" data-icon="oa-edit_settings"
						data-background-icon="fa-square-o" 
						data-on-color="#505050" data-on-background-color="#505050">
					</div>
				</div>
				</div>';
	if($self->{label}) {
		$result .= '<div class="fuip-color">'.$self->{label}.'</div>';
	};	
	return $result;
};

	
sub dimensions($;$$){
	my $self = shift;
	# we ignore any settings
	my $height = 38;
	my $width = 38;
	if($self->{label}) {
		$height += 17;
		$width = 100;
	};	
	return ($width, $height);
};	
	
	
sub getStructure($) {
	# class method
	# returns general structure of the view without instance values
	my ($class) = @_;
	return [
		{ id => "class", type => "class", value => $class },
		{ id => "device", type => "device" },
		{ id => "title", type => "text", default => { type => "field", value => "device"} },
		{ id => "label", type => "text", default => { type => "field", value => "title"} }
		];
};

# register me as selectable
$FUIP::View::selectableViews{"FUIP::View::ShutterTimer"}{title} = "Timer (for Shutters)"; 
	
1;	