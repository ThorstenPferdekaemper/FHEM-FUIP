package FUIP::View::MenuItem;

use strict;
use warnings;

use lib::FUIP::View;
use parent -norequire, 'FUIP::View';


sub _convertFromOldVersion($) {
	my ($self) = @_;
	return unless(not $self->{linkType} or $self->{linkType} eq "fuip-page" and $self->{link} and not $self->{pageid});
	if(substr($self->{link},0,1) eq "/") {
		$self->{linkType} = "ftui-link";
		$self->{defaulted}{linkType} = 0;
	}else{
		$self->{linkType} = "fuip-page";
		$self->{pageid} = $self->{link};
		$self->{link} = "";
	};
};


sub getHTML($){
	my ($self) = @_;
	my $class = "fuip-menu-item";
	my $color = "fuip-color-menuitem";
	if($self->{active}) {
		$class = "fuip-menu-item-active";
		$color = "fuip-color-menuitem-active";
	};
	$self->_convertFromOldVersion();
	# my $link = (substr($self->{link},0,1) eq "/" ? $self->{link} : "/fhem/".lc($self->{fuip}{NAME})."/page/".$self->{link});
	my $link = "";
	if($self->{linkType} eq "fuip-page") {
		$link = 'data-url="'.FUIP::urlBase($self->{fuip}).'/page/'.$self->{pageid}.'"'; 
	}elsif($self->{linkType} eq "ftui-link") {
		$link = 'data-url="'.$self->{link}.'"';
	}elsif($self->{linkType} eq "fhem-reading") {
		$link = 'data-device="'.$self->{device}.'" data-get="'.$self->{reading}.'"';
	};
	return '	
		<div data-type="link" data-color="'.$color.'" data-background-color="'.$class.'" '.$link.'  
			data-icon="'.$self->{icon}.'" class="'.$class.'" data-height="calc(100% - 2px)">'.$self->{text}.'</div>';	
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
		$self->{height} = 38;
	};
	if(not $self->{width} or $self->{sizing} eq "fixed") {
		$self->{width} = main::AttrVal($self->{fuip}{NAME},"baseWidth",142);
	};	
	return ($self->{width},$self->{height});
};
	
	
sub getStructure($) {
	# class method
	# returns general structure of the view without instance values
	my ($class) = @_;
	return [
		{ id => "class", type => "class", value => $class },
		{ id => "text", type => "text" },
		{ id => "title", type => "text", default => { type => "field", value => "text"} },
		{ id => "linkType", type => "text", options => [ "ftui-link", "fuip-page", "fhem-reading" ], 
					default => { type => "const", value => "fuip-page" } },
		{ id => "link", type => "link",	depends => { field => "linkType", value => "ftui-link" } },
		{ id => "pageid", type => "pageid",	depends => { field => "linkType", value => "fuip-page" } },
		{ id => "device", type => "device",	depends => { field => "linkType", value => "fhem-reading" } },
		{ id => "reading", type => "reading", refdevice => "device", depends => { field => "linkType", value => "fhem-reading" } },
		{ id => "icon", type => "icon" },
		# TODO: proper "boolean" drop down
		{ id => "active", type => "boolean", value => "0" },
		{ id => "width", type => "dimension" },
		{ id => "height", type => "dimension" },
		{ id => "sizing", type => "sizing", options => [ "fixed", "resizable" ],
			default => { type => "const", value => "fixed" } }		
		];
};


sub reconstruct($$$) {
	my ($class,$conf,$fuip) = @_;
	my $self = FUIP::View::reconstruct($class,$conf,$fuip);
	$self->_convertFromOldVersion();
	return $self;
};


