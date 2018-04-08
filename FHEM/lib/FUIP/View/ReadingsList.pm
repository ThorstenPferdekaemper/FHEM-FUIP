# class FUIPViewReadingsList
package FUIP::View::ReadingsList;
	
use strict;
use warnings;
	
use lib::FUIP::View;
use parent -norequire, 'FUIP::View';
	
use lib::FUIP::Model;	
	
sub getHTML($){
	my ($self) = @_;
	my $device = $self->{device};
	my $hash = FUIP::Model::getDevice($self->{fuip}{NAME},$device,[]); 
	return "Device not found" unless defined $hash;
	my $result = "<table>";
	foreach my $reading (sort keys %{$hash->{Readings}}) {
		next if(substr($reading,0,1) eq ".");
		$result .= "<tr><td><div class=\"big left\">".$reading."</div></td>
					<td><div data-type=\"label\" 
					data-device=\"".$device."\" 
					data-get=\"".$reading."\"
					class=\"cell big left\"></div></td>
					<td><div data-type=\"label\" 
					data-device=\"".$device."\" 
					data-get=\"".$reading."\"
					class=\"cell big left timestamp\">
				</div></td></tr>";
	};
	return $result."</table>";
};
	
	
sub getStructure($) {
	# class method
	# returns general structure of the view without instance values
	my ($class) = @_;
	return [
		{ id => "class", type => "class", value => $class },
		# TODO: device selection
		{ id => "device", type => "device" },
		{ id => "title", type => "text", default => { type => "field", value => "device"} },
		{ id => "width", type => "internal", value => 800 },
		{ id => "height", type => "internal", value => 540 }
		];
};

# register me as selectable
$FUIP::View::selectableViews{"FUIP::View::ReadingsList"}{title} = "List of all Readings"; 

1;	