package FUIP::View::Popup;

use strict;
use warnings;

use lib::FUIP::View;
use parent -norequire, 'FUIP::View';


sub getHTML($){
	my ($self) = @_;
	my $result = $self->{text};
	if($self->{icon}){
		$result = '<div data-type="link" data-color="fuip-color-foreground" data-text-align="left" data-icon="'.$self->{icon}.'">'.$result.'</div>';	
	};
	return $result;
};
	
	
sub dimensions($;$$){
	my $self = shift;
	if($self->{text}) {
		return (main::AttrVal($self->{fuip}{NAME},"baseWidth",142), 30);
	};
	return (30,30);
};	
	

sub getStructure($) {
	# class method
	# returns general structure of the view without instance values
	my ($class) = @_;
	return [
		{ id => "class", type => "class", value => $class },
		{ id => "text", type => "text", default => { type => "const", value => "Click here..."} },
		{ id => "icon", type => "icon" },
		{ id => "title", type => "text", default => { type => "field", value => "text"} },
		{ id => "popup", type => "dialog" }
		];
};


# register me as selectable
$FUIP::View::selectableViews{"FUIP::View::Popup"}{title} = "Trigger a popup"; 

1;	