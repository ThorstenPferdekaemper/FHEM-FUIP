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


sub getHTML($){
	my ($self) = @_; 
	
	my $gplot = FUIP::Model::getGplot($self->{fuip}{NAME},$self->{device});
	return "Error getting gplot information" unless $gplot;
	# my $device = FUIP::Model::getDevice($self->{fuip}{NAME},$self->{device},["GPLOTFILE"]);
	main::Log3(undef,1,main::Dumper($gplot));

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
			main::Log3(undef,1,$lspec);	
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
	my $result = '<link rel="stylesheet" href="/fhem/'.lc($self->{fuip}{NAME}).'/fuip/css/fuipchart.css">
				<div data-type="chart"
					data-device=\'["'.join('","',@devices).'"]\'
					data-logdevice=\'["'.join('","',@logdevices).'"]\'
					data-columnspec=\'["'.join('","',@colspecs).'"]\'
					data-style=\'["'.join('","',@styles).'"]\'
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

	# my $result = '<div data-type="svgplot"
					# data-device="'.$self->{device}.'"
					# data-gplotfile="'.$device->{Internals}{GPLOTFILE}.'"
					# data-logdevice="'.$logdevices[0].'"
					# data-logfile="CURRENT"
					# data-refresh="300"></div>';
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
		{ id => "popup", type => "dialog", default=> { type => "const", value => "inactive"} }	
		];
};


# register me as selectable
$FUIP::View::selectableViews{"FUIP::View::Chart"}{title} = "Chart (experimental)"; 
	
1;	