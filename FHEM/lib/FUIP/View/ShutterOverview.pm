
# class FUIPViewShutterOverview
package FUIP::View::ShutterOverview;

use strict;
use warnings;

    use lib::FUIP::View;
	use parent -norequire, 'FUIP::View';


	sub getHTML($){
		my ($self) = @_;
		my $device = $self->{device};
		my (undef,$height) = $self->dimensions();
		my $result = '
			<table style="width:100%;height:'.$height.'px !important;"><tr><td>
			<div data-type="symbol" data-device="'.$device.'" data-get="level"
                    data-icons=\'["oa-fts_shutter_100","oa-fts_shutter_90",
								"oa-fts_shutter_80","oa-fts_shutter_70","oa-fts_shutter_60","oa-fts_shutter_50",
								"oa-fts_shutter_40","oa-fts_shutter_30","oa-fts_shutter_20","oa-fts_shutter_10","oa-fts_window_2w"]\'
					data-get-on=\'["0","10","20","30","40","50","60","70","80","90","100"]\' data-on-color="#2A2A2A" 
					data-on-background-color="#aa6900" data-background-icon="fa-square">
			</div>
			</td></tr>';
		if($self->{label}) {
			$result .= '<tr><td>'.$self->{label}.'</td></tr>';
		};	
		$result .= '</table>';	
		return $result;
	};

	
	sub dimensions($;$$){
		my $self = shift;
		# we ignore any settings
		my $height = 70;
		$height += 10 if($self->{label});
		return (70, $height);
	};	
	
	
	sub getStructure($) {
	# class method
	# returns general structure of the view without instance values
	my ($class) = @_;
	return [
		{ id => "class", type => "class", value => $class },
		{ id => "device", type => "device" },
		{ id => "title", type => "text", default => { type => "field", value => "device"} },
		{ id => "label", type => "text", default => { type => "field", value => "title"} },
		{ id => "width", type => "internal", value => 70 },
		{ id => "height", type => "internal", value => 70 }
		];
};

	
1;	