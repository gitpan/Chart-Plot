#=================================================================#
# Plot.pm -- Front end to GD.pm for plotting two dimensional data #
#            by Sanford Morton <sanford@halcyon.com>              #
#=================================================================#

# Changes:
#   v 0.0 - 08 March 1998 
#           first version
#   v 0.01 - 09 March 1998; 
#            - _getOM reports >= max instead of >;
#            - fixed bug in setData() data check
#   v 0.02 - 10 March 1998; 
#            - changed error handling in setData() (public method) which
#            now returns undef on success and sets $self->error ;
#            - changed legend to title (public method)
#            - adjusted horizontal tick labels up a bit
#   v 0.03 - 15 March 1998
#            - added colors and dashed line options to dataset graph style
#            - added option to pass dataset as two arrays (@xdata, @ydata)
#            - added hack for case om == max
#   v 0.04 - 15 March 1998
#            - added general purpose setGraphOptions()
#   v 0.05 - 18 March 1998
#            _ added synopsis to pod
#            - added getBounds()
#            - Hor axis label is set below and right centered or justified.
#            - additional vertical offset if title is present; larger font
#   v 0.06 - 22 March 1998
#            - removed title, offset and axis label methods in favor of
#              setGraphOptions()
#            - added getBounds()
#   v 0.07 - 29 May 1998
#            - finally put into standard h2xs form
#            - added check for tick step too small
#            - changed data validity check to permit scientific notation
#              but this invites awful looking tick labels

package Chart::Plot;

$Chart::Plot::VERSION = '0.07';

use GD;
use strict;

#==================#
#  public methods  #
#==================#

# usage: $plot = new Chart::Plot(); # default 400 by 300 pixels or 
#        $plot = new Chart::Plot(640, 480); 
sub new {
    my $class = shift;
    my $self = {};
    
    bless $self, $class;
    $self->_init (@_);

    return $self;
}

sub setData {
  my $self = shift;
  my ($arrayref1, $arrayref2, $style) = @_;
  my ($arrayref, $i);

  if (ref $arrayref2) { # passing data as two data arrays (x0 ...) (y0 ...)

    unless ($#$arrayref1 = $#$arrayref2) { # error checking
      $self->{'_errorMessage'} = "The dataset does not contain an equal number of x and y values.";
      return 0;
    }

    # check whether data are numeric
    # and construct a single flat array
    for ($i=0; $i<=$#$arrayref1; $i++) {

      if ($$arrayref1[$i] !~ /^([+-]?)(?=\d|\.\d)\d*(\.\d*)?([Ee]([+-]?\d+))?$/) {
	# if ($$arrayref1[$i] =~ /[^\d\.-]/) {
	$self->{'_errorMessage'} = "The data element $$arrayref1[$i] is non-numeric.";
	return 0;
      }
      if ($$arrayref2[$i] !~ /^([+-]?)(?=\d|\.\d)\d*(\.\d*)?([Ee]([+-]?\d+))?$/) {
	# if ($$arrayref2[$i] =~ /[^\d\.-]/) {
	$self->{'_errorMessage'} = "The data element $$arrayref2[$i] is non-numeric.";
	return 0;
      }

      # construct a flat array
      $$arrayref[2*$i] = $$arrayref1[$i];
      $$arrayref[2*$i+1] = $$arrayref2[$i];
    }

  } else { # passing data as a single flat data array (x0 y0 ...)

    $arrayref = $arrayref1;
    $style = $arrayref2; 
  
    # check whether array is unbalanced
    if ($#$arrayref % 2 == 0) {
      $self->{'_errorMessage'} = "The dataset does not contain an equal number of x and y values.";
      return 0;
    }

    # check whether data are numeric
    for ($i=0; $i<=$#$arrayref; $i++) {
      if ($$arrayref[$i] !~ /^([+-]?)(?=\d|\.\d)\d*(\.\d*)?([Ee]([+-]?\d+))?$/) { 
	# if ($$arrayref1[$i] =~ /[^\d\.-]/) {
	$self->{'_errorMessage'} = "The data element $$arrayref[$i] is non-numeric.";
	return 0;
      }
    }
  }

  # record the dataset
  my $label = ++$self->{'_numDataSets'};
  $self->{'_data'}->{$label} = $arrayref;
  $self->{'_dataStyle'}->{$label} = ($style ? $style : 'linespoints');

  $self->{'_validMinMax'} = 0; # invalidate any prior min-max calculations
  return $label;
}

