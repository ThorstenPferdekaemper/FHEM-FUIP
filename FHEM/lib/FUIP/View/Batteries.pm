package FUIP::View::Batteries;

use strict;
use warnings;

use lib::FUIP::View;
use parent -norequire, 'FUIP::View';
use lib::FUIP::Model;
	

sub _getDevices($){
	my ($name) = @_;
	my %devices;
	for my $reading (qw(battery batteryLevel batVoltage Activity)) {
		for my $dev (@{FUIP::Model::getDevicesForReading($name,$reading)}) {
			$devices{$dev}{$reading} = 1;
		};	
	};
	return \%devices;
};	
	
	
sub getHTML($){
	my ($self) = @_;
	my $result = '<table width="100%"><tr><td> 
					<table>';
	my $devices = _getDevices($self->{fuip}{NAME});				
	my $numDevs = keys %$devices;				
	my $count = 0;
	use integer;
	for my $devKey (sort keys %$devices) {
		if($count == $numDevs/2) {
			$result .= '</table></td><td style="width:100%;"></td><td><table>';
		}  
		$count++;
		$result.= '<tr><td>
					<div data-type="label" class="left">'.$devKey.'</div>
					</td><td>';
		my $device = $devices->{$devKey};			
		if(exists($device->{batteryLevel})){
			$result .= '<div style="margin-top:-30px;margin-bottom:-30px;margin-right:-10px" data-type="symbol" 
							data-device="'.$devKey.'" data-get="batteryLevel"
							data-icons=\'["oa-measure_battery_0 fa-rotate-90","oa-measure_battery_25 fa-rotate-90","oa-measure_battery_50 fa-rotate-90","oa-measure_battery_75 fa-rotate-90","oa-measure_battery_100 fa-rotate-90"]\'
							data-get-on=\'["0","2.1","2.4","2.7","3.0"]\'
							data-on-colors=\'["red","yellow","green","green","green"]\'>
						</div>';
		}elsif(exists($device->{batVoltage})){
			$result .= '<div style="margin-top:-30px;margin-bottom:-30px;margin-right:-10px" data-type="symbol" 
							data-device="'.$devKey.'" data-get="batVoltage"
							data-icons=\'["oa-measure_battery_0 fa-rotate-90","oa-measure_battery_25 fa-rotate-90","oa-measure_battery_50 fa-rotate-90","oa-measure_battery_75 fa-rotate-90","oa-measure_battery_100 fa-rotate-90"]\'
							data-get-on=\'["0","2.1","2.4","2.7","3.0"]\'
							data-on-colors=\'["red","yellow","green","green","green"]\'></div>';
		} elsif(exists($device->{battery})){
			$result .= '<div style="margin-top:-30px;margin-bottom:-30px;margin-right:-10px" data-type="symbol" 
							data-device="'.$devKey.'" data-get="battery"
							data-icons=\'["oa-measure_battery_0 fa-rotate-90","oa-measure_battery_75 fa-rotate-90"]\'
							data-states=\'["((?!ok).)*","ok"]\'
							data-on-colors=\'["red","green"]\'></div>';
		};
		$result .= '</td><td>';
		if(exists($device->{batteryLevel})){
			$result .= '<div data-type="label" data-device="'.$devKey.'" data-get="batteryLevel" data-unit="V"></div>';
		};
		if(exists($device->{batVoltage})){
			$result .= '<div data-type="label" data-device="'.$devKey.'" data-get="batVoltage" data-unit="V"></div>';
		};
		$result .= '</td><td style=\"padding-left:20px\">'; 
		if(exists($device->{Activity})){
			$result .= '<div data-type="label" data-device="'.$devKey.'" 
							data-get="Activity" data-colors=\'["red","green"]\' data-limits=\'["dead","alive"]\'></div>';
		};
		$result .= '</td></tr>';  
	}
	$result .= '</table></td></tr></table>'; 
	return $result;	
};

	
sub dimensions($;$$){
	my $self = shift;
	# we ignore any settings
	my $devices = _getDevices($self->{fuip}{NAME});				
	use integer;
	my $numDevs = keys %$devices;
	return (650,19 * ($numDevs / 2 + $numDevs % 2) + 8);
};	
	
	
sub getStructure($) {
	# class method
	# returns general structure of the view without instance values
	my ($class) = @_;
	return [
		{ id => "class", type => "class", value => $class },
		{ id => "title", type => "text", default => { type => "const", value => "Batteries"} },
		];
};

	
	
1;	