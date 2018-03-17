# class FUIP::View
package FUIP::View::STATE;

use strict;
use warnings;

    use lib::FUIP::View;
	use parent -norequire, 'FUIP::View';


	sub getHTML($){
		my ($self) = @_;
		# show STATE
		return "<table width='100%' style='border:1px solid #808080; border-radius:8px;'>
					<tr><td>".$self->{device}."</td></tr>
					<tr><td><div data-type=\"label\" 
								 data-device=\"".$self->{device}."\">
					</div></td></tr>
				</table>";
	};
	
	
	sub dimensions($;$$){
		my $self = shift;
		if (@_) {
			$self->{width} = shift;
			$self->{height} = shift;
		}	
		$self->{width} = main::AttrVal($self->{fuip}{NAME},"baseWidth",142) unless $self->{width};
		return ($self->{width}, $self->{height});
	};	
	

sub getStructure($) {
	# class method
	# returns general structure of the view without instance values
	my ($class) = @_;
	return [
		{ id => "class", type => "class", value => $class },
		{ id => "device", type => "device" },
		{ id => "title", type => "text", default => { type => "field", value => "device"} },
		{ id => "height", type => "internal", value => 60 }
		];
};

1;	