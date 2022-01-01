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
	$self->{zebra} = "on" unless $self->{zebra};
	return '<div data-type="readingsgroup" 
				data-device="'.$self->{device}.'" 
				data-columns="'.$self->{columns}.'"
				data-zebra="'.$self->{zebra}.'"
				style="text-align:left;height:100%;overflow-y:auto"></div>'; 
};
	

sub getDevicesForValueHelp($$) {
	# Return devices with TYPE readingsGroup
	my ($fuipName,$sysid) = @_;
	return FUIP::_toJson(FUIP::Model::getDevicesForType($fuipName,"readingsGroup",$sysid));
}	
	
	
sub getStructure($) {
# class method
# returns general structure of the view without instance values
	my ($class) = @_;
	return [
		{ id => "class", type => "class", value => $class },
		{ id => "device", type => "device", filterfunc => "FUIP::View::ReadingsGroup::getDevicesForValueHelp"  },
		{ id => "title", type => "text", default => { type => "field", value => "device"} },
		{ id => "zebra", type => "text", options => [ "on", "off" ], default => { type => "const", value => "on" } }, 
		{ id => "columns", type => "text", default => { type => "const", value => "1"}, options => ["1","2","3","4"] }, 
		{ id => "width", type => "dimension", value => 300},
		{ id => "height", type => "dimension", value => 100 },
		{ id => "sizing", type => "sizing", options => [ "resizable", "auto" ],
			default => { type => "const", value => "auto" } },
		{ id => "popup", type => "dialog", default=> { type => "const", value => "inactive"} }	
		];
};


our %docu = (
	general => "Die View <i>ReadingsGroup</i> zeigt eine in FHEM definierte readingsGroup an. Dabei wird im Wesentlichen das generierte HTML aus FHEMWEB &uuml;bernommen, wodurch die in FHEM definierten Formatierungen erhalten bleiben. Dennoch wird eine ReadingsGroup in FUIP immer etwas anders aussehen als in FHEMWEB. Meistens d&uuml;rfte es sinnvoll sein, in FHEM eine eigene ReadingsGroup f&uuml;r FUIP zu definieren und diese insbesondere mit den Attributen <i>style</i>, <i>cellStyle</i>, <i>nameStyle</i> und <i>valueStyle</i> entprechend zu gestalten.",
	device => "Hier wird die darzustellende readingsGroup eingetragen.",
	zebra => "Normalerweise wird die ReadingsGroup mit alternierenden Hintergrundfarben in den einzelnen Zeilen ausgegeben. Dabei wird zwischen der Farbe <i>background</i> und <i>background-intensified</i> abgewechselt. Dies kann man abschalten, indem <i>zebra</i> auf \"off\" gesetzt wird.",
	columns => "Mit dem Parameter <i>columns</i> kann man die ReadingsGroup mehrspaltig ausgeben, auch wenn das in FHEM nicht so festgelegt ist.",
);


# register me as selectable
$FUIP::View::selectableViews{"FUIP::View::ReadingsGroup"}{title} = "Readings Group"; 
	
1;	