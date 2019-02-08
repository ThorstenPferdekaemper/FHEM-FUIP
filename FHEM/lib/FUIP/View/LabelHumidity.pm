package FUIP::View::LabelHumidity;

use strict;
use warnings;

use lib::FUIP::View;
use parent -norequire, 'FUIP::View';
	
sub getDependencies($$) {
	return ['js/fuip_5_resize.js','js/fuip_label.js'];
};	
	
sub getHTML($){
	my ($self) = @_;
	my $result = '<div data-fuip-type="fuip-label-humidity" style="width:100%;height:100%;">';
	if($self->{label}) {
		$result .= '<div class="fuip-color left">'.$self->{label}.':</div>
					<div style="position:absolute;top:0px;right:0px"';
	}else{
		$result .= '<div';
	};	
	$result .= " data-type=\"label\" 
						 data-device=\"".$self->{humidity}{device}."\" 
						 data-get=\"".$self->{humidity}{reading}."\"
						 data-unit=\" %\"
						 data-limits=\"[-1,20,39,59,65,79]\"
						 data-colors='[\"#ffffff\",\"#6699ff\",\"#AA6900\",\"#AB4E19\",\"#AD3333\",\"#FF0000\"]'>
					</div></div>";
	return $result;	
};

	
sub dimensions($;$$){
	my ($self,$width,$height) = @_;
	$self->{sizing} = "fixed" unless $self->{sizing} and $self->{sizing} eq "resizable";
	if($self->{sizing} eq "resizable") {
		$self->{width} = $width if $width;
		$self->{height} = $height if $height;
	};
	# do we have to determine the size?
	# even if sizing is "auto", we at least determine an initial size
	# either resizable and no size yet
	# or fixed
	if(not $self->{height} or $self->{sizing} eq "fixed") {
		$self->{height} = 25;
	};
	if(not $self->{width} or $self->{sizing} eq "fixed") {
		$self->{width} = 60;
		$self->{width} += 120 if($self->{label});
	};	
	return ($self->{width},$self->{height});
};		

	
sub getStructure($) {
	# class method
	# returns general structure of the view without instance values
	my ($class) = @_;
	return [
		{ id => "class", type => "class", value => $class },
		{ id => "title", type => "text", default => { type => "const", value => "Humidity"} },
		{ id => "humidity", type => "device-reading",
			device => { },
			reading => { default => { type => "const", value => "humidity"} } },
		{ id => "label", type => "text", default => { type => "field", value => "humidity-reading"} },
		{ id => "width", type => "dimension" },
		{ id => "height", type => "dimension" },
		{ id => "sizing", type => "sizing", options => [ "fixed", "resizable" ],
			default => { type => "const", value => "fixed" } },		
		{ id => "popup", type => "dialog", default=> { type => "const", value => "inactive"} }			
		];
};

# register me as selectable
$FUIP::View::selectableViews{"FUIP::View::LabelHumidity"}{title} = "Humidity Label"; 
	
1;	