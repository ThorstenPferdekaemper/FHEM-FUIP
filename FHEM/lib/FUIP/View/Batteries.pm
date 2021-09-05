package FUIP::View::Batteries;

use strict;
use warnings;

use lib::FUIP::View;
use parent -norequire, 'FUIP::View';
use lib::FUIP::Model;
	
	
sub getDependencies($$) {
	return ['js/fuip_5_resize.js','js/fuip_batteries.js'];
};
	

sub _getDevices($){
	my ($self) = @_;
	my $name = $self->{fuip}{NAME};
	my $deviceFilter = $self->{deviceFilter};
	my %devices;
	my @readings = qw(battery batteryLevel batVoltage batteryPercent);
	push(@readings,"Activity") if($deviceFilter eq "all");
	my $sysid = $self->getSystem();
	for my $reading (@readings) {
		for my $dev (@{FUIP::Model::getDevicesForReading($name,$reading,$sysid)}) {
			$devices{$dev}{$reading} = 1;
		};	
	};
	# only devices with battery, but we want the Activity reading nevertheless, if it exists
	# NAME is always added because jsonlist2 does not return devices with Attribute ignore=1. This 
	#	leads in Model::getDevice to an "empty" device, which could also happen if a device
	#   simply does not have alias or battery set. NAME, however, is always there unless 
	#	ignore=1
	#	(In other words: jsonlist2 never returns the Attribute ignore, if it is 1.)
	my $fields = ["battery","NAME","TYPE"];
	# add fields for the label rule
	$self->{labelRule} = "alias,NAME" unless defined $self->{labelRule};	
	my @labelFields = split(/,/,$self->{labelRule});
	push(@$fields,@labelFields);
	if($deviceFilter ne "all") {
		push(@$fields,"Activity");
	};	
	# exclude devices?
	$self->{exclude} = [] unless $self->{exclude};
	for my $excl (@{$self->{exclude}}) {
		delete $devices{$excl};
	};
	for my $dev (keys(%devices)) {
		my $device = FUIP::Model::getDevice($name,$dev,$fields,$sysid);
		unless(exists($device->{Internals}{NAME})) {
			delete $devices{$dev};
			next;
		};
		$devices{$dev}{TYPE} = $device->{Internals}{TYPE};  # this should always exist
		if(exists($device->{Readings}{Activity})) {
			$devices{$dev}{Activity} = 1;
		};
		# fields to form label
		# determine name here already, as we need it for sorting
		for my $field (@labelFields) {
			for my $area (qw(Attributes Internals Readings)) {
				next unless $device->{$area}{$field};
				$devices{$dev}{fuipName} = $device->{$area}{$field};
				last;
			};
			last if $devices{$dev}{fuipName};
		};
		$devices{$dev}{fuipName} = $dev unless $devices{$dev}{fuipName};
		$devices{$dev}{battery} = $device->{Readings}{battery} if $devices{$dev}{battery};
		# own key
		$devices{$dev}{key} = $dev;
	};
	# we need a sorted array as a result
	# sort by displayed name 
	# sort case-insensitive
	my @result = 
		sort { return CORE::fc($a->{fuipName}) cmp CORE::fc($b->{fuipName}); } values %devices;
	return \@result;
};	
	
	
sub _getHtmlName($) {
	my $device = shift;
	return '<div
		style="text-align:left;overflow:hidden;text-overflow:ellipsis;white-space:nowrap;" 
		class="fuip-color fuip-devname">'.$device->{fuipName}.'</div>';
};


sub _getReadingType($$) {
# determine type of reading:
#	text:	ok/low etc.
#	percentage: percentage (without the % sign)
#	voltage:	voltage, without the V sign
	my ($device,$reading) = @_;
	return "percentage" if($reading eq "batteryPercent");
	return "percentage" if($reading eq "batteryLevel" and $device->{TYPE} =~ m/^(PRESENCE|Arlo)$/); 
	return "voltage" if($reading =~ m/^(batteryLevel|batVoltage)$/);
	# now only "battery" is left, which usually is like ok/low etc., but can be percentage as well
	my $value = $device->{$reading};
	return "percentage" if($value =~ m/^\s*\d*\s*$/);	# i.e. (blanks,) digits (, blanks)
	return "text";
};


