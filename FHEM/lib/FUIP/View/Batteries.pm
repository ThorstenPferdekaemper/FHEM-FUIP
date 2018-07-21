package FUIP::View::Batteries;

use strict;
use warnings;

use lib::FUIP::View;
use parent -norequire, 'FUIP::View';
use lib::FUIP::Model;
	

sub _getDevices($$){
	my ($name,$deviceFilter) = @_;
	my %devices;
	my @readings = qw(battery batteryLevel batVoltage);
	push(@readings,"Activity") if($deviceFilter eq "all");
	for my $reading (@readings) {
		for my $dev (@{FUIP::Model::getDevicesForReading($name,$reading)}) {
			$devices{$dev}{$reading} = 1;
		};	
	};
	# only devices with battery, but we want the Activity reading nevertheless, if it exists
	if($deviceFilter ne "all") {
		for my $dev (keys(%devices)) {
			my $device = FUIP::Model::getDevice($name,$dev,["Activity"]);
			if(exists($device->{Readings}{Activity})) {
				$devices{$dev}{Activity} = 1;
			};
		};
	};
	return \%devices;
};	
	
	
sub getHTML($){
	my ($self) = @_;
	my $result = '<table width="100%"><tr><td> 
					<table>';
	my $devices = _getDevices($self->{fuip}{NAME},$self->{deviceFilter});				
	my $numDevs = keys %$devices;				
	my $count = 0;
	use integer;
	for my $devKey (sort keys %$devices) {
		if($count == $numDevs/2) {
			$result .= '</table></td><td style="width:100%;"></td><td><table>';
		}  
		$count++;
		$result.= '<tr><td>
					<div data-type="label" class="left fuip-color">'.$devKey.'</div>
					</td><td>';
		my $device = $devices->{$devKey};			
		if(exists($device->{batteryLevel})){
			$result .= '<div style="margin-top:-26px;margin-bottom:-30px;margin-right:-10px" data-type="symbol" 
							data-device="'.$devKey.'" data-get="batteryLevel"
							data-icons=\'["oa-measure_battery_0 fa-rotate-90","oa-measure_battery_25 fa-rotate-90","oa-measure_battery_50 fa-rotate-90","oa-measure_battery_75 fa-rotate-90","oa-measure_battery_100 fa-rotate-90"]\'
							data-states=\'["0","2.1","2.4","2.7","3.0"]\'
							data-colors=\'["red","yellow","green","green","green"]\'>
						</div>';
		}elsif(exists($device->{batVoltage})){
			$result .= '<div style="margin-top:-26px;margin-bottom:-30px;margin-right:-10px" data-type="symbol" 
							data-device="'.$devKey.'" data-get="batVoltage"
							data-icons=\'["oa-measure_battery_0 fa-rotate-90","oa-measure_battery_25 fa-rotate-90","oa-measure_battery_50 fa-rotate-90","oa-measure_battery_75 fa-rotate-90","oa-measure_battery_100 fa-rotate-90"]\'
							data-states=\'["0","2.1","2.4","2.7","3.0"]\'
							data-colors=\'["red","yellow","green","green","green"]\'></div>';
		} elsif(exists($device->{battery})){
			$result .= '<div style="margin-top:-26px;margin-bottom:-30px;margin-right:-10px" data-type="symbol" 
							data-device="'.$devKey.'" data-get="battery"
							data-icons=\'["oa-measure_battery_0 fa-rotate-90","oa-measure_battery_75 fa-rotate-90"]\'
							data-states=\'["((?!ok).)*","ok"]\'
							data-colors=\'["red","green"]\'></div>';
		};
		$result .= '</td><td>';
		if(exists($device->{batteryLevel})){
			$result .= '<div data-type="label" data-device="'.$devKey.'" data-get="batteryLevel" data-unit="V" class="fuip-color"></div>';
		};
		if(exists($device->{batVoltage})){
			$result .= '<div data-type="label" data-device="'.$devKey.'" data-get="batVoltage" data-unit="V" class="fuip-color"></div>';
		};
		$result .= '</td><td style=\"padding-left:20px\">'; 
		if(exists($device->{Activity})){
			$result .= '<div data-type="label" data-device="'.$devKey.'" 
							data-get="Activity" data-colors=\'["red","green","yellow"]\' data-limits=\'["dead","alive","unknown"]\'></div>';
		};
		$result .= '</td></tr>';  
	}
	$result .= '</table></td></tr></table>'; 
	return $result;	
};

	
sub dimensions($;$$){
	my $self = shift;
	# we ignore any settings
	my $devices = _getDevices($self->{fuip}{NAME},$self->{deviceFilter});
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
		{ id => "deviceFilter", type => "text", options => [ "all", "battery"], 
			default => { type => "const", value => "all" } }, 
		];
};


# register me as selectable
$FUIP::View::selectableViews{"FUIP::View::Batteries"}{title} = "Batteries"; 
	
1;	