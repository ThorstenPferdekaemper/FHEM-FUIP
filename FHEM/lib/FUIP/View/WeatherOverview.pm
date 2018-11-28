package FUIP::View::WeatherOverview;

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
	$self->{startday} = 0 unless $self->{startday};
	$self->{days} = 14 - $self->{startday} if $self->{startday} + $self->{days} > 14;
};

	
sub getHTML($){
	my ($self) = @_;
	my $device = $self->{device};
	# avoid issues with broken instance
	$self->{days} = 1 unless $self->{days};
	my @overviewArr;
	if(ref($self->{overview}) eq "ARRAY") {
		@overviewArr = @{$self->{overview}};
	};
	my $overview = '[]';
	if(@overviewArr) {
		$overview = '["'.join('","',@overviewArr).'"]';
	};
	$self->_fixDays();
	return '<div style="width:100%;height:100%;overflow:hidden;">
			<div style="width:100%;height:100%;"
				data-type="weatherdetail" 
				data-device="'.$device.'" 
				data-startday='.$self->{startday}.'
				data-days='.$self->{days}.' 
				data-overview='.$overview.'					
				data-detail=\'[]\'
				data-layout="'.$self->{layout}.'">
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
		# if layout is "small", height is always base height
		if($self->{layout} eq "small") {
			$self->{height} = main::AttrVal($self->{fuip}{NAME},"baseHeight",108);
		}else{
			$self->{height} = 205;
		};	
	};	
	if(not $self->{width} or $self->{sizing} eq "fixed") {
		# width "fixed" and "normal" => 149 * days, "small" => depends on baseWidth
		$self->_fixDays();
		if($self->{layout} eq "small") {
			$self->{width} = (main::AttrVal($self->{fuip}{NAME},"baseWidth",142) + 10) * $self->{days} - 10;
		}else{
			$self->{width} = 149 * $self->{days};
		};
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
				options => [0,1,2,3,4,5,6,7,8,9,10,11,12,13],
				default => { type => "const", value => 0 } },
		{ id => "days", type => "text", 
				options => [1,2,3,4,5,6,7,8,9,10,11,12,13,14],
				default => { type => "const", value => 1 } },
		{ id => "overview", type => "setoptions",
				options => ["text","sun","uv","frost"], 
				default => { type => "const", value => [] } },				
		{ id => "width", type => "dimension" },
		{ id => "height", type => "dimension" },
		{ id => "sizing", type => "sizing", options => [ "fixed", "auto", "resizable" ],
			default => { type => "const", value => "fixed" } },
		{ id => "layout", type => "text", options => [ "normal", "small" ], default => { type => "const", value => "normal" }},	
		{ id => "popup", type => "dialog", default=> { type => "const", value => "inactive"} }				
	  ];
};

# register me as selectable
$FUIP::View::selectableViews{"FUIP::View::WeatherOverview"}{title} = "Weather Overview"; 
	
1;	