#
#
# 42_FUIP.pm
# written by Thorsten Pferdekaemper
#
##############################################
# $Id: 42_FUIP.pm 00035 2018-08-25 15:00:00Z Thorsten Pferdekaemper $

package main;

sub
FUIP_Initialize($) {
	# load view modules
	FUIP::loadViews();
    my ($hash) = @_;
    $hash->{DefFn}     = "FUIP::Define";
	$hash->{SetFn}     = "FUIP::Set";
	$hash->{GetFn}     = "FUIP::Get";
    $hash->{UndefFn}   = "FUIP::Undef";
	FUIP::setAttrList($hash);
	$hash->{AttrFn}    = "FUIP::Attr";
	$hash->{parseParams} = 1;	
    return undef;
 }


package FUIP;

use strict;
use warnings;
use POSIX qw(ceil);
use vars qw(%data);
use HttpUtils;
use Scalar::Util qw(blessed);
use File::Basename qw(basename);

use lib::FUIP::Model;
use lib::FUIP::View;

# selectable views
my $selectableViews = \%FUIP::View::selectableViews;

my $matchlink = "^\/?(([^\/]*(\/[^\/]+)*)\/?)\$";
my $fuipPath = $main::attr{global}{modpath} . "/FHEM/lib/FUIP/";


# possible values of attributes can change...
sub setAttrList($) {
	my ($hash) = @_;
    $hash->{AttrList}  = "locked:0,1 fhemwebUrl baseWidth baseHeight pageWidth styleColor styleBackgroundImage:";
	my $imageNames = getImageNames();
	$hash->{AttrList} .= join(",",@$imageNames);
}


# load view modules
sub loadViews() {
	my $viewsPath = $fuipPath . "View/";

	if(not opendir(DH, $viewsPath)) {
		main::Log3(undef, 1, "FUIP ERROR: Cannot read view modules");
		return;
	};	
	foreach my $m (sort readdir(DH)) {
		next if($m !~ m/(.*)\.pm$/);
		my $viewFile = $viewsPath . $m;
		if(-r $viewFile) {
			main::Log3(undef, 4, 'FUIP: Loading view: ' .  $viewFile);
			my $includeResult = do $viewFile;
			if(not $includeResult) {
				main::Log3(undef, 1, 'FUIP: Error in view module: ' . $viewFile . ":\n $@");
			}
		} else {
			main::Log3(undef, 1, 'FUIP: Error loading view module file: ' .  $viewFile);
		}
	}
	closedir(DH);
};


# determine possible image names (for background)
sub getImageNames() {
	my $imagesPath = $fuipPath . "images/";
	my @result;
	if(not opendir(DH, $imagesPath)) {
		main::Log3(undef, 1, "FUIP ERROR: Cannot read image directory");
		return \@result;
	};	
	foreach my $m (sort readdir(DH)) {
		next if($m !~ m/(.*)\.(jpg|png)$/);
		push(@result,$m);
	}
	closedir(DH);
	return \@result;
};


#########################
sub addExtension($$$$) {
    my ($name,$func,$link,$friendlyname)= @_;

    # do some cleanup on link/url
    #   link should really show the link as expected to be called (might include trailing / but no leading /)
    #   url should only contain the directory piece with a leading / but no trailing /
    #   $1 is complete link without potentially leading /
    #   $2 is complete link without potentially leading / and trailing /
    $link =~ /$matchlink/;

    my $url = "/".$2;
    my $modlink = $1;

	if(exists($main::data{FWEXT}{$url})) {
		my $msg = 'Link "'.$url.'" already registered';
		if(defined($main::data{FWEXT}{$url}{deviceName})) {
			$msg .= ' by device '.$main::data{FWEXT}{$url}{deviceName};
		};	
		return $msg;
	};
    main::Log3($name, 3, "FUIP: Registering $name for URL $url");
    $main::data{FWEXT}{$url}{deviceName} = $name;
    $main::data{FWEXT}{$url}{FUNC} = $func;
    $main::data{FWEXT}{$url}{LINK} = $modlink;
    $main::data{FWEXT}{$url}{NAME} = $friendlyname;
	return undef;
}

sub removeExtension($) {
    my ($link)= @_;

    # do some cleanup on link/url
    #   link should really show the link as expected to be called (might include trailing / but no leading /)
    #   url should only contain the directory piece with a leading / but no trailing /
    #   $1 is complete link without potentially leading /
    #   $2 is complete link without potentially leading / and trailing /
    $link =~ /$matchlink/;

    my $url = "/".$2;

    my $name= $main::data{FWEXT}{$url}{deviceName};
    main::Log3 $name, 3, "Unregistering FUIP $name for URL $url...";
    delete $main::data{FWEXT}{$url};
}

##################

##################
sub Define($$$) {

  my ($hash, $a, undef) = @_;
  # return "Usage: define <name> FUIP <infix> <directory> <friendlyname>"  if(int(@a) != 5);
  my $name= $a->[0];
  # TODO: check if name allows to be used in an URL
  my $infix= lc($name)."/";
  my $directory= "./www/tablet";  # TODO: change via attribute?
  my $friendlyname= $name;

  $hash->{fhem}{infix}= $infix;
  $hash->{fhem}{directory}= $directory;
  $hash->{fhem}{friendlyname}= $friendlyname;

  my $msg = addExtension($name, "FUIP::CGI", $infix, $friendlyname);
  return $msg if($msg);
  
  $hash->{STATE} = $name;
  $hash->{pages} = {};
  $hash->{editOnly} = 0;
  # set default base dimensions
  $main::attr{$name}{baseWidth} = 142;
  $main::attr{$name}{baseHeight} = 108;  
  # load old definition, if exists
  load($hash);
  return undef;
}

##################
sub Undef($$) {

  my ($hash, $name) = @_;

  removeExtension($hash->{fhem}{infix});

  return undef;
}


sub Attr ($$$$) {
	my ( $cmd, $name, $attrName, $attrValue  ) = @_;
	# if fhemwebUrl is changed, we need to refresh the buffer
	if($attrName eq "fhemwebUrl") {
		FUIP::Model::refresh($name);
	};
	if($cmd eq "set" and $attrName eq "pageWidth") {
		if($attrValue < 100 or $attrValue > 2500) {
			return "pageWidth must be a number between 100 and 2500";
		}	
	};
	return undef;
}


sub createRoomsMenu($$) {
	my ($hash,$pageid) = @_;
	my $cell = FUIP::Cell->createDefaultInstance($hash);
	$cell->{title} = "R&auml;ume";	
	$cell->position(0,1);
    # create a MenuItem view for each room
	my @rooms = FUIP::Model::getRooms($hash->{NAME});
	my $posY = 0; 
	for my $room (@rooms) {
		my $menuItem = FUIP::View::MenuItem->createDefaultInstance($hash);
		$menuItem->{text} = $room;
		$menuItem->{link} = "room/".$room;
		$menuItem->{active} = "0";
		my @parts = split('/',$pageid);
		if(@parts > 1) {
			if($parts[0] =~ /room|device/ and $parts[1] eq $room) {
				$menuItem->{active} = "1";
			};
		};	
		$menuItem->position(0,$posY);
		my (undef,$h) = $menuItem->dimensions();
		$posY += $h;  
		push(@{$cell->{views}}, $menuItem);												
	};
	$cell->dimensions(1,undef);
    return $cell;
};


sub addStandardCells($$$) {
	my ($hash,$cells,$pageid) = @_;
	my $view = FUIP::View::HomeButton->createDefaultInstance($hash);
	$view->{active} = ($pageid eq "home" ? 1 : 0);
	$view->position(0,0);
	my $cell = FUIP::Cell->createDefaultInstance($hash);
	$cell->position(0,0);
	$cell->{views} = [ $view ];
	push(@$cells,$cell);
	$view = FUIP::View::Clock->createDefaultInstance($hash);
	$view->position(0,0);
	$cell = FUIP::Cell->createDefaultInstance($hash);
	$cell->position(5,0);
	$cell->{views} = [ $view ];
	push(@$cells,$cell);
	my $title = ($pageid eq "home" ? "Home, sweet home" : ( split '/', $pageid )[ -1 ]);
	$view = FUIP::View::Title->createDefaultInstance($hash);
	$view->{text} = $title;
	$view->position(0,0);
	$cell = FUIP::Cell->createDefaultInstance($hash);
	$cell->position(1,0);
	$cell->{views} = [ $view ];
	push(@$cells,$cell);
	push(@$cells,createRoomsMenu($hash,$pageid));
};


