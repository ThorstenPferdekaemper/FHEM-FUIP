package FUIP::View::Window;

use strict;
use warnings;

use lib::FUIP::View;
use parent -norequire, 'FUIP::View';

	
sub getHTML($){
	my ($self) = @_;
	return '
		<div data-type="symbol" class="compressed large" 
			style="margin: 5px 5px 5px 5px;"
			data-device="'.$self->{device}.'" 
			data-states=\'["'.$self->{openstate}.'","'.$self->{closedstate}.'"]\' 
			data-icons=\'["'.$self->{openicon}.'","'.$self->{closedicon}.'"]\' 
			data-colors=\'["red","green"]\' >
		</div>'.
		($self->{label} ? '
			<div class="fuip-color">'.$self->{label}.'</div>' : ''); 
};

	
sub dimensions($;$$){
	my ($self,$width,$height) = @_;
	if($self->{sizing} eq "resizable") {
		$self->{width} = $width if $width;
		$self->{height} = $height if $height;
	};
	if($self->{sizing} eq "fixed") {
		if($self->{label}) {
			return (100,62);
		}else{
			return (43,43);
		};	
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
		{ id => "device", type => "device" },
		{ id => "title", type => "text", 
			default => { type => "field", value => "device" } },
		{ id => "label", type => "text", 
			default => { type => "field", value => "device" } },	
		{ id => "openstate", type => "text",
			default => { type => "const", value => "open" } },		
		{ id => "openicon", type => "icon",
			default => { type => "const", value => "oa-fts_window_1w_open" } },	
		{ id => "closedstate", type => "text",
			default => { type => "const", value => "closed" } },			
		{ id => "closedicon", type => "icon",
			default => { type => "const", value => "oa-fts_window_1w" } },		
		{ id => "width", type => "dimension", value => 43},
		{ id => "height", type => "dimension", value => 43},
		{ id => "sizing", type => "sizing", options => [ "fixed", "resizable", "auto" ],
			default => { type => "const", value => "fixed" } },
		{ id => "popup", type => "dialog", default=> { type => "const", value => "inactive"} }			
		];
};


# register me as selectable
$FUIP::View::selectableViews{"FUIP::View::Window"}{title} = "Window, Door or similar"; 
	
1;	