sub _getHtmlBatterySymbol($) {
	my ($device) = @_;
	my $reading;
	for my $r (qw(batteryLevel batVoltage batteryPercent battery)) {
		next unless exists($device->{$r});
		$reading = $r; 
		last;
	};	
	return "" unless $reading;	
	my $readingType = _getReadingType($device,$reading);
	my $result = '<div style="margin-top:-26px;margin-bottom:-30px;margin-right:-10px;margin-left:-10px;" 
					data-type="symbol" 
					data-device="'.$device->{key}.'" 
					data-get="'.$reading.'"'."\n";
	if($readingType eq "text") {
		$result .= 'data-icons=\'["oa-measure_battery_0 fa-rotate-90","oa-measure_battery_75 fa-rotate-90"]\''."\n";
	}else{
		$result .= 'data-icons=\'["oa-measure_battery_0 fa-rotate-90","oa-measure_battery_25 fa-rotate-90","oa-measure_battery_50 fa-rotate-90","oa-measure_battery_75 fa-rotate-90","oa-measure_battery_100 fa-rotate-90"]\''."\n";
	};
	if($readingType eq "percentage") {
		$result .= 'data-states=\'["0","10","35","60","90"]\''."\n";
	}elsif($readingType eq "text") {
		$result .= 'data-states=\'["((?!ok).)*","ok"]\''."\n";
	}else{
		$result .= 'data-states=\'["0","2.1","2.4","2.7","3.0"]\''."\n";
	};
	if($readingType eq "text") {
		$result .= 'data-colors=\'["red","green"]\'>'."\n";
	}else{
		$result .= 'data-colors=\'["red","yellow","green","green","green"]\'>'."\n";
	};
	$result .= '</div>';
	return $result;
};


sub _getHtmlBatteryLevel($) {
	my ($device) = @_;
	my $result = "";
	for my $reading (qw(batteryLevel batteryPercent battery batVoltage)) {
		next unless exists $device->{$reading};
		my $readingType = _getReadingType($device,$reading);
		next if $readingType eq "text";  # we do not want to see texts, just numbers here
		$result .= '<div data-type="label" 
						data-device="'.$device->{key}.'" 
						data-get="'.$reading.'" 
						data-unit="'.($readingType eq "percentage" ? '%' : 'V').'"
						class="fuip-color"></div>'."\n";	
		last;  # especially for those with userReadings				
	};
	return $result;
};	


sub _getHtmlActivity($) {
	my ($device) = @_;
	return "" unless exists($device->{Activity});
	return '<div data-type="label" 
				data-device="'.$device->{key}.'" 
				data-get="Activity" 
				data-colors=\'["red","green","yellow"]\' 
				data-limits=\'["dead","alive","unknown"]\'>
			</div>'."\n";
};