sub determineMaxCols($;$) {
	my ($hash,$default) = @_;
	$default = 7 unless defined $default;
	my $baseWidth = main::AttrVal($hash->{NAME},"baseWidth",142);
	my $pageWidth = main::AttrVal($hash->{NAME},"pageWidth",undef);
	#should be compatible to what we did before
	return $default unless $pageWidth;
	use integer;
	my $maxCols = $pageWidth / ($baseWidth + 10);
	no integer;
	return 1 unless $maxCols > 1;  # 0 or negative cols do not make sense
	return $maxCols;
};


sub renderPage($$$) {
	my ($hash,$currentLocation,$locked) = @_;
	# falls $locked, dann werden die Editierfunktionen nicht mit gerendert
	my $title = $hash->{pages}{$currentLocation}{title};
	$title = $currentLocation unless $title;
	$title = "FHEM Tablet UI by FUIP" unless $title;
	my $baseWidth = main::AttrVal($hash->{NAME},"baseWidth",142);
	my $baseHeight = main::AttrVal($hash->{NAME},"baseHeight",108);	
	my $styleColor = main::AttrVal($hash->{NAME},"styleColor","#808080");
	my $pageWidth = main::AttrVal($hash->{NAME},"pageWidth",undef);
  	my $result = 
	   "<!DOCTYPE html>
		<html".($locked ? "" : " data-name=\"".$hash->{NAME}."\" data-pageid=\"".$currentLocation."\" data-editonly=\"".$hash->{editOnly}."\"").">
			<head>
				<script type=\"text/javascript\">
					// when using browser back or so, we should reload
					if(performance.navigation.type == 2){
						location.reload(true);
					};	
				</script>
				<title>".$title."</title>
				<link rel=\"shortcut icon\" href=\"/fhem/icons/favicon\" />
				<link rel=\"stylesheet\" href=\"/fhem/".lc($hash->{NAME})."/lib/font-awesome.min.css\" />
				<link rel=\"stylesheet\" href=\"/fhem/".lc($hash->{NAME})."/lib/nesges.css\">
				<script type=\"text/javascript\" src=\"/fhem/".lc($hash->{NAME})."/lib/jquery.min.js\"></script>
		        <script type=\"text/javascript\" src=\"/fhem/".lc($hash->{NAME})."/fuip/jquery-ui/jquery-ui.min.js\"></script>".
				($locked ? "" : "<link rel=\"stylesheet\" href=\"/fhem/".lc($hash->{NAME})."/fuip/jquery-ui/jquery-ui.css\">
								<!-- tablesorter -->
								 <script type=\"text/javascript\" src=\"/fhem/".lc($hash->{NAME})."/fuip/js/jquery.tablesorter.js\"></script>
								 <script type=\"text/javascript\" src=\"/fhem/".lc($hash->{NAME})."/fuip/js/jquery.tablesorter.widgets.js\"></script>").
				"<script type=\"text/javascript\" src=\"/fhem/".lc($hash->{NAME})."/lib/jquery.gridster.min.js\"></script>
                <script src=\"/fhem/".lc($hash->{NAME})."/js/fhem-tablet-ui.js\"></script>".
				($locked ? "" : "<script src=\"/fhem/".lc($hash->{NAME}).
				"/fuip/js/fuip.js\"></script>
  				    <script>
						fuipInit(".$baseWidth.",".$baseHeight.",".determineMaxCols($hash,99).")
					</script>
								 <link rel=\"stylesheet\" href=\"/fhem/".lc($hash->{NAME})."/fuip/css/theme.blue.css\">").
                "<style type=\"text/css\">
	                .fuip-color {
		                color: ".$styleColor.";
                    }
					.gridster ul li {
						border-radius:8px;";
	my $backgroundImage = main::AttrVal($hash->{NAME},"styleBackgroundImage",undef);
	$result .= '		background: rgba(0, 0, 0, 0.7) !important;' if($backgroundImage);
	$result .= "
					}
					.gridster ul li header {
						border-radius:8px;";
	$result .= '		background: rgba(0, 0, 0, 0.7) !important;' if($backgroundImage);
	$result .= "
					}
					.tablesorter-filter option {
						background-color:#fff;
					}
					select.tablesorter-filter {
						-moz-appearance: auto;
						-webkit-appearance: menulist;
						appearance: auto;
						border-radius: 0;
						padding: 4px !important;
					}
					select.fuip {
						-moz-appearance: auto;
						-webkit-appearance: menulist;
						appearance: auto;
						border-radius: 0;
						padding: 1px 0px !important;	
						border-style: inset;	
						border-width: 2px;
						border-color: initial;
						border-image: initial;
						width: initial;
						color: initial;
						background-color: initial;
					}
					option.fuip {
						background-color: initial;
					}	
                </style>
				<meta name=\"widget_base_width\" content=\"".$baseWidth."\">
				<meta name=\"widget_base_height\" content=\"".$baseHeight."\">".
				(main::AttrVal($hash->{NAME},"fhemwebUrl",undef) ? "<meta name=\"fhemweb_url\" content=\"".main::AttrVal($hash->{NAME},"fhemwebUrl",undef)."\">" : "").
				($locked ? '<meta name="gridster_disable" content="1">' : "").
            "</head>
            <body";
	if($backgroundImage) {
		$result .= ' style="background:#000000 url(/fhem/'.lc($hash->{NAME}).'/fuip/images/'.$backgroundImage.') 0 0/';
		if($pageWidth) {
			$result .= $pageWidth.'px';
		}else{	
			$result .= 'cover';
		};
		$result .= ' no-repeat"';
	};
	$result .= '>	
                <div class="gridster"';
	if($pageWidth) {
		$result .= ' style="width:'.$pageWidth.'px"';
	};
	$result .= '>
                    <ul>';
	# render Cells	
	$result .= renderCells($hash,$currentLocation,$locked);
	$result.= '</ul>
	           </div>'.
			   ($locked ? "" :
			   '<div id="viewsettings">
			   </div>
			   <div id="valuehelp">
			   </div>
				<div data-type="symbol" data-icon="ftui-door" class="hide"></div>
				<div data-type="symbol" data-icon="fa-volume-up" class="hide"></div>
				<div data-type="symbol" data-icon="mi-local_gas_station" class="hide"></div>
				<div data-type="symbol" data-icon="oa-secur_locked" class="hide"></div>
				<div data-type="symbol" data-icon="wi-day-rain-mix" class="hide"></div>
				<div data-type="symbol" data-icon="fs-ampel_aus" class="hide"></div>').	
			'<div id="inputpopup01">
			</div>	
       </body>
       </html>';
    return ("text/html; charset=utf-8", $result);
};


sub findDialogFromFieldId($$$$) {
	# gets the FUIP::Dialog instance at the "end" of the field id
	# if this is not a dialog, it is created and assigned to the field of 
	# the related view
	my ($hash,$pageid,$cellid,$fieldid) = @_;
	# find the dialog and render it	
	my $cell = $hash->{pages}{$pageid}{cells}[$cellid];
	my @fieldIdSplit = split(/-/,$fieldid);
	# $fieldid should have the form like views-1-popup-views-4-popup-views...
	# or in general
	# <name>-<num>-<name>-<name>-<num>-<name>...
	my $view;
	my $dialog = $cell;
	my $popupName;
	while(@fieldIdSplit) {
		$view = $dialog->{shift(@fieldIdSplit)}[shift(@fieldIdSplit)];
		$popupName = shift(@fieldIdSplit);
		$dialog = $view->{$popupName};
	};	
	# if the dialog maintenance is called, we can assume that the "popup"
	# field is not defaulted (i.e. inactive) and that we need a dialog instance
	if( not blessed($dialog) or not $dialog->isa("FUIP::Dialog")) {
		$dialog = FUIP::Dialog->createDefaultInstance($hash);
		$view->{$popupName} = $dialog;
		$view->{defaulted}{$popupName} = 0;
	};		
	return $dialog;
};


