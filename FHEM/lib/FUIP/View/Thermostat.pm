package FUIP::View::Thermostat;

use strict;
use warnings;

use lib::FUIP::View;
use parent -norequire, 'FUIP::View';


sub getStructure($) {
	# class method
	# returns general structure of the view without instance values
	# thermostat   : device
	# measuredTemp : device-reading
	# humidity     : device-reading
	# valvePos     : device-reading
	my ($class) = @_;
	return [
		{ id => "class", type => "class", value => $class },
		{ id => "device", type => "device" },
		{ id => "title", type => "text", default => { type => "field", value => "device"} },
		{ id => "label", type => "text", default => { type => "field", value => "device"} },
		{ id => "desiredTemp", type => "reading", refdevice => "device", default => { type => "const", value => "desired-temp" } },
		{ id => "desiredSet", type => "set", refdevice => "device", default => { type => "field", value => "desiredTemp" } },
		{ id => "measuredTemp", type => "reading", refdevice => "device", default => { type => "const", value => "measured-temp" } },
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
		{ id => "size", type => "text", options => [ "normal", "big" ], 
			default => { type => "const", value => "normal" } }, 	
		{ id => "readonly", type => "text", options => [ "on", "off" ], 
			default => { type => "const", value => "off" } },
		{ id => "popup", type => "dialog", default=> { type => "const", value => "inactive"} }			
		];
};


sub dimensions($;$$){
	my $self = shift;
	if($self->{size} eq "big") {
		return (210, 199) if($self->{label});
		return (210, 165);
	};
	return (100,102)  if($self->{label});
	return (100, 80);	
};	


sub getHTML($){
	my ($self) = @_;
	# set defaults for "new" parameters
	$self->{minTemp} = "10" unless defined $self->{minTemp};
	$self->{maxTemp} = "30" unless defined $self->{maxTemp};
	$self->{step} = "0.5" unless defined $self->{step};
	my $result = '';
	$result .= '<div';
	$result .= '
		data-type="thermostat" 
		data-device="'.$self->{device}.'" 
		data-get="'.$self->{desiredTemp}.'" 
		data-set="'.$self->{desiredSet}.'" 
		data-temp="'.$self->{measuredTemp}.'" 
		data-min="'.$self->{minTemp}.'" 
		data-max="'.$self->{maxTemp}.'" 	
		data-step="'.$self->{step}.'" ';
	if($self->{size} eq "normal") {
		$result .= 'data-width="100" data-height="80"';
	}else{	
		$result .= 'data-width="210" data-height="165"';
	};
	$result .= ' class="left';
			# without the "left" above, the desired temp appears somewhere, but not within the widget
	if($self->{readonly} eq "on") {
		$result .= ' readonly';	
	};
	$result .= '">
			</div>
			<table style="';
	if($self->{size} eq "normal") {
		$result .= 'width:70px;position:absolute;top:67px;left:15px';
	}else{
		$result .= 'width:120px;position:absolute;top:140px;left:45px';
	};	
	$result .= '">
				<tr>';
	for my $fName (qw(valvePos1 valvePos2 valvePos3)) { 			
		next unless($self->{$fName}{device});
		$result .= '<td>
					<div style="color:#666;"
						data-type="label"
						data-device="'.$self->{$fName}{device}.'" 
						data-get="'.$self->{$fName}{reading}.'"
						data-unit="%"
						class="';
		if($self->{size} eq "normal") {
			$result .= 'small';
		}else{
			$result .= $self->{size};
		};
		$result .= '">
					</div> 
				</td>'; 
	};
	$result .= "</tr>
		</table>";
	if($self->{label}){
		$result .= '<div class="fuip-color';
		if($self->{size} ne "normal") {
			$result .= ' '.$self->{size};
		};	
		$result .= '">'.$self->{label}.'</div>';
	};
	return $result;		
};


our %docu = (
	general => "Die View <i>Thermostat</i> kann einen (Wand-)Thermostat mit Soll- und Ist-Temperatur sowie bis zu drei angeschlossene (\"gepeerte\") Stellantriebe (Heizk&ouml;rperthermostate) darstellen. Au&szlig;erdem kann man die Solltemperatur einstellen. Man kann auch einfach nur einen Heizk&ouml;rperthermostat darstellen und steuern.",
	device => "Dies ist das Haupt-Device der Thermostat-Kombination. Das ist immer das Device, welches die Soll- und Ist-Temperatur \"enth&auml;lt\". D.h. bei Kombinationen von Wand- und Heizk&ouml;rperthermostat ist das in der Regel der Wandthermostat. Wenn es nur um einen einzelnen Heizk&ouml;rperthermostat geht, dann ist es dieser.",
	label => "Dies ist ein Text, der unter der Thermostat-Grafik angezeigt wird. Man kann ihn auch weglassen.",
	desiredTemp => "Hier wird das Reading des Haupt-Device (im Parameter <i>device</i> angegeben, welches die Solltemperatur enth&auml;lt.",
	desiredSet => "Hier wird die Set-Option angegeben, mit der die Solltemperatur im Haupt-Device gesetzt wird. Normalerweise ist das dasselbe wie <i>desiredTemp</i>, es kann aber auch abweichen.",
	measuredTemp => "Hier wird das Reading des Haupt-Device (im Parameter <i>device</i> angegeben, welches die Ist-Temperatur enth&auml;lt.",
	minTemp => "Dies ist die minimale darstellbare/einstellbare Temperatur.",
	maxTemp => "Dies ist die maximale darstellbare/einstellbare Temperatur.",
	step => "Hier wird die Schrittweite der Temperatureinstellung und -anzeige angegeben. Zusammen mit <i>minTemp</i> und <i>maxTemp</i> legt das fest, welche Temperaturen eingestellt werden k&ouml;nnen und wie genau die Temperaturen angezeigt werden. Man kann hier auch \"Kommazahlen\" eingeben (Default ist 0.5). Dabei muss man darauf achten, dass als Dezimaltrennzeichen der Punkt und nicht das Komma benutzt wird.",
	valvePos1 => "Die <i>valvePos</i>-Parameter sind Device/Reading-Kombinationen, aus denen der jeweilige Ventilstellungsgrad gelesen wird.",
	valvePos2 => "Die <i>valvePos</i>-Parameter sind Device/Reading-Kombinationen, aus denen der jeweilige Ventilstellungsgrad gelesen wird.",
	valvePos3 => "Die <i>valvePos</i>-Parameter sind Device/Reading-Kombinationen, aus denen der jeweilige Ventilstellungsgrad gelesen wird.",
	size => "Die View <i>Thermostat</i> unterst&uuml;tzt die bei FUIP &uuml;blichen Sizing-Mechanismen nicht. Statt dessen gibt es zwei w&auml;hlbare Gr&ouml;&szlig;en \"normal\" und \"big\". Ersteres ist vor Allem f&uuml;r &Uuml;bersichtsseiten geeignet w&auml;hrend letzteres angenehmer zu bedienen ist.",
	readonly => "Hiermit kann man das Setzen der Solltemperatur deaktivieren. D.h. die View zeigt dann die Daten nur noch an. Das ist vor Allem dann interessant, wenn man das eigentliche Bedienelement mit weiteren Details auf ein Popup auslagert."
);


# register me as selectable
$FUIP::View::selectableViews{"FUIP::View::Thermostat"}{title} = "Thermostat"; 

1;	