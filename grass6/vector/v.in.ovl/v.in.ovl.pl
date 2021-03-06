#!/usr/bin/perl

###############################################################################
#
# MODULE:    v.in.ovl
#
# AUTHOR(S): Peter Loewe
#
# PURPOSE:   Import content from a OVL ASCII into a GRASS GIS vector layer.
#
# COPYRIGHT: (c) 2006, 2007 Peter Loewe
#
#            This program is free software under the GNU General Public   
#            Licence (>= v2). Read the file COPYING that comes with GRASS
#            for further details. 
#
# Notes: 
#
# June 2007 (PL): Minor beautification & clean up
#
################################################################################
#REQUIREMENTS:
#
# Perl

#%Module
#%  description: Imports ASCII OVL files generated by German TOP[25/50/200]-CDROMS
#%End

#%option
#% key: input
#% type: string
#% gisprompt: old_file,file,input
#% description: Name of input vector map
#% required : yes
#%end
#%option
#% key: output
#% type: string
#% description: Name for output vector map
#% required : no
#%end

#GRASS up and running ?

if ( !$ENV{'GISBASE'} ) {
    printf(STDERR  "You must be in GRASS GIS to run this program.\n");
    exit 1;
}

#Call up GUI if no parameters are provided

if( $ARGV[0] ne '@ARGS_PARSED@' ){
    my $arg = "";
    for (my $i=0; $i < @ARGV;$i++) {
        $arg .= " $ARGV[$i] ";
    }
    system("$ENV{GISBASE}/bin/g.parser $0 $arg");
    exit;
}


$ykoo_min=10000000000;
$ykoo_max=0;
$xkoo_min=10000000000;
$xkoo_max=0;

$gisdbase ="";
$mapset ="";
$location_name ="";
$monitor ="";
$grass_gui ="";

@gml_content=();

@xkoo_stack=();
@ykoo_stack=();
@struct_stack=();
#a list of all structs read from the file

@the_struct=();
#the current struct

$sammel_hash={};
# a hash for all variables ever occuring in all structs

##############

$GRASS_LAYER = $ENV{'GIS_OPT_OUTPUT'}; 


if ($GRASS_LAYER eq "") {die "ERROR: Missing output file\n";}

$GML_OUTPUT=`g.tempfile pid=$$`;
chomp($GML_OUTPUT);
#This file must be removed later on

$dateiname=s(^.*/)($ENV{'GIS_OPT_INPUT'});

unless (open(INPUT,$ENV{'GIS_OPT_INPUT'}))
{die "ERROR: No input file provided"}

$event = 0;

