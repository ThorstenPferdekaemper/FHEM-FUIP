package FUIP::View::Chart;

use strict;
use warnings;

use lib::FUIP::View;
use parent -norequire, 'FUIP::View';

use DateTime;
use DateTime::Duration;

sub dimensions($;$$){
	return ("auto","auto");
};	


my @possibleTimeranges =
	(	["LastHour",'["Letzte Stunde","1h","0h"]'],
		["Last3Hours",'["3 Stunden","3h","0h"]'],
		["Last6Hours",'["6 Stunden","6h","0h"]'],
		["Last12Hours",'["12 Stunden","12h","0h"]'],
		["Last24Hours",'["24 Stunden","24h","0h"]'],
		["Today",'["Heute","0D","-1D"]'],
		["Yesterday",'["Gestern","1D","0D"]'],
		["CurrentWeek",'["Aktuelle Woche","0W","-1W"]'],
		["LastWeek",'["Vorherige Woche","1W","0W"]'],
		["CurrentMonth",'["Aktueller Monat","0M","-1M"]'],
		["LastMonth",'["Vorheriger Monat","1M","0M"]'],
		["CurrentYear",'["Aktuelles Jahr","0Y","-1Y"]'],
		["LastYear",'["Vorheriges Jahr","1Y","0Y"]']
	);	


