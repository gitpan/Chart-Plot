#!/usr/bin/perl

# CGI Demonstration of Plot.pm
#     Place Chart/Plot/Plot.pm beneath this script's directory,
#        or use lib '...'
#        or just install Chart::Plot
#     Make sure there is also a writable tmp subdirectory here.
#     Requires both GD.pm and CGI.pm.
#     Copyright 1998 Sanford Morton <sanford@halcyon.com>.

use CGI;
use Chart::Plot;
# use strict;
# use cgidebug;

sub error {
  print "Content-type: text/html\n\n<html><body>\n$_[0]\n</body></html>";
  exit;
}

my $web_form = <<"HERE";
<FORM METHOD=POST>
<CENTER><H1>CGI Demonstration of Plot.pm</H1></CENTER>
<TABLE BORDER=0><TR><TD>
Enter your data, one data point per line. Enter the independent (x) variable 
followed by the dependent (y) variable separated by whitespace, like this
<PRE>
1.5  -325
2.75 450.7
3 645
</PRE>
Do not enter any other symbols. There is a limit of 100 data points
in this demonstration. 
</TD><TD>
<TEXTAREA COLS=20 ROWS=10 NAME=data></TEXTAREA>
</TD></TR></TABLE><P>
All the following are optional (CAPS are the default):<UL>
<LI>Plot data with 
    <INPUT TYPE=RADIO NAME=linestyle VALUE=solidline> SOLID lines,
    <INPUT TYPE=RADIO NAME=linestyle VALUE=dashedline> dashed lines, or
    <INPUT TYPE=RADIO NAME=linestyle VALUE=noline> no lines? <BR>
    Plot with 
    <INPUT TYPE=RADIO NAME=pointstyle VALUE=points> POINTS or
    <INPUT TYPE=RADIO NAME=pointstyle VALUE=nopoints> no points? <BR>
    What color,
    <INPUT TYPE=RADIO NAME=colorstyle VALUE=red> red, 
    <INPUT TYPE=RADIO NAME=colorstyle VALUE=green> green, 
    <INPUT TYPE=RADIO NAME=colorstyle VALUE=blue> blue or
    <INPUT TYPE=RADIO NAME=colorstyle VALUE=black> BLACK?
<LI>Enter a title for the graph: <INPUT TYPE=TEXT NAME=title>.
<LI>Enter labels for the axes:
    Hor: <INPUT TYPE=TEXT NAME=horAxisLabel> 
    Vert: <INPUT TYPE=TEXT NAME=vertAxisLabel>
<LI>Image size (default 400x400, max 640x480 in this demonstration): 
    Hor: <INPUT TYPE=TEXT NAME=horImgSz SIZE=3>
    Vert: <INPUT TYPE=TEXT NAME=verImgSz SIZE=3>
<LI>Pixel distance from graph to image boundary (default 50x50):
    Hor: <INPUT TYPE=TEXT NAME=horGraphOffset SIZE=3>
    Vert: <INPUT TYPE=TEXT NAME=vertGraphOffset SIZE=3>
</UL><INPUT TYPE=SUBMIT> <INPUT TYPE=RESET></FORM>
HERE
;

# get form data
my $q = new CGI;

# print web form and exit if no data
&error($web_form) unless $q->param('data');

# create plot object with image size
my $horimg = ( $q->param('horImgSz') =~ /^\d+$/ 
	    ? $q->param('horImgSz') 
	    : 400 );
$horimg = ($horimg > 640 ? 640 : $horimg);
my $verimg = ( $q->param('verImgSz') =~ /^\d+$/ 
	    ? $q->param('verImgSz') 
	    : 400 );
$verimg = ($verimg > 480 ? 480 : $verimg);
my $p = new Plot ($horimg,$verimg);

# set graph offset, labels and title
my $horGraphOffset = ( $q->param('horGraphOffset') =~ /^\d+$/ 
		       ? $q->param('horGraphOffset') 
		       : 50 );
$horGraphOffset = ($horGraphOffset > $horimg/2 ? $horimg/2 : $horGraphOffset);

my $vertGraphOffset = ( $q->param('vertGraphOffset') =~ /^\d+$/ 
			? $q->param('vertGraphOffset') 
			: 50 );
$vertGraphOffset = ($vertGraphOffset > $verimg/2 ? $verimg/2 : $vertGraphOffset);

$p->setGraphOptions ('horGraphOffset' => $horGraphOffset,
		     'vertGraphOffset' => $vertGraphOffset,
		     'title' => $q->param('title'),
		     'horAxisLabel' => $q->param('horAxisLabel'),
		     'vertAxisLabel' => $q->param('vertAxisLabel')
		    );

# set data and plot style
my $style = $q->param('linestyle').$q->param('pointstyle').$q->param('colorstyle');
my $data; my @data;
($data = $q->param('data')) =~ s/^\s+//;
@data = split /\s+/, $data;
$#data > 200 and
  &error( "Sorry, there is a limit of 100 data points in this demonstration." );    
$p->setData (\@data, $style) or &error( $p->error() );

#   The one array option to setData() is more convenient in this script, 
#   but to exercise the two array option, comment out the previous line 
#   and uncomment the following two lines.
# for ($i=0; $i<$#data/2; $i++) {$data1[$i] = $data[2*$i]; $data2[$i] = $data[2*$i+1];}
# $p->setData (\@data1, \@data2, $style)  or &error( $p->error() );

# write data report
my $report = '<TABLE><TR ALIGN=RIGHT><TD>X data</TD><TD>Y data</TD></TR>';
for ($i=0; $i<$#data; $i+=2)  {
  $report .= "<TR ALIGN=RIGHT><TD>$data[$i]</TD><TD>$data[$i+1]</TD></TR>\n";
}
$report .= "</TABLE>";

# write files
open (WR,">tmp/$$.gif") or &error ("Fatal error: failed open tmp/$$.gif");
print WR $p->draw();
close WR;
open (WR,">tmp/$$.html") or &error ("Fatal error: failed open tmp/$$.html");
print WR "<HTML><BODY><IMG SRC=\"$$.gif\"><br>$report</BODY></HTML>";
close WR;

# redirect
$| = 1;
print "Location: tmp/$$.html\n\n";

exit;

__END__



