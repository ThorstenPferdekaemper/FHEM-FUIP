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


sub getHTML_swiper($$){
	my ($self,$locked) = @_;
	my $views = $self->{views};
	my @classes;
	push(@classes, "navbuttons") if($self->{navbuttons} eq "on");
	push(@classes, "nopagination") if($self->{pagination} eq "off");
	my $result = 
		'<div data-type="swiper" style="position:absolute;top:22px;left:0px;height:calc(100% - 22px);" data-height="calc(100% - 22px)" data-autoplay="'.$self->{autoplay}.'" class="'.join(' ',@classes).'">
			<ul>';
	my $i = 0;
	for my $view (@$views) {
		my ($width,$height) = $view->dimensions();
		# TODO: hardcode 22px headers?
		$result .= '
		<li>
			<div style="position:absolute;left:'.($self->{navbuttons} eq "on" ? '37' : '0').'px;width:'.($self->{navbuttons} eq "on" ? 'calc(100% - 74px)' : '100%').';">
				<div data-viewid="'.$i.'"'.$self->getHTML_sysid($view).' class="'.$view->getCssClasses($locked).'" style="';
		my (undef, $cellHeight) = FUIP::cellSizeToPixels($self);
		if($width eq "auto") {
			$result .= 'width:100%;';
			# It seems that the swiper widget does some funny computations for the height, so 100% and calculations do not 
			# work directly. I.e. we need to find out the height of the cell and determine from there
			$result .= 'height:'.($cellHeight - ($self->{pagination} eq "on" ? 47 : 22)).'px;'; 
		}else{
			$result .= 'width:'.$width.'px;';
			$result .= 'height:'.$height.'px;';
			$result .= 'margin:auto;';
			$result .= 'top:'.(($cellHeight - ($self->{pagination} eq "on" ? 25 : 0) - $height)/2).'px;';
		};
		$result .= 'z-index:10;position:relative;"><div style="position:absolute;width:100%;height:100%;">'.$view->getViewHTML().'</div>';
		if( not $locked and $self->{fuip}{editOnly}) {
			my $title = ($view->{title} ? $view->{title} : '');
			$title .= ' ('.blessed($view).')';
			$result .= '<div title="'.$title.'" style="position:absolute;left:0;top:0;width:100%;height:100%;z-index:11;background:var(--fuip-color-editonly,rgba(255,255,255,.1));"></div>';
		};
		$result .= '</div></div></li>';
		$i++;
	};
	$result .= '</ul>';
	$result .= '</div>';
	return $result;	
};

		
sub getHTML($$){
	my ($self,$locked) = @_;
	if($self->{layout} and $self->{layout} eq "swiper") {
		return getHTML_swiper($self,$locked);
	};	
	my $views = $self->{views};
	my $result = "";

	my $i = 0;
	for my $view (@$views) {
		my ($left,$top) = $view->position();
		my ($width,$height) = $view->dimensions();
		# TODO: hardcode 22px headers?
		$result .= '<div><div data-viewid="'.$i.'"'.$self->getHTML_sysid($view).' class="'.$view->getCssClasses($locked).'" style="position:absolute;left:'.$left.'px;top:'.($top+22).'px;';
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


sub getCssClasses($$) {
    my ($self,$locked) = @_;
	
	my $result = 'fuip-cell';
	$result = 'fuip-droppable '.$result unless $locked;
	#Does the page have a background image?
	my $backgroundImage = FUIP::getBackgroundImage($self->{parent});
	$result .= ' fuip-transparent' if $backgroundImage;	
	my $userCssClasses = $self->getUserCssClasses();
	$result .= ' '.$userCssClasses if $userCssClasses;
	return $result;
};	

	
sub getStructure($) {
	# class method
	# returns general structure of the view without instance values
	my ($class) = @_;
	return [
		{ id => "class", type => "class", value => $class },
		{ id => "title", type => "text" },
		{ id => "layout", type => "text", options => ["position","swiper"], 
			default => { type => "const", value => "position" } },
		{ id => "autoplay", type => "text", 
			default => { type => "const", value => "0" }, 
			depends => { field => "layout", value => "swiper" } },
		{ id => "navbuttons", type => "text", options => ["on","off"], 
			default => { type => "const", value => "on" }, 
			depends => { field => "layout", value => "swiper" } },
		{ id => "pagination", type => "text", options => ["on","off"], 
			default => { type => "const", value => "on" }, 
			depends => { field => "layout", value => "swiper" } },
		{ id => "views", type => "viewarray" }
		];
};


our %docu = (
	general => "Die Zellen sind die \"K&auml;stchen\", aus denen eine FUIP-Oberfl&auml;che besteht. Im Bearbeitungsmodus k&ouml;nnen sie mit der Maus positioniert werden und man kann ebenfalls mit der Maus ihre Gr&ouml;&szlig;e &auml;ndern.",
	title => "&Uuml;berschrift der Zelle.<br>
			Eine Zelle muss keine &Uuml;berschrift haben. Die Zahl hinter der &Uuml;berschrift in der Zelle selbst verschwindet, wenn man die Oberfl&auml;che gegen Bearbeitung sperrt (Attribut <i>locked</i> bzw. Kommando <i>set...lock</i>)."
);

1;	