sub renderPopupMaint($$) {
	my ($hash,$request) = @_;
	# get pageid, cellid and fieldid
	my $urlParams = urlParamsGet($request);
	$DB::single = 1;
	# TODO: error management
	return undef unless exists $urlParams->{pageid};
	return undef unless exists $urlParams->{cellid};
	return undef unless exists $urlParams->{fieldid};

	my $title = "Maintain Popup Content";
	my $styleColor = main::AttrVal($hash->{NAME},"styleColor","#808080");
  	my $result = 
	   "<!DOCTYPE html>
		<html data-name=\"".$hash->{NAME}."\" data-pageid=\"".$urlParams->{pageid}."\" 
				data-cellid=\"".$urlParams->{cellid}."\" data-fieldid=\"".$urlParams->{fieldid}."\"
				data-editonly=\"".$hash->{editOnly}."\">
			<head>
	            <title>".$title."</title>
				<link rel=\"shortcut icon\" href=\"/fhem/icons/favicon\" />
				<link rel=\"stylesheet\" href=\"/fhem/".lc($hash->{NAME})."/lib/font-awesome.min.css\" />
				<link rel=\"stylesheet\" href=\"/fhem/".lc($hash->{NAME})."/lib/nesges.css\">
				<script type=\"text/javascript\" src=\"/fhem/".lc($hash->{NAME})."/lib/jquery.min.js\"></script>
		        <script type=\"text/javascript\" src=\"/fhem/".lc($hash->{NAME})."/fuip/jquery-ui/jquery-ui.min.js\"></script>".
				"<link rel=\"stylesheet\" href=\"/fhem/".lc($hash->{NAME})."/fuip/jquery-ui/jquery-ui.css\">
								<!-- tablesorter -->
								 <script type=\"text/javascript\" src=\"/fhem/".lc($hash->{NAME})."/fuip/js/jquery.tablesorter.js\"></script>
								 <script type=\"text/javascript\" src=\"/fhem/".lc($hash->{NAME})."/fuip/js/jquery.tablesorter.widgets.js\"></script>".
				"<script type=\"text/javascript\" src=\"/fhem/".lc($hash->{NAME})."/lib/jquery.gridster.min.js\"></script>".
                "<script src=\"/fhem/".lc($hash->{NAME})."/js/fhem-tablet-ui.js\"></script>".
				"<script src=\"/fhem/".lc($hash->{NAME}).
				"/fuip/js/fuip.js\"></script>
  				    <script>
						fuipInit(10,10,".determineMaxCols($hash,99).")
					</script>
								 <link rel=\"stylesheet\" href=\"/fhem/".lc($hash->{NAME})."/fuip/css/theme.blue.css\">".
                "<style type=\"text/css\">
	                .fuip-color {
		                color: ".$styleColor.";
                    }
					.gridster ul li {
						border-radius:8px;";
	$result .= "
					}
					.gridster ul li header {
						border-radius:8px;";
	$result .= "
					}
					.tablesorter-filter option {
						background-color:#fff;
					}
					select.tablesorter-filter {
						-moz-appearance: auto;
						-webkit-appearance: menulist;
						appearance: auto;
						border-radius: 0;
						padding: 4px !important;
					}
					select.fuip {
						-moz-appearance: auto;
						-webkit-appearance: menulist;
						appearance: auto;
						border-radius: 0;
						padding: 1px 0px !important;	
						border-style: inset;	
						border-width: 2px;
						border-color: initial;
						border-image: initial;
						width: initial;
						color: initial;
						background-color: initial;
					}
					option.fuip {
						background-color: initial;
					}	
                </style>".
				(main::AttrVal($hash->{NAME},"fhemwebUrl",undef) ? "<meta name=\"fhemweb_url\" content=\"".main::AttrVal($hash->{NAME},"fhemwebUrl",undef)."\">" : "").
				'<script>
					$( function() {
						$( "#popupcontent" ).resizable({
							stop: onDialogResize
						});
					} );
				</script>'.
            "</head>
            <body style='background-color:lightgrey;'";
	# find the dialog and render it	
	my $dialog = findDialogFromFieldId($hash, $urlParams->{pageid}, $urlParams->{cellid}, $urlParams->{fieldid});
	my ($width,$height) = $dialog->dimensions();	
	$result .= '>	
	<div id="popupcontent" class="fuip-droppable"
		style="width:'.$width.'px;height:'.$height.'px;border:0;border-bottom:1px solid #aaa;
									border-radius: 4px;box-shadow: 0 3px 9px rgba(0, 0, 0, 0.5);
									border: 1px solid rgba(0, 0, 0, 0.1);
									background-color: #2A2A2A;
									margin:0;display:inline;position:absolute;top:0;left:0;">
		<span style="position: absolute; right: 1px; top: 0;" class="fa-stack fa-lg"
								onclick="openSettingsDialog(\''.$hash->{NAME}.'\',\''.$urlParams->{pageid}.'\',\''.$urlParams->{cellid}.'\',\''.$urlParams->{fieldid}.'\')">
									<i class="fa fa-square-o fa-stack-2x"></i>
									<i class="fa fa-cog fa-stack-1x"></i>
							</span>							
		<header>'.$dialog->{title}.'</header>';
	$result .= $dialog->getHTML(0);  # this is maint, so never locked	
	$result .= '</div>
		<div id="viewsettings">
		</div>
		<div id="valuehelp">
		</div>
       </body>
       </html>';
    return ("text/html; charset=utf-8", $result);
};


sub defaultPageIndex($) {
	my ($hash) = @_;
	my @cells;
	# home button and rooms menu
	addStandardCells($hash, \@cells, "home");
	my $baseWidth = main::AttrVal($hash->{NAME},"baseWidth",142);
	# get "room views" 
	my @rooms = FUIP::Model::getRooms($hash->{NAME});
	foreach my $room (@rooms) {
	    my $cell = FUIP::Cell->createDefaultInstance($hash);
		$cell->{title} = $room;
		$cell->{views} = getDeviceViewsForRoom($hash,$room,"overview");
		$cell->applyDefaults();
		my $posY = 0;  
		for my $view (@{$cell->{views}}) {
			# try to center in X direction
			my ($w,$h) = $view->dimensions();
			$view->position(($baseWidth - $w)/2, $posY);  
			$posY += $h;  # next one is directly after this one 	
		};
		$cell->dimensions(1,undef);  #let system determine height
		push(@cells, $cell);
	};
	$hash->{pages}{"home"} = FUIP::Page->createDefaultInstance($hash);
	$hash->{pages}{"home"}{cells} = \@cells;
};


sub defaultPageRoom($$){
	my ($hash,$room) = @_;
	my $pageid = "room/".$room;
	my $viewsInRoom = getDeviceViewsForRoom($hash,$room,"room");
	# make a "Bag" of all switches (lights)
	my @switches;
	my @views;
	for my $view (@$viewsInRoom) {
		if($view->isa('FUIP::View::SimpleSwitch')) {
			push(@switches,$view);
		}else{
			push(@views, $view);
		};		
	};
	my @cells;
	if(@switches) {
		my $num = @switches;	
		use integer; 
		my $rows = sqrt($num);
		my $cols = $num / $rows;
		my $fullrows = $num % $rows;	
		if($fullrows) {
			$cols++;
		}else{
			$fullrows = $rows;
		};	
		no integer;
		$cols = $num if($cols > $num);
		my $i = 0;	
		my $posY = 0;
		for(my $row = 0; 1; $row++) {		
			$cols-- if($row == $fullrows); 
			my $posX = 0;
			my $maxHeight = 1;
			for( my $col = 0; $col < $cols; $col++ ) {
				$switches[$i]->position($posX,$posY);
				my ($w,$h) = $switches[$i]->dimensions();
				$posX += $w;
				$maxHeight = $h if($h > $maxHeight);	
				$i++;
				last if($i >= $num);
			};
			$posY += $maxHeight;
			last if($i >= $num);			
        };
		my $cell = FUIP::Cell->createDefaultInstance($hash);
		$cell->{title} = "Lampen";
		$cell->{views} = \@switches;
		push(@cells,$cell);
	};	
	# create cells 
	for my $view (@views) {
		$view->position(0,0);
		my $cell = FUIP::Cell->createDefaultInstance($hash);
		$cell->{views} = [$view];
		push(@cells,$cell);
	};
	# home button and rooms menu
	addStandardCells($hash, \@cells, $pageid);
	# add to pages
	$hash->{pages}{$pageid} = FUIP::Page->createDefaultInstance($hash);
	$hash->{pages}{$pageid}{cells} = \@cells;
};


