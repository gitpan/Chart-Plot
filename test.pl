
# Before `make install' is performed this script should be runnable with
# `make test'. After `make install' it should work as `perl test.pl'

######################### We start with some black magic to print on failure.

# Change 1..1 below to 1..last_test_to_print .
# (It may become useful if the test is moved to ./t subdirectory.)

BEGIN { $| = 1; print "1..3\n"; }
END {print "not ok 1\n" unless $loaded;}
use Chart::Plot;
$loaded = 1;
print "Ok 1: loaded module\n";

######################### End of black magic.

# Insert your test code below (better if it prints "ok 13"
# (correspondingly "not ok 13") depending on the success of chunk 13
# of the test code):

eval {
  my $plot = Chart::Plot->new; 
  my @data = qw( -3 9   -2 4   -1 1   0 0   1 1  2 4  3 9);
  $plot->setData (\@data) or die ( $plot->error() );
  $plot->setGraphOptions ('title' => 'Test A',
			  'horAxisLabel' => 'X axis',
			  'vertAxisLabel' => 'Y axis'); 
  open (WR,'>testa.gif') or die ("Failed to write file: $!");
  print WR $plot->draw();
  close WR;
};
$_ = ($@ ? "Not ok 2: $@" : "Ok 2: created testa.gif\n");
print;

eval {
  my $plot = Chart::Plot->new(500,400); 
  my @xdata = -10..10;
  my @ydata = map $_**3, @xdata;
  $plot->setData (\@xdata, \@ydata, 'red nolines points') 
    or die ( $plot->error() );
  $plot->setGraphOptions ('title' => 'Test B: Y = X**3',
			  'horGraphOffset' => 40,
			  'vertGraphOffset' => 20);
  open (WR,'>testb.gif') or die ("Failed to write file: $!");
  print WR $plot->draw();
  close WR;
};
$_ = $@ ? "Not ok 3: $@" : "Ok 3: created testb.gif\n";;
print;
