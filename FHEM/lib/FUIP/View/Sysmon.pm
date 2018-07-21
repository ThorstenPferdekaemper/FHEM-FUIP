package FUIP::View::Sysmon;

use strict;
use warnings;
    use lib::FUIP::View;
	use parent -norequire, 'FUIP::View';
	
	
sub getHTML($){
	my ($self) = @_;
	my $dev = $self->{device};
	return '<table width="100%" class="fuip-color">
				<tr>
					<td><div data-type="label" class="left">Typ: </div></td>
					<td><div data-type="label" data-device="'.$dev.'" data-get="cpu_model_name" class="left inline"></div></td>
				</tr>
				<tr>
					<td><div data-type="label" class="left">Uptime: </div></td>
					<td><div data-type="label" data-device="'.$dev.'" data-get="uptime_text" class="left inline"></div></td>
				</tr>
				<tr>
					<td><div data-type="label" class="left">RAM: </div></td>
					<td><div data-type="label" data-device="'.$dev.'" data-get="ram" class="left inline"></div></td>
				</tr>
				<tr>
					<td><div data-type="label" class="left">CPU: </div></td>
					<td><div data-type="label" data-device="'.$dev.'" data-get="stat_cpu_text" class="left inline"></div></td>
				</tr>
				<tr>
					<td><div data-type="label" class="left">Root: </div></td>
					<td><div data-type="label" data-device="'.$dev.'" data-get="root" class="left inline"></div></td>
				</tr>
				<tr>
					<td><div data-type="label" class="left">CPU Temp: </div></td>
					<td><div data-type="label" data-device="'.$dev.'" data-get="cpu_temp" class="left inline"></div></td>
				</tr>
			</table>';	 
};

	
sub dimensions($;$$){
	# we ignore any settings
	return (650, 116);
};	

	
	
sub getStructure($) {
	# class method
	# returns general structure of the view without instance values
	my ($class) = @_;
	return [
		{ id => "class", type => "class", value => $class },
		{ id => "device", type => "device" },
		{ id => "title", type => "text", default => { type => "field", value => "device"} }	];
};


# register me as selectable
$FUIP::View::selectableViews{"FUIP::View::Sysmon"}{title} = "System Monitor"; 

1;	