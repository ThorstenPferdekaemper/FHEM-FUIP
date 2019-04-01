package FUIP::View::MenuItem;

use strict;
use warnings;

use lib::FUIP::View;
use parent -norequire, 'FUIP::View';


sub getHTML($){
	my ($self) = @_;
	my $class = "fuip-menu-item";
	my $color = "fuip-color-menuitem";
	if($self->{active}) {
		$class = "fuip-menu-item-active";
		$color = "fuip-color-menuitem-active";
	};
	my $link = (substr($self->{link},0,1) eq "/" ? $self->{link} : "/fhem/".lc($self->{fuip}{NAME})."/page/".$self->{link});
	return '	
		<div data-type="link" data-color="'.$color.'" data-background-color="'.$class.'" data-url="'.$link.'" 
			data-icon="'.$self->{icon}.'" class="'.$class.'" data-height="calc(100% - 2px)">'.$self->{text}.'</div>';	
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
		$self->{height} = 38;
	};
	if(not $self->{width} or $self->{sizing} eq "fixed") {
		$self->{width} = main::AttrVal($self->{fuip}{NAME},"baseWidth",142);
	};	
	return ($self->{width},$self->{height});
};
	
	
sub getStructure($) {
	# class method
	# returns general structure of the view without instance values
	my ($class) = @_;
	return [
		{ id => "class", type => "class", value => $class },
		{ id => "text", type => "text" },
		{ id => "title", type => "text", default => { type => "field", value => "text"} },
		{ id => "link", type => "link" },
		{ id => "icon", type => "icon" },
		# TODO: proper "boolean" drop down
		{ id => "active", type => "boolean", value => "0" },
		{ id => "width", type => "dimension" },
		{ id => "height", type => "dimension" },
		{ id => "sizing", type => "sizing", options => [ "fixed", "resizable" ],
			default => { type => "const", value => "fixed" } }		
		];
};


# register me as selectable
$FUIP::View::selectableViews{"FUIP::View::MenuItem"}{title} = "Menu Item"; 
	
1;	