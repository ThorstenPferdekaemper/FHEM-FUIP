package FUIP::View::7SegmentReading;

use strict;
use warnings;

use lib::FUIP::View;
use parent -norequire, 'FUIP::View';
		
sub getHTML($){
	my ($self) = @_;
	my $result= '<div
		data-type = "7segment"
		data-get-value = "'.$self->{reading}{device}.':'.$self->{reading}{reading}.'" 
		data-digits="'.$self->{digits}.'"
		data-decimals="'.$self->{decimals}.'" ';
	if($self->{colorscheme} eq "temp-air") {
		$result .= 'data-limits=[-99,12,19,23,28]
					data-limit-colors=["#ffffff","#6699ff","#AA6900","#AD3333","#FF0000"] ';
	}elsif($self->{colorscheme} eq "temp-boiler") {
		$result .= 'data-limits=[-99,25,40,55,70]
					data-limit-colors=["#ffffff","#6699ff","#AA6900","#AD3333","#FF0000"] ';
	}elsif($self->{colorscheme} eq "humidity") {
		$result .= 'data-limits=[-1,20,39,59,65,79]
					data-limit-colors=["#ffffff","#6699ff","#AA6900","#AB4E19","#AD3333","#FF0000"] ';
	}else { # single color	
		$result .= 'data-color-fg="'.$self->{color}.'" ';
	};
	$result .= ' data-color-bg="rgba(255,255,255,0)"></div>';
	return $result;
};


sub dimensions($;$$){
	# 19 * digits x 30
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
		$self->{width} = $self->{digits} * 19;
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
		{ id => "reading", type => "device-reading", 
			device => { },
			reading => { } },	
		{ id => "title", type => "text", default => { type => "field", value => "reading-reading"} },
		{ id => "digits", type => "text", default => { type => "const", value => "3"},
				options => ["1","2","3","4","5","6","7","8"] },
		{ id => "decimals", type => "text", default => { type => "const", value => "1"},
				options => ["0","1","2","3","4","5","6","7"] },
		{ id => "colorscheme", type => "text", default => { type => "const", value => "single" },
				options => ["single","temp-air","temp-boiler","humidity"] },
		{ id => "color", type => "setoption", 
				default => { type => "const", value => "fuip-color-symbol-active" },
				options => ["fuip-color-symbol-active","fuip-color-symbol-inactive","fuip-color-symbol-foreground","fuip-color-foreground","green","yellow","red"],
				depends => { field => "colorscheme", value => "single" } },
		{ id => "width", type => "dimension" },
		{ id => "height", type => "dimension" },
		{ id => "sizing", type => "sizing", options => [ "fixed", "resizable", "auto" ],
			default => { type => "const", value => "fixed" } },
		{ id => "popup", type => "dialog", default=> { type => "const", value => "inactive"} }		
		];
};
	
# register me as selectable
$FUIP::View::selectableViews{"FUIP::View::7SegmentReading"}{title} = "7-Segment-Display (Reading)"; 
	
1;	