sub error {
  my $self = shift;
  return $self->{'_errorMessage'};
}

sub setGraphOptions {
    my $self = shift;
    my %hash = @_;

    for (keys (%hash)) { $self->{"_$_"} = $hash{$_}; }
}         

sub getBounds {
  my $self = shift;
  $self->_getMinMax() unless $self->{'_validMinMax'};

  return ($self->{'_xmin'}, $self->{'_ymin'},
	  $self->{'_xmax'}, $self->{'_ymax'});
}

sub draw {
  my $self = shift;

  $self->_getMinMax() unless $self->{'_validMinMax'};
  $self->_drawTitle() if $self->{'_title'}; # vert offset may be increased
  $self->_drawAxes();
  $self->_drawData();

  return $self->{'_im'}->gif;
}


#===================#
#  private methods  #
#===================#

# initialization; this contains a record of all private data
sub _init {
  my $self = shift;
    
  #  create an image object
  if ($#_ == 1) {
    $self->{'_im'} = new GD::Image($_[0], $_[1]);
    $self->{'_imx'} = $_[0];
    $self->{'_imy'} = $_[1];
  }
  else {
    $self->{'_im'} = new GD::Image(400,300);
    $self->{'_imx'} = 400;
    $self->{'_imy'} = 300;
  }
    
  # set graph offset; graph will be centered this many pixels within  image
  $self->{'_horGraphOffset'} = 50;
  $self->{'_vertGraphOffset'} = 50;
  
  # create an empty hash for the datsets
  # data sets and their styles are hashes whose keys are 1 ... _numDataSets
  # and values are refs to flat data arrays or style strings, respectively
  $self->{'_data'} = {};
  $self->{'_dataStyle'} = {};
  $self->{'_numDataSets'} = 0;
  
  # calculated by _getMinMax and used in translating _data2pxl()
  $self->{'_xmin'} = 0;    $self->{'_xmax'} = 0; # among all datasets
  $self->{'_ymin'} = 0;    $self->{'_ymax'} = 0;
  $self->{'_xslope'} = 0;  $self->{'_yslope'} = 0; # for _data2pxl()
  $self->{'_ax'} = 0;      $self->{'_ay'} = 0;
  $self->{"_omx"} = 0;     $self->{"_omy"} = 0; # for axis ticks
  $self->{'_validMinMax'} = 0; # last calculated min and max still valid
  
  # initialize text 
  ($self->{'_horAxisLabel'}, $self->{'_vertAxisLabel'}) = ('','');
  $self->{'_title'} = '';
  $self->{'_errorMessage'} = '';
  
  #  allocate some colors
  $self->{'_white'} = $self->{'_im'}->colorAllocate(255,255,255);
  $self->{'_black'} = $self->{'_im'}->colorAllocate(0,0,0);        
  $self->{'_red'} = $self->{'_im'}->colorAllocate(255,0,0);       
  $self->{'_blue'} = $self->{'_im'}->colorAllocate(0,0,255); 
  $self->{'_green'} = $self->{'_im'}->colorAllocate(0,255,0);
 
  # make the background transparent and interlaced
  $self->{'_im'}->transparent($self->{'_white'});
  $self->{'_im'}->interlaced('true');

  # Put a black frame around the picture
  $self->{'_im'}->rectangle( 0, 0,
			     $self->{'_imx'}-1, $self->{'_imy'}-1,
			     $self->{'_black'});

  # undocumented: in script, use as $plotObject->{'_debugging'} = 1;
  $self->{'_debugging'} = 0;
}


