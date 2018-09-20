package FUIP::View::WeatherDetail;

use strict;
use warnings;

use lib::FUIP::View;
use parent -norequire, 'FUIP::View';


	
sub getHTML($){
	my ($self) = @_;
	my $device = $self->{device};
	my @detailArr;
	if(ref($self->{detail}) eq "ARRAY") {
		@detailArr = @{$self->{detail}};
	};
	if($self->{icons} eq "meteocons") {
		push(@detailArr,"icons");
	};	
	my $detail = '[]';
	if(@detailArr) {
		$detail = '["'.join('","',@detailArr).'"]';
	};
	# avoid issues with "old" instance
	$self->{days} = 4 unless $self->{days};
	return '<div>
			<link rel="stylesheet" href="/fhem/'.lc($self->{fuip}{NAME}).'/fuip/css/widget_weatherdetail.css">
			<div class="cell" data-type="weatherdetail" 
				data-device="'.$device.'" 
				data-days='.$self->{days}.' 
				data-detail=\''.$detail.'\'
			</div>
			</div>';
};

	
	sub dimensions($;$$){
		my $self = shift;
		# we ignore any settings
		my $height = 205 + @{$self->{detail}} * 23;
		# normal lines: 23
		# weather line: 33 if icons, 51 otherwise
		if(grep( /^weather$/, @{$self->{detail}} )) {
			$height += 10;
			if($self->{icons} eq "kleinklima") {
				$height += 18;
			};
		};
		return (($self->{width} eq "fixed") ? 598 : "auto", $height);
	};	
	
	
	sub getStructure($) {
	# class method
	# returns general structure of the view without instance values
	my ($class) = @_;
	return [
		{ id => "class", type => "class", value => $class },
		{ id => "device", type => "device" },
		{ id => "title", type => "text", default => { type => "field", value => "device"} },
		{ id => "days", type => "text", 
				options => [4,5,6,7],
				default => { type => "const", value => 4 } },
		{ id => "detail", type => "setoptions", 
				options => ["clock","weather","temp","chOfRain","rain","wind","windDir"], 
				default => { type => "const", value => ["clock","weather","temp","chOfRain","rain","windDir"] } },
		{ id => "icons", type => "text", options => [ "meteocons", "kleinklima" ], 
			default => { type => "const", value => "kleinklima" } },
		{ id => "width", type => "text", options => [ "fixed", "auto" ],
			default => { type => "const", value => "fixed" } }			
		];
};

# register me as selectable
$FUIP::View::selectableViews{"FUIP::View::WeatherDetail"}{title} = "Detailed Forecast"; 
	
1;	