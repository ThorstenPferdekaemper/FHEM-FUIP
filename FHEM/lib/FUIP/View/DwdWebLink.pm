package FUIP::View::DwdWebLink;

use strict;
use warnings;

use lib::FUIP::View;
use parent -norequire, 'FUIP::View';


sub dimensions($;$$){
	my ($self,$width,$height) = @_;
	if($self->{sizing} eq "resizable") {
		$self->{width} = $width if $width;
		$self->{height} = $height if $height;
	};
	return ("auto","auto") if($self->{sizing} eq "auto");
	if($self->{sizing} eq "fixed") {
		my $device = FUIP::Model::getDevice($self->{fuip}{NAME},$self->{device},['forecastDays']);
		my $forecastDays = 4;
		if(defined($device->{Attributes}{forecastDays})) {
			$forecastDays = $device->{Attributes}{forecastDays};
			$forecastDays = 1 if($forecastDays < 1);
			$forecastDays = 9 if($forecastDays > 9);
		};
		return ($forecastDays * 200, 125);
	};
	return ($self->{width},$self->{height});
};	


sub getHTML($){
	my ($self) = @_; 
	return '<div data-type="dwdweblink" data-device="'.$self->{device}.'"></div>'
};
	
	
sub getStructure($) {
# class method
# returns general structure of the view without instance values
	my ($class) = @_;
	return [
		{ id => "class", type => "class", value => $class },
		{ id => "device", type => "device" },
		{ id => "title", type => "text", default => { type => "field", value => "device"} },
		{ id => "width", type => "dimension", value => 800},
		{ id => "height", type => "dimension", value => 125 },
		{ id => "sizing", type => "sizing", options => [ "fixed", "resizable", "auto" ],
			default => { type => "const", value => "fixed" } },
		{ id => "popup", type => "dialog", default=> { type => "const", value => "inactive"} }	
		];
};


# register me as selectable
$FUIP::View::selectableViews{"FUIP::View::DwdWebLink"}{title} = "DWD_OpenData_Weblink"; 
	
1;	