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
			default => { type => "const", value => "off" } }	
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
	my $result = '';
	my $thermostatPos = 0;
	if($self->{label}){
		$result = '<div class="fuip-color';
		$thermostatPos = 22;
		if($self->{size} ne "normal") {
			$result .= ' '.$self->{size};
			$thermostatPos = 34;
		};	
		$result .= '">'.$self->{label}.'</div>';
	};
	$result .= '<div';
    if($thermostatPos) {
		$result .= ' style="position:absolute;top:'.$thermostatPos.'px;"'; 
	};
	$result .= ' data-type="thermostat" data-device="'.$self->{device}.'" data-get="'.$self->{desiredTemp}.'" data-set="'.$self->{desiredSet}.'" data-temp="'.$self->{measuredTemp}.'" data-step="0.5" ';
	if($self->{size} eq "normal") {
		$result .= 'data-width="100" data-height="80"';
	}else{	
		$result .= 'data-width="210" data-height="165"';
	};
	$result .= ' class="left';
			# without the "left" above, the desired temp appears somewhere, but not within the widget
	if($self->{size} ne "normal") {
		#$result .= ' '.$self->{size};
	};	
	if($self->{readonly} eq "on") {
		$result .= ' readonly';	
	};
	$result .= '">
			</div>
			<table style="';
	if($self->{size} eq "normal") {
		$result .= 'width:70px;position:absolute;top:'.($thermostatPos + 67).'px;left:15px';
	}else{
		$result .= 'width:120px;position:absolute;top:'.($thermostatPos + 140).'px;left:45px';
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
		$result .= '"
					</div> 
				</td>'; 
	};
	$result .= "</tr>
		</table>";
	return $result;		
};


# register me as selectable
$FUIP::View::selectableViews{"FUIP::View::Thermostat"}{title} = "Thermostat"; 

1;	