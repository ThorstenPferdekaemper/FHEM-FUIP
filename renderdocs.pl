use strict;
use warnings;

use Cwd qw( abs_path );
use File::Basename qw( dirname );
use File::Path qw( remove_tree );
use File::Copy qw( copy );
my $incdir = dirname(abs_path($0)).'/FHEM';
$incdir =~ s=\\=/=g;
push(@INC,$incdir); 


sub loadViews() {
	my $viewsPath = $incdir . "/lib/FUIP/View/";

	if(not opendir(DH, $viewsPath)) {
		die "Cannot read view modules";
	};	
	foreach my $m (sort readdir(DH)) {
		next if($m !~ m/(.*)\.pm$/);
		my $viewFile = $viewsPath . $m;
		if(-r $viewFile) {
			print("Loading view: $viewFile\n");
			my $includeResult = do $viewFile;
			if(not $includeResult) {
				die "Error in view module $viewFile: $@";
			}
		} else {
			die "Error loading view module file: $viewFile";
		}
	}
	closedir(DH);
};


sub render() {
	# start of help file
	open(FILE, $incdir.'/lib/FUIP/doc/maindoc.html');
	my @maindocLines = <FILE>;
	close(FILE);
	my $result = join("",@maindocLines);
	
	# render docu for all the (selectable) views	
	my @viewclasses = sort keys %FUIP::View::selectableViews;	
	for	my $view (@viewclasses) {
		next if $view eq "FUIP::View";
		my (undef,undef,$viewname) = split(/::/,$view);
		$result .= '
			<h3 id="views-'.$viewname.'">'.$viewname.': '.$FUIP::View::selectableViews{$view}{title}.'</h3>
			<img src="doc/FUIP-View-'.$viewname.'.png" style="border-style:solid;border-width:1px;float:left;margin-right:10px;margin-bottom:10px" />'.$view->getDocu();
		my $fields = $view->getStructure();	
		my @fieldnames = map { $_->{id} } grep { $_->{id} ne "class" and $_->{type} ne "dimension" and $_->{type} ne "flexfields"} @$fields;
		if(@fieldnames) {
			$result .= '<br>Die View '.$viewname.' l&auml;sst sich &uuml;ber die folgenden Felder konfigurieren: <i>'.join('</i>, <i>',@fieldnames).'</i>.';

		};
		$result .= '<p style="clear:left;height:0em;">
			<ul>';
		for my $field (@$fields) {
			# next if $field->{id} =~ /^(class|title|label|sizing|popup)$/;
			next if $field->{type} =~ /^(dimension|flexfields)$/;
			my $doctext = $view->getDocu($field->{id},1); # 1 => only specific docu 
			next unless $doctext;
			$result .= '<li><b>'.$viewname.' - '.$field->{id}.'</b><br>'.$doctext.'</li>';
		};	
		$result .= '</ul><br>';
	};
	$result .= '
		</body>
		</html>';	
	return ("text/html; charset=utf-8", $result);
};


print "Ready to start\n";
loadViews();
my $docu = render();
# print $docu;

my $docuPath = dirname(abs_path($0)).'/docu';
if(-d $docuPath) {
	remove_tree($docuPath, { verbose => 1, keep_root => 1 } );
}else{
    mkdir($docuPath);
};


my $fileName = $docuPath.'/docu.html';
if(open(FH, ">$fileName")) {
	binmode (FH);
    print FH $docu;
	close(FH);
} else {
    die "Can't open $fileName: $!";
}

#Create dir for images etc.
my $imgPath = $docuPath.'/doc';
mkdir($imgPath);
opendir(DH, $incdir.'/lib/FUIP/doc') or die "Cannot read docu images";
foreach my $m (readdir(DH)) {
	next if($m eq 'maindoc.html');
	copy($incdir.'/lib/FUIP/doc/'.$m, $imgPath);
};	
opendir(DH, $incdir.'/lib/FUIP/view-images') or die "Cannot read docu images";
foreach my $m (readdir(DH)) {
	next if($m !~ m/(.*)\.png$/);
	copy($incdir.'/lib/FUIP/view-images/'.$m, $imgPath);
};	








