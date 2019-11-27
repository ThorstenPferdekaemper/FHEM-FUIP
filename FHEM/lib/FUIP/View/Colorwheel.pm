package FUIP::View::Colorwheel;

use strict;
use warnings;
use lib::FUIP::View;
use parent -norequire, 'FUIP::View';
	
sub getDependencies($$) {
	return ['js/fuip_5_resize.js'];
};	
	
sub getHTML($){
	my ($self) = @_;
	my $result = '
		<div data-type="fuip_colorwheel"
			data-fuip-type="fuip-colorwheel"
			data-device="'.$self->{device}.'"
			data-get="'.$self->{reading}.'"
			data-set="'.$self->{set}.'"
			class="roundIndicator"
			style="width:100%;height:';
	if($self->{label}) {
		$result .= 'calc(100% - 20px)';
	}else{
		$result .= 'calc(100% - 5px)';
	};
	$result .= '">
		</div>';
	if($self->{label}) {
		$result .= '<div class="fuip-color" style="height:15px">'.$self->{label}.'</div>';
	};	
	return $result;
};


sub dimensions($;$$){
	my ($self,$width,$height) = @_;
	$self->{sizing} = "fixed" unless $self->{sizing};
	if($self->{sizing} eq "resizable") {
		$self->{width} = $width if $width;
		$self->{height} = $height if $height;
	};
	# do we have to determine the size?
	# even if sizing is "auto", we at least determine an initial size
	# either resizable and no size yet
	# or fixed
	if(not $self->{height} or $self->{sizing} eq "fixed") {
		$self->{height} = 200;
		$self->{height} += 17 if $self->{label};
	};
	if(not $self->{width} or $self->{sizing} eq "fixed") {
		$self->{width} = 160;
	};	
	return ("auto","auto") if($self->{sizing} eq "auto");
	return ($self->{width},$self->{height});
};	
	
	
sub getStructure($) {
	# class method
	# returns general structure of the view without instance values
	my ($class) = @_;
	return [
		{ id => "class", type => "class", value => $class },
		{ id => "device", type => "device" },	
		{ id => "title", type => "text", default => { type => "field", value => "device"} },
		{ id => "label", type => "text" },
		{ id => "set", type => "set", refdevice => "device", default => { type => "const", value => "rgb" } },
		{ id => "reading", type => "reading", refdevice => "device", default => { type => "field", value => "set"}},
		{ id => "width", type => "dimension" },
		{ id => "height", type => "dimension" },
		{ id => "sizing", type => "sizing", options => [ "fixed", "auto", "resizable" ],
			default => { type => "const", value => "fixed" } },
		];
};

our %docu = (
	general => "Farbauswahl im RGB-Format<br>
		Mit der View <i>Colorwheel</i> kann man Geräte steuern, die Farben im RGB-Format akzeptieren bzw. bereitstellen, wie z.B. Hue-Leuchten. Die View entspricht ungef&auml;hr dem FTUI-Widget \"colorwheel\", wobei FUIP eine eigene Implementierung bereitstellt, die beim Sizing flexibler ist.",
	device => "Das Device, auf das sich die Farbauswahl bezieht. Das kann z.B. eine Leuchte vom Typ HUEDevice sein.",
	label => "Der hier eingetragene Text erscheint unter der Farbauswahl, also am unteren Rand der View. Man kann das Label auch leer lassen.",
	set => "Set-Option, die eine Farbe im RGB-Hex-Format akzeptiert.<br>
		Beim Setzen der Farbe ruft die View folgenden FHEM-Befehl auf: <i>set &lt;device&gt; &lt;set&gt; RRGGBB</i>. Defaultwert ist \"rgb\". Bei Hue-Leuchten ergibt sich also normalerweise so etwas wie <i>set myHueDevice rgb FF0000</i>, wenn man die Lampe auf Rot setzt.",
	reading => "Reading, welches die aktuelle Farbe im RGB-Hex-Format enth&auml;lt.<br>
		Defaultwert ist das, was bei <i>set</i> eingetragen wurde." 
);

# register me as selectable
$FUIP::View::selectableViews{"FUIP::View::Colorwheel"}{title} = "Farbauswahl"; 

1;	