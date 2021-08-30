package FUIP::Exception;

use strict;
use warnings;
use Scalar::Util qw(blessed);


sub raise($) {
    my ($ex) = @_;
	my $self = {};
	
	# There is always a list of reasons, which goes
	# from coarse to fine grained and becoming more
	# technical
    if(ref($ex) eq "ARRAY") {
		$self->{reasons} = $ex;
	}else{
		$self->{reasons} = [$ex];
    };	

	# Add stacktrace
	my $i = 1;
	$self->{stacktrace} = [];
	while( (my @call_details = (caller($i++))) && ($i<50) ) {
		push(@{$self->{stacktrace}}, {name => $call_details[3], file => $call_details[1], line => $call_details[2]});
	};	
	
    $self = bless($self,"FUIP::Exception");
	
    die $self;	
};


sub getErrorHtml($;$) {
	my ($exception,$message) = @_;

	my $result = '<div>';	
	if($message) {
		$result .= $message;
	};

	if($exception) {
		if($message) {
			$result .= '<br>';
		};
		if(blessed($exception) and $exception->isa("FUIP::Exception")) {
			$result .= $exception->{reasons}[0];
		}else{
			$result .= $exception;
		};
	};	
	$result .= '</div>';
	return $result;
}


sub log($) {
    my ($exception) = @_;
	
	if(blessed($exception) and $exception->isa("FUIP::Exception")) {
	    $exception->_log();
	}else{
	    main::Log3(undef,1,"FUIP exception: ".$exception);
		main::stacktrace();
	};
    return undef;	
};


sub _log($) {
    my ($self) = @_;
	main::Log3(undef,1,"FUIP exception: ".$self->{reasons}[0]);
	for(my $i = 1; $i < scalar(@{$self->{reasons}}); $i++) {
		main::Log3(undef,3,"    ".$self->{reasons}[$i]);
	};
	main::Log3(undef,3,"Stacktrace:");
	foreach my $entry (@{$self->{stacktrace}}) {
        main::Log3(undef,3, sprintf ("    %-35s called by %s (%s)",
               $entry->{name}, $entry->{file}, $entry->{line}));
    };
};


1;