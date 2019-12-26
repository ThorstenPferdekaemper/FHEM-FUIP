package FUIP::View::Reading;

use strict;
use warnings;

use lib::FUIP::View;
use parent -norequire, 'FUIP::View';
	
sub getDependencies($$) {
	return ['js/fuip_5_resize.js','js/fuip_reading.js'];
};	


sub _getHTML_color($){
	my ($self) = @_;
	if($self->{colorscheme} eq "temp-air") {
		return 'data-limits=[-99,12,19,23,28]
				data-colors=["#ffffff","#6699ff","#AA6900","#AD3333","#FF0000"] ';
	}elsif($self->{colorscheme} eq "temp-boiler") {
		return 'data-limits=[-99,25,40,55,70]
				data-colors=["#ffffff","#6699ff","#AA6900","#AD3333","#FF0000"] ';
	}elsif($self->{colorscheme} eq "humidity") {
		return 'data-limits=[-1,20,39,59,65,79]
				data-colors=["#ffffff","#6699ff","#AA6900","#AB4E19","#AD3333","#FF0000"] ';
	}else { # single color	
		return 'data-color="'.$self->{color}.'" ';
	};
};


sub _getHTML_unit($) {
	my ($self) = @_;
	return "" unless $self->{unit};
	if($self->{unitSize} eq "full") {
		return ' data-post-text="'.$self->{unit}.'"';
	}else{	
		return ' data-unit="'.$self->{unit}.'"';
	};	
};

	
sub _getHTML_line($){
	my ($self) = @_;
	my $result = '<div data-fuip-type="fuip-reading" class="fuip-singleline" style="display:flex;width:100%;height:100%;border-spacing:0px;';
	$result .= 'border:1px solid; border-radius:8px;padding-right:4px;padding-left:4px;' if($self->{border} eq "solid");
	$result .= '">'."\n";
	if($self->{icon}){
		$result .= '<div style="align-self:center;">
						<i class="fa '.$self->{icon}.' fuip-color" style="padding:0.14em;"></i>
					</div>';
	};
	if($self->{label}) {
		$result .= '<div class="fuip-color left" style="white-space:nowrap;overflow:hidden;text-overflow: ellipsis">'.$self->{label}.'</div>';
	};	
	if($self->{content} =~ m/^value|both$/) {
		$result .= "<div style='flex-grow:1;text-align:right;padding-left:0.1em;white-space:nowrap;' 
					data-type=\"label\" 
					data-device=\"".$self->{reading}{device}."\" 
					data-get=\"".$self->{reading}{reading}."\"".
					_getHTML_color($self).
					_getHTML_unit($self).
					"></div>" ;	
	};
				 
	if($self->{content} =~ m/^timestamp|both$/) {
		my $padding = ($self->{content} eq "both" ? "0.8" : "0.1")."em";				
		$result .= "<div style='flex-grow:1;text-align:right;padding-left:".$padding.";white-space:nowrap;'
						data-type=\"label\" 
						class=\"fuip-color timestamp\"
						data-substitution=\"toDate().ddmmhhmm()\"
						data-device=\"".$self->{reading}{device}."\"
						data-get=\"".$self->{reading}{reading}."\" ></div>";			
	};				
	$result .= "</div>"; 
	return $result;	
};


sub _getHTML_column($){
	my ($self) = @_;
	my $result = '<div data-fuip-type="fuip-reading" 
						class="fuip-color fuip-multiline" style="display:flex;width:100%;height:100%;';
	$result .= 'border:1px solid; border-radius:8px;' if($self->{border} eq "solid");
	$result .= '">'."\n";					
	if($self->{icon}){
		$result .= '<div style="align-self:center;">
						<i class="fa '.$self->{icon}.' fuip-color"></i>
					</div>';
	};
	$result .= "<div style='display:flex;flex-direction:column;margin-left:auto;margin-right:auto;'>";
	$result .= "<div data-fuip-type='fuip-reading-label' class=\"fuip-color\">".$self->{label}."</div>" if($self->{label});
	
	$result .= "<div data-type=\"label\" 
					data-fuip-type='fuip-reading-reading'
					class=\"fuip-color\"
					data-device=\"".$self->{reading}{device}."\"
					data-get=\"".$self->{reading}{reading}."\"".
					_getHTML_color($self).
					_getHTML_unit($self).
					"></div>" if $self->{content} =~ m/^value|both$/;
	$result .= "<div data-type=\"label\" 
					data-fuip-type='fuip-reading-timestamp'
					class=\"fuip-color timestamp\"
					data-substitution=\"toDate().ddmmhhmm()\"
					data-device=\"".$self->{reading}{device}."\"
					data-get=\"".$self->{reading}{reading}."\" ></div>" if $self->{content} =~ m/^timestamp|both$/;		
	$result .= "</div>";
	$result .= "</div>";
	return $result;
};		


