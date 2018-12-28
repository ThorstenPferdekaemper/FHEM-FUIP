package FUIP::View::HeatingControl;

# deprecated
# use FUIP::View::Thermostat instead 

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
		{ id => "measuredTemp", type => "device-reading", 
			device => { default => { type => "field", value => "device"} },
			reading => { default => { type => "const", value => "measured-temp" } } },	
		{ id => "humidity", type => "device-reading",
			device => { default => { type => "const", value => ""} },
			reading => { default => { type => "const", value => "humidity"} } },
		{ id => "valvePos1", type => "device-reading",  
			device => { default => { type => "field", value => "device"} },
			reading => { default => { type => "const", value => "ValvePosition"} } },
		{ id => "valvePos2", type => "device-reading",  
			device => { default => { type => "const", value => ""} },
			reading => { default => { type => "const", value => "ValvePosition"} } },
		{ id => "valvePos3", type => "device-reading",  
			device => { default => { type => "const", value => ""} },
			reading => { default => { type => "const", value => "ValvePosition"} } },
		{ id => "width", type => "internal", value => 423 },
		{ id => "height", type => "internal", value => 204 }
		];
};


	sub getHTML($){
		my ($self) = @_;
		my $result = '
			<div>
				<div data-type="thermostat" data-device="'.$self->{device}.'" data-valve="dumdumdummy" data-step="0.5"
					class="cell left big">
				</div>
				<table>
					<tr>
						<td class="big">Temperatur:</td>
						<td>
							<div data-type="label" 
								data-device="'.$self->{measuredTemp}{device}.'" 
								data-get="'.$self->{measuredTemp}{reading}.'"
								data-unit=" %B0C%0A"
								data-limits="[-99,12,19,23,28]"
								data-colors=\'["#ffffff","#6699ff","#AA6900","#AD3333","#FF0000"]\'
								class="cell big narrow">
							</div>
						</td>
					</tr>'.
					($self->{humidity}{device} and $self->{humidity}{reading} ?	
					'<tr>
						<td class="big">Feuchtigkeit:</td>
						<td>
							<div data-type="label" 
								data-device="'.$self->{humidity}{device}.'" 
								data-get="'.$self->{humidity}{reading}.'"
								data-unit=" %"
								data-limits="[-1,20,39,59,65,79]"
								data-colors=\'["#ffffff","#6699ff","#AA6900","FFCC80","#AD3333","#FF0000"]\'
								class="cell big narrow">
							</div>
						</td>
					</tr>' : '').
				'</table>	
			</div>';	
	$result .= "<table style=\"width:120px;position:absolute;top:150px;left:55px\">
				<tr>";
	if($self->{valvePos1}{device}) {
		$result .= "<td>
					<div data-type=\"label\" 
						 data-device=\"".$self->{valvePos1}{device}."\" 
						 data-get=\"".$self->{valvePos1}{reading}."\"
						 data-unit=\"%\"
						 class=\"big\"
					</div> 
				</td>"; 
	};	
	if($self->{valvePos2}{device}) {
		$result .= "<td>
					<div data-type=\"label\" 
						 data-device=\"".$self->{valvePos2}{device}."\" 
						 data-get=\"".$self->{valvePos2}{reading}."\"
						 data-unit=\"%\"
						 class=\"big\"
					</div> 
					</td>";
	};
	if($self->{valvePos3}{device}) {
		$result .= "<td>
					<div data-type=\"label\" 
						 data-device=\"".$self->{valvePos3}{device}."\" 
						 data-get=\"".$self->{valvePos3}{reading}."\"
						 data-unit=\"%\"
						 class=\"big\"
					</div> 
					</td>";
	};
	$result .= "</tr>
		</table>";
	return $result;		
};

1;	