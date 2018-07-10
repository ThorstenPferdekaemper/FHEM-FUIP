package FUIP::View::ShutterControl;

use strict;
use warnings;

use lib::FUIP::View;
use parent -norequire, 'FUIP::View';
	
	
	sub getHTML($){
		my ($self) = @_;
		my $device = $self->{device};
		my $result = '
			<div style="position:relative";>
			<table>	
				<tr>
					<td>
						<div data-type="symbol" class="cell bigger left" data-device="'.$device.'" data-get="level"
							data-icons=\'["oa-fts_shutter_100","oa-fts_shutter_90",
										"oa-fts_shutter_80","oa-fts_shutter_70","oa-fts_shutter_60","oa-fts_shutter_50",
										"oa-fts_shutter_40","oa-fts_shutter_30","oa-fts_shutter_20","oa-fts_shutter_10","oa-fts_window_2w"]\'
					data-states=\'["0","10","20","30","40","50","60","70","80","90","100"]\' 
					data-colors=\'["#2A2A2A","#2A2A2A","#2A2A2A","#2A2A2A","#2A2A2A","#2A2A2A","#2A2A2A","#2A2A2A","#2A2A2A","#2A2A2A","#2A2A2A"]\' 
					data-background-colors=\'["#aa6900","#aa6900","#aa6900","#aa6900","#aa6900","#aa6900","#aa6900","#aa6900","#aa6900","#aa6900","#aa6900"]\' 
					data-background-icons=\'["fa-square","fa-square","fa-square","fa-square","fa-square","fa-square","fa-square","fa-square","fa-square","fa-square","fa-square"]\'>
						</div>
					</td>
					<td width="60">  
						<div class="triplebox-v left" >
							<div data-type="push" data-device="'.$device.'" data-icon="fa-chevron-up" 
								data-background-icon="fa-square-o" 	data-set-on="up" class=""> 
							</div>
							<div data-type="push" data-device="'.$device.'" data-icon="fa-minus" 
								data-background-icon="fa-square-o" data-set-on="stop" class=""> 
							</div>
							<div data-type="push" data-device="'.$device.'" data-icon="fa-chevron-down" 
								data-background-icon="fa-square-o" data-set-on="down" class=""> 
							</div>
						</div> 
					</td>
					<td>
						<div data-type="select" data-device="'.$device.'" 
							data-items=\'["0","10","20","30","40","50","60","70","80","90","100"]\' 
							data-alias=\'["Zu","10%","20%","30%","40%","50%","60%","70%","80%","90%","Auf"]\' 
							data-get="level" data-set="level" class="right">
						</div>
					</td>
				</tr>	
			</table>';
		if($self->{timer}) {
			$result .= '
			<div style="position:absolute; top:92px; left:210px;"
				data-type="wdtimer" 
				data-device="'.$self->{timer}.'"    
				data-style="round" 
				data-theme="dark" 
				data-title="'.$device.'"  
				data-sortcmdlist="MANUELL"
				data-cmdlist=\'{"Zu":"0","Auf":"100","10%":"10","20%":"20","30%":"30","40%":"40","50%":"50","60%":"60","70%":"70","80%":"80","90%":"90"}\'>
				<div data-type="button" class="cell small readonly" data-icon="oa-edit_settings" data-background-icon="fa-square-o" 
						data-on-color="#505050" data-on-background-color="#505050">
				</div>
			</div>';
		};
		$result .= '</div>';
		return $result;
	};

	
sub getStructure($) {
	# class method
	# returns general structure of the view without instance values
	my ($class) = @_;
	return [
		{ id => "class", type => "class", value => $class },
		{ id => "device", type => "device" },
		{ id => "title", type => "text", default => { type => "field", value => "device"} },
		{ id => "timer", type => "device", default => { type => "field", value => "device", suffix => "Timer" } },
		{ id => "width", type => "internal", value => 260 },
		{ id => "height", type => "internal", value => 140 }
		];
};

# register me as selectable
$FUIP::View::selectableViews{"FUIP::View::ShutterControl"}{title} = "Shutter (detail)"; 
	
1;	