package FUIP::View::7SegmentClock;

use strict;
use warnings;

use lib::FUIP::View;
use parent -norequire, 'FUIP::View';
		
sub getHTML($){
	my ($self) = @_;
	return '<div
		data-type = "7segment"
		data-view = "clock'.($self->{seconds} eq "yes" ? '6' : '4').'"
		data-color-fg="'.$self->{color}.'"
		data-color-bg="rgba(255,255,255,0)">
	</div>';
};


sub dimensions($;$$){
	# 6 -> 120x30
	# 4 -> 80x30
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
		$self->{height} = 30;
	};
	if(not $self->{width} or $self->{sizing} eq "fixed") {
		$self->{width} = 80;
		$self->{width} = 120 if($self->{seconds} eq "yes");
	};	
	return ("auto","auto") if($self->{sizing} eq "auto");
	return ($self->{width},$self->{height});
};	

	
sub getStructure($) {
# class method
# returns general structure of the view without instance values
	my ($class) = @_;
	return [
		{ id => "class", type => "class", value => $class },
		{ id => "title", type => "text", default => { type => "const", value => "Time"} },
		{ id => "seconds", type => "text", default => { type => "const", value => "no"},
				options => ["yes","no"] },
		{ id => "color", type => "setoption", 
				default => { type => "const", value => "fuip-color-symbol-active" },
				options => ["fuip-color-symbol-active","fuip-color-symbol-inactive","fuip-color-symbol-foreground","fuip-color-foreground","green","yellow","red"] },
		{ id => "width", type => "dimension" },
		{ id => "height", type => "dimension" },
		{ id => "sizing", type => "sizing", options => [ "fixed", "resizable", "auto" ],
			default => { type => "const", value => "fixed" } },
		{ id => "popup", type => "dialog", default=> { type => "const", value => "inactive"} }			
		];
};

our %docu = (
	general => "Diese View zeigt eine Digitaluhr im 7-Segment-Design an.<br>
				Es wird die Client-Zeit (also die Zeit des Browsers) angezeigt.",
	seconds => "Dieser Parameter steuert, ob man nur Stunden und Minuten oder 
				auch Sekunden sieht.",
	color => "Farbe der Anzeige.<br>
			Es k&ouml;nnen insbesondere die \"FUIP-Farbsymbole\" ausgew&auml;hlt werden, so dass die Anzeige zum Rest der Oberfl&auml;che passt. Ansonsten kann man so ziemlich alles eingeben, was CSS als Farbe erlaubt."
);


# register me as selectable
$FUIP::View::selectableViews{"FUIP::View::7SegmentClock"}{title} = "7-Segment-Display clock"; 
	
1;	