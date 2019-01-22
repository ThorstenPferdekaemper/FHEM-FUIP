package FUIP::View::MenuItem;

use strict;
use warnings;

    use lib::FUIP::View;
	use parent -norequire, 'FUIP::View';


	sub getHTML($){
		my ($self) = @_;
		# show Reading state, if it exists
		my $class = "fuip-menu-item";
		my $color = "fuip-color-menuitem";
		if($self->{active}) {
			$class = "fuip-menu-item-active";
			$color = "fuip-color-menuitem-active";
		};
		my $link = (substr($self->{link},0,1) eq "/" ? $self->{link} : "/fhem/".lc($self->{fuip}{NAME})."/page/".$self->{link});
		return '	
			<div data-type="link" data-color="'.$color.'" data-background-color="'.$class.'" data-height="36px" data-url="'.$link.'" 
				data-icon="'.$self->{icon}.'" class="'.$class.'">'.$self->{text}.'</div>';		
	};

	
sub dimensions($;$$){
	my $self = shift;
	return (main::AttrVal($self->{fuip}{NAME},"baseWidth",142), 38);
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
		{ id => "active", type => "boolean", value => "0" }	
		];
};


# register me as selectable
$FUIP::View::selectableViews{"FUIP::View::MenuItem"}{title} = "Menu Item"; 
	
1;	