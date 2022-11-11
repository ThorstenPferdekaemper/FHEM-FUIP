
# class FUIPViewPage
package FUIP::Page;

use strict;
use warnings;
use POSIX qw(ceil);

use lib::FUIP::View;
use parent -norequire, 'FUIP::View';


sub getImagesForValueHelp($$) {
	# Return images 
	my ($fuipName,$sysid) = @_;
	return FUIP::_toJson(FUIP::getImageNames());
}	
	
	
sub getStructure($) {
	# class method
	# returns general structure of the view without instance values
	my ($class) = @_;
	return [
		{ id => "class", type => "class", value => $class },
		{ id => "title", type => "text" },
		{ id => "autoReturn", type => "text", options => ["on","off"], 
			default => { type => "const", value => "off" } },
		{ id => "returnAfter", type => "text", 
			default => { type => "const", value => "30" }, 
			depends => { field => "autoReturn", value => "on" } },
		{ id => "returnTo", type => "pageid",  
			default => { type => "const", value => "home" }, 
			depends => { field => "autoReturn", value => "on" } },
		{ id => "backgroundImage", type => "setoption", reffunc => "FUIP::Page::getImagesForValueHelp" },	
		];
};


our %docu = (
	general => "Eine Seite in FUIP ist eine einzelne Webseite.",
	title => "&Uuml;berschrift der Seite.<br>
			Hier kann ein Titel für die Seite eingetragen werden. Das erscheint dann je nach Browser irgendwo oben. (Technisch ist es der Inhalt des &lt;title&gt; Tags in &lt;head&gt;.)",
	autoReturn => "Automatisches &quot;zur&uuml;ck&quot;<br>
			Wenn <i>autoReturn</i> auf &quot;on&quot; gesetzt wird, dann ruft das System nach einer bestimmten Zeit automatisch eine bestimmte Seite auf. Urspr&uuml;nglich war das daf&uuml;r gedacht, um automatisch zur Startseite zur&uuml;ckzukehren. Allerdings kann man damit auf eine beliebige Seite, einschlie&szlig;lich der aktuellen Seite selbst verweisen. Durch letzteres kann man ein Auto-Refresh implementieren.<br>
			Wenn <i>autoReturn</i> aktiviert ist, dann werden die Felder <i>returnAfter</i> und <i>returnTo</i> sichtbar.",
	returnAfter => "Zeit in Sekunden, nach der die Seite automatisch verlassen wird<br>
			Dieses Feld ist nur sichtbar, wenn <i>autoReturn</i> aktiviert ist. In dem Fall wird nach der angebenen Anzahl Sekunden automatisch auf die Seite navigiert, die in <i>returnTo</i> angegeben ist. Die Zeitmessung wird zur&uuml;ckgesetzt, wenn der Benutzer die Maus bewegt, eine Taste dr&uuml;ckt oder etwas anklickt.<br>
			Im &Auml;nderungsmodus (&quot;unlocked&quot;) wird immer mindestens 5 Sekunden gewartet. Ansonsten k&ouml;nnte es passieren, dass die Seite nicht mehr ge&auml;ndert werden kann. Es k&ouml;nnen aber trotzdem kleinere Werte angegeben werden.", 	
	returnTo => "Seite, zu der automatisch navigiert wird<br>
			Dieses Feld ist nur sichtbar, wenn <i>autoReturn</i> aktiviert ist. Es kann eine beliebige Seite der aktuellen FUIP-Instanz angegeben werden. Die aktuelle Seite wird dann nach der in <i>returnAfter</i> angegebenen Zeit automatisch durch die in <i>returnTo</i> angegebene Seite ersetzt. Es ist m&ouml;glich, hier die aktuelle Seite einzugeben. Dann wird die Seite nach der angegebenen Zeit einfach neu geladen (&quot;auto-refresh&quot;).",	
	backgroundImage	=> "Dateiname des Hintergrundbilds<br>
			Die Bilddatei muss sich im Verzeichnis &lt;fhem&gt;/FHEM/lib/FUIP/images befinden. (&lt;fhem&gt; steht meistens für /opt/fhem) Unterst&uuml;tzt werden jpg- und png- Dateien.<br>
			Falls das Attribut <code>pageWidth</code> gesetzt ist, dann wird die Breite des Hintergrundbilds auf die angegebene Gr&ouml;&szlig;e gesetzt. Ansonsten (ohne <code>pageWidth</code>) nimmt das Bild die Breite des Browser-Fensters ein. Die H&ouml;he des Bilds wird entsprechend skaliert, man muss sich also selbst darum k&uuml;mmern, dass das Bild ein passendes Seitenverh&auml;ltnis hat.<br>
			Bei Verwendung eines Hintergrundbilds werden die Zellenhintergr&uuml;nde automatisch auf halbtransparent gesetzt, so dass das Bild durchscheint.<br>
			Falls das Attribut <code>styleBackgroundImage</code> ebenfalls gesetzt ist, dann &quot;gewinnt&quot; das Feld <i>backgroundImage</i>, falls es einen Wert enth&auml;lt. Will man dasselbe Hintergrundbild f&uuml;r (fast) alle Seiten der FUIP-Instanz setzen, dann mach man das am Besten &uuml;ber das Attribut <code>styleBackgroundImage</code>."
);

1;	