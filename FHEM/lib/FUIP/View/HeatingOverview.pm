package FUIP::View::HeatingOverview;

# deprecated
# use FUIP::View::Thermostat instead 

use strict;
use warnings;

    use lib::FUIP::View;
	use parent -norequire, 'FUIP::View';
	
	
	sub getHTML($){
		my ($self) = @_;
		my $device = $self->{device};
		my $result = "";
		my $thermpos = 0;
		my $valvepos = 77;
		my $humpos = 95;
		if($self->{measuredTemp}{device}) {
			$result .= "<div data-type=\"label\" 
					 data-device=\"".$self->{measuredTemp}{device}."\" 
					 data-get=\"".$self->{measuredTemp}{reading}."\"
					 data-unit=\" %B0C%0A\"
					 data-limits=\"[-99,12,19,23,28]\"
					 data-colors='[\"#ffffff\",\"#6699ff\",\"#AA6900\",\"#AD3333\",\"#FF0000\"]'
					 class=\"big\">
				</div>";
			$thermpos = 23;
			$valvepos = 100;
			$humpos = 118;
		};		
		$result .= "<div data-type=\"thermostat\" data-device=\"".$device."\" data-valve=\"";
		if(not $self->{valvePos2}{device} and not $self->{valvePos3}{device} and $self->{valvePos1}{device} eq $device) {
			$result .= $self->{valvePos1}{reading};
		}else{
			$result .= "dumdumdummy";
		};	
		$result .= "\" data-step=\"0.5\"
					class=\"cell readonly\" style='position:absolute;top:".$thermpos."px;'>
				</div>";
		if($self->{valvePos2}{device} or $self->{valvePos3}{device} or $self->{valvePos1}{device} and not $self->{valvePos1}{device} eq $device) {
			$result .= "<table style=\"width:70px;position:absolute;top:".$valvepos."px;left:25px\">
					<tr>";
			if($self->{valvePos1}{device}) {
				$result .= "<td>
							<div data-type=\"label\" 
								 data-device=\"".$self->{valvePos1}{device}."\" 
								 data-get=\"".$self->{valvePos1}{reading}."\"
								 data-unit=\"%\"
								 class=\"small\">
							</div> 
						</td>"; 
			};	
			if($self->{valvePos2}{device}) {
				$result .= "<td>
							<div data-type=\"label\" 
								 data-device=\"".$self->{valvePos2}{device}."\" 
								 data-get=\"".$self->{valvePos2}{reading}."\"
								 data-unit=\"%\"
								 class=\"small\">
							</div> 
						</td>";
			};
			if($self->{valvePos3}{device}) {
				$result .= "<td>
							<div data-type=\"label\" 
								 data-device=\"".$self->{valvePos3}{device}."\" 
								 data-get=\"".$self->{valvePos3}{reading}."\"
								 data-unit=\"%\"
								 class=\"small\">
							</div> 
						</td>";
			};
			$result .= "</tr>
				</table>";
		};		
		if($self->{humidity}{device}) {
			$result .= "<div style=\"position:absolute; top:".$humpos."px; left:50px;\">		
					<div data-type=\"label\" 
						 data-device=\"".$self->{humidity}{device}."\" 
						 data-get=\"".$self->{humidity}{reading}."\"
						 data-unit=\" %\"
						 data-limits=\"[-1,20,39,59,65,79]\"
						 data-colors='[\"#ffffff\",\"#6699ff\",\"#AA6900\",\"FFCC80\",\"#AD3333\",\"#FF0000\"]'
						 class=\"big\">
					</div>
				</div>";
		};		
		return $result;	
	};

	
	sub dimensions($;$$){
		my $self = shift;
		# we ignore any settings
		my $height = 94;
		$height += 23 if($self->{humidity}{device});
		$height += 23 if($self->{measuredTemp}{device});
		return (120, $height);
	};	
	
	
	sub getStructure($) {
	# class method
	# returns general structure of the view without instance values
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
			reading => { default => { type => "const", value => "ValvePosition"} } }
		];
};

1;	