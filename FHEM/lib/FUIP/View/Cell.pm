package FUIP::Cell;

use strict;
use warnings;
use POSIX qw(ceil);
use Scalar::Util qw(blessed);

use lib::FUIP::View;
use parent -norequire, 'FUIP::View';

sub dimensions($;$$){
	my $self = shift;
	if (@_) {
		$self->{width} = shift;
		$self->{height} = shift;
	}	
	return ($self->{width}, $self->{height}) if(defined($self->{width}) and defined($self->{height}));
	my ($width,$height) = (1,1);
	for my $view (@{$self->{views}}) {
		my ($x,$y) = $view->position();
		$x = 0 unless defined $x;  
		$y = 0 unless defined $y;
		my ($w,$h) = $view->dimensions();
		$w = 1 unless $w;
		$h = 1 unless $h;
		$width = $x + $w if($x+$w > $width);
		$height = $y + $h if($y+$h > $height);
	};
	# now $width,$height is in pixels of the views
	# a cell of w X h can contain (pixels)
	#		width:  w * baseWidth  + (w-1) * 10  =>  width = w * baseWidth + w * 10 - 10 = w * (baseWidth + 10) - 10 
	#                                                w = (width + 10) / (baseWidth + 10)  
	#		height:	h * baseHeight + (h-1) * 10 - 22  (TODO: hardcoding...)
	#						=> height = h * baseHeight + h * 10 -10 -22 = h * (baseHeight +10) -32
    #                          h = (height + 32) / (baseHeight + 10)
	if(not defined($self->{width})) {
		$self->{width} = ceil(($width + 10) / (main::AttrVal($self->{fuip}{NAME},"baseWidth",142) + 10));
	};
	if(not defined($self->{height})) {
		$self->{height} = ceil(($height + 32) / (main::AttrVal($self->{fuip}{NAME},"baseHeight",142) + 10));
	};
	return ($self->{width},$self->{height});
};	
	
	
sub getHTML($$){
	my ($self,$locked) = @_;
	my $views = $self->{views};
	my $result = "";

	my $i = 0;
	for my $view (@$views) {
		my ($left,$top) = $view->position();
		my ($width,$height) = $view->dimensions();
		my $resizable = ($view->isResizable() ? " fuip-resizable" : "");
		# TODO: hardcode 22px headers?
		$result .= '<div><div data-viewid="'.$i.'"'.($locked ? '' : ' class="fuip-draggable'.$resizable.'"').' style="position:absolute;left:'.$left.'px;top:'.($top+22).'px;';
		if($width eq "auto") {
			$result .= 'width:calc(100% - '.$left.'px);';
			$result .= 'height:calc(100% - '.($top+22).'px);'; 
		}else{
			$result .= 'width:'.$width.'px;';
			$result .= 'height:'.$height.'px;';
		};
		$result .= 'z-index:10">'.$view->getViewHTML();
		if( not $locked and $self->{fuip}{editOnly}) {
			my $title = ($view->{title} ? $view->{title} : '');
			$title .= ' ('.blessed($view).')';
			$result .= '<div title="'.$title.'" style="position:absolute;left:0;top:0;width:100%;height:100%;z-index:11;background:var(--fuip-color-editonly,rgba(255,255,255,.1));"></div>';
		};
		$result .= '</div></div>';
		$i++;
	};
	return $result;	
};

	
sub getStructure($) {
	# class method
	# returns general structure of the view without instance values
	my ($class) = @_;
	return [
		{ id => "class", type => "class", value => $class },
		{ id => "title", type => "text" },
		{ id => "views", type => "viewarray" }
		];
};

	
1;	