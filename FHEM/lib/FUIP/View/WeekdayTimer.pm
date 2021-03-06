package FUIP::View::WeekdayTimer;

use strict;
use warnings;

use lib::FUIP::View;
use parent -norequire, 'FUIP::View';


sub getHTML($){
	my ($self) = @_;
	# determine levels
	my $levelStr;
	if($self->{levelType} eq "heating") {
		if($self->{minLevel} > $self->{maxLevel}) {
			($self->{minLevel}, $self->{maxLevel}) = ($self->{maxLevel}, $self->{minLevel});
		};	
		for(my $level = $self->{minLevel}; $level <= $self->{maxLevel}; $level += 0.5) {
			my $temp = sprintf("%.1f",$level);
			$levelStr .= ',' if($levelStr);
			$levelStr .= '"'.$temp.'&deg;C":"'.$temp.'"';	
		};
	}elsif($self->{levelType} eq "switch") {
		$levelStr = '"'.$self->{minLevel}.'":"'.$self->{minLevel}.'", "'.$self->{maxLevel}.'":"'.$self->{maxLevel}.'"';
	}else{  # shutter/inverted_shutter
		my @levels;
		use integer;
		my $inverted = ($self->{levelType} eq "inverted_shutter");
		for (my $i=0; $i <= 10; $i++) {
			push(@levels,$self->{minLevel} + ($self->{maxLevel} - $self->{minLevel}) * $i / 10);
		};
		$levelStr = '"Auf":"'.$levels[$inverted ? 0 : 10].'"'; 		
		for (my $i=9; $i >= 1; $i--) {
			$levelStr .= ',"'.(($inverted ? (10 - $i) : $i)*10).'%":"'.$levels[$inverted ? (10 - $i) : $i].'"';
		};
		$levelStr .= ',"Zu":"'.$levels[$inverted ? 10 : 0].'"';
	};
	$self->{timeInput} = "dropdownOnly" unless $self->{timeInput};
	my $result = '
				<div data-type="fuip_wdtimer" 
					data-device="'.$self->{device}.'"    
					data-style="round noicons'.($self->{timeInput} eq "dropdownOnly" ? ' nokeyboard':'').'" 
					data-theme="dark" 
					data-title="'.($self->{label} ? $self->{label} : $self->{title}).'"  
					data-sortcmdlist="MANUELL" ';
	if($self->{saveconfig} eq "yes") {
		$result .= 'data-savecfg=true ';
	};
	$result .= 'data-cmdlist=\'{'.$levelStr.'}\'>
				</div>';
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
		$self->{height} = 300;
	};
	if(not $self->{width} or $self->{sizing} eq "fixed") {
		$self->{width} = 450;
	};	
	return ("auto","auto") if($self->{sizing} eq "auto");
	return ($self->{width},$self->{height});
};	

	
sub getDevicesForValueHelp($$) {
	# Return devices with TYPE WeekdayTimer
	my ($fuipName,$sysid) = @_;
	return FUIP::_toJson(FUIP::Model::getDevicesForType($fuipName,"WeekdayTimer",$sysid));
};	
	
	
sub getStructure($) {
	# class method
	# returns general structure of the view without instance values
	my ($class) = @_;
	return [
		{ id => "class", type => "class", value => $class },
		{ id => "device", type => "device", filterfunc => "FUIP::View::WeekdayTimer::getDevicesForValueHelp" },
		{ id => "title", type => "text", default => { type => "field", value => "device"} },
		{ id => "label", type => "text", default => { type => "field", value => "title"} },
		{ id => "saveconfig", type => "text", options => [ "yes", "no" ], 
				default => { type => "const", value => "no" }},
		{ id => "levelType", type => "text", options => [ "shutter", "inverted_shutter", "heating", "switch" ], 
				default => { type => "const", value => "shutter" }},
		{ id => "minLevel", type => "text", default => { type => "const", value => "0" } },
		{ id => "maxLevel", type => "text", default => { type => "const", value => "100" } },
		{ id => "timeInput", type => "text", options => [ "keyboardAllowed", "dropdownOnly" ], 				
				default => { type => "const", value => "dropdownOnly" }},
		{ id => "width", type => "dimension" },
		{ id => "height", type => "dimension" },
		{ id => "sizing", type => "sizing", options => [ "fixed", "auto", "resizable" ],
			default => { type => "const", value => "resizable" } }
		];
};