# sets min and max values of all data (_xmin, _ymin, _xmax, _ymax);
# also sets _xslope, _yslope, _ax and _ay used in _data2pxl;
# usage: $self->_getMinMax
sub _getMinMax {
  my $self = shift;
  my ($i, $arrayref);
  
  # 0 is always in range
  my ($xmin, $ymin, $xmax, $ymax) = (0,0,0,0); 

  # if no data, set arbitrary bounds
  ($xmin, $ymin, $xmax, $ymax) = (0,0,1,1) unless keys %{$self->{'_data'}} > 0; 

  # cycle through the datasets looking for min and max values
  foreach (keys %{$self->{'_data'}}) {
  
    $arrayref = $self->{'_data'}->{$_};
    
    for ($i=0; $i<$#{$arrayref}; $i++) {
      $xmin = ($xmin > $$arrayref[$i] ? $$arrayref[$i] : $xmin);
      $xmax = ($xmax < $$arrayref[$i] ? $$arrayref[$i] : $xmax);
      $i++;
      $ymin = ($ymin > $$arrayref[$i] ? $$arrayref[$i] : $ymin);
      $ymax = ($ymax < $$arrayref[$i] ? $$arrayref[$i] : $ymax);
    }
  }

  # set axes data ranges as decimal order of magnitude of widest dataset
  ($self->{'_xmin'}, $self->{'_xmax'}) = $self->_getOM ('x', $xmin,$xmax);
  ($self->{'_ymin'}, $self->{'_ymax'}) = $self->_getOM ('y', $ymin,$ymax);

  # calculate conversion constants for _data2pxl()
  $self->{'_xslope'} = ($self->{'_imx'} - 2 * $self->{'_horGraphOffset'}) 
    / ($self->{'_xmax'} - $self->{'_xmin'});
  $self->{'_yslope'} = ($self->{'_imy'} - 2 * $self->{'_vertGraphOffset'}) 
    / ($self->{'_ymax'} - $self->{'_ymin'});

  $self->{'_ax'} = $self->{'_horGraphOffset'};
  $self->{'_ay'} = $self->{'_imy'} - $self->{'_vertGraphOffset'};

  $self->{'_validMinMax'} = 1;

  print STDERR 
    "_getMinMax(): ($self->{'_omx'}, $self->{'_omy'}) " 
      . "($xmin,$xmax) ($ymin,$ymax) "
	. "($self->{'_xmin'}, $self->{'_xmax'}) "
	  . "($self->{'_ymin'}, $self->{'_ymax'})\n"
	    if $self->{'_debugging'};
}


# returns order of magnitude (with decimal) greater than +/- min and max
# sets _omx (or y) used for translating _data2pxl
# usage: ($min, $max) = $self->_getOM ('x', $xmin, $xmax);  # or y
sub _getOM { 
  my $self = shift; 
  my $xory = shift;
  my @nums = @_;
  my ($tmp, $om, $count) = (0,0);
  my @sign = ();
  
  # find the (exponential) order of magnitude eg, 1000
  foreach (@nums) {
    if ($_<0) {
      push @sign, ('-1');
      $_ = - $_;
    } elsif ($_ == 0) {
      push @sign, ('0');
      next;
    } else {
      push @sign, ('1');
    }

    $tmp = 10 ** (int (log($_) / log(10))); # 1, 10, 100, ... less than $_
    $om = ( $tmp>$om?$tmp:$om );
  }
  $self->{"_om$xory"} = $om;

  # return the decimal order of magnitude eg, 7000
  # epsilon adjustment in case om equals min or max
  return (0,0) if $om == 0;
  return ( $om * (int(($_[0]-0.00001*$sign[0])/$om) + $sign[0]),
	   $om * (int(($_[1]-0.00001*$sign[1])/$om) + $sign[1])
	 ); 
}



