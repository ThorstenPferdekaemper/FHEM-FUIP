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
		$result .= '"
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


# register me as selectable
$FUIP::View::selectableViews{"FUIP::View::Thermostat"}{title} = "Thermostat"; 

1;	