package FUIP::View::ThermostatFuip;

use strict;
use warnings;

use lib::FUIP::View;
use parent -norequire, 'FUIP::View';


sub getDependencies($$) {
	return ['js/fuip_5_resize.js'];
};

sub getStructure($) {
	# class method
	# returns general structure of the view without instance values
	my ($class) = @_;
	return [
		{ id => "class", type => "class", value => $class },
		{ id => "device", type => "device" },
		{ id => "title", type => "text", default => { type => "field", value => "device"} },
		{ id => "label", type => "text", default => { type => "field", value => "device"} },
		{ id => "desiredTemp", type => "device-reading", 
			device => { default => { type => "field", value => "device"} },			
			reading => { default => { type => "const", value => "desired-temp" } } },
		{ id => "desiredSet", type => "set", refdevice => "device", default => { type => "field", value => "desiredTemp-reading" } },
		{ id => "measuredTemp", type => "device-reading", 
			device => { default => { type => "field", value => "device"} },			
			reading => { default => { type => "const", value => "measured-temp" } } },
		{ id => "humidity", type => "device-reading",
			device => { default => { type => "field", value => "device"} },			
			reading => { default => { type => "const", value => "humidity" } } },
		{ id => "minTemp", type => "text", default => { type => "const", value => "10" } },
		{ id => "maxTemp", type => "text", default => { type => "const", value => "30" } },
		{ id => "step", type => "text", default => { type => "const", value => "0.5" } },		
		{ id => "valvePos1", type => "device-reading",  
			device => { default => { type => "field", value => "device"} },
			reading => { default => { type => "const", value => "ValvePosition"} } },
		{ id => "valvePos2", type => "device-reading",  
			device => { default => { type => "const", value => ""} },
			reading => { default => { type => "const", value => "ValvePosition"} } },
		{ id => "valvePos3", type => "device-reading",  
			device => { default => { type => "const", value => ""} },
			reading => { default => { type => "const", value => "ValvePosition"} } },
		{ id => "readonly", type => "text", options => [ "on", "off" ], 
			default => { type => "const", value => "off" } },
		{ id => "width", type => "dimension" },
		{ id => "height", type => "dimension" },	
		{ id => "sizing", type => "sizing", options => [ "fixed", "auto", "resizable" ],
			default => { type => "const", value => "fixed" } },	
		{ id => "popup", type => "dialog", default=> { type => "const", value => "inactive"} }			
		];
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
		$self->{height} = 150;  # TODO: Maybe dependent on label
	};
	if(not $self->{width} or $self->{sizing} eq "fixed") {
		$self->{width} = 300;
	};	
	return ("auto","auto") if($self->{sizing} eq "auto");
	return ($self->{width},$self->{height});
};	


sub _getHTML_getValve($$) {
	my ($self,$reading) = @_;
	
	#Is there a valve reading defined?
	return "" unless $self->{$reading}{device} and $self->{$reading}{reading};
	#Does the device have this reading?
  	my $device = FUIP::Model::getDevice($self->{fuip}{NAME},$self->{$reading}{device},
	                                    [$self->{$reading}{reading}],$self->getSystem());
	return "" unless $device && exists $device->{Readings}{$self->{$reading}{reading}};
	#Create string for valve reading
	return '"'.$self->{$reading}{device}.':'.$self->{$reading}{reading}.'"'; 	
};


sub _getHTML_getHumidity($) {
	my ($self) = @_;
	
	#Is there a humidity reading defined?
	return "" unless $self->{humidity} and $self->{humidity}{device} and $self->{humidity}{reading};
	#Does the device have this reading?
  	my $device = FUIP::Model::getDevice($self->{fuip}{NAME},$self->{humidity}{device},
	                                    [$self->{humidity}{reading}],$self->getSystem());
	return "" unless $device && exists $device->{Readings}{$self->{humidity}{reading}};
	#Create string for valve reading
	return 'data-humidity="'.$self->{humidity}{device}.':'.$self->{humidity}{reading}.'" ';; 	
};