# draws all the datasets in $self->{'_data'}
# usage: $self->_drawData()
sub _drawData { 
  my $self = shift; 
  my ($i, $num, $px, $py, $prevpx, $prevpy, $dataSetLabel, $color); 

  foreach $dataSetLabel (keys %{$self->{'_data'}}) { 

    # get color
    if ( $self->{'_dataStyle'}->{$dataSetLabel} =~ /((red)|(blue)|(green))/i ) {
      $color = "_$1";
      $color =~ tr/A-Z/a-z/;
    } else {
      $color = '_black';
    }

    # draw the first point 
    ($px, $py) = $self->_data2pxl (
			     $self->{'_data'}->{$dataSetLabel} [0],  
			     $self->{'_data'}->{$dataSetLabel} [1]
			    ); 
    $self->{'_im'}->arc($px, $py,4,4,0,360,$self->{$color})
      unless $self->{'_dataStyle'}->{$dataSetLabel} =~ /nopoint/i; 

    ($prevpx, $prevpy) = ($px, $py); 

    # debugging
    if ($self->{'_debugging'}) {
      $self->{'_im'}->string(gdSmallFont,$px,$py-10,
			     "0($px,$py)",$self->{$color});
      print STDERR "pxldata: 0 ($px, $py)";
    }

    # draw the rest of the points and lines 
    $num = @{ $self->{'_data'}->{$dataSetLabel} }; 
    for ($i=2; $i<$num; $i+=2) { 

      # get next point
      ($px, $py) = $self->_data2pxl (
				     $self->{'_data'}->{$dataSetLabel}[$i], 
				     $self->{'_data'}->{$dataSetLabel}[$i+1]
				    );

      # draw point, maybe
      $self->{'_im'}->arc($px, $py,4,4,0,360,$self->{$color})
	unless $self->{'_dataStyle'}->{$dataSetLabel} =~ /nopoint/i;

      # draw line from previous point, maybe
      if ($self->{'_dataStyle'}->{$dataSetLabel} =~ /dashed/) {
	$self->{'_im'}->dashedLine($prevpx, $prevpy, $px, $py, $self->{$color});
      } elsif ($self->{'_dataStyle'}->{$dataSetLabel} =~ /noline/i) {
	next;
      } else { # default to solid line
	$self->{'_im'}->line($prevpx, $prevpy, $px, $py, $self->{$color});
      }

      ($prevpx, $prevpy) = ($px, $py); 

      # debugging
      if ($self->{'_debugging'}) {
	$self->{'_im'}->string(gdSmallFont,$px-10,$py+10,
			       "$i($px,$py)",$self->{$color});
	print STDERR "$i ($px, $py)";
      }
    }
  }
}



# translate a data point to the nearest pixel point within the graph
# usage: (px,py) = $self->_data2pxl (x,y)
sub _data2pxl {
  my $self = shift;
  my ($x, $y) = @_;

  return ( int ( $self->{'_ax'} 
		 + ($x - $self->{'_xmin'}) * $self->{'_xslope'} ),
	   int ( $self->{'_ay'} 
		 - ($y - $self->{'_ymin'}) * $self->{'_yslope'} )
	 );
}



