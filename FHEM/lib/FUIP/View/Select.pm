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
	my (undef,$height) = $self->dimensions();
	# if the set command is "state", then it needs to be blanked out
	my $set = ($self->{set} eq "state" ? "" : $self->{set}); 
	# data-list needs to be set "" explicitly as the default is setList, which would then fetch it
	# again from the device, overriding our settings
	my $options = '[]';
	# compatibility with earlier versions
	if(ref($self->{options}) eq "ARRAY") {
		if(@{$self->{options}}) {
			$options = '["'.join('","',@{$self->{options}}).'"]';
		};
	}else{
		$options = $self->{options};
	};	
	my $result = '<table style="width:100%;height:'.$height.'px !important;border-collapse: collapse;">
					<tr>
					<td style="padding:0;">
					<div data-type="select"'.$widthclass.'
					data-device="'.$self->{device}.'"
					data-list=""
					data-items=\''.$options.'\'
					data-get="'.$self->{reading}.'"
					data-set="'.$set.'"></div>
					</td></tr>';
	if($self->{label}) {
		$result .= '<tr><td  style="padding:0;" class="fuip-color">'.$self->{label}.'</td></tr>';
	};
	$result .= '</table>';	
	return $result;
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
	return ($width, ($self->{label} ? 49 : 32));
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
		{ id => "title", type => "text", default => { type => "field", value => "device"} },
		{ id => "label", type => "text" }
		];
};

# register me as selectable
$FUIP::View::selectableViews{"FUIP::View::Select"}{title} = "Select from options"; 
	
1;	