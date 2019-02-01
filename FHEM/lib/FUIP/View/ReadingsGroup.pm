package FUIP::View::ReadingsGroup;

use strict;
use warnings;

use lib::FUIP::View;
use parent -norequire, 'FUIP::View';

sub getDependencies($$) {
	return ['js/fuip_readingsgroup.js'];
};

sub dimensions($;$$){
	my ($self,$width,$height) = @_;
	if($self->{sizing} eq "resizable") {
		$self->{width} = $width if $width;
		$self->{height} = $height if $height;
	};
	return ("auto","auto") if($self->{sizing} eq "auto");
	return ($self->{width},$self->{height});
};	


sub getHTML($){
	my ($self) = @_; 
	$self->{columns} = 1 unless $self->{columns};
	return '<div data-type="readingsgroup" 
				data-device="'.$self->{device}.'" 
				data-columns="'.$self->{columns}.'"
				style="text-align:left;"></div>'; 
};
	
	
sub getStructure($) {
# class method
# returns general structure of the view without instance values
	my ($class) = @_;
	return [
		{ id => "class", type => "class", value => $class },
		{ id => "device", type => "device" },
		{ id => "title", type => "text", default => { type => "field", value => "device"} },
		{ id => "columns", type => "text", default => { type => "const", value => "1"}, options => ["1","2","3","4"] }, 
		{ id => "width", type => "dimension", value => 300},
		{ id => "height", type => "dimension", value => 100 },
		{ id => "sizing", type => "sizing", options => [ "resizable", "auto" ],
			default => { type => "const", value => "auto" } },
		{ id => "popup", type => "dialog", default=> { type => "const", value => "inactive"} }	
		];
};


# register me as selectable
$FUIP::View::selectableViews{"FUIP::View::ReadingsGroup"}{title} = "Readings Group (HTML from FHEMWEB)"; 
	
1;	