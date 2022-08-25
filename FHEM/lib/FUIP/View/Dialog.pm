package FUIP::Dialog;
# Popup, like FUIP::Cell

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
	return ($self->{width} ? $self->{width} : 400, $self->{height} ? $self->{height} : 300);
};	
	
	
sub getHTML($$){
	my ($self,$locked) = @_;
	$self->applyDefaults();
	my $views = $self->{views};
	my $result = '';
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
		if(not $locked and $self->{fuip}{editOnly}) {
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
	
	my $result = ' fuip-cell';
	if($locked) {
		$result = 'dialog'.$result;
	}else{
		$result = 'fuip-droppable'.$result;
	};	
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
		{ id => "position", type => "text", options => [ "screen-center", "starter-area" ],
			default => { type => "const", value => "screen-center" } },		
		{ id => "autoclose", type => "text", 
			default => { type => "const", value => "0" } }, 	
		{ id => "views", type => "viewarray" }
		];
};


our %docu = (
	general => "Ein Popup (oder auch Dialog) enth&auml;lt wie eine Zelle Views, die frei positioniert werden k&ouml;nnen. Die Gr&ouml;szlig des Popups selbst kann pixelgenau eingestellt werden.",
	title => "&Uuml;berschrift des Popups.<br>
			Wird hier etwas eingetragen, dann erscheint es in der Titelzeile des Popups. Ein Popup muss keine &Uuml;berschrift haben."
);
	
1;	