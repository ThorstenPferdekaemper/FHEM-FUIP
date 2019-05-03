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
	return $self->{viewtemplate}->getStructure() if(blessed($self) and $self->{viewtemplate} and blessed($self->{viewtemplate}));
	# something went wrong if we come here
	# the following error handling is a bit more complex as there have been multiple issues here
	if(not blessed($self)) {
		main::Log3(undef, 1, "FUIP ERROR: ViewTemplInstance::getStructure called for non-blessed");
	}elsif(not $self->{viewtemplate}){
		main::Log3(undef, 1, "FUIP ERROR: ViewTemplInstance without View Template");
	}else{  # not blessed($self->{viewtemplate})
		my $id = $self->{templateid} ? $self->{templateid} : "<empty>"; 
		main::Log3(undef, 1, "FUIP ERROR: ViewTemplInstance with non-blessed View Template ".$id);
		
	};
	use Carp;
	Carp::confess("Problem:");
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

my @instancesWithoutTemplates;

sub reconstruct($$$) {
	my ($class,$conf,$fuip) = @_;
	# this expects that $conf is already hash reference
	# and key "class" is already deleted
	my $self = FUIP::View::reconstructRec($conf,$fuip);
	$self->{fuip} = $fuip;
	weaken($self->{fuip});
	# get the view template instance back
	if(exists $fuip->{viewtemplates}{$self->{templateid}}) {
		$self->{viewtemplate} = $fuip->{viewtemplates}{$self->{templateid}};
	}else{
		# Remember the instance in case the view template is not loaded
		# yet. This happens for templates, which are used in templates,
		# including usage on popups (on popups...), which are part of templates.
		push(@instancesWithoutTemplates,$self);
	};	
	return bless($self,$class);
};


# To be called after all templates have been loaded, so that 
# the missing ones can be set. 
# TODO: Error management for those which stay missing.
#	(However, this should not happen.)
sub fixInstancesWithoutTemplates() {
	for my $inst (@instancesWithoutTemplates) {
		if(exists $inst->{fuip}{viewtemplates}{$inst->{templateid}} and blessed($inst->{fuip}{viewtemplates}{$inst->{templateid}})) {
			$inst->{viewtemplate} = $inst->{fuip}{viewtemplates}{$inst->{templateid}};	
		}else{		
			main::Log3(undef,1,"FUIP ".$inst->{fuip}{NAME}.": View Template does not exist: ".$inst->{templateid});
			$inst->{viewtemplate} = FUIP::ViewTemplate->createDefaultInstance($inst->{fuip});
			$inst->{viewtemplate}{id} = "<ERROR>";
			$inst->{title} = "Error ".$inst->{templateid} unless $inst->{title};
			$inst->{defaulted}{title} = '0';
			my $view = "FUIP::View"->createDefaultInstance($inst->{fuip});
			$view->{content} = "View template <b>".$inst->{templateid}."</b> does not exist.";
			$view->{defaulted}{content} = '0';
			$view->{width} = 150;
			$view->{height} = 50;
			$view->position(0,0);
			push(@{$inst->{viewtemplate}{views}},$view);
		};	
	};
	@instancesWithoutTemplates = ();
};

1;	