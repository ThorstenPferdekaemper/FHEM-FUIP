package FUIP::View::UpStopDown;

use strict;
use warnings;
    use lib::FUIP::View;
	use parent -norequire, 'FUIP::View';
	
	
sub getHTML($){
	my ($self) = @_;
	my $left = "";
	$left = 'left:24px;' if($self->{label}); 
	my $result = '<div style="width:100px;height:140px;">
					<div style="position:absolute;top:0px;'.$left.'" data-type="push" data-device="'.$self->{device}.'" data-icon="fa-chevron-up" data-background-icon="fa-square-o" data-set-on="up" class="readonly"> </div>
					<div style="position:absolute;top:44px;'.$left.'" data-type="push" data-device="'.$self->{device}.'" data-icon="fa-minus" data-background-icon="fa-square-o" data-set-on="stop" class="readonly"> </div>
					<div style="position:absolute;top:86px;'.$left.'" data-type="push" data-device="'.$self->{device}.'" data-icon="fa-chevron-down" data-background-icon="fa-square-o" data-set-on="down" class="readonly"> </div>
					</div>';
	if($self->{label}) {
		$result .= '<div class="fuip-color">'.$self->{label}.'</div>';
	};	
	return $result;	 
};

	
sub dimensions($;$$){
    my $self = shift;
	my $height = 140;
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
		{ id => "title", type => "text", default => { type => "field", value => "device"} },
		{ id => "label", type => "text" }
		];
};


# register me as selectable
$FUIP::View::selectableViews{"FUIP::View::UpStopDown"}{title} = "Up, Stop and Down"; 

1;	