sub defaultPageDevice($$$){
    my ($hash,$room,$device) = @_;
	my $pageid = "device/".$room."/".$device;
	my @cells;
	addStandardCells($hash, \@cells,$pageid);
	my $deviceView = FUIP::View::ReadingsList->createDefaultInstance($hash);
	$deviceView->{device} = $device;
	my $cell = FUIP::Cell->createDefaultInstance($hash);
	$cell->{views} = [$deviceView];
	push(@cells, $cell);
	$hash->{pages}{$pageid} = FUIP::Page->createDefaultInstance($hash);
	$hash->{pages}{$pageid}{cells} = \@cells;
};


sub defaultPage($$){
	#creates a default (almost empty) page
	my ($hash,$pageId) = @_;
	$hash->{pages}{$pageId} = FUIP::Page->createDefaultInstance($hash);
	$hash->{pages}{$pageId}{cells} = [FUIP::Cell->createDefaultInstance($hash)];
};


sub getDeviceView($$$){
	my ($hash,$name, $level) = @_;
	my $device = FUIP::Model::getDevice($hash->{NAME},$name,["TYPE","subType","state","chanNo","model"]);
	return undef unless defined $device;
	# don't show FileLogs or FHEMWEBs
	# TODO: rooms and types to ignore could be configurable
	return undef if($device->{Internals}{TYPE} =~ m/^(FileLog|FHEMWEB|at|notify|SVG)$/);
	# we have something special for SYSMON
	if($device->{Internals}{TYPE} eq "SYSMON" and not $level eq "overview") {
		my $view = FUIP::View::Sysmon->createDefaultInstance($hash);
		$view->{device} = $name;
		return $view;
	};
	# don't show HM485 devices, only channels
	if($device->{Internals}{TYPE} eq "HM485") {
		return undef unless $device->{Internals}{chanNo};
	};	
	my $subType = (exists($device->{Attributes}{subType}) ? $device->{Attributes}{subType} : "none");
	# subType "key" does not make that much sense 
	return undef if($subType eq "key");
	my $model = (exists($device->{Attributes}{model}) ? $device->{Attributes}{model} : "none");
	# TODO: Does subType "heating" exist at all?
	if($subType eq "heating" or 
		$device->{Internals}{TYPE} eq "CUL_HM" and defined($device->{Internals}{chanNo}) 
			and ( $model eq "HM-CC-RT-DN" and $device->{Internals}{chanNo} eq "04"
			   or $model eq "HM-TC-IT-WM-W-EU" and $device->{Internals}{chanNo} eq "02" )){
		my $view = FUIP::View::Thermostat->createDefaultInstance($hash);
		$view->{device} = $name;
		if($level eq 'overview') {
			$view->{readonly} = "on";
			$view->{defaulted}{readonly} = 0;
			return $view;
		}else{
			$view->{size} = "big";	
			$view->{defaulted}{size} = 0;
			return $view;
		};	
	};
    my $view;
	# TODO: Does subType "shutter" exist at all?
	if($subType =~ /^(shutter|blind)$/){
		if($level eq 'overview') {
			$view = FUIP::View::ShutterOverview->createDefaultInstance($hash);
		}else{
			$view = FUIP::View::ShutterControl->createDefaultInstance($hash);
		};	
	}else{
		my $state = (exists($device->{Readings}{state}) ? $device->{Readings}{state} : 0);
		if($state eq "on" or $state eq "off") {
			$view = FUIP::View::SimpleSwitch->createDefaultInstance($hash);
		}else{
			$view = FUIP::View::STATE->createDefaultInstance($hash);
		};
	};	
	$view->{device} = $name;
	return $view;
}


sub getDeviceViewsForRoom($$$) {
	my ($hash,$room,$level) = @_;
	my @views;
	my $devices = FUIP::Model::getDevicesForRoom($hash->{NAME},$room);
	foreach my $d (@$devices) {
		my $deviceView = getDeviceView($hash,$d,$level);
		next unless $deviceView;
		push(@views,$deviceView);
	};
	return \@views;
};


sub findPositions($$) {
	my ($hash,$pageId) = @_;
	my $cells = $hash->{pages}{$pageId}{cells};
	my $maxCols = determineMaxCols($hash);
	# find positions for all views
	# cells array:
    #   0 or undef means that the cell is free
    #   everything else means that the cell is occupied 	
	#   the left upper entry of an occupied block contains the reference to "its" view
	#   all other entries of an occupied block contain 1                
	my @places; 	
	# occupy places for cells which are already positioned
	for my $cell (@{$cells}) {
		my ($x,$y) = $cell->position();
		next unless(defined($x) and defined($y));
		# get dimensions
		my @dim = $cell->dimensions();
		for (my $yv = $y; $yv < $y + $dim[1]; $yv++) {
			for (my $xv = $x; $xv < $x + $dim[0]; $xv++) {
				$places[$xv][$yv] = 1;
			}	
		}	
	};
	
	for my $cell (@$cells) {
		my ($x,$y) = $cell->position();
		# ignore if already positioned
		next if(defined($x) and defined($y));
		# get dimensions
		my @dim = $cell->dimensions();
		# find a nice free spot
		my $found = 0;
		for ($y = 0; 1; $y++) {
			# for each column in the row
			# we need to check after the loop body to give
			# views a chance which are actually wider than the page
			for ($x=0; 1; $x++) {
				$found = 1;
				# check dimensions of view
				for (my $yv = $y; $yv < $y + $dim[1]; $yv++) {
					for (my $xv = $x; $xv < $x + $dim[0]; $xv++) {
						if($places[$xv][$yv]) {  # occupied
							$found = 0;
							last;
						}	
					}	
					last unless $found;
				}
				last if $found or $x + $dim[0] >= $maxCols;
			}
			last if $found;
	    };
		# "not found" would be very weird here.
		# TODO: What to do?
		main::Log3($hash, 1, "FUIP: No place found for cell") unless $found;
		# now occupy the place
		for (my $yv = $y; $yv < $y + $dim[1]; $yv++) {
			for (my $xv = $x; $xv < $x + $dim[0]; $xv++) {
				$places[$xv][$yv] = 1;
			}	
		}	
		# and remember where this cell goes
		$cell->position($x,$y);
	};
};


