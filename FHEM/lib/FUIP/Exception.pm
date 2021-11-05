package FUIP::Exception;

use strict;
use warnings;
use Scalar::Util qw(blessed);

use overload '""' => 'toString';

sub raise($;$) {
    my ($ex,$prev) = @_;
	my $self;
	if($prev and blessed($prev) and $prev->isa("FUIP::Exception")) {
		# Just re-raise with new messages
		$self = $prev;
		$prev = undef;
	}else{
	    # create new exception
		$self = { reasons => [] };
	    # Add stacktrace
	    my $i = 1;
	    $self->{stacktrace} = [];
	    while( (my @call_details = (caller($i++))) && ($i<50) ) {
			last unless $call_details[3] =~ m/FUIP/ or $call_details[1] =~ m/FUIP/; 
		    push(@{$self->{stacktrace}}, {name => $call_details[3], file => $call_details[1], line => $call_details[2]});
	    };	
	    $self = bless($self,"FUIP::Exception");	
	};
	
	# There is always a list of reasons, which goes
	# from coarse to fine grained and becoming more
	# technical
    if(ref($ex) eq "ARRAY") {
		unshift(@{$self->{reasons}},@$ex);
	}else{
		unshift(@{$self->{reasons}},$ex);
    };	
	if($prev) {
		push(@{$self->{reasons}},$prev);
	};
	
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
};


sub getShortText($) {
	my ($exception) = @_;
	if(blessed($exception) and $exception->isa("FUIP::Exception")) {
		return $exception->{reasons}[0];
	}else{
		return $exception;
	};
};


sub getErrorPage($;$) {
	my ($exception,$message) = @_;
	
	my $reasons = [];
	push(@$reasons,$message) if($message); 
	if(blessed($exception) and $exception->isa("FUIP::Exception")) {
		push(@$reasons,@{$exception->{reasons}})
	}else{
		push(@$reasons,$exception);
	};	
	my $header = shift(@$reasons);
	
  	my $result = 
	   "<!DOCTYPE html>
		<html>
		<head>
		<title>FUIP Exception</title>
		</head>
		<body style='word-wrap: break-word'>
		<h1>FUIP Exception - something went wrong</h1>";
	if($header) {
		$result .= "<h2>".$header."</h2>".join("<br>",@$reasons);
	};
	if((blessed($exception) or ref($exception) eq 'HASH') and defined($exception->{stacktrace})) {
		$result .= "<h2>Stacktrace</h2>";
		$result .= "<table><tr><th style='text-align:left'>Routine name</th><th style='text-align:left'>Called in file (line)</th></tr>";
	    foreach my $entry (@{$exception->{stacktrace}}) {
			$result .= sprintf("<tr><td style='padding-right:10px'>%-35s</td><td>%s (%s)</td></tr>", $entry->{name}, $entry->{file}, $entry->{line});
		};	
		$result .= "</table>";
    };	
		
	$result .= "</body></html>";
	return $result;	
};


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


# The toString function is mainly for the case when the exception is not caught at all
# and FHEM crashes. In this case, toString is called and the result is printed in the log.
sub toString($) {
	my ($self) = @_;
	my $result = "FUIP exception";
	for(my $i = 0; $i < scalar(@{$self->{reasons}}); $i++) {
		$result .= "\n    ".$self->{reasons}[$i];
	};
	$result .= "\nFUIP Stacktrace";
	foreach my $entry (@{$self->{stacktrace}}) {
        $result .= sprintf("\n    %-35s called by %s (%s)", $entry->{name}, $entry->{file}, $entry->{line});
    };
	return $result;
};

1;