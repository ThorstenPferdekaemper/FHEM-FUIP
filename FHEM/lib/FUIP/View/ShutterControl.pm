package FUIP::View::ShutterControl;

use strict;
use warnings;

use lib::FUIP::View;
use parent -norequire, 'FUIP::View';
	
	
sub getHTML($){
	my ($self) = @_;
	my $device = $self->{device};
	my @icons = (
				"oa-fts_shutter_100","oa-fts_shutter_90",
				"oa-fts_shutter_80","oa-fts_shutter_70","oa-fts_shutter_60","oa-fts_shutter_50",
				"oa-fts_shutter_40","oa-fts_shutter_30","oa-fts_shutter_20","oa-fts_shutter_10","oa-fts_window_2w");
	# determine levels
	use integer;
	my @levels;
	for (my $i=0; $i <= 10; $i++) {
		push(@levels,$self->{minLevel} + ($self->{maxLevel} - $self->{minLevel}) * $i / 10);
	};
	my @iconLevels = @levels;
	# for "reverse" shutters, we need to reverse the icon list
	if($self->{minLevel} > $self->{maxLevel}) {
		@icons = reverse(@icons);
		@iconLevels = reverse(@iconLevels);
	};
	my $result = '
		<div style="position:relative;">
		<table>	
			<tr>
				<td>
					<div data-type="symbol" class="cell bigger left" data-device="'.$device.'" data-get="'.$self->{readingLevel}.'"
                    data-icons=\'["'.join('","',@icons).'"]\'
					data-states=\'["'.join('","',@iconLevels).'"]\'
					data-background-colors=\'['.('"fuip-color-symbol-active",' x 10).'"fuip-color-symbol-active"]\' 
					data-colors=\'['.('"fuip-color-symbol-foreground",' x 10).'"fuip-color-symbol-foreground"]\' 
					data-background-icons=\'["fa-square","fa-square","fa-square","fa-square","fa-square","fa-square","fa-square","fa-square","fa-square","fa-square","fa-square"]\'>
					</div>';
	if($self->{label}) {
		$result .= '<div class="fuip-color" style="position:absolute; top:122px;left:0px;width:126px;text-align:center">'
						.$self->{label}
					.'</div>';
	};	
	$result .= '</td>
				<td width="60">  
					<div class="triplebox-v left" >
						<div data-type="push" data-device="'.$device.'" data-icon="fa-chevron-up" 
							data-background-icon="fa-square-o" 	data-set-on="'.$self->{setUp}.'" class=""> 
						</div>
						<div data-type="push" data-device="'.$device.'" data-icon="fa-minus" 
							data-background-icon="fa-square-o" data-set-on="'.$self->{setStop}.'" class=""> 
						</div>
						<div data-type="push" data-device="'.$device.'" data-icon="fa-chevron-down" 
							data-background-icon="fa-square-o" data-set-on="'.$self->{setDown}.'" class=""> 
						</div>
					</div> 
				</td>
				<td>
					<div data-type="select" data-device="'.$device.'" 
						data-items=\'["'.join('","',reverse(@levels)).'"]\' 
						data-alias=\'["Auf","90%","80%","70%","60%","50%","40%","30%","20%","10%","Zu"]\' 
						data-get="'.$self->{readingLevel}.'" data-set="'.$self->{setLevel}.'"
						style="width:65px">
					</div>
				</td>
			</tr>';
	$result .= '</table>';
	if($self->{timer}) {
		$result .= '
		<div style="position:absolute; top:92px; left:210px;"
			data-type="fuip_wdtimer" 
			data-device="'.$self->{timer}.'"    
			data-width="450"
			data-style="round noicons" 
			data-theme="dark" 
			data-title="'.$device.'"  
			data-sortcmdlist="MANUELL"
			data-cmdlist=\'{"Auf":"'.$levels[10].'"'; 		
	for (my $i=9; $i >= 1; $i--) {
		$result .= ',"'.($i*10).'%":"'.$levels[$i].'"';
	};
	$result .= ',"Zu":"'.$levels[0].'"';
	$result .= '}\'>
			<div data-type="button" class="cell small readonly" data-icon="oa-edit_settings" data-background-icon="fa-square-o" 
					data-on-color="#505050" data-on-background-color="#505050">
			</div>
		</div>';
	};
	$result .= '</div>';
	return $result;
};


sub dimensions($;$$){
	return (260,148);
};	

	
sub getStructure($) {
	# class method
	# returns general structure of the view without instance values
	my ($class) = @_;
	return [
		{ id => "class", type => "class", value => $class },
		{ id => "device", type => "device" },
		{ id => "title", type => "text", default => { type => "field", value => "device"} },
		{ id => "label", type => "text" },		
		{ id => "setUp", type => "set", refdevice => "device", default => { type => "const", value => "up" } },
		{ id => "setStop", type => "set", refdevice => "device", default => { type => "const", value => "stop" } },
		{ id => "setDown", type => "set", refdevice => "device", default => { type => "const", value => "down" } },
		{ id => "setLevel", type => "set", refdevice => "device", default => { type => "const", value => "level" } },
		{ id => "readingLevel", type => "reading", refdevice => "device", default => { type => "field", value => "setLevel"}},
		{ id => "minLevel", type => "text", default => { type => "const", value => "0" } },
		{ id => "maxLevel", type => "text", default => { type => "const", value => "100" } },
		{ id => "timer", type => "device", default => { type => "field", value => "device", suffix => "Timer" } }
		];
};

# register me as selectable
$FUIP::View::selectableViews{"FUIP::View::ShutterControl"}{title} = "Shutter (detail)"; 
	
1;	