# ticks 
# 'y2tics' => '"Nice" 22, "Ok" 20, "Cool" 18, "Cold" 16',	
# data-yticks='[[0,"open"],[1,"closed"]]'
sub _convertTicks($) {
	my ($svgTicks) = @_;
	return undef unless $svgTicks;
	my @resultArray;
	my @lines = split(/,/,$svgTicks);
	# it seems that this needs at least two lines in order not to create issues
	return undef if(0+@lines < 2); 
	for my $line (@lines) {
		$line =~ s/^\s+//;  #remove leading blank
		my ($text,$num) = split(/ /,$line);
		return undef unless defined $num;
		push(@resultArray, [$num,$text]);
	};
	# sort is needed as the chart widget otherwise creates an endless loop 
	@resultArray = sort { $a->[0] <=> $b->[0] } @resultArray;
	@resultArray = map { '['.$_->[0].','.$_->[1].']' } @resultArray;
	return '['.join(',',@resultArray).']';
};
	
	
sub getHTML($){
	my ($self) = @_; 
	
	my $gplot = FUIP::Model::getGplot($self->{fuip}{NAME},$self->{device});
	return "Error getting gplot information" unless $gplot;
	# my $device = FUIP::Model::getDevice($self->{fuip}{NAME},$self->{device},["GPLOTFILE"]);
	# main::Log3(undef,1,main::Dumper($gplot));

	my @devices;
	my @logdevices;
	my @colspecs;
	my @svgidx;
	for my $logdevice (@{$gplot->{srcDesc}{order}}) {  #FileLog_HM_21F923
		# DbLog? - need type of logdevice
		my $ldev = FUIP::Model::getDevice($self->{fuip}{NAME},$logdevice,["TYPE"]);
		my @lspecs = split(/ /,$gplot->{srcDesc}{src}{$logdevice}{arg}); 
		# (4:HM_21F923.measured-temp\\x3a::, 4:HM_21F923.desired-temp\\x3a::, 4:HM_21F923.actuator\\x3a::')
		my $i = 0;
		for my $lspec (@lspecs) {
			# main::Log3(undef,1,$lspec);	
			my $dev = "";
			if($ldev->{Internals}{TYPE} eq "DbLog") {
				($dev,undef) = split(/:/,$lspec,2);
			}elsif($ldev->{Internals}{TYPE} eq "logProxy") {
				$dev = "";  # TODO: can we determine anything at all here?
			}else{	
				my ($col,$rest) = split(/:/,$lspec,2);
				($dev,undef) = split(/\./,$rest,2);
			};	
			push(@devices,$dev);
			push(@logdevices,$logdevice);
			$lspec =~ s/\\/\\\\/g;  	# \ -> \\
			$lspec =~ s/\"/\\\"/g;	# " -> \"
			push(@colspecs,$lspec); #$col.':'.$reading);
			push(@svgidx,$gplot->{srcDesc}{rev}{$gplot->{srcDesc}{src}{$logdevice}{num}}{$i});
			$i++;
		}
	};
	my @styles;
	my @uaxis;
	my @legend;
	my @ptype;
	for my $idx (@svgidx) {
		my $style = (split(/"/,$gplot->{conf}{lStyle}[$idx]))[1];
		$style =~ s/SVGplot/fuipchart/g;
		if($gplot->{conf}{lType}[$idx] eq "points") {
			$style .= " ".$gplot->{conf}{lType}[$idx];
		};
		push(@styles, $style);  #'class="SVGplot l1"' => SVGplot l1	
		push(@uaxis, $gplot->{conf}{lAxis}[$idx] eq "x1y1" ? "primary" : "secondary");
		push(@legend, $gplot->{conf}{lTitle}[$idx]);
		push(@ptype, $gplot->{conf}{lType}[$idx]);
	};
	my @minmax;
	if(exists($gplot->{conf}{yrange})) {
		if(substr($gplot->{conf}{yrange},0,1) eq "[") {
			$gplot->{conf}{yrange} = substr($gplot->{conf}{yrange},1,-1);
		};	
		@minmax = split(/:/,$gplot->{conf}{yrange});
	}else{
		@minmax = ("auto","auto");
	};	
	my @minmax_sec;
	if(exists($gplot->{conf}{y2range})) {
		if(substr($gplot->{conf}{y2range},0,1) eq "[") {
			$gplot->{conf}{y2range} = substr($gplot->{conf}{y2range},1,-1);
		};	
		@minmax_sec = split(/:/,$gplot->{conf}{y2range});
	}else{
		@minmax_sec = ("auto","auto");
	};
	
	# data-timeranges
	my %timerangeKeys;
	if(ref($self->{timeranges}) eq "ARRAY") {
		%timerangeKeys = map {$_ => 1} @{$self->{timeranges}};
	};
	my $timeranges;
	if(%timerangeKeys) {
		my @selectedTimeranges = map { $timerangeKeys{$_->[0]} ? $_->[1] : () } @possibleTimeranges; 
		$timeranges = '['.join(',',@selectedTimeranges).']';
	};
	
	# ticks (
	# 'y2tics' => '"Nice" 22, "Ok" 20, "Cool" 18, "Cold" 16',	
	# data-yticks='[[0,"open"],[1,"closed"]]'
	my $yticks = _convertTicks($gplot->{conf}{ytics});
	my $y2ticks = _convertTicks($gplot->{conf}{y2tics});
	
	# fixedrange -> data-daysago_start, data-daysago_end
	my $svgDevice = FUIP::Model::getDevice($self->{fuip}{NAME},$self->{device},
						["fixedrange","endPlotNow","endPlotToday"]);
	my $daysago_start;
	my $daysago_end;
	my $nofulldays = "false";
	if($svgDevice->{Attributes}{fixedrange}) {
		# YYYY-MM-DD YYYY-MM-DD
		# hour, <N>hours, day, <N>days, week, month, year, <N>years [offset]
		# TODO: offset is not considered
		my @fixedrange = split(/ /,$svgDevice->{Attributes}{fixedrange});
		if($fixedrange[0] =~ /(.*)(hour|hours|day|days|week|month|year|years)$/) {
			my $unit = substr($2,0,1);
			if($unit eq "h"){
				$nofulldays = "true";
				$daysago_end = "now"; # seems this is the same as "0h"
			}elsif($unit eq "d") {
				if($svgDevice->{Attributes}{endPlotNow}) {
					$nofulldays = "true";
					$daysago_end = "now"; 
				}else{
					$unit = "D";
					$daysago_end = "-1D"; 
				};
			}else{		
				if(not $svgDevice->{Attributes}{endPlotToday}) {
					$unit = uc($unit);
				};
				$daysago_end = "-1".$unit; 
			}	
			if($nofulldays eq "false") {
				$daysago_start = ($1 ? ($1-1) : 0).$unit;
			}else{
				$daysago_start = ($1 ? ($1) : 1).$unit;
			};
		}else{
			# YYYY-MM-DD YYYY-MM-DD
			$daysago_start = $fixedrange[0];
			$daysago_end = $fixedrange[1];
		};
		
	};
	
	my $result = '<link rel="stylesheet" href="/fhem/'.lc($self->{fuip}{NAME}).'/fuip/css/fuipchart.css">
				<div data-type="chart"
					data-device=\'["'.join('","',@devices).'"]\'
					data-logdevice=\'["'.join('","',@logdevices).'"]\'
					data-columnspec=\'["'.join('","',@colspecs).'"]\'';
	if($timeranges) {
		$result .= ' data-timeranges=\''.$timeranges.'\' ';
	};	
	$result .= ' data-daysago_start="'.$daysago_start.'" ' if defined $daysago_start;
	$result .= ' data-daysago_end="'.$daysago_end.'" ' if defined $daysago_end;
	$result .= ' data-nofulldays="'.$nofulldays.'" ';
	$result .= ' data-yticks=\''.$yticks.'\' ' if $yticks;
	$result .= ' data-yticks_sec=\''.$y2ticks.'\' ' if $y2ticks;
	$result .= 	'	data-style=\'["'.join('","',@styles).'"]\'
					data-ptype=\'["'.join('","',@ptype).'"]\'
					data-uaxis=\'["'.join('","',@uaxis).'"]\'
					data-legend=\'["'.join('","',@legend).'"]\';
					data-minvalue="'.$minmax[0].'" data-maxvalue="'.$minmax[1].'"
					data-minvalue_sec="'.$minmax_sec[0].'" data-maxvalue_sec="'.$minmax_sec[1].'"
					data-title="'.$gplot->{conf}{title}.'"
					data-title_class="fuipchart title"
					data-ytext='.$gplot->{conf}{ylabel}.'
					data-ytext_sec='.$gplot->{conf}{y2label}.'
					data-legendpos=\'["left","top"]\'
					data-width="100%" data-height="100%"
					style="width:100%;height:100%;">
				</div>';
	# main::Log3(undef,1,$result);	
	return $result;				
};
	
	
sub getStructure($) {
# class method
# returns general structure of the view without instance values
	my ($class) = @_;
	my @timeranges = map {$_->[0]} @possibleTimeranges;
	return [
		{ id => "class", type => "class", value => $class },
		{ id => "device", type => "device" },
		{ id => "title", type => "text", default => { type => "field", value => "device"} },
		{ id => "timeranges", type => "setoptions", 
				options => \@timeranges, 
				default => { type => "const", value => \@timeranges } },
		{ id => "popup", type => "dialog", default=> { type => "const", value => "inactive"} }	
		];
};


# register me as selectable
$FUIP::View::selectableViews{"FUIP::View::Chart"}{title} = "Chart (experimental)"; 
	
1;	