# draw the axes, axis labels, ticks and tick labels
# usage: $self->_drawAxes
sub _drawAxes {
  # axes run from data points: x -- ($xmin,0) ($xmax,0);
  #                            y -- (0,$ymin) (0,$ymax);

  my $self = shift;
  my ($w,$h) = (gdSmallFont->width, gdSmallFont->height);

  # horizontal axis
  my ($p1x, $p1y) = $self->_data2pxl ($self->{'_xmin'}, 0);
  my ($p2x, $p2y) = $self->_data2pxl ($self->{'_xmax'}, 0);
  $self->{'_im'}->line($p1x, $p1y, $p2x, $p2y, $self->{'_black'});

  # axis label
  my $len = $w * length ($self->{'_horAxisLabel'});
  my $xStart = ($p2x+$len/2 > $self->{'_imx'}-10) # center under right end of axis 
    ? ($self->{'_imx'}-10-$len) : ($p2x-$len/2);  #   or right justify
  $self->{'_im'}->string (gdSmallFont, $xStart, $p2y+3*$h/2,
			  $self->{'_horAxisLabel'},
			  $self->{'_black'});

  print STDERR "\nHor: p1 ($p1x, $p1y) p2 ($p2x, $p2y)\n" 
    if $self->{'_debugging'};

  # vertical axis
  ($p1x, $p1y) = $self->_data2pxl (0, $self->{'_ymin'});
  ($p2x, $p2y) = $self->_data2pxl (0, $self->{'_ymax'});
  $self->{'_im'}->line($p1x, $p1y, $p2x, $p2y, $self->{'_black'});

  # axis label
  $xStart = $p2x - length ($self->{'_vertAxisLabel'}) * $w / 2;
  $self->{'_im'}->string (gdSmallFont, ($xStart>10 ? $xStart : 10), $p2y - 2*$h,
			  $self->{'_vertAxisLabel'},
			  $self->{'_black'});

  print STDERR "Ver: p1 ($p1x, $p1y) p2 ($p2x, $p2y)\n" 
    if $self->{'_debugging'};

  # draw axis ticks and tick labels
  my ($i,$px,$py, $step);

  # horizontal step calculation
  $step = $self->{'_omx'}; 
  # step too large
  $step /= 2  if ($self->{'_xmax'} - $self->{'_xmin'}) / $step < 6;
  # once again. A poor hack for case  om = max.
  $step /= 2  if ($self->{'_xmax'} - $self->{'_xmin'}) / $step < 6;
  # step too small. As long as we are doing poor hacks
  $step *= 2  if ($self->{'_xmax'} - $self->{'_xmin'}) / $step > 12;

  for ($i=$self->{'_xmin'}; $i <= $self->{'_xmax'}; $i+=$step ) {
    ($px,$py) = $self->_data2pxl($i, 0);
    $self->{'_im'}->line($px, $py-2, $px, $py+2, $self->{'_black'});
    $self->{'_im'}->string (gdSmallFont, 
			    $px-length($i)*$w/2, $py+$h/2, 
			    $i, $self->{'_black'}) unless $i == 0;
  }
  print STDERR "Horstep: $step ($self->{'_xmax'} - $self->{'_xmin'})/$self->{'_omx'})\n"
    if $self->{'_debugging'};

  # vertical
  $step = $self->{'_omy'};
  $step /= 2  if ($self->{'_ymax'} - $self->{'_ymin'}) / $step < 6;
  $step /= 2  if ($self->{'_ymax'} - $self->{'_ymin'}) / $step < 6; 
  $step *= 2  if ($self->{'_ymax'} - $self->{'_ymin'}) / $step > 12;

  for ($i=$self->{'_ymin'}; $i <= $self->{'_ymax'}; $i+=$step ) {
    ($px,$py) = $self->_data2pxl (0, $i);
    $self->{'_im'}->line($px-2, $py, $px+2, $py, $self->{'_black'});
    $self->{'_im'}->string (gdSmallFont, 
			    $px-5-length($i)*$w, $py-$h/2, 
			    $i, $self->{'_black'}) unless $i == 0;
  }
  print STDERR "Verstep: $step ($self->{'_ymax'} - $self->{'_ymin'})/$self->{'_omy'})\n"
    if $self->{'_debugging'};

}


sub _drawTitle {
  my $self = shift;
  my ($w,$h) = (gdMediumBoldFont->width, gdMediumBoldFont->height);

  # increase vert offset and recalculate conversion constants for _data2pxl()
  $self->{'_vertGraphOffset'} += 2*$h;

  $self->{'_xslope'} = ($self->{'_imx'} - 2 * $self->{'_horGraphOffset'}) 
    / ($self->{'_xmax'} - $self->{'_xmin'});
  $self->{'_yslope'} = ($self->{'_imy'} - 2 * $self->{'_vertGraphOffset'}) 
    / ($self->{'_ymax'} - $self->{'_ymin'});

  $self->{'_ax'} = $self->{'_horGraphOffset'};
  $self->{'_ay'} = $self->{'_imy'} - $self->{'_vertGraphOffset'};


  # centered below chart
  my ($px,$py) = ($self->{'_imx'}/2, # $self->{'_vertGraphOffset'}/2);
		  $self->{'_imy'} - $self->{'_vertGraphOffset'}/2);

  ($px,$py) = ($px - length ($self->{'_title'}) * $w/2, $py+$h/2);
  $self->{'_im'}->string (gdMediumBoldFont, $px, $py,
			  $self->{'_title'},
			  $self->{'_black'}); 
}

1;

__END__


=head1 NAME

Chart::Plot.pm - Plot two dimensional data in a gif image. Version 0.07.

=head1 SYNOPSIS

    use Chart::Plot; 
    
    my $plot = Chart::Plot->new; 
    my $anotherPlot = Chart::Plot->new ($gif_width, $gif_height); 
    
    $plot->setData (\@dataset) or die( $plot->error() );
    $plot->setData (\@xdataset, \@ydataset);
    $plot->setData (\@anotherdataset, 'red_dashedline_points'); 
    $plot->setData (\@xanotherdataset, \@yanotherdataset, 
                    'Blue SolidLine NoPoints');
    
    my ($xmin, $ymin, $xmax, $ymax) = $plot->getBounds();
    
    $plot->setGraphOptions ('horGraphOffset' => 75,
    			    'vertGraphOffset' => 100,
    			    'title' => 'My Graph Title',
    			    'horAxisLabel' => 'my X label',
    			    'vertAxisLabel' => 'my Y label' );
    
    print $plot->draw;