sub getHTML($){
	my ($self) = @_;
	my $result = '<div  data-fuip-type="fuip-batteries" style="overflow:auto;width:100%;height:100%;">
				<table style="border-spacing:0px;"><tr><td style="padding:0;">';
	my $devices = $self->_getDevices();				
	my $numDevs = @$devices;				
	my $count = 0;
	use integer;
	# avoid division by zero error
	$self->{columns} = 2 unless $self->{columns};
	my $perCol = $numDevs / $self->{columns} + ($numDevs % $self->{columns} ? 1 : 0);
	my $colWidth = 100 / ($self->{columns} + 1);
	$result .= '<table style="border-spacing:0px;">';
	for my $device (@$devices) {
		if($count == $perCol) {
			$result .= '</table></td><td style="padding:0;"><div style="width:25px;"></div></td><td style="padding:0;"><table style="table-layout:fixed;border-spacing:0px;">';
			$count = 0;
		}  
		$count++;
		$result.= '<tr>
					<td>'._getHtmlName($device).'</td>
					<td><div style="width:42px;">'._getHtmlBatterySymbol($device).'</div></td>
					<td><div style="width:30px">'._getHtmlBatteryLevel($device).'</div></td>
					<td style="padding-left:5px"><div style="width:54px">'._getHtmlActivity($device).'</div></td>
				</tr>';  
	}
	$result .= '</table>'; 
	$result .= '</td></tr></table></div>';
	return $result;	
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
		my $devices = $self->_getDevices();
		use integer;
		my $numDevs = @$devices;
		$self->{height} = 19 * ($numDevs / 2 + $numDevs % 2) + 8;
	};	
	if(not $self->{width} or $self->{sizing} eq "fixed") {
			$self->{width} = 650;
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
	
	
sub getDevicesForValueHelp($$) {
	# Return all devices which might appear in the view
	# TODO: combine with _getDevices
	my ($fuipName,$sysid) = @_;
	my %devices;
	my @readings = qw(battery batteryLevel batVoltage batteryPercent Activity);
	# TODO: deviceFilter?
	# push(@readings,"Activity") if($deviceFilter eq "all");
	for my $reading (@readings) {
		for my $dev (@{FUIP::Model::getDevicesForReading($fuipName,$reading,$sysid)}) {
			$devices{$dev} = 1;
		};	
	};
	my @result = keys %devices;
	return FUIP::_toJson(\@result);
};	
	
	
sub getStructure($) {
	# class method
	# returns general structure of the view without instance values
	my ($class) = @_;
	return [
		{ id => "class", type => "class", value => $class },
		{ id => "title", type => "text", default => { type => "const", value => "Batteries"} },
		{ id => "deviceFilter", type => "text", options => [ "all", "battery"], 
			default => { type => "const", value => "all" } }, 
		{ id => "exclude", type => "devices", default => { type => "const", value => [] }, 
					filterfunc => "FUIP::View::Batteries::getDevicesForValueHelp" },	
		{ id => "width", type => "dimension" },
		{ id => "height", type => "dimension" },
		{ id => "sizing", type => "sizing", options => [ "fixed", "auto", "resizable" ],
			default => { type => "const", value => "auto" } },
		{ id => "columns", type => "text", options => [1,2,3,4], 
			default => { type => "const", value => 2 } },
		{ id => "labelRule", type => "text", default => { type => "const", value => "alias,NAME" } }	
		];
};


our %docu = (
	general => "Diese View zeigt eine Liste der batteriebetriebenen Ger&auml;te mit den aktuellen Ladest&auml;nden an. Dazu werden alle FHEM-Devices mit den Readings <i>battery</i>, <i>batteryLevel</i>, <i>batVoltage</i>, <i>batteryPercent</i> und <i>Activity</i> gesucht und in einer Liste dargestellt. Devices, f&uuml;r die das Attribut <i>ignore</i> auf einen Wert ungleich 0 gesetzt ist, werden ignoriert. Je nachdem, was bei den einzelnen Devices m&ouml;glich ist, wird ein Batterie-Icon erzeugt, welches den Zustand der Batterie zeigt sowie ein Spannungs- oder Prozentwert und eine alive/dead-Angabe f&uuml;r Devices mit dem Reading <i>Activity</i>.",
	deviceFilter => "Hier kann angegeben werden, ob auch Devices angezeigt werden sollen, die das Reading <i>Activity</i> haben, aber gar nicht batteriebetrieben sind. Es gibt zwei m&ouml;gliche Werte:
	<ul>
	<li><b>all</b>: Es werden alle Devices angezeigt, auch solche, die nur das Reading <i>Activity</i> haben.</li>
	<li><b>battery</b>: Es werden nur die Devices angezeigt, die (mindestens) eins der Batterie-Readings haben. Es wird dann f&uuml;r diese Devices trotzdem \"dead\" oder \"alive\" angezeigt, wenn sie das <i>Activity</i> Reading haben.</li></ul>",
	exclude => "Hier kann eine Liste von Devices angegeben werden, die normalerweise von der <i>Batteries</i>-View angezeigt w&uuml;rden. Diese werden dann nicht angezeigt. In der zugeh&ouml;rigen Werthilfe werden nur Devices angezeigt, die normalerweise von der View gefunden werden.",
	columns => "Hier kann man angeben, ob die Liste in einer, zwei, drei oder vier Spalten ausgegeben werden soll. Es ist empfehlenswert, mit dieser Angabe im Zusammenhang mit dem Parameter <i>sizing</i> etwas zu experimentieren, bevor man sich festlegt.",
	labelRule => "Normalerweise wird der Text (das Label) zu jedem Device in der Liste vom Attribut <i>alias</i> genommen, falls dieses Attribut gesetzt ist. Ansonsten wird der Device-Name (das Internal NAME) benutzt. Mit dem Parameter <i>labelRule</i> kann man das &auml;ndern. Man gibt hier eine Komma-separierte Liste von Attributen, Internals und/oder Readings ein. Dann sucht die View f&uuml;r jedes Device nach dem ersten Eintrag, f&uuml;r den tats&auml;chlich etwas gesetzt ist. Man sollte <i>NAME</i> normalerweise immer als letztes in der Liste haben, um keine Eintr&auml;ge in der Liste ohne Text zu erzeugen.<br>
	Hat man z.B. Devices, bei denen der \"sinnvolle\" Name im Internal <i>name</i> steht und andere, f&uuml;r die das Attribut <i>alias</i> gef&uuml;llt ist, dann kann man <i>labelRule</i> mit \"name,alias,NAME\" oder \"alias,name,NAME\" f&uuml;llen, je nachdem ob <i>name</i> oder <i>alias</i> h&ouml;here Priorit&auml;t hat."	
);


# register me as selectable
$FUIP::View::selectableViews{"FUIP::View::Batteries"}{title} = "Liste der Batterien"; 
	
1;	