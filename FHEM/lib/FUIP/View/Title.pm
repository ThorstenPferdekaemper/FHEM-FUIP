package FUIP::View::Title;

use strict;
use warnings;

use lib::FUIP::View;
use parent -norequire, 'FUIP::View';


sub getHTML($){
	my ($self) = @_;
	return '<div style="display:flex;justify-content:flex-start;align-items:center;">
				<div data-type="button" data-icon="'.$self->{icon}.'" 
		             data-on-color="fuip-color-symbol-foreground" data-on-background-color="fuip-color-symbol-active"
					 data-off-color="fuip-color-symbol-foreground" data-off-background-color="fuip-color-symbol-active" 
		             class="cell small readonly"></div>
		        <div style="overflow:hidden;text-overflow:ellipsis;white-space:nowrap;" class="bigger fuip-color-foreground">'.uc($self->{text}).'</div>
		      </div>';
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
		$self->{height} = 86;
	};	
	if(not $self->{width} or $self->{sizing} eq "fixed") {
			$self->{width} = 500;
	};	
	return ("auto","auto") if($self->{sizing} eq "auto");
	return ($self->{width},$self->{height});
};		


sub reconstruct($$$) {
	my ($class,$conf,$fuip) = @_;
	my $self = FUIP::View::reconstruct($class,$conf,$fuip);
	# downward compatibility: automatically convert width to resizable
	return $self unless defined($self->{width});
	return $self unless $self->{width} =~ m/^(fixed|auto)$/;
	$self->{sizing} = $self->{width};
	delete $self->{width};
	if(defined($self->{defaulted}{width})) {
		$self->{defaulted}{sizing} = $self->{defaulted}{width};
		delete $self->{defaulted}{width};
	};	
	return $self;
};

	
sub getStructure($) {
	# class method
	# returns general structure of the view without instance values
	my ($class) = @_;
	return [
		{ id => "class", type => "class", value => $class },
		{ id => "text", type => "text" },
		{ id => "icon", type => "icon" },
		{ id => "title", type => "text", default => { type => "field", value => "text"} },
		{ id => "width", type => "dimension" },
		{ id => "height", type => "dimension" },
		{ id => "sizing", type => "sizing", options => [ "fixed", "auto", "resizable" ],
			default => { type => "const", value => "auto" } },
		{ id => "popup", type => "dialog", default=> { type => "const", value => "inactive"} }	
		];
};


# register me as selectable
$FUIP::View::selectableViews{"FUIP::View::Title"}{title} = "Title"; 
	
1;	