sub getHTML($){
	my ($self) = @_;
	return _getHTML_line($self) unless $self->{layout} eq "column";
	return _getHTML_column($self);
};




sub dimensions($;$$){
	my ($self,$width,$height) = @_;
	$self->{sizing} = "fixed" unless $self->{sizing} and $self->{sizing} eq "resizable";
	if($self->{sizing} eq "resizable") {
		$self->{width} = $width if $width;
		$self->{height} = $height if $height;
	};
	# do we have to determine the size?
	# even if sizing is "auto", we at least determine an initial size
	# either resizable and no size yet
	# or fixed
	if($self->{layout} eq "line") {
		if(not $self->{height} or $self->{sizing} eq "fixed") {
			$self->{height} = 25;
		};
		if(not $self->{width} or $self->{sizing} eq "fixed") {
			$self->{width} = 65 if($self->{content} eq "value");
			$self->{width} = 125 if($self->{content} eq "timestamp");
			$self->{width} = 185 if($self->{content} eq "both");
			$self->{width} += 28 if($self->{icon});
			$self->{width} += 120 if($self->{label});
		};	
	}else{
		if(not $self->{height} or $self->{sizing} eq "fixed") {
			my $height = 17;
			$height += 17 if $self->{content} eq "both";
			$height += 17 if $self->{label};
			$height = 28 if $height < 28 and $self->{icon};
			$height += 2 if(not $self->{border} or $self->{border} eq "solid");	
			$self->{height} = $height;
		};	
		if(not $self->{width} or $self->{sizing} eq "fixed") {
			$self->{width} = main::AttrVal($self->{fuip}{NAME},"baseWidth",142);
		};	
	};
	return ($self->{width},$self->{height});
};	

	
sub getStructure($) {
# class method
# returns general structure of the view without instance values
	my ($class) = @_;
	return [
		{ id => "class", type => "class", value => $class },
		{ id => "title", type => "text", default => { type => "field", value => "reading-device"} },
		{ id => "reading", type => "device-reading", 
			device => {},
			reading => {} },	
		{ id => "icon", type => "icon" },	
		{ id => "label", type => "text" },
		{ id => "content", type => "text", options => [ "value", "timestamp", "both" ],
			 default => { type => "const", value => "value" } },
		{ id => "unit", type => "unit", 
			depends => { field => "content", regex => '^(value|both)$'} },	
		{ id => "unitSize", type => "text", options => [ "full", "half" ],
			default => { type => "const", value => "full" }, 
			depends => { field => "unit", regex => '.*\S.*' } },	
		{ id => "layout", type => "text", options => [ "line", "column" ],
			default => { type => "const", value => "line" } },
		{ id => "border", type => "text", options => [ "solid", "none" ], 
			default => { type => "const", value => "none" } }, 
		{ id => "colorscheme", type => "text", default => { type => "const", value => "single" },
				options => ["single","temp-air","temp-boiler","humidity"],
				depends => { field => "content", regex => '^(value|both)$'} },				
		{ id => "color", type => "setoption", 
				default => { type => "const", value => "fuip-color-foreground" },
				options => ["fuip-color-symbol-active","fuip-color-symbol-inactive","fuip-color-symbol-foreground","fuip-color-foreground","green","yellow","red"],
				depends => { field => "colorscheme", value => "single" } },
		{ id => "width", type => "dimension" },
		{ id => "height", type => "dimension" },
		{ id => "sizing", type => "sizing", options => [ "fixed", "resizable" ],
			default => { type => "const", value => "fixed" } },
		{ id => "popup", type => "dialog", default=> { type => "const", value => "inactive"} }			
		];
};


