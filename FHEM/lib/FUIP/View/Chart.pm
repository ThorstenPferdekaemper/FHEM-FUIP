package FUIP::View::Chart;

use strict;
use warnings;

use lib::FUIP::Systems;
use lib::FUIP::View;
use parent -norequire, 'FUIP::View';


sub dimensions($;$$){
	my ($self,$width,$height) = @_;
	if($self->{sizing} eq "resizable") {
		$self->{width} = $width if $width;
		$self->{height} = $height if $height;
	};
	return ("auto","auto") if($self->{sizing} eq "auto");
	return ($self->{width},$self->{height});
};	


sub getDependencies($$) {
	my ($self,$fuip) = @_;
	
	#Determine the default system. Otherwise, we might end up with different
	#styles from different backend systems. The result would not be really
	#predictable.
	my $sysid = FUIP::Systems::getDefaultSystem($fuip);
	my $stylesheetPrefix = FUIP::Model::getStylesheetPrefix($fuip->{NAME},$sysid);
	return [$sysid.':www/pgm2/'.$stylesheetPrefix.'svg_defs.svg',
			$sysid.':www/pgm2/'.$stylesheetPrefix.'svg_style.css',
			'FHEM/lib/FUIP/css/fuipchart.css'];
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
	
	
sub _convertYRange($$) {
	
	my ($conf,$key) = @_;	
	my ($min,$max) = ("auto","auto");
	
	#Do we have an y range at all?
	return ($min,$max) unless exists $conf->{$key};
	my $yrange = $conf->{$key};
	return ($min,$max) unless $yrange;
	
	#Perl coding or similar? 
	$yrange = main::AnalyzeCommand(undef, $1) if($yrange =~ /^(\{.*\})$/);
	
	if($yrange =~ /\[(.*):(.*)\]/) {
      $min = $1 if($1 ne "");
      $max = $2 if($2 ne "");
    };
	return ($min,$max);
};	
	
	
sub getHTML($){
	my ($self) = @_; 
	my $sysid = $self->getSystem();
	my $gplot = FUIP::Model::getGplot($self->{fuip}{NAME},$self->{device},$sysid);
	return "Error getting gplot information" unless $gplot;
	# my $device = FUIP::Model::getDevice($self->{fuip}{NAME},$self->{device},["GPLOTFILE"]);
	# main::Log3(undef,1,main::Dumper($gplot));

	my @devices;
	my @logdevices;
	my @colspecs;
	my @svgidx;
	for my $logdevice (@{$gplot->{srcDesc}{order}}) {  #FileLog_HM_21F923
		# DbLog? - need type of logdevice
		my $ldev = FUIP::Model::getDevice($self->{fuip}{NAME},$logdevice,["TYPE"],$sysid);
		my @lspecs = split(/ /,$gplot->{srcDesc}{src}{$logdevice}{arg}); 
		# (4:HM_21F923.measured-temp\\x3a::, 4:HM_21F923.desired-temp\\x3a::, 4:HM_21F923.actuator\\x3a::')
		my $i = 0;
		for my $lspec (@lspecs) {
			#main::Log3(undef,1,$lspec);	
			my $dev = "";
			if($ldev->{Internals}{TYPE} eq "DbLog") {
				($dev,undef) = split(/:/,$lspec,2);
			}elsif($ldev->{Internals}{TYPE} eq "logProxy") {
				#FileLog:<log device>[,<options>]:<(alte) FileLog column_spec>
				#or
				#DbLog:<log device>,[<options>]:<(alte) DbLog column_spec>
				my ($logType, $logDeviceSpec,$rest) = split(/:/,$lspec,3);
				if($logType eq "FileLog"){
					(undef,$rest) = split(/:/,$rest,2);
					($dev,undef) = split(/\./,$rest,2);
				}elsif($logType eq "DbLog"){
					($dev,undef) = split(/:/,$rest,2);
				}else{
					$dev = "";  
				};	
			}else{	
				my ($col,$rest) = split(/:/,$lspec,2);
				($dev,undef) = split(/\./,$rest,2);
			};	
			push(@devices,$dev);
			push(@logdevices,$logdevice);
			$lspec =~ s/\\/\\\\/g;  	# \ -> \\
			$lspec =~ s/\"/\\\"/g;	# " -> \"
			$lspec =~ s/'/&#39;/g;	# escape single quote
			push(@colspecs,$lspec); #$col.':'.$reading);
			push(@svgidx,$gplot->{srcDesc}{rev}{$gplot->{srcDesc}{src}{$logdevice}{num}}{$i});
			$i++;
		}
	};
	my @styles;
	my @uaxis;
	my @legend;
	my @ptype;
	my @lwidth;
	my $primaryExists;
	for my $idx (@svgidx) {
		my $style = (split(/"/,$gplot->{conf}{lStyle}[$idx]))[1];
		$style =~ s/SVGplot/SVGplot fuipchart/g;
		# line width
		my $lwidth = $gplot->{conf}{lWidth}[$idx];
		$lwidth = (split(/:/,$lwidth))[1];
		$lwidth =~ s/"//g;   # remove "
		$lwidth =~ s/\./p/;  # . => p
		$style .= " lwidth".$lwidth;
		if($gplot->{conf}{lType}[$idx] eq "points") {
			$style .= " ".$gplot->{conf}{lType}[$idx];
		};
		push(@styles, $style);  #'class="SVGplot l1"' => SVGplot l1	
		if($gplot->{conf}{lAxis}[$idx] eq "x1y1") {
			$primaryExists = 1;
			push(@uaxis, "primary");
		}else{
			push(@uaxis, "secondary");
		};
		push(@legend, $gplot->{conf}{lTitle}[$idx]);
		push(@ptype, $gplot->{conf}{lType}[$idx]);
	};
	# range as
	my @minmax = _convertYRange($gplot->{conf}, 'yrange');
	my @minmax_sec = _convertYRange($gplot->{conf}, 'y2range');;
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
						["fixedrange","endPlotNow","endPlotToday"],$sysid);
	my $daysago_start;
	my $daysago_end;
	my $nofulldays = "false";
	# looks like "day" range is the default
	$svgDevice->{Attributes}{fixedrange} = "day" unless $svgDevice->{Attributes}{fixedrange};
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
	
	# if only "secondary" axis, we need to swap axis. Otherwise, the chart widget is empty...
	# TODO: eki?
	if(not $primaryExists) {
		@uaxis = ("primary") x @uaxis;
		($yticks,$y2ticks) = ($y2ticks,$yticks);
		($minmax[0],$minmax[1],$minmax_sec[0],$minmax_sec[1]) = ($minmax_sec[0],$minmax_sec[1],$minmax[0],$minmax[1]);
		($gplot->{conf}{ylabel},$gplot->{conf}{y2label}) = ($gplot->{conf}{y2label},$gplot->{conf}{ylabel})
	};

	my $result = '<div data-type="chart"
					data-device=\'["'.join('","',@devices).'"]\'
					data-logdevice=\'["'.join('","',@logdevices).'"]\'
					data-columnspec=\'["'.join('","',@colspecs).'"]\''."\n";
	if($timeranges) {
		$result .= 'data-timeranges=\''.$timeranges.'\''."\n";
	};	
	$result .= 'data-daysago_start="'.$daysago_start.'" '."\n" if defined $daysago_start;
	$result .= 'data-daysago_end="'.$daysago_end.'" '."\n" if defined $daysago_end;
	$result .= 'data-nofulldays="'.$nofulldays.'" '."\n";
	$result .= 'data-yticks=\''.$yticks.'\' '."\n" if $yticks;
	$result .= 'data-yticks_sec=\''.$y2ticks.'\' '."\n" if $y2ticks;
	$result .= 	'	data-style=\'["'.join('","',@styles).'"]\'
					data-ptype=\'["'.join('","',@ptype).'"]\'
					data-uaxis=\'["'.join('","',@uaxis).'"]\'
					data-legend=\'["'.join('","',@legend).'"]\'
					data-minvalue="'.$minmax[0].'" 
					data-maxvalue="'.$minmax[1].'"
					data-minvalue_sec="'.$minmax_sec[0].'" 
					data-maxvalue_sec="'.$minmax_sec[1].'"
					data-title="'.$gplot->{conf}{title}.'"
					data-title_class="fuipchart title fuip-color-foreground"
					data-ytext='.$gplot->{conf}{ylabel}.'
					data-ytext_sec='.$gplot->{conf}{y2label}.'
					data-legendpos=\'["left","top"]\'
					data-width="100%" data-height="100%"
					style="width:100%;height:calc(100% - 4px);">	
				</div>'."\n";
	# main::Log3(undef,1,$result);	
	return $result;		
};
	
	
sub getDevicesForValueHelp($$) {
	# Return devices with TYPE SVG
	my ($fuipName,$sysid) = @_;
	return FUIP::_toJson(FUIP::Model::getDevicesForType($fuipName,"SVG",$sysid));
}	
	
	
sub getStructure($) {
# class method
# returns general structure of the view without instance values
	my ($class) = @_;
	my @timeranges = map {$_->[0]} @possibleTimeranges;
	return [
		{ id => "class", type => "class", value => $class },
		{ id => "device", type => "device", filterfunc => "FUIP::View::Chart::getDevicesForValueHelp" },
		{ id => "title", type => "text", default => { type => "field", value => "device"} },
		{ id => "width", type => "dimension", value => 200},
		{ id => "height", type => "dimension", value => 100 },
		{ id => "sizing", type => "sizing", options => [ "resizable", "auto" ],
			default => { type => "const", value => "auto" } },
		{ id => "timeranges", type => "setoptions", 
				options => \@timeranges, 
				default => { type => "const", value => \@timeranges } },		
		{ id => "popup", type => "dialog", default=> { type => "const", value => "inactive"} }	
		];
};


# register me as selectable
$FUIP::View::selectableViews{"FUIP::View::Chart"}{title} = "Chart from SVG"; 
	
1;	