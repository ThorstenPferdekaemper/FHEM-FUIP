package FUIP::View::Title;

use strict;
use warnings;

use lib::FUIP::View;
use parent -norequire, 'FUIP::View';


sub getHTML($){
	my ($self) = @_;
	return '<div style="display:flex;justify-content:flex-start;align-items:center;">
				<div data-type="button" data-icon="'.$self->{icon}.'" 
		             data-on-color="#2A2A2A" data-on-background-color="#aa6900" data-off-color="#2A2A2A" data-off-background-color="#aa6900" 
		             class="cell small readonly"></div>
		        <div style="color:#808080;overflow:hidden;text-overflow:ellipsis;white-space:nowrap;" class="bigger">'.uc($self->{text}).'</div>
		      </div>';
};


sub dimensions($;$$){
	my $self = shift;
	$self->{width} = "auto" unless $self->{width};
	return (($self->{width} eq "fixed") ? 500 : "auto", 86);
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
		{ id => "width", type => "text", options => [ "auto", "fixed" ],
			default => { type => "const", value => "auto" } },
		{ id => "popup", type => "dialog", default=> { type => "const", value => "inactive"} }	
		];
};


# register me as selectable
$FUIP::View::selectableViews{"FUIP::View::Title"}{title} = "Title"; 
	
1;	