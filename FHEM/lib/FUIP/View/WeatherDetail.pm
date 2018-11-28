package FUIP::View::WeatherDetail;

use strict;
use warnings;

use lib::FUIP::View;
use parent -norequire, 'FUIP::View';


sub getDependencies($$) {
	return ['FHEM/lib/FUIP/css/widget_weatherdetail.css'];
};


# fix startday and days in case of wrong user choice
# ...or "old" instances
sub _fixDays($) {
	my ($self) = @_;
	$self->{days} = 4 unless $self->{days};
	$self->{startday} = 0 unless $self->{startday};
	$self->{days} = 7 - $self->{startday} if $self->{startday} + $self->{days} > 7;
};

	
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

	my @overviewArr;
	if(ref($self->{overview}) eq "ARRAY") {
		@overviewArr = @{$self->{overview}};
	};
	my $overview = '[]';
	if(@overviewArr) {
		$overview = '["'.join('","',@overviewArr).'"]';
	};

	# avoid issues with "old" instance
	$self->_fixDays();
	return '<div style="width:100%;height:100%;overflow:hidden;">
			<div  style="width:100%;height:100%;"
				data-type="weatherdetail" 
				data-device="'.$device.'" 
				data-startday='.$self->{startday}.'
				data-days='.$self->{days}.'
				data-overview='.$overview.'	
				data-detail=\''.$detail.'\'>
			</div>
			</div>';
};

	
sub dimensions($;$$){
	my ($self,$width,$height) = @_;
	if($self->{sizing} eq "resizable") {
		$self->{width} = $width if $width;
		$self->{height} = $height if $height;
	};
	# do we have to determine the size?
	# even if sizing is "auto", we at least determine an initial size
	# either resizable and no size yet
	# or fixed
	if(not $self->{height} or $self->{sizing} eq "fixed") {
		$self->{height} = 205 + @{$self->{detail}} * 23;
		# normal lines: 23
		# weather line: 33 if icons, 51 otherwise
		if(grep( /^weather$/, @{$self->{detail}} )) {
			$self->{height} += 10;
			if($self->{icons} eq "kleinklima") {
				$self->{height} += 18;
			};
		};
	};
	if(not $self->{width} or $self->{sizing} eq "fixed") {
		$self->{width} = 598;
	};	
	return ("auto","auto") if($self->{sizing} eq "auto");
	return ($self->{width},$self->{height});
};	
	
	
sub reconstruct($$$) {
	my ($class,$conf,$fuip) = @_;
	my $self = FUIP::View::reconstruct($class,$conf,$fuip);
	# downward compatibility: automatically convert width to resizable
	return $self unless defined($self->{width});
	return $self unless $self->{width} =~ m/^(fixed|auto)$/;
	$self->{sizing} = $self->{width};
	delete $self->{width};
	if(defined($self->{defaulted}{width})) {
		$self->{defaulted}{sizing} = $self->{defaulted}{width};
		delete $self->{defaulted}{width};
	};	
	return $self;
};
	
	
sub getStructure($) {
	# class method
	# returns general structure of the view without instance values
	my ($class) = @_;
	return [
		{ id => "class", type => "class", value => $class },
		{ id => "device", type => "device" },
		{ id => "title", type => "text", default => { type => "field", value => "device"} },
		{ id => "startday", type => "text", 
				options => [0,1,2,3],
				default => { type => "const", value => 0 } },
		{ id => "days", type => "text", 
				options => [4,5,6,7],
				default => { type => "const", value => 4 } },
		{ id => "overview", type => "setoptions",
				options => ["text","sun","uv","frost"], 
				default => { type => "const", value => [] } },		
		{ id => "detail", type => "setoptions", 
				options => ["clock","weather","text","temp","chOfRain","rain","wind","windDir"], 
				default => { type => "const", value => ["clock","weather","temp","chOfRain","rain","windDir"] } },
		{ id => "icons", type => "text", options => [ "meteocons", "kleinklima" ], 
			default => { type => "const", value => "kleinklima" } },
		{ id => "width", type => "dimension" },
		{ id => "height", type => "dimension" },
		{ id => "sizing", type => "sizing", options => [ "fixed", "auto", "resizable" ],
			default => { type => "const", value => "fixed" } },
	];
};

# register me as selectable
$FUIP::View::selectableViews{"FUIP::View::WeatherDetail"}{title} = "Detailed Forecast"; 
	
1;	