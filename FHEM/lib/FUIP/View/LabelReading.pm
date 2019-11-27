package FUIP::View::LabelReading;

use strict;
use warnings;

use lib::FUIP::View;
use parent -norequire, 'FUIP::View';

sub getDependencies($$) {
	return ['js/fuip_5_resize.js','js/fuip_labelreading.js'];
};	

sub _getHTML_flex($){
	my ($self) = @_;
	my $result = "<div data-fuip-type='fuip-labelreading' 
						class=\"fuip-color\" style='display:flex;width:100%;height:100%;";
	$result .= 'border:1px solid; border-radius:8px;' if(not $self->{border} or $self->{border} eq "solid");
	$result .= "'>\n";					
	if($self->{icon}){
		$result .= '<div style="align-self:center;">
						<i class="fa '.$self->{icon}.' fuip-color"></i>
					</div>';
	};
	$result .= "<div style='display:flex;flex-direction:column;margin-left:auto;margin-right:auto;'>";
	$result .= "<div data-fuip-type='fuip-labelreading-label' class=\"fuip-color\">".$self->{label}."</div>" if($self->{label});
	
	$result .= "<div data-type=\"label\" 
					data-fuip-type='fuip-labelreading-reading'
					class=\"fuip-color\"
					data-device=\"".$self->{reading}{device}."\"
					data-get=\"".$self->{reading}{reading}."\"".
					($self->{unit} ? ' data-post-text="'.$self->{unit}.'"' : '').
					"></div>" if $self->{content} =~ m/^value|both$/;
	$result .= "<div data-type=\"label\" 
					data-fuip-type='fuip-labelreading-timestamp'
					class=\"fuip-color timestamp\"
					data-substitution=\"toDate().ddmmhhmm()\"
					data-device=\"".$self->{reading}{device}."\"
					data-get=\"".$self->{reading}{reading}."\" ></div>" if $self->{content} =~ m/^timestamp|both$/;		
	$result .= "</div>";
	$result .= "</div>";
	return $result;
};		


sub _getHTML_fixed($){
	my ($self) = @_;
	$self->{content} = "value" unless $self->{content};
	# show reading
	my $result = '<table width="100%" class="fuip-color" style="border-spacing: 0px;';
	$result .= 'border:1px solid; border-radius:8px;' if(not $self->{border} or $self->{border} eq "solid");
	$result .= '">'."\n";
	if($self->{icon}){
		$result .= '<tr><td style="vertical-align:center">
							<i class="fa '.$self->{icon}.' fuip-color" style="font-size:26px"></i>
					</td><td style="padding:0px;"><table style="border-collapse: collapse; border-spacing: 0px;">'."\n";
	};
	$result .= "<tr><td class=\"fuip-color\">".$self->{label}."</td></tr>" if($self->{label});
	$result .= "<tr><td><div data-type=\"label\" 
							 class=\"fuip-color\"
							 data-device=\"".$self->{reading}{device}."\"
							 data-get=\"".$self->{reading}{reading}."\"".
							 ($self->{unit} ? ' data-post-text="'.$self->{unit}.'"' : '').
							 ">
				</div></td></tr>"	if $self->{content} =~ m/^value|both$/;
	$result .= "<tr><td><div data-type=\"label\" 
							 class=\"fuip-color timestamp\"
							 data-substitution=\"toDate().ddmmhhmm()\"
							 data-device=\"".$self->{reading}{device}."\"
							 data-get=\"".$self->{reading}{reading}."\">
				</div></td></tr>"	if $self->{content} =~ m/^timestamp|both$/;		
	if($self->{icon}){
		$result .= '</table></td></tr>';
	};
	$result .= "</table>";
	return $result;
};


sub getHTML($){
	my ($self) = @_;
	$self->{sizing} = "fixed" unless $self->{sizing};
	return $self->_getHTML_fixed() if $self->{sizing} eq "fixed";
	return $self->_getHTML_flex();	
};	
	
	
sub dimensions($;$$){
	my ($self,$width,$height) = @_;
	$self->{sizing} = "fixed" unless $self->{sizing};
	if($self->{sizing} eq "resizable") {
		$self->{width} = $width if $width;
		$self->{height} = $height if $height;
	};
	$self->{content} = "value" unless $self->{content};
	# none: 17
	# border: 19
	# icon:	28
	# border, icon: 30
	# label: 34
	# icon, label: 34
	# border, label: 36
	# border, icon, label: 36
	
	# border always +2
	# label => 34
	# else icon => 28
	# else 17
	# do we have to determine the size?
	# even if sizing is "auto", we at least determine an initial size
	# either resizable and no size yet
	# or fixed
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
		{ id => "label", type => "text", default => { type => "field", value => "title"} },
		{ id => "icon", type => "icon" },
		{ id => "content", type => "text", options => [ "value", "timestamp", "both" ],
			default => { type => "const", value => "value" } },	
		{ id => "unit", type => "unit" },	
		{ id => "border", type => "text", options => [ "solid", "none" ], 
			default => { type => "const", value => "solid" } }, 
		{ id => "width", type => "dimension" },
		{ id => "height", type => "dimension" },
		{ id => "sizing", type => "sizing", options => [ "fixed", "auto", "resizable" ],
			default => { type => "const", value => "fixed" } },	
		{ id => "popup", type => "dialog", default=> { type => "const", value => "inactive"} }		
		];
};

our %docu = (
	general => "Diese View stellt ein beliebiges Reading dar. Der Wert (und/oder der Timestamp) wird als Text angezeigt.",
	reading => "Hier wird die Device-Reading-Kombination eingegeben, auf den sich die View beziehen soll.", 
	icon => "Das hier angegebene Icon wird links im View angezeigt. ", 
	content => 'Der Inhalt der View kann der Wert des Readings, der Timestamp oder beides sein. Entsprechend kann <i>content</i> die Werte "value", "timestamp" und "both" annehmen. Der Timestamp wird im Format "12.03. 17:28" angezeigt.', 
	unit => 'Hier kann man eine Einheit eintragen, die hinter dem Wert angezeigt wird. In der Werthilfe dazu kann man sowohl die Kurzschreibweise (wie z.B. "A"), als auch den kompletten Namen der Einheit ("Ampere") ausw&auml;hlen.', 
	border => "Hier kann man angeben, ob die View einen Rahmen haben soll. Bei der Option <i>solid</i> wird ein Rahmen gezeichnet, bei der Option <i>none</i> wird kein Rahmen erzeugt." 
);


# register me as selectable
$FUIP::View::selectableViews{"FUIP::View::LabelReading"}{title} = "Ein Reading als Text anzeigen"; 

1;	