while (<INPUT>) 
{

    s/\r\n/\n/;
    if (/^\[Symbol/) {
	
       	## [Symbol]-event: A geometry-objects begins
	##1=ikone 3=line 4=area 5=square 6=circle 7=triangle 2=text
	
	$event++;
	#crank up counter for geometry objects

	$the_symbol0 = $_;
	if ($event > 1)
	{
	     
	     geometry_processing();	    
	     push(@struct_stack,$derhash);
	     @the_struct=();
	     @xkoo_stack=();
	     @ykoo_stack=();
	   
	     undef $derhash;
	    
	}
	else
	{undef $derhash;
     }
		
        #if a geometry-objects have already been handled, they are saved now. The last one /only one is handled/saved outside the loop.
    }
    elsif (/=/) {  
	#a line of data 
	@zeile = split /=/ ;
	chomp $zeile[1];
	datenzeile();
    }
    else 
    {
	## it is one of the other structs
	$foo = 42;
    }
}
close(INPUT);
	   	
geometry_processing();

push(@struct_stack,$derhash);  
	
##This code is necessary if there is only one struct in the file
## or we have processed all lest the last one.
## The last remaining structs is not dealt with.

####
#hashtest();
####

gml_out();


open(GML,"> $GML_OUTPUT")or die "Could not write out $GML_OUTPUT !\n";
foreach $content (@gml_content) {
print GML $content;

}

#dsnXXX is a tempfile which has to be created.

$vogr="v.in.ogr -o dsn=$GML_OUTPUT output=$GRASS_LAYER ";

    print "$vogr\n";
#gisenv();
system($vogr);
print "Das wars\n";



#Suggestion: If no name for the output file is provided, use the source layer name.

#########################################
###SUBS##################################
#########################################

sub gisenv {

#    my $gisdbase ="";
#    my $mapset ="";
#    my $location_name ="";
#    my $monitor ="";
#    my $grass_gui ="";
    my @gisenv=`g.gisenv`;
    my %gisenv;
    foreach $giszeile (@gisenv) {
	@gisvar = split(/=/, $giszeile );
	chomp $gisvar[1];
	$gisvar[1]=~s/'//g;
	$gisvar[1]=~s/;//g;
        $gisenv{$gisvar[0]}=$gisvar[1];
	#print "$gisvar[0] -- $gisvar[1]\n";
    }
   $gisbase=$gisenv{"GISDBASE"};
  $mapset=$gisenv{"MAPSET"};
 $location_name=$gisenv{"LOCATION_NAME"};
 $monitor=$gisenv{"MONITOR"};
 $grass_gui=$gisenv{"GRASS_GUI"};

}

sub gml_out {
    vorlauf();
    middle();
    nachlauf();
}

sub coordinate_string {
    my $composite = "";
    my $tupelx,$tupely;
    for ($i; $i <= $#xkoo_stack; $i++ ){
    $tupelx = $xkoo_stack[$i];
    $tupely = $ykoo_stack[$i];
    $composite="$composite $tupelx,$tupely";}
  
  return $composite;
}


sub point_string {
    my $tupelx="";
    my $tupely="";;
    my $linestring;
    my $open="<gml:Point><gml:coordinates>";
    my $close="</gml:coordinates></gml:Point>";
    $mymagic=magic(); 

    $linestring=$open.$mymagic.$close;
    
    return ${\($linestring)};
}


sub magic {
    my $mymagic = "";
    my $mtupelx = "";
    my $mtupely = "";
    for ($i=0; $i <= $#xkoo_stack; $i++ ){
	$mtupelx = $xkoo_stack[$i];
	$mtupely = $ykoo_stack[$i]; 
        $mymagic="${\($mymagic)} ${\($mtupelx)},${\($mtupely)}";
    }
   
    return $mymagic;
}

sub line_string {
    my $composite = "";
    my $tupelx,$tupely;
    my $linestring="";    
    my $open = "<gml:LineString><gml:coordinates>";
    my $close = "</gml:coordinates></gml:LineString>";
    $composite = magic();
    $linestring="$open$composite$close";
    return $linestring;
}

sub polygon_string {
    my $composite = "";
    my $tupelx,$tupely;
    my $linestring;    
    my $open="<gml:Polygon><gml:OuterBoundaryIs><gml:LinearRing><gml:coordinates>";
    my $close="</gml:coordinates></gml:LinearRing></gml:OuterBoundaryIs></gml:Polygon>";
    $composite=magic();
    $linestring="$open$composite$close";
  return $linestring;
}


sub vorlauf{

    $zeile1_xml=qq(<?xml version="1.0" encoding="utf-8" ?> \n);
    $zeile2_ogr_featurecollection=qq(<ogr:FeatureCollection
     xmlns:xsi="http://www.w3c.org/2001/XMLSchema instance"
     xsi:schemaLocation=". FOOO.xsd"
     xmlns:ogr="http://ogr.maptools.org/"
     xmlns="http://ogr.maptools.org/"
     xmlns:gml="http://www.opengis.net/gml">\n);

    $ogr_geometry_property_A=q(<ogr:geometryProperty>);
    $ogr_geometry_property_Z=q(</ogr:geometryProperty>);

    $gml_linestring_A=q(<gml:LineString>);
    $gml_linestring_Z=q(</gml:LineString>);

    $gml_coordinates_A=q(<gml:coordinates>);
    $gml_coordinates_Z=q(</gml:coordinates>);

    $gml_box_A=q(<gml:Box>);
    $gml_box_Z=q(</gml:Box>);

    $gml_boundedby_A=q(<gml:boundedBy>);
    $gml_boundedby_Z=q(<gml:boundedBy>);

    $gml_coord_A=q(<gml:coord>);
    $gml_coord_Z=q(</gml:coord>);

    push(@gml_content,$zeile1_xml);
    push(@gml_content,$zeile2_ogr_featurecollection);
    push(@gml_content,"<gml:boundedBy>\n");
    push(@gml_content,"<gml:Box>\n");
    push(@gml_content,"<gml:coord>\n");
    push(@gml_content,"<gml:X>$xkoo_min</gml:X> \n<gml:Y>$ykoo_min</gml:Y>\n");
    push(@gml_content,"</gml:coord>\n");
    push(@gml_content,"<gml:coord>\n");
    push(@gml_content,"<gml:X>$xkoo_max</gml:X> \n<gml:Y>$ykoo_max</gml:Y>\n");
    push(@gml_content,"</gml:coord>\n");
    push(@gml_content,"</gml:Box>\n");
    push(@gml_content,"</gml:boundedBy>\n");

}


sub nachlauf{
    #Schliesst die GML-Datei
    push(@gml_content,"</ogr:FeatureCollection>\n");
}

sub middle{
    my $count=0;
    my $gml_feature_open="<gml:featureMember>\n";
    my $gml_feature_close="</gml:featureMember>\n";
    my $FID_open_a=q(<test_wege fid=");
    my $FID_open_b=q(">);
    my $FID_close=" </test_wege>\n";
    my $CAT_open="<cat>";
    my $CAT_close="</cat>\n";

    my $cleaned_content;

    foreach $href (@struct_stack) {

	push(@gml_content,$gml_feature_open);
	push(@gml_content," $FID_open_a$count$FID_open_b\n");
	$count++;
	push(@gml_content," $CAT_open$count$CAT_close");


	while (($schluessel, $wert) = each(%$href)){

	    $cleaned_content = $wert;
	    # Get rid off Umlauts as v.in.ogr-XML input does not like them
            $cleaned_content =~ s/�/Ae/g;
            $cleaned_content =~ s/�/ae/g;
            $cleaned_content =~ s/�/Oe/g;
            $cleaned_content =~ s/�/oe/g;
            $cleaned_content =~ s/�/Ue/g;
            $cleaned_content =~ s/�/ue/g;
            $cleaned_content =~ s/�/ss/g;
	     push(@gml_content," <$schluessel>$cleaned_content </$schluessel>\n");
	}

	push(@gml_content,$FID_close);
	push(@gml_content,$gml_feature_close);
    }

}


sub hashtest {
print "------------------------------------------\n";
print "STRUCTSTACKLAENGE= ($#struct_stack + 1)\n";

$jj=0;
 foreach $href (@struct_stack) {
     $jj++;
     print "bbb".%$href."vvv\n";
     $hh=0;
while (($key, $value) = each(%{$href})) {
    $hh++;
    print "=$jj=$hh=> $key $value\n";
}

my %dh=$href;
my $dhf=$href;
print "DH-Hash#=_".$#dhf."_\n";
print "DH-1=_".$dhf{"ogr:geometryProperty"}."_\n";

if (ref{$dh} ne 'HASH' ){ die "DH IST KEIN HASH";} else {print "DH IST HASH\n";} 
print "HREF=".$href."\n";
print "DH=".$dhf."\n";

    }
print "------------------------------------------\n";
print "HASHTEST ENDS. \n";
die;

}



sub geometry_processing {
if ($derhash->{"Typ"} eq "3") {
    $cs = line_string(); }
elsif ($derhash->{"Typ"} eq "4") {
    $cs = polygon_string(); }
elsif ((((($derhash->{"Typ"} eq "5") ||  ($derhash->{"Typ"} eq "6")) || ($derhash->{"Typ"} eq "7")|| ($derhash->{"Typ"} eq "1") ) ||($derhash->{"Typ"} eq "2")  )) {
  
    $cs = point_string(); 
}
else
{
    $cs = coordinate_string();
    print "UNKOWN GEOMETRY TYPE !: ";
    print "$the_symbol0\n";
    print"__";
    print  $derhash{"Typ"};
    print "--";
    print "\n";
    die;
}

$derhash->{"ogr:geometryProperty"} = $cs;

}


sub datenzeile {
	chomp $zeile[1];
	#hier bei koords die min und max in x und y suchen
	if ($zeile[0] =~ /YKoord/) {
	    push(@ykoo_stack,$zeile[1]);
	    if ($zeile[1] < $ykoo_min) {$ykoo_min = $zeile[1];}
	    if ($zeile[1] > $ykoo_max) {$ykoo_max = $zeile[1];}
	} 
	elsif ($zeile[0] =~ /XKoord/) {   
	    push(@xkoo_stack,$zeile[1]);
	    if ($zeile[1] < $xkoo_min) {$xkoo_min = $zeile[1];}
	    if ($zeile[1] > $xkoo_max) {$xkoo_max = $zeile[1];}
	} 
	else {
	    $derhash->{$zeile[0]} = $zeile[1];
	    #das tupel der zeile wandert in den stack f�r das geometrieobjekt
	    
	    if (! exists $sammel_hash{$zeile[0]}){
		$sammel_hash{$zeile[0]} = 1;
		#Das Tag wird auch in die gro�e Liste geschrieben,
		#falls es nicht eh schon drin steht.
	    }
	}
}

