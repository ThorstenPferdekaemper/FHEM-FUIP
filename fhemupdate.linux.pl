#!/usr/bin/perl

# Copies files from development and
# creates control file for FUIP

use IO::File;
use strict;
use warnings;


#First copy files

my $devdir = '/opt/fhem';
my $gitdir = '~thorsten/Dokumente/GitHub/FHEM-FUIP';

my @filelist1 = (
  'FHEM/42_FUIP.pm',
  'FHEM/lib/FUIP/*.pm',
  'FHEM/lib/FUIP/css/*.*',
  'FHEM/lib/FUIP/fonts/*.*',
  'FHEM/lib/FUIP/html/*.*',
  'FHEM/lib/FUIP/images/*.*',
  'FHEM/lib/FUIP/doc/*.*',
  'FHEM/lib/FUIP/view-images/*.*',
  'FHEM/lib/FUIP/js/*.js',
  'FHEM/lib/FUIP/View/*.pm',
  'FHEM/lib/FUIP/jquery-ui/*.*',
  'FHEM/lib/FUIP/jquery-ui/images/*.*'
);

foreach my $fspec (@filelist1) {
  $fspec =~ m,^(.+)/([^/]+)$,;
  my ($dir,$pattern) = ($1, $2);

  my $devpath = "$devdir/$fspec";
  my $gitpath = "$gitdir/$dir";
  my $cmd = "cp $devpath $gitpath";
  system($cmd);
};


#Now create command file

my @filelist2 = (
  "FHEM/.*.pm",
  "FHEM/lib/FUIP/.*.pm",
  "FHEM/lib/FUIP/css/.*.css",
  "FHEM/lib/FUIP/fonts/.*",
  "FHEM/lib/FUIP/html/.*",
  "FHEM/lib/FUIP/images/.*",
  "FHEM/lib/FUIP/doc/.*",
  "FHEM/lib/FUIP/view-images/.*",
  "FHEM/lib/FUIP/js/.*.js",
  "FHEM/lib/FUIP/View/.*.pm",
  "FHEM/lib/FUIP/jquery-ui/.*",
  "FHEM/lib/FUIP/jquery-ui/images/.*"
);


# Can't make negative regexp to work, so do it with extra logic
my %skiplist2 = ( );

# Read in the file timestamps
my %filetime2;
my %filesize2;
my %filedir2;
foreach my $fspec (@filelist2) {
  $fspec =~ m,^(.+)/([^/]+)$,;
  my ($dir,$pattern) = ($1, $2);
  my $tdir = $dir;
  opendir DH, $dir || die("Can't open $dir: $!\n");
  foreach my $file (grep { /$pattern/ && -f "$dir/$_" } readdir(DH)) {
    next if($skiplist2{$tdir} && $file =~ m/$skiplist2{$tdir}/);
    my @st = stat("$dir/$file");
    my @mt = localtime($st[9]);
    $filetime2{"$tdir/$file"} = sprintf "%04d-%02d-%02d_%02d:%02d:%02d",
                $mt[5]+1900, $mt[4]+1, $mt[3], $mt[2], $mt[1], $mt[0];

	open(FH, "$dir/$file");
	if($file =~ m/.*(png|jpg)$/) {
		binmode FH;
	};
    my $data = join("", <FH>);
    close(FH);

    $filesize2{"$tdir/$file"} = length($data); # $st[7];
    $filedir2{"$tdir/$file"} = $dir;
  }
  closedir(DH);
}

my %controls = (fuip=>0);
foreach my $k (keys %controls) {
  my $fname = "controls_$k.txt";
  $controls{$k} = new IO::File ">$fname" || die "Can't open $fname: $!\n";
  if(open(ADD, "fhemupdate.control.$k")) {
    while(my $l = <ADD>) {
      my $fh = $controls{$k};
      print $fh $l;
    }
    close ADD;
  }
}

my $cnt;
foreach my $f (sort keys %filetime2) {
  my $fn = $f;
  $fn =~ s/.txt$// if($fn =~ m/.pl.txt$/);
  foreach my $k (keys %controls) {
    my $fh = $controls{$k};
    print $fh "UPD $filetime2{$f} $filesize2{$f} $fn\n"
  }
}

foreach my $k (keys %controls) {
  close $controls{$k};
}
