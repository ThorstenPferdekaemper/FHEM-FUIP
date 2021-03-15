package FUIP::View::Html;

use strict;
use warnings;

use lib::FUIP::View;
use parent -norequire, 'FUIP::View';

	
sub getDependencies($$) {
	return ['js/fuip_htmlview.js'];
};
	
	
sub getHTML($){
	my ($self) = @_;
	my $html = $self->{html};
	$html =~ s/\\/\\\\/g;  	# \ -> \\
	$html =~ s/\r//g;		# remove lf
	$html =~ s/\n/\\n/g;	# replace new line by \n
	$html =~ s/\"/\\\"/g;	# " -> \"
	$html =~ s|<\/script>|<\\/script>|g; # </script> => <\/scipt>
	my @flexfields;
	# avoid "undefined" message
	@flexfields = split(/,/,$self->{flexfields}) if defined $self->{flexfields};
	my $fieldStr;
	for my $flexfield (@flexfields) {
		if($fieldStr) {
			$fieldStr .= ',';
		}else{
			$fieldStr = '{';
		};
		my $value = $self->{$flexfield};
		if($self->{flexstruc}{$flexfield}{type} eq "setoptions") {
			$value = '[\"'.join('\",\"',@$value).'\"]';
		}else{
			# allow double-ticks (") in variables, which are not type "setoptions"
			# for setoptions, it would not work anyway when they have them
			$value =~ s/\"/\\\"/g;	# " -> \"
		};
		$fieldStr .= '"'.$flexfield.'":"'.$value.'"'; 
	};
	if($fieldStr) {
		$fieldStr .= '}';
	}else{
		$fieldStr = '{}';
	};	
	return '<script type="text/javascript">
				renderHtmlView("'.$html.'",'.$fieldStr.');
			</script>';	
};

	
sub dimensions($;$$){
	my ($self,$width,$height) = @_;
	if($self->{sizing} eq "resizable") {
		$self->{width} = $width if $width;
		$self->{height} = $height if $height;
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
		{ id => "title", type => "text" },
		{ id => "html", type => "longtext" },
		{ id => "flexfields", type => "flexfields" },
		{ id => "width", type => "dimension", value => 50},
		{ id => "height", type => "dimension", value => 25 },
		{ id => "sizing", type => "sizing", options => [ "resizable", "auto" ],
			default => { type => "const", value => "resizable" } },
		{ id => "popup", type => "dialog", default=> { type => "const", value => "inactive"} }			
		];
};


