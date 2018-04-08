package FUIP::View::MenuItem;

use strict;
use warnings;

    use lib::FUIP::View;
	use parent -norequire, 'FUIP::View';


	sub getHTML($){
		my ($self) = @_;
		# show Reading state, if it exists
		my $color = "grey";
		if($self->{active}) {$color = "#aa6900";};
		my $link = (substr($self->{link},0,1) eq "/" ? $self->{link} : "/fhem/".lc($self->{fuip}{NAME})."/page/".$self->{link});
		return '	
			<div data-type="link" data-color="'.$color.'" data-border-color="'.$color.'" data-url="'.$link.'" 
				data-icon="'.$self->{icon}.'" class="round">'.$self->{text}.'</div>';		
	};

	
sub dimensions($;$$){
	my $self = shift;
	if (@_) {
		$self->{width} = shift;
		$self->{height} = shift;
	}	
	$self->{width} = main::AttrVal($self->{fuip}{NAME},"baseWidth",142) unless $self->{width};
	return ($self->{width}, $self->{height});
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
		{ id => "height", type => "internal", value => 42 }
		];
};


# register me as selectable
$FUIP::View::selectableViews{"FUIP::View::MenuItem"}{title} = "Menu Item"; 
	
1;	