our %docu = (
	general => "Die View <i>WeekdayTimer</i> ist eine Sicht auf ein WeekdayTimer-Device in FHEM.<br>
				Man kann damit die meisten \"normalen\" Einstellungen &uuml;ber die FUIP-Oberfl&auml;che vornehmen. Anders als andere &auml;hnliche Views erzeugt <i>WeekdayTimer</i> allerdings nicht automatisch ein Popup, sondern wird ganz normal in eine Zelle eingebunden. Falls man den WeekdayTimer auf einem Popup haben m&ouml;chte, muss man explizit die View <i>Popup</i> verwenden bzw. eine andere Popup-f&auml;higen View. Wenn die View WeekdayTimer auf einem Popup platziert wird, dann schlie&szlig;en die Tasten \"Speichern\" und \"Abbrechen\" das Popup.<br>
				Die m&ouml;glichen Schaltbefehle werden durch die Parameter <i>levelType</i>, <i>minLevel</i> und <i>maxLevel</i> festgelegt. Insbesondere der Unterschied zwischen \"shutter\" und \"inverted_shutter\" ist manchmal verwirrend. Im Prinzip wird durch \"inverted_shutter\" nur die Reihenfolge der Prozentangaben umgedreht und \"Auf\" und \"Zu\" werden vertauscht. D.h. \"Auf\" entspricht <i>minLevel</i> (meistens 0) und \"Zu\" entspricht <i>maxLevel</i> (meistens 100). Das klingt im ersten Moment sehr &auml;hnlich wie beim Vertauschen von <i>minLevel</i> und <i>maxLevel</i>, allerdings ist dann auch die Zuordnung der Prozentangaben zu den Werten in FHEM umgedreht. Die folgende Tabelle soll das ganze verdeutlichen:
<table>
<tr><td><b>levelType</b></td><td><b>minLevel</b></td><td><b>maxLevel</b></td><td><b>Ergebnis (Anzeige in FUIP:Wert in FHEM)</b></td></tr>
<tr><td>shutter</td><td>0</td><td>100</td><td>Auf:100, 90%:90, 80%:80,... 20%:20, 10%:10, Zu:0</td></tr>
<tr><td>shutter</td><td>100</td><td>0</td><td>Auf:0, 90%:10, 80%:20,... 20%:80, 10%:90, Zu:100</td></tr>
<tr><td>inverted_shutter</td><td>0</td><td>100</td><td>Auf:0, 10%:10, 20%:20,... 80%:80, 90%:90, Zu:100</td></tr>
<tr><td>inverted_shutter</td><td>100</td><td>0</td><td>Auf:100, 10%:90, 20%:80,... 80%:20, 90%:10, Zu:0</td></tr>
</table>",
	device => "Dieser Parameter enth&auml;lt das WeekdayTimer-Device in FHEM.<br>
			Das Device muss ein WeekdayTimer-Device sein, andere Devices sind nicht m&ouml;glich. Insbesondere bezieht sich dieser Parameter <b>nicht</b> auf das vom WeekdayTimer gesteuerte Device.",
	label => "&Uuml;berschrift der View<br>
			Was man hier eingibt wird in der Titelzeile der View (also oben &uuml;ber der Liste mit den Schaltzeiten) angezeigt. Gibt man hier nichts an, dann wird der Text aus dem Feld <i>title</i> genommen.",
	saveconfig => "<i>save config</i> automatisch ausl&ouml;sen<br>
			Die View <i>WeekdayTimer</i> macht eine \"strukturelle &Auml;nderung\" in FHEM, da die Schaltprofile Teil der Device-Definition sind. Um solche &Auml;nderungen einen FHEM-Restart &uuml;berstehen zu lassen, muss man explizit ein <i>save config</i> absetzen. Wenn <i>saveconfig</i> auf \"yes\" gesetzt wird, dann &uuml;bernimmt die View das automatisch. Allerdings sollte man dabei bedenken, dass dadurch jede strukturelle &Auml;nderung gespeichert wird, nicht nur die durch diese View hervorgerufene.",
	levelType => 'Dies steuert, welche Schaltbefehle m&ouml;glich sind<br>
			Dieser Parameter kann die folgenden Werte annehmen:
			<ul>
			<li><b>shutter</b>: Diese Option ist f&uuml;r Rollladensteuerungen gedacht, bei denen "Auf" 100% entspricht. Als m&ouml;gliche Schaltbefehle werden dann "Auf", "90%", "80%",... ,"10%", "Zu" angeboten.
			<li><b>inverted_shutter</b>: Diese Option ist f&uuml;r Rollladensteuerungen gedacht, bei denen "Auf" 0% entspricht. Als m&ouml;gliche Schaltbefehle werden dann "Auf", "10%", "20%",... ,"90%", "Zu" angeboten.</li>
			<li><b>heating</b>: Diese Option ist f&uuml;r Thermostate (oder allgemein: Temperaturen) gedacht. Es werden alle Werte von <i>minLevel</i> bis <i>maxLevel</i> in Schritten zu 0,5&deg; angeboten.</li>
			<li><b>switch</b>: Bei dieser Option werden nur die zwei Werte in <i>minLevel</i> und <i>maxLevel</i> als Schaltbefehl angeboten. Dies ist insbesondere f&uuml;r reine Schalter sinnvoll. In dem Fall k&ouml;nnte dann <i>minLevel</i> = "on" und <i>maxLevel</i> = "off" gesetzt werden.</li>
			</ul>',
	minLevel => 'Kleinster m&ouml;glicher Schaltbefehl<br>
			Was das genau bedeutet, h&auml;ngt von <i>levelType</i> ab. 
			<ul>
			<li>Bei "shutter" ist das der Wert, der f&uuml;r "Zu" gesendet wird, also normalerweise "0".</li>
			<li>Bei "inverted_shutter ist das der Wert, der f&uuml;r "Auf" gesendet wird.</li> 
			<li>Bei "heating" ist es die kleinste einstellbare Temperatur (ohne das Grad-Zeichen).</li> 
			<li>Bei "switch" ist es einfach einer der beiden Werte.</li>
			</ul>
			Es ist auch erlaubt, in <i>minLevel</i> einen gr&ouml;&szlig;eren Wert als in <i>maxLevel</i> einzutragen: 
			<ul>
			<li>Bei "shutter" oder "inverted_shutter" wird dann einfach r&uuml;ckw&auml;rts gerechnet. 100% entspricht immer <i>maxLevel</i>, auch wenn das 0 sein sollte. Die restlichen Werte werden dann einfach linear zwischen 0% und 100% aufgeteilt.</li>
			<li>Bei "heating" wird dann <i>minLevel</i> und <i>maxLevel</i> vertauscht.</li> 
			<li>Bei "switch" spielt es sowieso keine Rolle.</li>
			</ul>',
	maxLevel => 'Gr&ouml;&szlig;ter m&ouml;glicher Schaltbefehl<br>
			Was das genau bedeutet, h&auml;ngt von <i>levelType</i> ab. 
			<ul>
			<li>Bei "shutter" ist das der Wert, der f&uuml;r "Auf" gesendet wird, also normalerweise "100".</li>
			<li>Bei "inverted_shutter ist das der Wert, der f&uuml;r "Zu" gesendet wird.</li> 
			<li>Bei "heating" ist es die gr&ouml;&szlig;te einstellbare Temperatur (ohne das Grad-Zeichen).</li> 
			<li>Bei "switch" ist es einfach einer der beiden Werte.</li>
			</ul>
			Es ist auch erlaubt, in <i>maxLevel</i> einen kleineren Wert als in <i>minLevel</i> einzutragen. Beim Feld <i>minLevel</i> wird erkl&auml;rt, was das bedeutet.',
	timeInput => 'Steuert, ob die Zeiten auch &uuml;ber die Tastatur eingegeben werden d&uuml;rfen<br>
			Normalerweise werden die Schaltzeiten nur &uuml;ber ein Dropdown-Feld ausgew&auml;hlt. (<i>timeInput</i> = "dropdownOnly"). Man kann hier aber auch "keyboardAllowed" w&auml;hlen, um Zeiten auch &uuml;ber die Tastatur eingeben zu k&ouml;nnen.'
);


# register me as selectable
$FUIP::View::selectableViews{"FUIP::View::WeekdayTimer"}{title} = "Wochen-Zeitschaltuhr"; 
	
1;	