our %docu = (
	general => 'Diese View kann praktisch beliebiges HTML enthalten. Es ist auch erlaubt, CSS und JavaScript zu verwenden. Allerdings sollte man sicherstellen, dass man dabei keine allzu groben Fehler macht. Syntaxfehler und &auml;hnliches werden abgefangen, aber man kann damit auch gro&szlig;en Bl&ouml;dsinn anstellen.<br>
	Im HTML-Text k&ouml;nnen spezielle Elemente verwendet werden, um sogenannte "flexible Felder" zu erzeugen. Diese werden dann zu Parametern, die auf dem Konfigurations-Popup durch eingegebene Werte ersetzt werden k&ouml;nnen. Dies ist insbesondere im Zusammenhang mit View Templates interessant, wo man auch aus "flexiblen Feldern" Variablen machen kann.',
	html => 'Hier wird der HTML-Text eingegeben. (Man kann das Feld auch gr&ouml;&szlig;er ziehen.)<br>
		Au&szlig;er normalem HTML (mit CSS und JavaScript) kann man mit dem Pseudo-Tag <i>fuip-field</i> "flexible Felder" definieren. Man kann z.B. folgendes in den HTML-Text einf&uuml;gen:<br>
		<i>&lt;fuip-field fuip-name=\'device\' fuip-type=\'device\'&gt;somedevice&lt;/fuip-field&gt;</i><br>
		Das kann man im HTML tats&auml;chlich &uuml;berall hinschreiben und nicht nur da, wo es normalerweise in HTML m&ouml;glich w&auml;re. Nach dem n&auml;chsten &Ouml;ffnen des Konfigurations-Popups erscheint "device" mit dem Wert "somedevice" als neues Feld unter dem HTML-Teil. Dabei kommt "device" von der Angabe bei "fuip-name" und "somedevice" ist einfach der Inhalt des <fuip-field>-Tags. Das neue Feld kann man jetzt &auml;ndern wie jedes andere auch. Durch die Angabe "device" bei "fuip-type" wei&szlig; FUIP auch, dass es die entsprechende Werthilfe liefern muss. Beim Rendern des Views (also wenn das ganze angezeigt wird), wird der &lt;fuip-field&gt;-Teil durch den Inhalt des Felds ersetzt. Im obigen Beispiel kann man also das HTML mit einem variablen Device angeben.<br>
		Das &lt;fuip-field&gt;-Pseudo-Tag kennt die folgenden Attribute.
		<ul>
		<li><b>fuip-name</b> ist der Name des neuen Felds. Der Name darf nur aus normalen Buchstaben (a-z, A-Z), Ziffern (0-9) und dem Unterstrich (_) bestehen. Au&szlig;erdem sind die folgenden Namen nicht erlaubt: class, defaulted, flexfields, height, html, popup, sizing, title, variable, variables, views, width.</li>
		<li><b>fuip-type</b> gibt den Typ des Felds an. Folgende Werte sind möglich.
		<ul>
			<li>text: Einfach ein Feld, ohne besondere Semantik.</li>
			<li>device: Ein FHEM-Device. Als Werthilfe wird eine Liste aller Devices angezeigt.</li>
			<li>reading: Ein Reading eines FHEM-Device. Wenn zus&auml;tzlich fuip-refdevice gesetzt ist, dann wird eine Liste der Readings des betreffenden Device als Werthilfe angeboten.</li>
			<li>set: Ein set-Befehl eines FHEM-Device. Wenn zus&auml;tzlich fuip-refdevice gesetzt ist, dann wird eine Liste der set-Befehle des betreffenden Device als Werthilfe angeboten.</li>
			<li>setoption: (Ein) Parameter zu einem set-Befehl. (Also z.B. das "22" in "set <device> desired-temp 22".) Wenn zus&auml;tzlich fuip-refset angegeben ist, dann werden die m&ouml;glichen Werte als Werthilfe angeboten.</li>
			<li>setoptions: Wie setoption, nur dass mehrere Werte ausw&auml;hlbar sind.</li>
			<li>icon: Ein Icon, in der "&uuml;blichen" FTUI-Codierung. Als Werthilfe wird eine Liste aller verwendbaren Icons angeboten.</li>
		</ul>
		</li>
		<li><b>fuip-refdevice</b> enth&auml;lt den Namen eines Felds, das den Device-Namen enth&auml;lt. Dies wird ben&ouml;tigt für Felder vom Typ reading und set.</li>
		<li><b>fuip-refset</b> enth&auml;lt den Namen eines Felds, das einen set-Befehl enth&auml;lt (also ein Feld vom Type set). Dies wird ben&ouml;tigt für Felder vom Typ setoption und setoptions. (Es kann aber auch sinnvoll sein, fuip-refset wegzulassen, insbesondere falls fuip-options angegeben wird.</li>
		<li><b>fuip-options</b> enth&auml;lt eine Komma-separierte Liste der m&ouml;glichen Werte, also z.B. "on,off,5,15,25". Wenn fuip-options verwendet wird, dann sollte man fuip-refset weglassen.</li>
		<li><b>fuip-default-type</b> zeigt an, dass es für das Feld einen Default-Wert gibt. M&ouml;gliche Werte sind "const" für einen konstanten Wert und "field", wenn der Wert aus einem anderen Feld &uuml;bernommen werden soll.</li>
		<li><b>fuip-default-value</b> enth&auml;lt den Default-Wert bzw. den Namen des Felds, von dem der Wert &uuml;bernommen werden soll. Für Felder des Typs setoptions k&ouml;nnen mehrere Werte durch Komma getrennt angegeben werden.</li>
		<li><b>fuip-default-suffix</b> kann verwendet werden wenn fuip-default-type "field" ist. Dann wird der Suffix an den Wert geh&auml;ngt.</li>
		</ul>', 
	flexfields => 'Dies ist ein "flexibles Feld", welches aus einer Definition im HTML-Text erzeugt wurde.' 
);


# register me as selectable
$FUIP::View::selectableViews{"FUIP::View::Html"}{title} = "Alles, was mit HTML geht"; 
	
1;	