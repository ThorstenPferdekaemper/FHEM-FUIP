package FUIP::View::LabelReading;

use strict;
use warnings;

use lib::FUIP::View;
use parent -norequire, 'FUIP::View';


sub getHTML($){
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
							 data-get=\"".$self->{reading}{reading}."\">
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
	
	
sub dimensions($;$$){
	my $self = shift;
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

	my $height = 17;
	$height += 17 if $self->{content} eq "both";
	$height += 17 if $self->{label};
	$height = 28 if $height < 28 and $self->{icon};
	$height += 2 if(not $self->{border} or $self->{border} eq "solid");	
	return (main::AttrVal($self->{fuip}{NAME},"baseWidth",142), $height);
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
		{ id => "border", type => "text", options => [ "solid", "none" ], 
			default => { type => "const", value => "solid" } }, 
		{ id => "popup", type => "dialog", default=> { type => "const", value => "inactive"} }		
		];
};


# register me as selectable
$FUIP::View::selectableViews{"FUIP::View::LabelReading"}{title} = "Display a reading as text"; 

1;	