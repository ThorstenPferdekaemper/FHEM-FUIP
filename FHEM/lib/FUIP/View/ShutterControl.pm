package FUIP::View::ShutterControl;

use strict;
use warnings;

use lib::FUIP::View;
use parent -norequire, 'FUIP::View';
	
	
sub getHTML($){
	my ($self) = @_;
	my $device = $self->{device};
	# for old instances
	$self->{dirReading} = "direction" unless($self->{dirReading});	
	$self->{dirUp} = "up" unless($self->{dirUp});	
	$self->{dirDown} = "down" unless($self->{dirDown});	
	# icons Closed ... Open
	my @icons = (
				"oa-fts_shutter_100","oa-fts_shutter_90",
				"oa-fts_shutter_80","oa-fts_shutter_70","oa-fts_shutter_60","oa-fts_shutter_50",
				"oa-fts_shutter_40","oa-fts_shutter_30","oa-fts_shutter_20","oa-fts_shutter_10","oa-fts_window_2w");
	# "hardware" levels min ... max (usually 0 ... 100)
	use integer;
	my @levels;
	for (my $i=0; $i <= 10; $i++) {
		push(@levels,$self->{minLevel} + ($self->{maxLevel} - $self->{minLevel}) * $i / 10);
	};
	my @iconLevels = @levels;
	# percentages Auf, 90%, 80% ... 10%, Zu
	my @texts;
	if($self->{levelType} eq "inverted_shutter") {
		@texts = ("Auf","10%","20%","30%","40%","50%","60%","70%","80%","90%","Zu");
	}else{	
		@texts = ("Auf","90%","80%","70%","60%","50%","40%","30%","20%","10%","Zu");
		@levels = reverse(@levels);
	};	
	# data-states in symbol always needs to be ascending	
	# for "reverse" shutters, we need to reverse the icon list
	if($self->{minLevel} > $self->{maxLevel}) {
		@icons = reverse(@icons);
		@iconLevels = reverse(@iconLevels);
	};
	# for "inverted_shutter", we need to invert the icon list
	@icons = reverse(@icons) if $self->{levelType} eq "inverted_shutter";
	my $result = '
		<div style="position:relative;">
		<table>	
			<tr>
				<td>
					<div data-type="symbol" class="cell bigger left" data-device="'.$device.'" data-get="'.$self->{readingLevel}.'"
                    data-icons=\'["'.join('","',@icons).'"]\'
					data-states=\'["'.join('","',@iconLevels).'"]\'
					data-background-colors=\'['.('"fuip-color-symbol-active",' x 10).'"fuip-color-symbol-active"]\' 
					data-colors=\'['.('"fuip-color-symbol-foreground",' x 10).'"fuip-color-symbol-foreground"]\' 
					data-background-icons=\'["fa-square","fa-square","fa-square","fa-square","fa-square","fa-square","fa-square","fa-square","fa-square","fa-square","fa-square"]\'>
					</div>';
	if($self->{label}) {
		$result .= '<div class="fuip-color" style="position:absolute; top:122px;left:0px;width:126px;text-align:center">'
						.$self->{label}
					.'</div>';
	};	
	$result .= '</td>
				<td width="60">  
					<div class="triplebox-v left" >
						<div data-type="push" data-device="'.$device.'" data-icon="fa-chevron-up" 
							data-background-icon="fa-square-o" 	data-set-on="'.$self->{setUp}.'" 
							data-get="'.$self->{dirReading}.'" data-get-on="'.$self->{dirUp}.'"
							class=""> 
						</div>
						<div data-type="push" data-device="'.$device.'" data-icon="fa-minus" 
							data-background-icon="fa-square-o" data-set-on="'.$self->{setStop}.'" class=""> 
						</div>
						<div data-type="push" data-device="'.$device.'" data-icon="fa-chevron-down" 
							data-background-icon="fa-square-o" data-set-on="'.$self->{setDown}.'" 
							data-get="'.$self->{dirReading}.'" data-get-on="'.$self->{dirDown}.'"
							class=""> 
						</div>
					</div> 
				</td>
				<td>
					<div data-type="fuip_numselect" data-device="'.$device.'" 
						data-items=\'['.join(',',@levels).']\' 
						data-alias=\'["'.join('","',@texts).'"]\' 
						data-get="'.$self->{readingLevel}.'" data-set="'.$self->{setLevel}.'"
						style="width:65px">
					</div>
				</td>
			</tr>';
	$result .= '</table>';
	if($self->{timer}) {
		my $cmdStr;
		for(my $i = 0; $i <= 10; $i++) {
			$cmdStr .= ',' if $cmdStr;
			$cmdStr .= '"'.$texts[$i].'":"'.$levels[$i].'"';
		};
		$result .= '
		<div style="position:absolute; top:92px; left:210px;"
			data-type="fuip_wdtimer" 
			data-device="'.$self->{timer}.'"    
			data-width="450"
			data-style="round noicons" 
			data-theme="dark" 
			data-title="'.$device.'"  
			data-sortcmdlist="MANUELL"
			data-cmdlist=\'{'.$cmdStr.'}\'>
			<div data-type="button" class="cell small readonly" data-icon="oa-edit_settings" data-background-icon="fa-square-o" 
					data-on-color="#505050" data-on-background-color="#505050">
			</div>
		</div>';
	};
	$result .= '</div>';
	return $result;
};


