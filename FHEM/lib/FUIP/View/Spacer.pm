package FUIP::View::Spacer;

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
	# do we have to determine the size?
	# even if sizing is "auto", we at least determine an initial size
	# either resizable and no size yet
	# or fixed
	if(not $self->{height} or $self->{sizing} eq "fixed") {
		$self->{height} = 10;
	};
	if(not $self->{width} or $self->{sizing} eq "fixed") {
		$self->{width} = main::AttrVal($self->{fuip}{NAME},"baseWidth",142);
	};	
	return ("auto","auto") if($self->{sizing} eq "auto");
	return ($self->{width},$self->{height});
};	


sub getHTML($){
	return '';  # this is just empty and needs some space 			
};
	
	
sub getStructure($) {
	# class method
	# returns general structure of the view without instance values
	my ($class) = @_;
	return [
		{ id => "class", type => "class", value => $class },
		{ id => "title", type => "text", default => { type => "const", value => "Spacer"} },
		{ id => "width", type => "dimension" },
		{ id => "height", type => "dimension" },
		{ id => "sizing", type => "sizing", options => [ "fixed", "auto", "resizable" ],
			default => { type => "const", value => "resizable" } }	
		];
};


# register me as selectable
$FUIP::View::selectableViews{"FUIP::View::Spacer"}{title} = "Spacer (just wastes some space)"; 
	
1;	