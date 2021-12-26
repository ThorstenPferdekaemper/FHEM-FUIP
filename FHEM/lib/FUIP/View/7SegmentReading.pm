package FUIP::View::7SegmentReading;

use strict;
use warnings;

use lib::FUIP::View;
use parent -norequire, 'FUIP::View';
		
sub getHTML($){
	my ($self) = @_;
	my $result= '<div
		data-type = "7segment"
		data-get-value = "'.$self->{reading}{device}.':'.$self->{reading}{reading}.'" 
		data-digits="'.$self->{digits}.'"
		data-decimals="'.$self->{decimals}.'" ';
	if($self->{colorscheme} eq "temp-air") {
		$result .= 'data-limits=[-99,12,19,23,28]
					data-limit-colors=["#ffffff","#6699ff","#AA6900","#AD3333","#FF0000"] ';
	}elsif($self->{colorscheme} eq "temp-boiler") {
		$result .= 'data-limits=[-99,25,40,55,70]
					data-limit-colors=["#ffffff","#6699ff","#AA6900","#AD3333","#FF0000"] ';
	}elsif($self->{colorscheme} eq "humidity") {
		$result .= 'data-limits=[-1,20,39,59,65,79]
					data-limit-colors=["#ffffff","#6699ff","#AA6900","#AB4E19","#AD3333","#FF0000"] ';
	}else { # single color	
		$result .= 'data-color-fg="'.$self->{color}.'" ';
	};
	$result .= ' data-color-bg="rgba(255,255,255,0)"></div>';
	return $result;
};


sub dimensions($;$$){
	# 19 * digits x 30
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
		$self->{height} = 30;
	};
	if(not $self->{width} or $self->{sizing} eq "fixed") {
		$self->{width} = $self->{digits} * 19;
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
		{ id => "reading", type => "device-reading", 
			device => { },
			reading => { } },	
		{ id => "title", type => "text", default => { type => "field", value => "reading-reading"} },
		{ id => "digits", type => "text", default => { type => "const", value => "3"},
				options => ["1","2","3","4","5","6","7","8"] },
		{ id => "decimals", type => "text", default => { type => "const", value => "1"},
				options => ["0","1","2","3","4","5","6","7"] },
		{ id => "colorscheme", type => "text", default => { type => "const", value => "single" },
				options => ["single","temp-air","temp-boiler","humidity"] },
		{ id => "color", type => "setoption", 
				default => { type => "const", value => "fuip-color-symbol-active" },
				options => ["fuip-color-symbol-active","fuip-color-symbol-inactive","fuip-color-symbol-foreground","fuip-color-foreground","green","yellow","red"],
				depends => { field => "colorscheme", value => "single" } },
		{ id => "width", type => "dimension" },
		{ id => "height", type => "dimension" },
		{ id => "sizing", type => "sizing", options => [ "fixed", "resizable", "auto" ],
			default => { type => "const", value => "fixed" } },
		{ id => "popup", type => "dialog", default=> { type => "const", value => "inactive"} }		
		];
};
	
	
our %docu = (
	general => "Diese View zeigt ein numerisches Reading im 7-Segment-Design an. Es sind auch negative Zahlen und Nachkommastellen m&ouml;glich.",
	digits => 'Anzahl der Ziffern.<br>
	           Es k&ouml;nnen 1 bis 8 Ziffern (inklusive Nachkommastellen und ggf. das Minuszeichen) angezeigt werden. Wenn der Wert des Readings au&szlig;erhalb des darstellbaren Bereichs liegt, dann wird "E" bzw. "-E" angezeigt. Der Wert ist au&szlig;erhalb des darstellbaren Bereichs, wenn der Ganzzahlanteil (also das vor dem Komma) mehr Ziffern hat als bei <i>digits</i> angegeben. Bei negativen Zahlen muss man noch das Minuszeichen mit in Betracht ziehen.',
	decimals => "Anzahl der Nachkommastellen.<br>
				 Es k&ouml;nnen 0 bis 7 Nachkommastellen angezeigt werden. So lange der Ganzzahlanteil des darzustellenden Werts h&ouml;chstens <i>digits</i> - <i>decimals</i> Ziffern hat (inklusive Minuszeichen), dann werden immer <i>decimals</i> Nachkommastellen angezeigt. Gegebenenfalls wird entsprechend gerundet oder hinten mit Nullen aufgef&uuml;llt. Falls der Ganzzahlanteil zu gro&szlig; ist, dann wird das Komma (eigentlich der Dezimalpunkt) entsprechend nach rechts verschoben. Das funktioniert nat&uuml;rlich nur dann, wenn der Ganzzahlanteil nicht mehr als <i>digits</i> Stellen hat.",
	colorscheme => 'Dieser Parameter steuert die Farbgebung. Es sind folgende Werte vorgesehen:
	<ul>
		<li>single: Es wird eine feste Farbe verwendet. Wird dieser Wert ausgew&auml;hlt, dann erscheint der Parameter <i>color</i>. Ansonsten bleibt <i>color</i> ausgeblendet.</li>
		<li>temp-air: Dies ist f&uuml;r Lufttemperaturen gedacht. Die Farbgebung erfolgt je nach Temperatur, wobei &uuml;bliche Lufttemperaturen zu Grunde gelegt werden.</li>
		<li>temp-boiler: Dies ist f&uuml;r die Wassertemperatur in einer Heizung gedacht. Die Farbgebung erfolgt je nach Temperatur, wobei &uuml;bliche Wassertemperaturen in einem Heizkreislauf zu Grunde gelegt werden.</li>
		<li>humidity: Dies ist f&uuml;r relative Luftfeuchtigkeiten gedacht. Die Farbgebung erfolgt je nach Feuchtigkeit, wobei f&uuml;r Menschen angenehme Luftfeuchtigkeiten zu Grunde gelegt werden.</li>
	</ul>',	   
	color => "Farbe der Anzeige.<br>
			Dieses Feld erscheint nur, wenn <i>colorscheme</i> auf \"single\" steht. Es kann so ziemlich alles eingegeben werden, was CSS als Farbe erlaubt sowie die \"FUIP-Farbsymbole\". Mit den \"FUIP-Farbsymbolen\" passt die Anzeige zum Rest der Oberfl&auml;che, auch wenn ein anderes <i>styleSchema</i> gew&auml;hlt wird oder die Farben im \"Colours\"-Menu anders eingestellt werden. In der Werthilfe zu diesem Feld erscheinen im Wesentlichen die \"FUIP-Farbsymbole\"."
);
	
	
# register me as selectable
$FUIP::View::selectableViews{"FUIP::View::7SegmentReading"}{title} = "7-Segment-Display (Reading)"; 
	
1;	