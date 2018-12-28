package FUIP::View::UpStopDown;

use strict;
use warnings;
    use lib::FUIP::View;
	use parent -norequire, 'FUIP::View';
	
	
sub getHTML($){
	my ($self) = @_;
	my $left = "";
	$left = 'left:24px;' if($self->{label}); 
	my $result = '<div style="width:100px;height:136px;">
					<div style="position:absolute;top:0px;'.$left.'" data-type="push" data-device="'.$self->{device}.'" data-icon="fa-chevron-up" data-background-icon="fa-square-o" data-set-on="'.$self->{setUp}.'" class="readonly"> </div>
					<div style="position:absolute;top:42px;'.$left.'" data-type="push" data-device="'.$self->{device}.'" data-icon="fa-minus" data-background-icon="fa-square-o" data-set-on="'.$self->{setStop}.'" class="readonly"> </div>
					<div style="position:absolute;top:84px;'.$left.'" data-type="push" data-device="'.$self->{device}.'" data-icon="fa-chevron-down" data-background-icon="fa-square-o" data-set-on="'.$self->{setDown}.'" class="readonly"> </div>
					</div>';
	if($self->{label}) {
		$result .= '<div class="fuip-color">'.$self->{label}.'</div>';
	};	
	return $result;	 
};

	
sub dimensions($;$$){
    my $self = shift;
	my $height = 136;
	my $width = 52;
	if($self->{label}) {
		$height += 17 ;
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
		{ id => "setUp", type => "set", refdevice => "device", default => { type => "const", value => "up" } },
		{ id => "setStop", type => "set", refdevice => "device", default => { type => "const", value => "stop" } },
		{ id => "setDown", type => "set", refdevice => "device", default => { type => "const", value => "down" } },
		{ id => "title", type => "text", default => { type => "field", value => "device"} },
		{ id => "label", type => "text" }
		];
};


# register me as selectable
$FUIP::View::selectableViews{"FUIP::View::UpStopDown"}{title} = "Up, Stop and Down"; 

1;	