package FUIP::View::Push;

use strict;
use warnings;
    use lib::FUIP::View;
	use parent -norequire, 'FUIP::View';
	
	
sub getHTML($){
	my ($self) = @_;
	my $left = "";
	$left = 'left:24px;' if($self->{label}); 
	my $result = '<div style="'.$left.'" data-type="push" 
					data-device="'.$self->{device}.'" 
					data-icon="'.$self->{icon}.'" data-background-icon="fa-square-o"';
	# it seems that data-set and data-set-on does not always work
	$result .= ' data-fhem-cmd="set '.$self->{device}.' '.$self->{set}.' '.$self->{option}.'"';
	$result .= ' class="readonly"> </div>';
	if($self->{label}) {
		$result .= '<div class="fuip-color">'.$self->{label}.'</div>';
	};	
	return $result;	 
};

	
sub dimensions($;$$){
    my $self = shift;
	my $height = 52;
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
		{ id => "icon", type => "icon" },
		{ id => "set", type => "set", refdevice => "device" },
		{ id => "option", type => "setoption", refset => "set" },
		{ id => "title", type => "text", default => { type => "field", value => "device"} },
		{ id => "label", type => "text" }
		];
};


# register me as selectable
$FUIP::View::selectableViews{"FUIP::View::Push"}{title} = "Push button"; 

1;	