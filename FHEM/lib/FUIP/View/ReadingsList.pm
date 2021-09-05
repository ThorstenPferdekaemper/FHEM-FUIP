package FUIP::View::ReadingsList;
	
use strict;
use warnings;
	
use lib::FUIP::View;
use parent -norequire, 'FUIP::View';
	
use lib::FUIP::Model;	
	

sub _getVisibleReadings($) {
	my ($self) = @_;
	
	my $fuipName = $self->{fuip}{NAME};
	my $hash = FUIP::Model::getDevice($fuipName,$self->{device}[0],[],$self->getSystem()); 
	return [] unless defined $hash;
	my $result = [];
	foreach my $reading (sort keys %{$hash->{Readings}}) {
		next if(substr($reading,0,1) eq ".");
		push @$result, $reading;
	};
	return $result;	
};
	
	
sub makeArray($){
	# if it is an array, then ok
	return if ref($_[0]) eq "ARRAY";
	# otherwise return an array with the argument as element
	# (unless it is undefined)
	if(defined($_[0])) {
		$_[0] = [ $_[0] ];
	}else{	
		$_[0] = [ ];
	};
};
	
	
sub getHTML($){
	my ($self) = @_;
	
	my $name = $self->{fuip}{NAME};
	
	# backward compatibility 
	makeArray($self->{device});
	makeArray($self->{reading});	
	makeArray($self->{detail});

	# determine aliasse
	my @alias;
	for my $devkey (@{$self->{device}}) {
		my $device = FUIP::Model::getDevice($name,$devkey,['alias'],$self->getSystem());
		if($device->{Attributes}{alias}) {
			push @alias, $device->{Attributes}{alias};
		}else{
			push @alias, $devkey;
		}	
	};
	# if no readings are given, then use all visible readings
	# for single devices and state for multiple devices
	my $readings = $self->{reading};
	unless(@$readings) {
		if(@{$self->{device}} == 1) {
			$readings = $self->_getVisibleReadings();
		}else{
			$readings = [ "state" ];
		};
	};
	# if no columns are given...
	# use "device value" for multiple devices
	# and "reading value timestamp" for single devices
	# (timestamp for downward compatibility)
	my $details = $self->{detail};
	unless(@$details){
		if(@{$self->{device}} == 1) {
			$details = ["reading","value","timestamp"];
		}else{
			$details = ["device","value"];		};
	};
	
	my $result = 
		'<div data-type="fuip_readingslist"
			data-detail=\'["'.join('","',@$details).'"]\' 
			data-device=\'["'.join('","',@{$self->{device}}).'"]\' 
			data-alias=\'["'.join('","',@alias).'"]\' 
			data-reading=\'["'.join('","',@$readings).'"]\'
			data-value="'.$self->{value}.'" 
			style="width:100%;height:100%;">
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
		$self->{height} = 540;
	};	
	if(not $self->{width} or $self->{sizing} eq "fixed") {
		$self->{width} = 800;
	};	
	return ("auto","auto") if($self->{sizing} eq "auto");
	return ($self->{width},$self->{height});
};		
	
	
sub getReadingsForValueHelp($$$) {
	# get all Readings for all devices
	# for FUIP's value help
	my ($fuipName,$devStr,$sysid) = @_; 	
	return FUIP::_toJson(FUIP::Model::getReadingsOfDevice($fuipName,$devStr,$sysid));	
};	
	
	
sub getStructure($) {
	# class method
	# returns general structure of the view without instance values
	my ($class) = @_;
	return [
		{ id => "class", type => "class", value => $class },
		{ id => "device", type => "devices" },
		{ id => "reading", type => "setoptions", reffunc => "FUIP::View::ReadingsList::getReadingsForValueHelp", refparms => ["device"] }, 
		{ id => "value", type => "text" },
		{ id => "detail", type => "setoptions", options => ["device","reading","value","timestamp"] },
		{ id => "title", type => "text", default => { type => "const", value => "ReadingsList"} },
		{ id => "width", type => "dimension" },
		{ id => "height", type => "dimension" },
		{ id => "sizing", type => "sizing", options => [ "fixed", "auto", "resizable" ],
			default => { type => "const", value => "auto" } }
		];
};


our %docu = (
	general => "Diese View zeigt ein oder mehrere Reading(s) von einem oder mehreren Device(s) als Liste an.<br>
				Zus&auml;tzlich kann man einen Filter angeben, wodurch nur Readings angezeigt werden, deren Wert dem Filter entspricht.",
	device => "Hier w&auml;hlt man die Devices aus, deren Readings man sehen will. Man kann mehrere Devices ausw&auml;hlen.",
	reading => "Hier w&auml;hlt man die Readings aus, die man sehen will. Man kann kein, ein oder mehrere Readings ausw&auml;hlen.<br> 
	Wenn man kein Reading angibt, das Feld also leer l&auml;sst, dann kommt es darauf an, ob man nur ein Device oder mehrere Devices ausgew&auml;hlt hat. Bei einem einzelnen Device werden alle Readings angezeigt, die man normalerweise auch in FHEMWEB sehen w&uuml;rde. (Also alle, au&szlig;er die mit einem Punkt am Anfang.) Bei mehreren Devices wird dann nur das Reading <i>state</i> angezeigt.<br>
	Wenn man mehrere Readings angibt und auch mehrere Devices angegeben hat, dann kann jedes der gew&auml;hlten Readings f&uuml;r jedes Device angezeigt werden. Dabei werden allerdings nur solche Kombinationen wirklich angezeigt, die auch tats&auml;chlich existieren.",
	value => "Hier gibt man einen Filterwert an. Nur Readings, die einen passenden Wert haben, werden angezeigt. &Auml;ndert sich der Wert in FHEM, dann wird die zugeh&ouml;rige Zeile automatisch aus- bzw. eingeblendet.<br>
	Was man hier eingibt wird als regul&auml;rer Ausdruck (Regex) interpretiert. D.h. man kann damit auch nach Mustern oder mehreren Werten filtern.",
	detail => "Hier werden die anzuzeigenden Spalten ausgew&auml;hlt. Die folgenden Spalten stehen zur Verf&uuml;gung.
	<ul>
	<li><b>device</b>: das Device. Falls f&uuml;r ein Device das Attribut <i>alias</i> gesetzt ist, dann wird der entsprechende Wert angezeigt.</li>
	<li><b>reading</b>: der Name des Readings.</li>
	<li><b>value</b>: der Wert des Readings.</li>
	<li><b>timestamp</b>: der Timestamp zum Reading.</li>
	</ul>
	Die Spalten werden in der Reihenfolge angezeigt, wie sie im Feld <i>detail</i> vorkommen. Man kann also Spalten umsortieren.<br>
	Wenn man das Feld leer l&auml;sst, dann kommt es darauf an, ob man nur ein Device oder mehrere Devices ausgew&auml;hlt hat. Bei einem einzelnen Device werden dann die Spalten reading, value und timestamp angezeigt. Bei mehreren Devices werden die Spalten device und value angezeigt.
	"
);


# register me as selectable
$FUIP::View::selectableViews{"FUIP::View::ReadingsList"}{title} = "Readings-Liste"; 

1;	