our %docu = (
	general => 
		"Ein <i>MenuItem</i>, also ein Men&uuml;-Eintrag ist im Prinzip ein Hyperlink. D.h. beim Klick auf diese View wird normalerweise die komplette Seite durch eine neue ersetzt. Wenn man mehrere <i>MenuItems</i> &uuml;ber- oder nebeneinander setzt, dann erh&auml;lt man ein Men&uuml;. Es gibt keine eigene View f&uuml;r ein ganzes Men&uuml;, es wird aber empfohlen, die Men&uuml;s einer FUIP-Oberfl&auml;che als View Template anzulegen, da die Men&uuml;s verschiedener Seiten meistens im Wesentlichen gleich sind.",
	text => "Dies ist der Text, der im Men&uuml;-Eintrag erscheint.",
	linkType => 'Die View <i>MenuItem</i> kann zu anderen FUIP-Seiten springen, aber auch zu allgemeinen Hyperlinks und zu Hyperlinks, die in Readings gespeichert sind. Daf&uuml;r kann <i>linkType</i> drei verschiedene Werte annehmen:
		<ul>
			<li><b>fuip-page</b> bedeutet, dass das Navigationsziel eine Seite desselben FUIP-Device ist. Wenn man "fuip-page" ausw&auml;hlt, dann erscheint der Parameter <i>pageid</i> mit einer Werthilfe, die alle (bereits generierten) Seiten des aktuellen FUIP-Device anzeigt. "fuip-page" ist sozusagen der Normalfall f&uuml;r ein Men&uuml; und damit auch die Voreinstellung.</li>
			<li><b>ftui-link</b> bedeutet, dass das Navigationsziel ein allgemeiner Link ist, wie man ihn auch im Tablet-UI (ohne FUIP) verwenden k&ouml;nnte. Wenn man "ftui-link" ausw&auml;hlt, dann erscheint das Feld <i>link</i>.</li> 
			<li><b>fhem-reading</b> ermittelt das Navigationsziel aus einem Reading eines FHEM-Devices. Wenn man "fhem-reading" ausw&auml;hlt, dann erscheinen die Felder <i>device</i> und <i>reading</i> mit den &uuml;blichen Werthilfen.</li>
		</ul>',
	pageid => 'Eine FUIP-Seite (derselben FUIP-Instanz). Das Feld ist nur sichtbar, wenn der Parameter <i>linkType</i> auf "fuip-page" steht. Am besten, man w&auml;hlt die gew&uuml;nschte Seite per Werthilfe aus. Man kann aber auch &uuml;ber ein <i>MenuItem</i> schnell eine neue Seite anlegen. Dazu tr&auml;gt man einfach den gew&uuml;nschten Seitennamen ein und klickt auf den Men&uuml;eintrag. Dadurch wird die Seite automatisch angelegt.',	
	link => 'Ein allgemeiner Hyperlink, der beim Klick auf das <i>MenuItem</i> angesprungen wird. Das Feld ist nur sichtbar, wenn der Parameter <i>linkType</i> auf "ftui-link" steht. Der Wert in diesem Feld kann dann zum Beispiel folgendes bedeuten:
		<ul>
			<li>Alles, was mit einem "/" beginnt, wird relativ zum FHEM-Server (auf dem FUIP l&auml;uft) interpretiert. Der Eintrag "/fhem?room=kitchen" w&uuml;rde FHEMWEB aufrufen und den Raum "kitchen" anzeigen.<br>
			Man kann damit auch zu Seiten anderer FUIP-Instanzen springen. Der Eintrag "/fhem/ui2/page/room/kitchen" w&uuml;rde zur Seite "room/kitchen" der FUIP-Instanz "ui2" springen.</li>
			<li>Relative links, die nicht mit "/" beginnen, rufen Dateien aus dem Tablet-UI	Installationsverzeichnis auf. Der Eintrag "demo_ftui.html" startet (zumindest bei mir) die Tablet-UI Demoseite.</li>
			<li>Komplette URLs werden einfach so aufgerufen, wie sie sind. Man kann z.B. "http://google.de" eingeben und erh&auml;lt... (Ja was wohl?)</li>
		</ul>',
	device => 'Dies ist das FHEM-Device zum Reading, aus dem der anzuspringende Hyperlink genommen wird. Dieses Feld wird sichtbar, wenn wenn der Parameter <i>linkType</i> auf "fhem-reading" steht. Weiteres ist beim Parameter <i>reading</i> erkl&auml;rt.',
	reading => 'Dies ist das FHEM-Reading, aus dem der anzuspringende Hyperlink genommen wird. Dieses Feld wird sichtbar, wenn wenn der Parameter <i>linkType</i> auf "fhem-reading" steht. Das hier gew&auml;hlte Reading muss einen Link wie oben unter "ftui-link" beschrieben enthalten. Das bedeutet, dass man nicht einfach den Namen einer FUIP-Seite eintragen kann (wie z.B. "room/kitchen"). Statt dessen muss der ganze Pfad inklusive FUIP-Device im Reading stehen, also z.B. "/fhem/ui/page/room/kitchen".',
	icon => "Das hier ausgew&auml;hlte Icon wird im Men&uuml;eintrag vor dem Text angezeigt.",
	active => 'Dieses Feld zeigt an, ob der Men&uuml;eintrag als aktiv oder inaktiv dargestellt werden soll. Es wird einer der Werte 0 oder 1 erwartet. Bei "1" wird der Men&uuml;eintrag als aktiv angezeigt, bei "0" als inaktiv. Normalerweise setzt man einen Men&uuml;eintrag auf aktiv, wenn er zu der Seite geh&ouml;rt, auf der man gerade ist. Wenn man sich ein ganzes Men&uuml; als View-Template zusammenstellt, dann sollte man den Parameter <i>active</i> aller Men&uuml;eintr&auml;ge als Variable anlegen. (Nat&uuml;rlich mit unterschiedlichen Namen.) So kann man das Men&uuml; auf jeder Seite wiederverwenden und muss nur den richtigen <i>active</i>-Parameter setzen.'
);
		

# register me as selectable
$FUIP::View::selectableViews{"FUIP::View::MenuItem"}{title} = "Ein Menu-Eintrag"; 
	
1;	