sub renderCells($$$) {
	my ($hash,$pageId,$locked) = @_;
	findPositions($hash,$pageId);
	# now try to render this
	my $result;
	my $i = 0;
	my $cells = $hash->{pages}{$pageId}{cells};
	for my $cell (@{$cells}) {
		my ($col,$row) = $cell->position();
		my ($sizeX, $sizeY) = $cell->dimensions();
		$sizeX = ceil($sizeX);
		$sizeY = ceil($sizeY);
		$result .= "<li data-cellid=\"".$i."\" data-row=\"".($row+1)."\" data-col=\"".($col+1)."\" data-sizex=\"".$sizeX."\" data-sizey=\"".$sizeY."\" class=\"fuip-droppable\">";
		$cell->applyDefaults();
		# if there is no title and it is locked, we do not display a header
		# TODO: find better handle for dragging
		if(not $locked or $cell->{title}) {
			$result .= "<header>".($cell->{title} ? $cell->{title} : "").($locked ? "" : " ".$i."
							<span style=\"position: absolute; right: 1px; top: 0;\" class=\"fa-stack fa-lg\"
								onclick=\"openSettingsDialog('".$hash->{NAME}."','".$pageId."','".$i."')\">
									<i class=\"fa fa-square-o fa-stack-2x\"></i>
									<i class=\"fa fa-cog fa-stack-1x\"></i>
							</span>").
						"</header>";
		};				
		$i++;
		$result .= $cell->getHTML($locked);
		$result .= "</li>";
	};
	return $result;
};


sub FW_setPositionsAndDimensions($$$) {
	my ($name,$pageid,$cells) = @_;
	my $hash = $main::defs{$name};
	return unless $hash;
	return unless defined($hash->{pages}{$pageid});
	my $page = $hash->{pages}{$pageid}{cells};
	#{
    #    'size_y' => 1,
    #    'col' => 1,
    #    'size_x' => 1,
    #    'row' => 1
    #},
	for(my $i = 0; $i < @{$page}; $i++) {
		last unless defined($cells->[$i]);
		$page->[$i]{posX} = $cells->[$i]->{col} -1;
		$page->[$i]{posY} = $cells->[$i]->{row} -1; 
		$page->[$i]{width} = $cells->[$i]->{size_x};
		$page->[$i]{height} = $cells->[$i]->{size_y};
	};
};


sub getFuipPage($$) {
	my ($hash,$pageid) = @_;
	
	my $locked = main::AttrVal($hash->{NAME},"locked",0);
	
	# refresh Model buffer if locked
	# if not locked, this would mean very bad performance for e.g. value help for devices
	FUIP::Model::refresh($hash->{NAME}) if($locked);
	
	# "" goes to "home" 
	if($pageid eq "") {
		$pageid = "home";
	};	
	
	# do we need to create the page?
	if(not defined($hash->{pages}{$pageid})) {
		return("text/plain; charset=utf-8", "FUIP page $pageid does not exist") if($locked);
		if($pageid eq "home"){
			defaultPageIndex($hash);
		}else{
			my @path = split(/\//,$pageid);
			if($path[0] eq "room") {
				defaultPageRoom($hash,$path[1]);
			}elsif($path[0] eq "device"){
				defaultPageDevice($hash,$path[1],$path[2]);
			}else{		
				defaultPage($hash,$pageid);
			};
		}		
	};
	# ok, we can render this	
    return renderPage($hash, $pageid, $locked);
};


sub showAllIcons() {
  	my $result = 
	   '<!DOCTYPE html>
		<html>
			<head>
				<script type="text/javascript" src="/fhem/ui/lib/jquery.min.js"></script>
				<script src="/fhem/ui/js/fhem-tablet-ui.js"></script>
				<script>
					$(function() {
						$("body").css("background-color", "#E0E0E0");
						$("body").css("color", "#101010");
					});	
				
					function getIcons() {
						if(document.styleSheets.length == 0) {
							window.setTimeout(getIcons,1000);
							return;
						};
						var currentSheet = null;
						var i = 0;
						var j = 0;
						var ruleKey = null;
						//loop through styleSheet(s)
						var allIcons = {};
						for(i = 0; i<document.styleSheets.length; i++){
							currentSheet = document.styleSheets[i];
							///loop through css Rules
							for(j = 0; j< currentSheet.cssRules.length; j++){
								if(!currentSheet.cssRules[j].selectorText) { continue; };
								var selectors = currentSheet.cssRules[j].selectorText.split(",");
								for(var k = 0; k < selectors.length; k++) {
									var icons = selectors[k].match(/\.(fa|ftui|mi|oa|wi|fs)-.*(?=::before)/);
									if(!icons){ continue; };
									var icon = icons[0].substring(1);
									// sometimes there is another class...
									icon = icon.split(" ")[0];
									allIcons[icon] = 1;
									break;  // only one name of the same icon is enough
								}
							}
						}
						allIconsAsArr = Object.keys(allIcons);
						allIconsAsArr.sort();
						var html = "<table>";
						for (var i = 0; i < allIconsAsArr.length; i++) {
							var icon = allIconsAsArr[i];
							if (! allIcons.hasOwnProperty(icon)) { continue };
							var prefix = icon.split("-")[0];
							if(prefix == "wi") {
								icon = "wi " + icon;
							};	
							html += "<tr><td style=\"max-width:64px;padding:5px;border-style:solid;border-width:1px;\"><i class=\"fa " +icon+ " bigger bg-orange\"></i></td><td style=\"border-style:solid;border-width:1px;\">"+icon+"</td></tr>";
						};
						html += "</table>";
						$("#allicons").html(html);
					};
					getIcons();		
				</script>
			</head>
			<body>
				<h1>Available Icons</h1>
				<div id="allicons">
				<p>Just a moment, more to come...</p>
				<div data-type="symbol" data-icon="ftui-door"></div>
				<div data-type="symbol" data-icon="fa-volume-up"></div>
				<div data-type="symbol" data-icon="mi-local_gas_station"></div>
				<div data-type="symbol" data-icon="oa-secur_locked"></div>
				<div data-type="symbol" data-icon="wi-day-rain-mix"></div>	
				<div data-type="symbol" data-icon="fs-ampel_aus"></div>
				</div>
			</body>
		</html>';	
	return ("text/html; charset=utf-8", $result);
};


sub urlParamsGet($) {
	my ($request) = @_;
	my @splitAtQ = split(/\?/,$request,2);
	return {} unless exists $splitAtQ[1];
	my @splitAtA = split(/&/,$splitAtQ[1]);
	my %result;
	foreach my $entry (@splitAtA) {
		my ($key,$value) = split(/=/,$entry,2);
		$result{$key} = $value;
	};
	return \%result;
};


sub settingsExport($$) {
	my ($hash,$request) = @_;
	# get pageid and cellid
	my $urlParams = urlParamsGet($request);
	# TODO: error management
	return undef unless exists $urlParams->{pageid};
	my $result = "";
	my $filename = "";
	if(exists $urlParams->{cellid}) {
		# export cell
		$result = $hash->{pages}{$urlParams->{pageid}}{cells}[$urlParams->{cellid}]->serialize(); 	
		$filename = $hash->{NAME}."_".$urlParams->{pageid}."_".$urlParams->{cellid};
	}else{	
		# export page
		$result = $hash->{pages}{$urlParams->{pageid}}->serialize(); 	
		$filename = $hash->{NAME}."_".$urlParams->{pageid};
	};	
	$filename = main::urlEncode($filename).".fuipexp";
	return("application/octet-stream; charset=utf-8\r\nContent-Disposition: attachment; filename=\"".$filename."\"",
		$result); 
};


sub settingsImport($$) {
	my ($hash,$request) = @_;
	# get pageid and cellid
	my $urlParams = urlParamsGet($request);
	# TODO: error management
	# content is now in $urlParams->{content}, but URI-encoded
	return unless $urlParams->{content};
	my $content = $urlParams->{content};
	$content =~ s/\+/%20/g;
	$content = main::urlDecode($content);
	my $confHash = eval($content);
	# cell or page?
	# TODO: Also maybe full FUIP instances?
	my $class = $confHash->{class}; # This allows for other cell-implementations (???)
	delete($confHash->{class});
	# we only allow FUIP::Cell and FUIP::Page so far
	# TODO: real error handling
	return undef unless (exists($urlParams->{cellid}) and $class eq "FUIP::Cell" 
						 or not exists($urlParams->{cellid}) and $class eq "FUIP::Page"); 
	my $newObject = $class->reconstruct($confHash,$hash);
	if(exists($urlParams->{cellid})) {
		delete $newObject->{posX};
		delete $newObject->{posY};
		push(@{$hash->{pages}{$urlParams->{pageid}}{cells}},$newObject);
	}else{
		$hash->{pages}{$urlParams->{pageid}} = $newObject;
	};	
	return("text/plain; charset=utf-8", "File imported successfully");
};


##################
#
# here we answer any request to http://host:port/fhem/$infix and below

sub CGI() {

  my ($request) = @_;   # /$infix/filename
  
  # main::Log3(undef,1,"FUIP Request: ".$request);
  # Match request first without trailing / in the link part 
  if($request =~ m,^(/[^/]+)(/(.*)?)?$,) {
    my $link= $1;
    my $filename= $3;
    my $name;

    # If FWEXT not found for this make a second try with a trailing slash in the link part
    if(! $main::data{FWEXT}{$link}) {
      $link = $link."/";
      return("text/plain; charset=utf-8", "Illegal request: $request") if(! $main::data{FWEXT}{$link});
    }
    
    # get device name
    $name= $main::data{FWEXT}{$link}{deviceName}; 
	
	my $hash = $main::defs{$name};

    # return error if no such device
    return("text/plain; charset=utf-8", "No FUIP device for $link") unless($hash);
	
	# main::Log3(undef,1,"FUIP Link: ".$link." File: ".$filename);
	
	my @path = split(/\//, $filename);
	if(@path == 0 or $path[0] eq "page") {
		if(@path > 0){ shift @path };
		return getFuipPage($hash,join('/',@path));
	};
	
	# fuip builtin stuff
	if($path[0] eq "fuip") {
		# export/import settings
		if($path[1] =~ m/^export/) {
			return settingsExport($hash,$request);
		}elsif($path[1] =~ m/^import/) {
			return settingsImport($hash,$request);
		# popup maintenance
		}elsif($path[1] =~ m/^popup/) { 
			return renderPopupMaint($hash,$request);
		}
		# other built in fuip files
		shift @path;
		$filename = $main::attr{global}{modpath}."/FHEM/lib/FUIP/".join('/',@path);
		my $MIMEtype= main::filename2MIMEType($filename);
		my @contents;
		if(open(INPUTFILE, $filename)) {
			binmode(INPUTFILE);
			@contents= <INPUTFILE>;
			close(INPUTFILE);
			return("$MIMEtype; charset=utf-8", join("", @contents));
		} else {
			return("text/plain; charset=utf-8", "File not found: $filename");
		}
	};
	
	# TODO: remove this again...
	if($path[0] eq "icons") {
		return showAllIcons();
	};

	# otherwise, this is some library file or js or...	
	
    $filename =~ s/\?.*//;
	
	# The following is to block any widget to load jquery-ui again. It would break drag/drop of views.
	my $basename = basename($filename);
	if($basename eq "jquery-ui.js" or $basename eq "jquery-ui.min.js") {
		return("text/plain; charset=utf-8", "");	
	};
		
    my $MIMEtype= main::filename2MIMEType($filename);
    my $directory= $main::defs{$name}{fhem}{directory};
    $filename= "$directory/$filename";
    #Debug "read filename= $filename";
    my @contents;
    if(open(INPUTFILE, $filename)) {
      binmode(INPUTFILE);
      @contents= <INPUTFILE>;
      close(INPUTFILE);
      return("$MIMEtype; charset=utf-8", join("", @contents));
    } else {
      return("text/plain; charset=utf-8", "File not found: $filename");
    }

  } else {
    return("text/plain; charset=utf-8", "Illegal request: $request");
  }
}  


# serializes all pages and views in order to save them
sub serialize($) {
	my ($hash) = @_;
	my $result = 0;
	for my $pageid (sort keys %{$hash->{pages}}) {
		if($result) {
			$result .= ",\n ";
		}else{
			$result = "{";
		};
		$result .= " '".$pageid."' => \n".$hash->{pages}{$pageid}->serialize(4);
	};
	$result .= "\n}";
	return $result;
}


sub save($) {
	my ($hash) = @_;
	my $config = serialize($hash);   
	my $filename = "FUIP_".$hash->{NAME}.".cfg";
    my @content = split(/\n/,$config);
	# make sure config directory exists
	my $cfgPath = $fuipPath."config";
	if(not(-d $cfgPath)) {
		mkdir($cfgPath);
		# we do not check for errors here as anyway the FileWrite will fail
	};
	return main::FileWrite($cfgPath."/".$filename,@content);		
};


sub load($) {
	# TODO: some form of error management
	my ($hash) = @_;
	my $filename = "FUIP_".$hash->{NAME}.".cfg";
	# try to read from FUIP directory
	my ($error, @content) = main::FileRead($fuipPath."config/".$filename);	
	if($error) {
		# not found or other issue => try to read from main fhem directory (old location for this file)
		my $err2;
		($err2, @content) = main::FileRead($filename);
		return $error if($err2);  # return $error, even though second read failed. This is to avoid confusing error messages.
	};	
	my $config = join("\n",@content);
	# now config is sth we can "eval"
	my $confHash = eval($config);
	# clear pages
	$hash->{pages} = {};
	# each page has an id (key) and is an instance of FUIP::Page
	for my $pageid (keys %$confHash) {
		my $pageConf = $confHash->{$pageid};
		my $class = $pageConf->{class}; # This allows for other page-implementations (???)
		delete($pageConf->{class});
		$hash->{pages}{$pageid} = $class->reconstruct($pageConf,$hash);
	};
	return undef;
};


# dclone does not work because of references to the FUIP object
sub cloneView($) {
	my ($view) = @_;
	my $conf = eval($view->serialize());
	my $class = $conf->{class}; 
	delete($conf->{class});
	return $class->reconstruct($conf,$view->{fuip});
};


sub setField($$$$$) {
	my ($view,$field,$component,$values,$prefix) = @_;

	my $refIntoView = $view;
	my $refIntoDefaulted = $view->{defaulted};
	my $refIntoField = $field;
	my $compName = $field->{id};
	my $nameInValues = $prefix.$field->{id};
	for my $comp (@$component) {
		$refIntoView = $refIntoView->{$compName};
		$refIntoDefaulted->{$compName} = {} unless(defined($refIntoDefaulted->{$compName}));
		$refIntoDefaulted = $refIntoDefaulted->{$compName};
		$refIntoField = $refIntoField->{$comp};
		$compName = $comp;
		$nameInValues .= "-".$comp;
	};
	$refIntoView->{$compName} = main::urlDecode($values->{$nameInValues}) if(defined($values->{$nameInValues}));
	# if this has a default setting 
	if(defined($refIntoField->{default}) and defined($values->{$nameInValues."-check"})) {
		$refIntoDefaulted->{$compName} = ($values->{$nameInValues."-check"} eq "1" ? 0 : 1);
	};	
};


# declaration to avoid warnings because of recursion
sub setViewSettings($$$$;$);

sub setViewSettings($$$$;$) {
	my ($hash, $viewlist, $viewindex, $h, $prefix) = @_;
	$prefix = "" unless defined $prefix;
	
	# do we need to (re-)create the view?
	my $newclass = undef;
	$newclass = main::urlDecode($h->{$prefix."class"}) if(defined($h->{$prefix."class"}));
	if(defined($viewlist->[$viewindex])) {
		$newclass = undef if($newclass eq blessed($viewlist->[$viewindex]));  # already this class
	}else{
		$newclass = "FUIP::View" unless $newclass;  # new view, assign FUIP::View
	};
	# has the class changed?
	if(defined($newclass)) {
		my $newView = $newclass->createDefaultInstance($hash);
		if(defined($viewlist->[$viewindex])) {
			my $oldView = $viewlist->[$viewindex];
			$newView->{posX} = $oldView->{posX} if defined $oldView->{posX}; 
			$newView->{posY} = $oldView->{posY} if defined $oldView->{posY};
			$newView->{width} = $oldView->{width} unless($newView->{width} > $oldView->{width} and $prefix ne "");
			$newView->{height} = $oldView->{height} unless($newView->{height} > $oldView->{height} and $prefix ne "");
		};	
		$viewlist->[$viewindex] = $newView;
	};
	# now set each field
	# the following automatically ignores fields which cannot be set
	my $view = $viewlist->[$viewindex];
	my $configFields = $view->getConfigFields();
	for my $field (@$configFields) {
		if($field->{type} eq "device-reading") {
			setField($view,$field,["device"],$h,$prefix);
			setField($view,$field,["reading"],$h,$prefix);
		}elsif($field->{type} eq "viewarray"){
			# we must have a "sort order" argument
			my @sortOrder;
			if(defined($h->{$prefix.$field->{id}})){
				@sortOrder = split(',',$h->{$prefix.$field->{id}});
			};
			my $newviewarray = [];
			for my $i (@sortOrder) {	
				setViewSettings($hash, $view->{$field->{id}},$i,$h,$prefix.$field->{id}.'-'.$i.'-'); 
				push(@$newviewarray,$view->{$field->{id}}[$i]);
			};
			$view->{$field->{id}} = $newviewarray;
		}else{
			setField($view,$field,[],$h,$prefix);
		};	
	};
};


sub setPageSettings($$) {
	my ($page, $h) = @_;
	# set each field
	# the following automatically ignores fields which cannot be set
	my $configFields = $page->getConfigFields();
	for my $field (@$configFields) {
		setField($page,$field,[],$h,"");
	};	
};


# TODO: This should go to FUIP::Cell, to allow 
# different "layouts" later
sub autoArrange($) {
	my ($cell) = @_;
	# get cell width
	# (This assumes we already have a width.)
	my $width;
	if($cell->isa("FUIP::Dialog")) {
		($width,undef) = $cell->dimensions();
	}else{	
		my ($w,$h) = $cell->dimensions();
		my $baseWidth = main::AttrVal($cell->{fuip}{NAME},"baseWidth",142);
		$width = $w * ($baseWidth + 10) -10;
	};	
	my ($posX,$posY) = (0,0);
	my $nextPosY = 0;
	for my $view (@{$cell->{views}}) {
		my ($w,$h) = $view->dimensions();
		if($posX) {
			# i.e. there is already sth in the row, check whether we can fit more
			if($posX + $w > $width) {
				# no, next row
				$posX = 0;
				$posY = $nextPosY;
			};
		};	
		$view->position($posX,$posY);
		$posX += $w;
		$nextPosY = $posY + $h if($nextPosY < $posY + $h);
	};
};


# auto-arrange all views which have not been positioned yet
sub autoArrangeNewViews($) {
	my ($cell) = @_;
	# get cell's dimensions
	my $width;
	my $height;
	my $cellWidth;
	my $cellHeight;
	if($cell->isa("FUIP::Dialog")) {
		($width,$height) = $cell->dimensions();
	}else{	
		my ($cellWidth,$cellHeight) = $cell->dimensions();
		my $baseWidth = main::AttrVal($cell->{fuip}{NAME},"baseWidth",142);
		$width = $cellWidth * ($baseWidth + 10) -10;
	};	
	# get the lower right corner of what is already occupied
	my ($occUntilX,$occUntilY) = (0,0);
	for my $view (@{$cell->{views}}) {
		my ($x,$y) = $view->position();
		next unless defined($x) or defined($y);
		my ($w,$h) = $view->dimensions();
		$occUntilX = $x + $w if $x + $w > $occUntilX;
		$occUntilY = $y + $h if $y + $h > $occUntilY;
	};
	# start positioning right to the already occupied region
	my ($posX,$posY) = ($occUntilX,0);
	my $nextPosY = 0;
	for my $view (@{$cell->{views}}) {
		# already positioned?
		my ($x,$y) = $view->position();
		next if defined($x) or defined($y);
		my ($w,$h) = $view->dimensions();
		# does this fit into the current row?
		# (unless we are anyway at the beginning of the row
		if($posX > 0 and $posX + $w > $width) {
			# no, next row
			$posY = $nextPosY;
			if($posY < $occUntilY) {
				$posX = $occUntilX;
			}else{
				$posX = 0;
			};	
		};	
		# if we are still "at the right" and it is to tall
		# or it is wider than the complete space to the right,
		# then start below
		if($posY < $occUntilY and ($posY + $h > $occUntilY or $posX + $w > $width)) {
			$posX = 0;
			$posY = $occUntilY;
			$nextPosY = $posY;
		};
		# now posX/posY should be the new position
		$view->position($posX,$posY);
		$posX += $w;
		$nextPosY = $posY + $h if($nextPosY < $posY + $h);
	}		
	# resize the cell itself in case we have added something "below", which does not anyway fit
	if($cell->isa("FUIP::Dialog")) {
		if($nextPosY + 25 > $height) {
			$height = $nextPosY + 25;
			$cell->dimensions($width,$height);
		};
	}else{
		my $baseHeight = main::AttrVal($cell->{fuip}{NAME},"baseHeight",108);
		if($nextPosY > $cellHeight * $baseHeight) {
			use integer;
			$cellHeight = $nextPosY / $baseHeight + ($nextPosY % $baseHeight ? 1 : 0);
			no integer;
			$cell->dimensions($cellWidth,$cellHeight);
		};
	};
};


sub getPageAndCellId($$) {
# determines page id and cell id from command
# includes error handling
	my ($hash,$a) = @_;
	my $cmd = $a->[1];
	my @pageAndCellId = split(/_/,$a->[2]);
	return (undef, "\"set ".$cmd."\" needs a page id and a view id") unless(@pageAndCellId > 1);
	my $cellId = pop(@pageAndCellId);
	my $pageId = join("_",@pageAndCellId);
	return (undef, "\"set ".$cmd."\": cell ".$pageId." ".$cellId." not found") unless(defined($hash->{pages}{$pageId}) and defined($hash->{pages}{$pageId}{cells}[$cellId]));
	return ($pageId,$cellId);
};


sub Set($$$)
{
	my ( $hash, $a, $h ) = @_;

	# main::Log3($hash, 4, 'FUIP: Set: ' . main::Dumper($a).'  '.main::Dumper($h));
	
	return "\"set ".$hash->{NAME}."\" needs at least one argument" unless(@$a > 1);
	my $cmd = $a->[1];
	if($cmd eq "save"){
		return save($hash);
	}elsif($cmd eq "load"){
		return load($hash);
	}elsif($cmd eq "viewsettings") {	
		# get cell id
		my ($pageId,$cellId) = getPageAndCellId($hash,$a);
		return $cellId unless(defined($pageId));
		setViewSettings($hash, $hash->{pages}{$pageId}{cells}, $cellId, $h);
		autoArrangeNewViews($hash->{pages}{$pageId}{cells}[$cellId]);
	}elsif($cmd eq "viewcomponent") {	
		# get cell id
		my ($pageId,$cellId) = getPageAndCellId($hash,$a);
		return $cellId unless(defined($pageId));
		# get dialog
		my $dialog = findDialogFromFieldId($hash,$pageId,$cellId,$a->[3]);
		my $comps = [$dialog];
		setViewSettings($hash, $comps, 0, $h);
		autoArrangeNewViews($dialog);	
	}elsif($cmd eq "dialogsize") {	
		# get cell id
		my ($pageId,$cellId) = getPageAndCellId($hash,$a);
		return $cellId unless(defined($pageId));
		my $dialog = findDialogFromFieldId($hash,$pageId,$cellId,$a->[3]);
		$dialog->dimensions($a->[4],$a->[5]);
	}elsif($cmd eq "viewdelete") {
		# get cell id
		my ($pageId,$cellId) = getPageAndCellId($hash,$a);
		return $cellId unless(defined($pageId));
		# delete cell from array
		splice(@{$hash->{pages}{$pageId}{cells}},$cellId,1);
	}elsif($cmd eq "viewaddnew"){
		#get page id
		my $pageId = (exists($a->[2]) ? $a->[2] : "");
		return "\"set viewaddnew\": page ".$pageId." does not exist" unless defined $hash->{pages}{$pageId};
		push(@{$hash->{pages}{$pageId}{cells}},FUIP::Cell->createDefaultInstance($hash));
	}elsif($cmd eq "pagedelete") {
		#get page id
		my $pageId = (exists($a->[2]) ? $a->[2] : "");
		return "\"set pagedelete\": page ".$pageId." does not exist" unless defined $hash->{pages}{$pageId};
		delete($hash->{pages}{$pageId});
	}elsif($cmd eq "pagecopy") {
		#get page ids
		return "\"set pagecopy\" needs two page ids" unless exists($a->[3]);
		my ($oldPageId,$newPageId) = ($a->[2], $a->[3]);
		return "\"set pagecopy\": page ".$oldPageId." does not exist" unless defined $hash->{pages}{$oldPageId};
		$hash->{pages}{$newPageId} = cloneView($hash->{pages}{$oldPageId});
	}elsif($cmd eq "cellcopy") {
		#get page ids etc.
		my ($oldPageId,$oldCellId) = getPageAndCellId($hash,$a);
		return $oldCellId unless(defined($oldPageId));
		my $newPageId = (exists($a->[3]) ? $a->[3] : "");
		my $newCell = cloneView($hash->{pages}{$oldPageId}{cells}[$oldCellId]);
		delete $newCell->{posX};
		delete $newCell->{posY};
		push(@{$hash->{pages}{$newPageId}{cells}},$newCell);
	}elsif($cmd eq "pagesettings") {	
		# get page id
		my $pageId = $a->[2]; 
		return "\"set pagesettings\": page ".$pageId." does not exist" unless defined $hash->{pages}{$pageId};
		setPageSettings($hash->{pages}{$pageId}, $h);
	}elsif($cmd eq "viewposition") {
		# set ... viewposition pageId_cellId_viewId posX posY
		# get cell
		my @pageAndViewId = split(/_/,$a->[2]);
		return "\"set viewposition\" needs a page id, a cell id and a view id" unless(@pageAndViewId > 2);
		my $viewId = pop(@pageAndViewId);
		my $cellId = pop(@pageAndViewId);
		my $pageId = join("_",@pageAndViewId);
		# cell exists? 
		return "\"set viewposition\": cell ".$pageId." ".$cellId." not found" unless(defined($hash->{pages}{$pageId}) and defined($hash->{pages}{$pageId}{cells}[$cellId]));
		my $cell = $hash->{pages}{$pageId}{cells}[$cellId];
		return "\"set viewposition\": view ".$viewId." not found in cell ".$pageId."_".$cellId unless(defined($cell->{views}[$viewId]));
		# set position into view
		$cell->{views}[$viewId]->position($a->[3],$a->[4]);
	}elsif($cmd eq "viewposdialog") {
		# set ... viewposdialog pageId_cellId fieldId viewId posX posY
		# get cell
		my @pageAndViewId = split(/_/,$a->[2]);
		my $cellId = pop(@pageAndViewId);
		my $pageId = join("_",@pageAndViewId);
		# cell exists? 
		return "\"set viewposdialog\": cell ".$pageId." ".$cellId." not found" unless(defined($hash->{pages}{$pageId}) and defined($hash->{pages}{$pageId}{cells}[$cellId]));
		my $dialog = findDialogFromFieldId($hash,$pageId,$cellId,$a->[3]);
		# find the view in the dialog
		my $view = $dialog->{views}[$a->[4]];
		# set position into view
		$view->position($a->[5],$a->[6]);	
	}elsif($cmd eq "viewmove") {
		# set ... viewposition pageId_cellId_viewId posX posY
		# get cell
		my @pageAndViewId = split(/_/,$a->[2]);
		return "\"set viewmove\" needs a page id, a cell id and a view id" unless(@pageAndViewId > 2);
		my $viewId = pop(@pageAndViewId);
		my $oldCellId = pop(@pageAndViewId);
		my $pageId = join("_",@pageAndViewId);
		# old cell exists? 
		return "\"set viewmove\": cell ".$pageId." ".$oldCellId." not found" unless(defined($hash->{pages}{$pageId}) and defined($hash->{pages}{$pageId}{cells}[$oldCellId]));
		my $oldCell = $hash->{pages}{$pageId}{cells}[$oldCellId];
		return "\"set viewmove\": view ".$viewId." not found in cell ".$pageId."_".$oldCellId unless(defined($oldCell->{views}[$viewId]));
		my $view = $oldCell->{views}[$viewId];
		# new cell exists? 
		my $newCellId = $a->[3];
		return "\"set viewmove\": cell ".$pageId." ".$newCellId." not found" unless(defined($hash->{pages}{$pageId}) and defined($hash->{pages}{$pageId}{cells}[$newCellId]));
		my $newCell = $hash->{pages}{$pageId}{cells}[$newCellId];
		# remove view from old cell
		splice(@{$oldCell->{views}},$viewId,1);
		# put view into new cell 
		push(@{$newCell->{views}},$view);
		# set position into view
		$view->position($a->[4],$a->[5]);
	}elsif($cmd eq "autoarrange") {
		# get cell id
		my ($pageId,$cellId) = getPageAndCellId($hash,$a);
		return $cellId unless(defined($pageId));
		if(exists($a->[3])) {
			autoArrange(findDialogFromFieldId($hash,$pageId,$cellId,$a->[3]));
		}else{		
			autoArrange($hash->{pages}{$pageId}{cells}[$cellId]);
		};	
	}elsif($cmd eq "refreshBuffer") {
		FUIP::Model::refresh($hash->{NAME});
	}elsif($cmd eq "editOnly") {
		$hash->{editOnly} = $a->[2];
	}else{
		# redetermine attribute values
		setAttrList($main::modules{FUIP});
		return "Unknown argument $cmd, choose one of save:noArg load:noArg viewsettings viewaddnew viewdelete viewposition autoarrange refreshBuffer pagedelete:".join(',',sort keys %{$hash->{pages}});
	}
	return undef;
}


sub _getViewClasses() {
	my @result = keys %$selectableViews;
	return \@result;
};


sub _toJson($);  # wegen Rekursion

sub _toJson($){
    my ($var) = @_;
	my $result = "";
	return "\"\"" if(!defined($var)); 
	if(ref($var) eq "HASH") {
		$result = '{';
	    my $afterfirst = 0;
	    foreach my $key (sort keys %{$var}) {
	        if($afterfirst) {
		        $result .= ',';
		    }else{
                $afterfirst = 1;
            };			
	        $result .= "\n";
	        $result .= '"'.$key.'":';
		    $result .= _toJson($var->{$key});
	    };
	    $result .= "\n}";
	}elsif(ref($var) eq "ARRAY") {
		$result .= " [ ";
	    for(my $i = 0; $i < int(@{$var}); $i++) {
		    $result .= "," if($i > 0);
			$result .= _toJson($var->[$i]);	
        };
		$result .= " ] ";
    }else{	
	    $result .= '"'.main::urlEncode($var).'"';
	};	
    return $result;
};


sub _getDeviceList($) {
	my ($name) = @_;
	my $result = [];
	
	my $keys = FUIP::Model::getDeviceKeys($name);
	for my $key (sort { lc($a) cmp lc($b) } @$keys) {
		my $device = FUIP::Model::getDevice($name,$key,["TYPE","room","alias"]);
		push(@$result, {
			NAME => $key,
			TYPE => $device->{Internals}{TYPE},
			room => $device->{Attributes}{room},
			alias => $device->{Attributes}{alias}
			});
	};
	return $result;
};


sub Get($$$)
{
	my ( $hash, $a, $h ) = @_;

	return "\"get ".$hash->{NAME}."\" needs at least one argument" unless(@$a > 1);
    my $opt = $a->[1];
	
	if($opt eq "cellsettings"){
		# get cell
		my @pageAndCellId = split(/_/,$a->[2]);
		return "\"get cellsettings\" needs a page id and a cell id" unless(@pageAndCellId > 1);
		my $cellId = pop(@pageAndCellId);
		my $pageId = join("_",@pageAndCellId);
		# get field list and values from views 
		return "\"get cellsettings\": cell ".$pageId." ".$cellId." not found" unless(defined($hash->{pages}{$pageId}) and defined($hash->{pages}{$pageId}{cells}[$cellId]));
		my $cell = $hash->{pages}{$pageId}{cells}[$cellId];
		# return as to JSON
		return _toJson($cell->getConfigFields());
	}elsif($opt eq "viewcomponent"){  
		# e.g. for popups: Get a component (field) of a view
		# TODO: error handling
		my @pageAndCellId = split(/_/,$a->[2]);
		my $cellId = pop(@pageAndCellId);
		my $pageId = join("_",@pageAndCellId);
		# find the dialog
		my $dialog = findDialogFromFieldId($hash,$pageId,$cellId,$a->[3]);
		return _toJson($dialog->getConfigFields()) if($dialog);
		return "Something went wrong with get viewcomponent";
	}elsif($opt eq "viewclasslist") {
		my @result = map { { id => $_, title => $selectableViews->{$_}{title} } } sort keys(%$selectableViews);
		return _toJson(\@result);
	}elsif($opt eq "viewdefaults") {
		my $class = $a->[2];
		return "\"get viewdefaults\" needs a view class as an argument" unless $class;
		my $viewclasses = _getViewClasses();
		return "\"get viewdefaults\": view class ".$class." unknown, use one of ".join(",",@$viewclasses) unless(grep $_ eq $class, @$viewclasses);
		return _toJson($class->getDefaultFields());		
	}elsif($opt eq "viewsByDevices") {
		my @views;
		foreach my $i (2 .. $#{$a}) {
			my $view = getDeviceView($hash, $a->[$i],"overview");
			if(not defined($view)) {
				$view = FUIP::View::STATE->createDefaultInstance($hash);
				$view->{device} = $a->[$i];
			};			
			$view->applyDefaults();
			push(@views,$view->getConfigFields());
		};
		return _toJson(\@views);
	}elsif($opt eq "pagelist"){
		my @pagelist = sort keys %{$hash->{pages}};
		my @result = map { {id => $_, title => ($hash->{pages}{$_}{title} ? $hash->{pages}{$_}{title} : $_) } } @pagelist;
		return _toJson(\@result);		
	}elsif($opt eq "pagesettings"){
		return "\"get pagesettings\" needs a page id" unless(defined($a->[2]));
		my $pageId = $a->[2];
		return "\"get pagesettings\": page ".$pageId." not found" unless(defined($hash->{pages}{$pageId}));
		my $page = $hash->{pages}{$pageId};	
		return _toJson($page->getConfigFields());			
	}elsif($opt eq "devicelist"){
		return _toJson(_getDeviceList($hash->{NAME}));
	}elsif($opt eq "readingslist") {
		# TODO: check if $a->[2] exists
		return _toJson(FUIP::Model::getReadingsOfDevice($hash->{NAME},$a->[2]));
	}elsif($opt eq "sets") {
		return _toJson(FUIP::Model::getSetsOfDevice($hash->{NAME},$a->[2]));
	}else{
		# get all pages
		my @pages = sort keys %{$hash->{pages}};
		# get all possible cells
		my @cells;
		for my $pKey (@pages) {
			for(my $cKey = 0; $cKey < @{$hash->{pages}{$pKey}{cells}}; $cKey++) {
				push(@cells,$pKey."_".$cKey);
			};
		};
		my $viewclasses = _getViewClasses();
		return "Unknown argument $opt, choose one of cellsettings:".join(",",@cells)." viewclasslist:noArg viewdefaults:".join(",",@$viewclasses)." pagelist:noArg pagesettings:".join(",",@pages)." devicelist:noArg readingslist sets";
	}
}



   
####

1;
