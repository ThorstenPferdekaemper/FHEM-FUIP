package FUIP::ViewTemplInstance;

use strict;
use warnings;
use POSIX qw(ceil);
use Scalar::Util qw(blessed weaken);

use lib::FUIP::View;
use parent -norequire, 'FUIP::View';

sub dimensions($;$$){
	my $self = shift;
	if (@_ and $self->{sizing} eq "resizable") {
		$self->{width} = shift;
		$self->{height} = shift;
	}	
	if($self->{sizing} eq "fixed") {
		($self->{width},$self->{height}) = $self->{viewtemplate}->dimensions();
	};
	return ("auto","auto") if($self->{sizing} eq "auto");
	return ($self->{width},$self->{height});
};	
	
	
sub getHTML($$){
	my ($self,$locked) = @_;
	# a bit of brute force, but we have to copy the template
	my $instanceStr = $self->{viewtemplate}->serialize();
	my $evalled = eval($instanceStr);
	my $instance = "FUIP::ViewTemplate"->reconstruct($evalled,$self->{fuip});
	# now replace variables
	my $h = {};
	my $variables = $self->{viewtemplate}{variables};
	for my $variable (@$variables) {
		for my $fieldPath (@{$variable->{fields}}) {
			$h->{$fieldPath} = $self->{$variable->{name}};
		};
	};
	FUIP::setViewSettings($self->{fuip},[$instance],0,$h);
	# Always locked...
	return $instance->getHTML(1);
};


sub getStructure($) {
	# instance method (!)
	# returns general structure of the view without real instance values
	my ($self) = @_;
	unless(blessed($self)) {
		main::Log3(undef, 1, "FUIP ERROR: ViewTemplInstance::getStructure called for non-blessed");
		use Carp;
		Carp::confess("Problem:");
	};
	return $self->{viewtemplate}->getStructure();
};


sub getConfigFields($) {
	# returns config fields including value, type and defaulting information
	# array of hash id, type, value
	# thermostat   : device
	# measuredTemp : device-reading
	# humidity     : device-reading
	# valvePos     : device-reading
	my ($self) = @_;
	unless(blessed($self)) {
		main::Log3(undef, 1, "FUIP ERROR: ViewTemplInstance::getConfigFields called for non-blessed");
		use Carp;
		Carp::confess("Problem:");
	};
	# get instance dependent structure... 
	my $result = $self->{viewtemplate}->getDefaultFields();
	# ...and fill with values
	for my $field (@$result) {
		$self->_fillField($field);
	};
	return $result;
}


sub serialize($;$) {
	my ($self, $indent) = @_;
	$indent = 0 unless($indent);
	my $blanks = " " x $indent;
    my $result = $blanks."{ class => '".blessed($self)."'";
	for my $field (keys %$self) {
		# fuip is the reference to the FUIP object, don't serialize this
		next if $field eq "fuip";
		next if $field eq "class";
		# do not serialize the viewtemplate instance, only store the id
		next if $field eq "viewtemplate";
		$result .= ",\n".$blanks."   ".$field." => ".FUIP::View::serializeRef($self->{$field},$indent);
	};
	$result .= "\n".$blanks."}";
	return $result;
}


sub reconstruct($$$) {
	my ($class,$conf,$fuip) = @_;
	# this expects that $conf is already hash reference
	# and key "class" is already deleted
	my $self = FUIP::View::reconstructRec($conf,$fuip);
	$self->{fuip} = $fuip;
	weaken($self->{fuip});
	# get the view template instance back
	$self->{viewtemplate} = $fuip->{viewtemplates}{$self->{templateid}};
	return bless($self,$class);
};


1;	