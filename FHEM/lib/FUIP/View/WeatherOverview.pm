package FUIP::View::WeatherOverview;

use strict;
use warnings;

use lib::FUIP::View;
use parent -norequire, 'FUIP::View';


	
sub getHTML($){
	my ($self) = @_;
	my $device = $self->{device};
	# avoid issues with broken instance
	$self->{days} = 1 unless $self->{days};
	return '<div>
			<link rel="stylesheet" href="/fhem/'.lc($self->{fuip}{NAME}).'/fuip/css/widget_weatherdetail.css">
			<div data-type="weatherdetail" 
				data-device="'.$device.'" 
				data-days='.$self->{days}.' 
				data-detail=\'[]\'
				data-layout="'.$self->{layout}.'">
			</div>
			</div>';
};

	
sub dimensions($;$$){
	my $self = shift;
	my $height = 205;
	my $width = "auto";
	# if layout is "small", height is always base height
	if($self->{layout} eq "small") {
		$height = main::AttrVal($self->{fuip}{NAME},"baseHeight",108);
	};
	# width "fixed" and "normal" => 149 * days, "small" => depends on baseWidth
	if($self->{width} eq "fixed") {
		if($self->{layout} eq "small") {
			$width = (main::AttrVal($self->{fuip}{NAME},"baseWidth",142) + 10) * $self->{days} - 10;
		}else{
			$width = 149 * $self->{days};
		};
	};	
	return ($width,$height);
};	
	
	
sub getStructure($) {
	# class method
	# returns general structure of the view without instance values
	my ($class) = @_;
	return [
		{ id => "class", type => "class", value => $class },
		{ id => "device", type => "device" },
		{ id => "title", type => "text", default => { type => "field", value => "device"} },
		{ id => "days", type => "text", 
				options => [1,2,3,4,5,6,7],
				default => { type => "const", value => 1 } },
		{ id => "width", type => "text", options => [ "fixed", "auto" ],
			default => { type => "const", value => "fixed" } },
		{ id => "layout", type => "text", options => [ "normal", "small" ], default => { type => "const", value => "normal" }},	
		{ id => "popup", type => "dialog", default=> { type => "const", value => "inactive"} }				
	  ];
};

# register me as selectable
$FUIP::View::selectableViews{"FUIP::View::WeatherOverview"}{title} = "Weather Overview"; 
	
1;	