package FUIP::View::Select;

use strict;
use warnings;

    use lib::FUIP::View;
	use parent -norequire, 'FUIP::View';
	
	
	sub getHTML($){
		my ($self) = @_;
		my $widthclass = "";
		if($self->{width} eq "single") {
			$widthclass = "1";
		}elsif($self->{width} eq "double") {
			$widthclass = "2";
		}elsif($self->{width} eq "triple") {
			$widthclass = "3";
		};
		if($widthclass) {
			$widthclass = ' class="w'.$widthclass.'x"';
		};
		return ' <div data-type="select"'.$widthclass.'
					data-device="'.$self->{device}.'"
					data-items=\''.$self->{options}.'\'
					data-get="'.$self->{reading}.'"
					data-set="'.$self->{set}.'"></div>';
	};

	
sub dimensions($;$$){
	# 70, 110, 160
	my $self = shift;
	my $width = 110;
	if($self->{width} eq "single") {
		$width = 70;
	}elsif($self->{width} eq "triple") {
		$width = 160;
	};
	return ($width, 32);
};	
	
	
	sub getStructure($) {
	# class method
	# returns general structure of the view without instance values
	my ($class) = @_;
	return [
		{ id => "class", type => "class", value => $class },
		{ id => "device", type => "device" },
		{ id => "set", type => "set", refdevice => "device" },
		{ id => "reading", type => "reading", refdevice => "device", default => { type => "field", value => "set"}},
		{ id => "options", type => "setoptions", refset => "set" }, 	
		{ id => "width", type => "text", options => [ "single", "double", "triple", "auto" ], 
			default => { type => "const", value => "double" } }, 
		{ id => "title", type => "text", default => { type => "field", value => "device"} }
		];
};

# register me as selectable
$FUIP::View::selectableViews{"FUIP::View::Select"}{title} = "Select from options"; 
	
1;	