package FUIP::View::Clock;

use strict;
use warnings;

use lib::FUIP::View;
use parent -norequire, 'FUIP::View';


sub getDependencies($$) {
	return ['js/fuip_5_resize.js','js/fuip_clock.js'];
};


sub dimensions($;$$){
	my ($self,$width,$height) = @_;
	$self->{sizing} = "fixed" unless $self->{sizing};
	if($self->{sizing} eq "resizable") {
		$self->{width} = $width if $width;
		$self->{height} = $height if $height;
	};
	# do we have to determine the size?
	# even if sizing is "auto", we at least determine an initial size
	# either resizable and no size yet
	# or fixed
	if(not $self->{height} or $self->{sizing} eq "fixed") {
		$self->{height} = 66;
	};
	if(not $self->{width} or $self->{sizing} eq "fixed") {
		$self->{width} = 110;
	};	
	return ("auto","auto") if($self->{sizing} eq "auto");
	return ($self->{width},$self->{height});
};	


sub getHTML($){
	return '<div data-fuip-type="fuip-clock" style="width:100%;height:100%;">
			<div data-type="fuip_clock" data-format="H:i" style="font-size:200%" class="fuip-color-foreground"></div> 
            <div data-type="fuip_clock" data-format="d.M Y" style="font-size:100%" class="cell fuip-color-foreground"></div>
			</div>'; 			
};
	
	
sub getStructure($) {
	# class method
	# returns general structure of the view without instance values
	my ($class) = @_;
	return [
		{ id => "class", type => "class", value => $class },
		{ id => "title", type => "text", default => { type => "const", value => "Uhrzeit"} },
		{ id => "width", type => "dimension" },
		{ id => "height", type => "dimension" },
		{ id => "sizing", type => "sizing", options => [ "fixed", "auto", "resizable" ],
			default => { type => "const", value => "fixed" } },
		{ id => "popup", type => "dialog", default=> { type => "const", value => "inactive"} }	
		];
};


# register me as selectable
$FUIP::View::selectableViews{"FUIP::View::Clock"}{title} = "Eine Uhr mit Anpassung an die Server-Zeit"; 
	
1;	