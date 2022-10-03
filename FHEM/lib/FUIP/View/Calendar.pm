package FUIP::View::Calendar;

use strict;
use warnings;

use lib::FUIP::View;
use parent -norequire, 'FUIP::View';


sub getHTML($){
	my ($self) = @_;
	$self->{layout} = 'week' unless defined $self->{layout};
	return '<div data-type="fuip_calendar"
			data-device=\'["'.join('","',@{$self->{device}}).'"]\'
			data-layout="'.$self->{layout}.'"
			style="height:100%;width:100%"
			></div>';
};

	
sub dimensions($;$$){
	my ($self,$width,$height) = @_;
	if($self->{sizing} eq "resizable") {
		$self->{width} = $width if $width;
		$self->{height} = $height if $height;
	};
	
	# do we have to determine the size?
	# even if sizing is "auto", we at least determine an initial size
	# either resizable and no size yet
	# or fixed
	if(not $self->{height} or $self->{sizing} eq "fixed") {
		$self->{height} = 400;
	};	
	if(not $self->{width} or $self->{sizing} eq "fixed") {
		$self->{width} = 750;
	};	
	return ("auto","auto") if($self->{sizing} eq "auto");
	return ($self->{width},$self->{height});
};	
	
	
sub getDevicesForValueHelp($$) {
	# Return devices with TYPE Calendar
	my ($fuipName,$sysid) = @_;
	return FUIP::_toJson(FUIP::Model::getDevicesForType($fuipName,"Calendar",$sysid));
}	
	
	
sub getStructure($) {
	# class method
	# returns general structure of the view without instance values
	my ($class) = @_;
	return [
		{ id => "class", type => "class", value => $class },
		{ id => "device", type => "devices", filterfunc => "FUIP::View::Calendar::getDevicesForValueHelp" },
		{ id => "title", type => "text", default => { type => "field", value => "device"} },
		
		#TODO
		#The list layout is not really ready yet
		#{ id => "layout", type => "text", options => [ "week", "list" ],
		#	default => { type => "const", value => "week" } },
		
		{ id => "width", type => "dimension" },
		{ id => "height", type => "dimension" },
		{ id => "sizing", type => "sizing", options => [ "fixed", "auto", "resizable" ],
			default => { type => "const", value => "auto" } }
	  ];
};


our %docu = (
	general => "Diese View ist eine einfache Darstellung eines Kalenders.<br>
				Es wird immer eine ganze Woche angezeigt. Die Anzeige basiert auf Calendar-Devices in FHEM.",
	device => "Hier gibt man ein oder mehrere Calendar-Devices an. Es werden die Termine aus allen ausgew&auml;hlten Kalendern angezeigt."
);


# register me as selectable
$FUIP::View::selectableViews{"FUIP::View::Calendar"}{title} = "Kalender (experimentell)"; 
	
1;	