our %docu = (
	general => "Diese View stellt ein beliebiges Reading dar. Der Wert (und/oder der Timestamp) wird als Text angezeigt.",
	reading => "Hier wird die Device-Reading-Kombination eingegeben, auf die sich die View beziehen soll.", 
	icon => "Das hier angegebene Icon wird links im View angezeigt. ", 
	content => 'Der Inhalt der View kann der Wert des Readings, der Timestamp oder beides sein. Entsprechend kann <i>content</i> die Werte "value", "timestamp" und "both" annehmen. Der Timestamp wird im Format "12.03. 17:28" angezeigt.', 
	unit => 'Hier kann man eine Einheit eintragen, die hinter dem Wert angezeigt wird. In der Werthilfe dazu kann man sowohl die Kurzschreibweise (wie z.B. "A"), als auch den kompletten Namen der Einheit ("Ampere") ausw&auml;hlen. Der Parameter <i>unit</i> ist nur verf&uuml;gbar, wenn auch der Wert des Readings angezeigt werden soll, also <i>content</i> auf "value" oder "both" steht.', 
	unitSize => 'Wenn beim Parameter <i>unit</i> etwas eingegeben wurde, dann kann hier ausgew&auml;hlt werden, ob die Einheit normal gro&szlig; ("full") oder kleiner ("half") dargestellt werden soll.',
	layout => 'Hier kann man ausw&auml;hlen, ob alles in einer Zeile angezeigt werden soll ("line") oder &uuml;bereinander ("column"). Wird "column" ausgew&auml;hlt, dann werden Label, Wert und Timestamp &uuml;bereinander gesetzt. Das Icon ist immer links vom Rest.',
	colorscheme => 'Dieser Parameter steuert die Farbgebung des Werts des Readings. Er hat keine Auswirkung auf das Icon, das Label und den Timestamp. Der Parameter <i>colorscheme</i> ist nur verf&uuml;gbar, wenn auch der Wert des Readings angezeigt werden soll, also <i>content</i> auf "value" oder "both" steht. Es sind folgende Werte vorgesehen:
	<ul>
		<li>single: Es wird eine feste Farbe verwendet. Wird dieser Wert ausgew&auml;hlt, dann erscheint der Parameter <i>color</i>. Ansonsten bleibt <i>color</i> ausgeblendet.</li>
		<li>temp-air: Dies ist f&uuml;r Lufttemperaturen gedacht. Die Farbgebung erfolgt je nach Temperatur, wobei &uuml;bliche Lufttemperaturen zu Grunde gelegt werden.</li>
		<li>temp-boiler: Dies ist f&uuml;r die Wassertemperatur in einer Heizung gedacht. Die Farbgebung erfolgt je nach Temperatur, wobei &uuml;bliche Wassertemperaturen in einem Heizkreislauf zu Grunde gelegt werden.</li>
		<li>humidity: Dies ist f&uuml;r relative Luftfeuchtigkeiten gedacht. Die Farbgebung erfolgt je nach Feuchtigkeit, wobei f&uuml;r Menschen angenehme Luftfeuchtigkeiten zu Grunde gelegt werden.</li>
	</ul>',
	color => 'Hier wird die Farbe des Werts des Readings angegeben, wenn <i>colorscheme</i> auf "single" steht. Der Parameter hat keine Auswirkung auf Icon, Label und Timestamp. Es k&ouml;nnen insbesondere die "FUIP-Farbsymbole" ausgew&auml;hlt werden, so dass die Anzeige zum Rest der Oberfl&auml;che passt. Ansonsten kann man so ziemlich alles eingeben, was CSS als Farbe erlaubt.',
	border => "Hier kann man angeben, ob die View einen Rahmen haben soll. Bei der Option <i>solid</i> wird ein Rahmen gezeichnet, bei der Option <i>none</i> wird kein Rahmen erzeugt." 
);
	
	
# register me as selectable
$FUIP::View::selectableViews{"FUIP::View::Reading"}{title} = "Ein beliebiges Reading"; 
	
1;	