=head1 DESCRIPTION

I wrote B<Chart::Plot.pm> to create gif images of some simple graphs
of two dimensional data. The other graphing interface modules to GD.pm
I saw on CPAN either could not handle negative data, or could only
chart evenly spaced horizontal data. (If you have evenly spaced or
nonmetric horizontal data and you want a bar or pie chart, I have
successfully used the GIFgraph and Chart::* modules, available on
CPAN.)

B<Chart::Plot.pm> will plot multiple data sets in the same graph, each
with some negative or positive values in the independent or dependent
variables. Each dataset can be a scatter graph (data are represented
by graph points only) or with lines connecting successive data points,
or both. Colors and dashed lines are supported, as is scientific
notation (1.7E10). Axes are scaled and positioned automatically
and 5-10 ticks are drawn and labeled on each axis.

You must have already installed the B<GD.pm> library by Lincoln Stein,
available on B<CPAN> or at
http://www.genome.wi.mit.edu/ftp/pub/software/WWW/GD.html

This is an early draft and has not received exhaustive testing, but it
seems to work ok. I will attempt to maintain compatibility of the
public interface in future versions.

=head1 USAGE

=head2 Create an image object: new()

    use Chart::Plot; 

    my $plot = Plot->new; 
    my $plot = Plot->new ( $gif_width, $gif_height ); 
    my $anotherGraph = Plot->new; 

Create a new empty image with the new() method. It will be transparent
and interlaced.  If image size is not specified, the default is 400 x
300 pixels, or, you can specify a different gif size. You can also
create more than one image in the same script.

=head2 Acquire a dataset: setData()

    $plot->setData (\@data);
    $plot->setData (\@xdata, \@ydata);
    $plot->setData (\@data, 'red_dashedline_points'); 
    $plot->setData (\@xdata, \@ydata, 'blue solidline');

The setData() method reads in a two-dimensional dataset to be plotted
into the image. You can pass the dataset either as one flat array
containing the paired x,y data or as two arrays, one each for the x
and y data.

As a single array, in your script, construct a flat array of the
form (x0, y0, ..., xn, yn) containing n+1 x,y data points .  Then plot
the dataset by passing a reference to the data array to the setData()
method. (If you do not know what a reference is, just put a backslash
(\) in front of the name of your data array when you pass it as an
argument to setData().) Like this:

    my @data = qw( -3 9   -2 4   -1 1   0 0   1 1  2 4  3 9);
    $plot->setData (\@data);

Or, you may find it more convenient to construct two equal length
arrays, one for the horizontal and one for the corresponding vertical
data. Then pass references to both arrays (horizontal first) to
setData():

    my @xdata = qw( -3  -2  -1  0  1  2  3 );
    my @ydata = qw(  9   4   1  0  1  4  9 );
    $plot->setData (\@xdata, \@ydata);

[In the current version, if you pass a reference to a single, flat
array to setData(), then only a reference to the data array is stored
internally in the plot object, not a copy of the array. The object
does not modify your data, but you can and the modified data will be
drawn.  On the other hand, if you pass references to two arrays, then
copies of the data are stored internally, and you cannot modify them
from within your script. This inconsistent behavior is probably a
bug, though it might be useful from time to time.]

You can also plot multiple datasets in the same graph by calling
$plot->setData() repeatedly on different datasets.

B<Error checking:> The setData() method returns a postive integer on
success and 0 on failure. If setData() fails, you can recover an error
message about the most recent failure with the error() method. The
error string returned will either be "The data set does not contain an
equal number of x and y values." or "The data element ... is
non-numeric."

    $plot->setData (\@data) or die( $plot->error() );

In the current version, only numerals, decimal points (apologies to
Europeans), minus signs, and more generally, scientific notation
(+1.7E-10 or -.298e+17) are supported. Commas (,), currencies ($),
time (11:23am) or dates (23/05/98) are not yet supported and will
generate errors. I hope to figure these out sometime in the future.

Be cautious with scientific notation, since the axis tick labels will
probably become unwieldy. Consider rescaling your data by orders of
magnitude or using logarithmic transforms before plotting them. Or
experiment with image size and graph offset.