sub dimensions($;$$){
	return (260,148);
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
		{ id => "setUp", type => "set", refdevice => "device", default => { type => "const", value => "up" } },
		{ id => "setStop", type => "set", refdevice => "device", default => { type => "const", value => "stop" } },
		{ id => "setDown", type => "set", refdevice => "device", default => { type => "const", value => "down" } },
		{ id => "setLevel", type => "set", refdevice => "device", default => { type => "const", value => "level" } },
		{ id => "readingLevel", type => "reading", refdevice => "device", default => { type => "field", value => "setLevel"}},
		{ id => "levelType", type => "text", options => [ "shutter", "inverted_shutter" ], 
				default => { type => "const", value => "shutter" }},
		{ id => "minLevel", type => "text", default => { type => "const", value => "0" } },
		{ id => "maxLevel", type => "text", default => { type => "const", value => "100" } },
		{ id => "dirReading", type => "reading", refdevice => "device", default => { type => "const", value => "direction" } },
		{ id => "dirUp", type => "text", default => { type => "const", value => "up" } },
		{ id => "dirDown", type => "text", default => { type => "const", value => "down" } },
		{ id => "timer", type => "device", default => { type => "field", value => "device", suffix => "Timer" } }
		];
};

our %docu = (
	general => "Diese View eignet sich, um einen Rollladen zu steuern. Man kann damit einen Rollladen (oder &auml;hnliches) &ouml;ffnen und schlie&szlig;en, auf einen bestimmten Prozentwert fahren sowie eine Wochen-Zeitschaltuhr aufrufen, um das ganze zu automatisieren.<br>
	Der im Select-Widget angezeigte Prozentwert ist nicht unbedingt genau der Wert, bei dem der Rollladen momentan steht. Es wird der Wert aus der Liste der m&ouml;glichen Werte des Select-Widgets angezeigt, der am n&auml;chsten am tats&auml;chlichen Wert liegt.<br>
	Die meisten Rollladenaktoren lassen sich &uuml;ber Prozentwerte steuern. Allerdings gibt es Unterschiede in der Interpretation, ob die 100% oben oder unten sind. Daf&uuml;r gibt es die Parameter <i>levelType</i>, <i>minLevel</i> und <i>maxLevel</i>. Durch <i>levelType</i> \"inverted_shutter\" wird die Reihenfolge der Prozentangaben umgedreht und \"Auf\" und \"Zu\" werden vertauscht. D.h. \"Auf\" entspricht <i>minLevel</i> (meistens 0) und \"Zu\" entspricht <i>maxLevel</i> (meistens 100). Das klingt im ersten Moment sehr &auml;hnlich wie beim Vertauschen von <i>minLevel</i> und <i>maxLevel</i>, allerdings ist dann auch die Zuordnung der Prozentangaben zu den Werten in FHEM umgedreht. Die folgende Tabelle soll das ganze verdeutlichen:
<table>
<tr><td><b>levelType</b></td><td><b>minLevel</b></td><td><b>maxLevel</b></td><td><b>Ergebnis (Anzeige in FUIP:Wert in FHEM)</b></td></tr>
<tr><td>shutter</td><td>0</td><td>100</td><td>Auf:100, 90%:90, 80%:80,... 20%:20, 10%:10, Zu:0</td></tr>
<tr><td>shutter</td><td>100</td><td>0</td><td>Auf:0, 90%:10, 80%:20,... 20%:80, 10%:90, Zu:100</td></tr>
<tr><td>inverted_shutter</td><td>0</td><td>100</td><td>Auf:0, 10%:10, 20%:20,... 80%:80, 90%:90, Zu:100</td></tr>
<tr><td>inverted_shutter</td><td>100</td><td>0</td><td>Auf:100, 10%:90, 20%:80,... 80%:20, 90%:10, Zu:0</td></tr>
</table>",
	device => "Hier gibt man den Rollladen-Aktor in FHEM an, also ein Device, welches einen Rollladen oder &auml;hnliches steuert.",
	label => "Der hier eingegebene Text erscheint unter dem gro&szlig;en Rollladen-Icon. Man kann ihn auch weglassen.",
	setUp => "Hier wird die Set-Option angegeben, die den Rollladen zum Hochfahren veranlasst.",
	setStop => "Hier wird die Set-Option angegeben, die den Rollladen zum Anhalten veranlasst.",
	setDown => "Hier wird die Set-Option angegeben, die den Rollladen zum Herunterfahren veranlasst.",
	setLevel => "Hier wird die Set-Option angegeben, bei der man einen Anzufahrenden (Prozent-)Wert mitgeben kann.",
	readingLevel => "Hier wird das Reading angegeben, das den momentanen Stand des Rollladens enth&auml;lt, in der Regel in Prozent.",
	levelType => 'Dies steuert ob 100% "oben" oder "unten" bedeutet. Die folgeden beiden Werte sind m&ouml;glich:
			<ul>
			<li><b>shutter</b>: Bei dieser Option bedeutet "Auf" 100%. Als m&ouml;gliche Optionen zum Anfahren werden dann "Auf", "90%", "80%",... ,"10%", "Zu" angeboten.
			<li><b>inverted_shutter</b>: Bei dieser Option bedeutet "Auf" 0%. Als m&ouml;gliche Optionen zum Anfahren werden dann "Auf", "10%", "20%",... ,"90%", "Zu" angeboten.</li>
			</ul>',
	minLevel => 'Hier wird der Wert eingetragen, der f&uuml;r 0% an das FHEM-Device gesendet wird. 	Es ist auch erlaubt, in <i>minLevel</i> einen gr&ouml;&szlig;eren Wert als in <i>maxLevel</i> einzutragen. In dem Fall wird r&uuml;ckw&auml;rts gerechnet. 100% entspricht immer <i>maxLevel</i>, auch wenn das 0 sein sollte. Die restlichen Werte werden dann einfach linear zwischen 0% und 100% aufgeteilt.',
	maxLevel => 'Hier wird der Wert eingetragen, der f&uuml;r 100% an das FHEM-Device gesendet wird.
			Es ist auch erlaubt, in <i>maxLevel</i> einen kleineren Wert als in <i>minLevel</i> einzutragen. Beim Feld <i>minLevel</i> wird erkl&auml;rt, was das bedeutet.',
	dirReading => "Hier kann ein Reading f&uuml;r die Richtungs- bzw. Bewegungsanzeige angegeben werden. Der Defaultwert ist \"direction\". Es sind nur Readings des Device im Parameter <i>device</i> vorgesehen.<br>
	Sobald dieser Parameter gef&uuml;llt ist, versucht die View, die Bewegungsrichtung zu visualisieren: Enth&auml;lt dieses Reading den Wert für \"hoch\" (per Default \"up\"), dann wird der Pfeil nach oben aktiv dargestellt. Entsprechend beim Wert für \"runter\" der Pfeil nach unten.",
	dirUp => "Hier wird der Wert angegeben, den das Reading <i>dirReading</i> annimmt, wenn der Rollladen nach oben f&auml;hrt. Defaultwert ist \"up\".",
	dirDown => "Hier wird der Wert angegeben, den das Reading <i>dirReading</i> annimmt, wenn der Rollladen nach unten f&auml;hrt. Defaultwert ist \"down\".",
	timer => "Hier kann ein WeekdayTimer-Device angegeben werden, mit dem man den Rollladen automatisieren kann. Das eingegebene Device muss schon in FHEM existieren und ein WeekdayTimer-Device sein. Es wird nicht automatisch angelegt.<br>
	Sobald hier etwas angegeben wird, erscheint ein \"Zahnrad\"-Button in der View. Klickt man auf den Button, dann erscheint ein Popup, &uuml;ber das man die Zeitschaltuhr programmieren kann. Allerdings ist dessen Funktionalit&auml;t gegen&uuml;ber der View <i>WeekdayTimer</i> etwas eingeschr&auml;nkt. Gegebenenfalls sollte man also die View <i>WeekdayTimer</i> verwenden."
);


# register me as selectable
$FUIP::View::selectableViews{"FUIP::View::ShutterControl"}{title} = "Rollladen (Detail)"; 
	
1;	