sub getHTML($){
	my ($self) = @_;
	
	# older versions...
	if(ref($self->{desiredTemp}) ne 'HASH') {
		$self->{desiredTemp} = { device => $self->{device}, reading => $self->{desiredTemp} };
	};
	if(ref($self->{measuredTemp}) ne 'HASH') {
		$self->{measuredTemp} = { device => $self->{device}, reading => $self->{measuredTemp} };
	};
	if(ref($self->{humidity}) ne 'HASH') {
		$self->{humidity} = { device => $self->{device}, reading => $self->{humidity} };
	};
	
	my $result = '';
	$result .= '<div';
	$result .= '
		data-type="fuip_thermostat" 
		data-fuip-type="fuip-thermostat"
		data-device="'.$self->{device}.'" 
		data-label="'.$self->{label}.'"
		data-desired-temp="'.$self->{desiredTemp}{device}.':'.$self->{desiredTemp}{reading}.'" 
		data-set="'.$self->{desiredSet}.'" 
		data-measured-temp="'.$self->{measuredTemp}{device}.':'.$self->{measuredTemp}{reading}.'" 
		data-min="'.$self->{minTemp}.'" 
		data-max="'.$self->{maxTemp}.'" 	
		data-step="'.$self->{step}.'" ';
	$result .= _getHTML_getHumidity($self);
	my $valves = _getHTML_getValve($self, 'valvePos1');
	my $valve = _getHTML_getValve($self, 'valvePos2');
	$valves .= ',' if $valves && $valve;
	$valves .= $valve if $valve;
	$valve = _getHTML_getValve($self, 'valvePos3');
	$valves .= ',' if $valves && $valve;
	$valves .= $valve if $valve;
	$result .= "data-valve='[$valves]' " if $valves;
	$result .= 'data-unit="°C" ';
	if($self->{readonly} eq "on") {
		$result .= ' class="lock" '
	};	
	$result .= '></div>';
	
	return $result;		
};


our %docu = (
	general => "Die View <i>ThermostatFuip</i> repr&auml;sentiert einen Heizungs- oder Wandthermostat. Sie zeigt die Soll- und die Ist-Temperatur an, wobei die Solltemperatur auch ge&auml;ndert werden kann. Zus&auml;tzlich kann die Luftfeuchtigkeit sowie die Ventilstellung von bis zu drei angeschlossenen (\"gepeerten\") Stellantrieben (Heizk&ouml;rperthermostaten) angezeigt werden.<br>
	Normalerweise wird die Ist-Temperatur in der Mitte gro&szlig; angezeigt. Wenn man auf die Mitte oder auf das \"-\" bzw. \"+\" klickt, dann wird stattdessen f&uuml;r ein paar Sekunden die Solltemperatur angezeigt.",
	device => "Dies ist das Haupt-Device der Thermostat-Kombination. Das ist immer das Device, &uuml;ber das man die Solltemperatur einstellt. D.h. bei Kombinationen von Wand- und Heizk&ouml;rperthermostat ist das in der Regel der Wandthermostat. Wenn es nur um einen einzelnen Heizk&ouml;rperthermostat geht, dann ist es dieser.",
	label => "Dies ist ein Text, der innerhalb der Thermostat-Grafik angezeigt wird. Man kann ihn auch weglassen.",
	desiredTemp => "Hier wird das Reading angegeben, welches die Solltemperatur enth&auml;lt. Normalerweise ist das ein Reading des Haupt-Devices (im Parameter <i>device</i> angegeben). Es kann aber auch davon abweichen.",
	desiredSet => "Hier wird die Set-Option angegeben, mit der die Solltemperatur im Haupt-Device gesetzt wird. Normalerweise ist das dasselbe wie <i>desiredTemp</i>, es kann aber auch abweichen.",
	measuredTemp => "Hier wird das Reading angegeben, welches die Ist-Temperatur enth&auml;lt. Normalerweise ist das ein Reading des Haupt-Devices (im Parameter <i>device</i>). Es kann aber auch davon abweichen.",
	humidity => "Hier wird das Reading angegeben, welches die Luftfeuchtigkeit enth&auml;lt. Normalerweise ist das ein Reading des Haupt-Devices (im Parameter <i>device</i>). Es kann aber auch davon abweichen.",
	minTemp => "Dies ist die minimale darstellbare/einstellbare Temperatur.",
	maxTemp => "Dies ist die maximale darstellbare/einstellbare Temperatur.",
	step => "Hier wird die Schrittweite der Temperatureinstellung und -anzeige angegeben. Zusammen mit <i>minTemp</i> und <i>maxTemp</i> legt das fest, welche Temperaturen eingestellt werden k&ouml;nnen und wie genau die Temperaturen angezeigt werden. Man kann hier auch \"Kommazahlen\" eingeben (Voreinstellung ist 0.5). Dabei muss man darauf achten, dass als Dezimaltrennzeichen der Punkt und nicht das Komma benutzt wird.",
	valvePos1 => "Die <i>valvePos</i>-Parameter sind Device/Reading-Kombinationen, aus denen der jeweilige Ventilstellungsgrad gelesen wird.",
	valvePos2 => "Die <i>valvePos</i>-Parameter sind Device/Reading-Kombinationen, aus denen der jeweilige Ventilstellungsgrad gelesen wird.",
	valvePos3 => "Die <i>valvePos</i>-Parameter sind Device/Reading-Kombinationen, aus denen der jeweilige Ventilstellungsgrad gelesen wird.",
	readonly => "Hiermit kann man das &Auml;ndern der Solltemperatur deaktivieren. D.h. die View zeigt dann die Daten nur noch an. Das ist vor Allem dann interessant, wenn man das eigentliche Bedienelement mit weiteren Details auf ein Popup auslagert."
);


# register me as selectable
$FUIP::View::selectableViews{"FUIP::View::ThermostatFuip"}{title} = "Thermostat (Fuip Version)"; 

1;	