B<Style options:> You can also specify certain graphing style options
for each dataset by passing an optional final string argument to
setData() with a concatenated list of selections from each of the
following groups:

    black  *
    red
    green 
    blue

    solidline  *
    dashedline
    noline

    points  *
    nopoints

The starred options in each group are the default for that group.  If
you do not specify any options, you will get black solid lines
connecting successive data points with dots at each data point
('black_solidline_points'). If you want a red scatter plot (red dots
but no lines) you could specify either

    $plot->setData (\@data, 'redNOLINE'); 
    $plot->setData (\@xdata, \@ydata, 'Points Noline Red');

Options are detected by a simple regexp match, so order does not
matter in the option string, options are not case sensitive and
extraneous characters I<between> options are ignored. There is no harm
in specifying a default. There is also no error checking.


=head2 Obtain current graph boundaries: getBounds()

    my ($xmin, $ymin, $xmax, $ymax) = $plot->getBounds;

This method returns tha data values of the lower left corner and upper
right corner of the graph, based on the datasets so far set.  If you
have only positive data, then $xmin and $ymin will be 0. The upper
values will typically not be the data maxima, since axis tick ranges
are usually a little beyond the range of the data.  If you add another
dataset, these values may become inaccurate, so you will need to call
the method again. As an example, I use this to draw a least
squares line through a scatter plot of the data, running from the
edges of the graph rather than from the bounds of the data.



=head2 Graph-wide options: setGraphOptions()

    $plot->setGraphOptions ('title' => 'My Graph Title',
		            'horAxisLabel' => 'my X label',
		            'vertAxisLabel' => 'my Y label' 
			    'horGraphOffset' => $numHorPixels,
	                    'vertGraphOffset' => $numvertPixels);

This method and each of its arguments are optional.  You can call it
with one, some or all options, or you can call it repeatedly to set or
change options. This method will also accept a hash.

In the current version, Chart::Plot.pm is a little smarter about
placement of text, but is still not likely to satisfy everyone, If you
are not constructing images on the fly, you might consider leaving
these blank and using a paint program to add text by hand.

Titles and Axis labels are blank, by default. The title will be
centered in the margin space below the graph. A little extra vertical
offset space (the margin between the edges of the graph proper and the
image) is added to allow room. There is no support for multi-line
strings. You can specify empty strings for one or the other of the
axis labels.  The vertical label will be centered or left justified
above the vertical axis; the horizontal label will be placed below the
end of the horizontal axis, centered or right justified.

By default, the graph will be centered within the gif image, with 50
pixels offset distance from its edges to the edges of the image
(though a title will increase the vertical offset). Axis and tick
labels and the title will appear in this margin (assuming all data are
positive). You can obtain more space for a title or a horizontal label
by increasing the image size (method new() ) and adjusting the
offset. 

=head2 Draw the image: draw() 

     $plot->draw;

This method draws the gif image and returns it as a string, which you
can print to a file or to STDOUT. (This should be the last method
called from the $plot object.) To save it in a file:

    open (WR,'>plot.gif') or die ("Failed to write file: $!");
    print WR $plot->draw();
    close WR;

Or, to return the graph from a cgi script as a gif image:

    print "Content-type: image/gif\n\n";
    print  $plot->draw();

Or, to pipe it to a viewing program which accepts STDIN (such as xv on
Unix)

    open (VIEWER,'| /usr/X11R6/bin/xv -') or die ("Failed to open viewer: $!");
    print VIEWER $plot->draw();
    close VIEWER;

=head1 BUGS AND TO DO

You will probably be unhappy with axis tick labels running together if
you use scientific notation.  Controlling tick label formatting and
length for scientific notation seems doable but challenging.

Future versions might incorporate data set labels inside the graph, a
legend, control of font size, word wrap and dynamic adjustment of axis
labels and title. Better code, a better pod page.


=head1 AUTHOR

Copyright (c) 1998 by Sanford Morton <sanford@halcyon.com>.  All
rights reserved.  This program is free software; you can redistribute
it and/or modify it under the same terms as Perl itself. 

=head1 SEE ALSO

GIFgraph(1) and Chart(1) are other front end modules to GD(1).

=cut 
