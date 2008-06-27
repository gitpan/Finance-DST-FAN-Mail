package Finance::DST::FAN::Mail::Utils;

use strict;
use warnings;
use IO::File;
use Class::MOP;
use DateTime;
use Carp qw/confess/;

our $VERSION = '0.001000';

our (@ISA, @EXPORT_OK);
BEGIN {
  require Exporter;
  @ISA = qw(Exporter);
  @EXPORT_OK = qw(trim parse_date read_file file_info_from_header get_file_info);
}

sub parse_date($;$) {
  my $date = shift;
  if( $date =~ /\d{8}/ ){
    return if 0+$date == 0;
    my $year = substr($date,0,4);
    my $month = substr($date,4,2);
    my $day = substr($date,6,2);
    confess if (@_ && !defined($_[0]));
    if (@_ && ($_[0] =~ /\d{6}/ ) ) {
      my $hour = substr($_[0],0,2);
      my $min = substr($_[0],2,2);
      my $sec = substr($_[0],4,2);
      return DateTime->new(year => $year, month  => $month, day    => $day,
                           hour => $hour, minute => $min,   second => $sec,
                          );
    }
    return DateTime->new(year => $year, month => $month, day => $day);
  }
  return;
}

sub trim($) {
  my $x = shift;
  $x =~ s/^\s+//;
  $x =~ s/\s+$//;
  return $x;
}

sub file_info_from_header{
  my $line = shift;
  my $type = trim(substr($line,6,15));
  if ($type eq 'PRICE REFRESHER') {
    $type = 'FPR';
  } elsif ($type eq 'SECURITY FILE') {
    $type = 'SF';
  } elsif ($type eq 'ACCT MASTER POS') {
    $type = 'AMP';
  } elsif ($type eq 'ACCT POSITION') {
    $type = 'APR';
  } elsif ($type eq 'DISTRIBUTION') {
    $type = 'DA';
  } elsif ($type eq 'FINANCIALDIRECT') {
    $type = 'DFA';
  } elsif ($type eq 'NEWACCT ACTIVIT') {
    $type = 'NAA';
  } elsif ($type eq 'NONFINANCIALACT') {
    $type = 'NFA';
  } else {
    confess "File type '${type}' not supported.",
  }

  my $file_date = parse_date(substr($line,29,8));
  my $type_code = substr($line,70,1);
  my $product_type;
  if ($type_code eq 'R') {
    $product_type = 'REIT';
  } elsif ($type_code eq 'L') {
    $product_type = 'LP';
  } elsif ($type_code eq 'V') {
    $product_type = 'VA';
  } else {
    if ( length(trim(substr($line,71,1))) ) {
      $product_type = 'VUL';
    } else {
      $product_type = 'MF';
    }
  }
  return +{
           processed_date => $file_date,
           file_class => $type,
           product_type => $product_type,
          };

}

sub get_file_info {
  my $file = shift;
  if(my $io = IO::File->new("<${file}")){
    defined(my $line = $io->getline) or confess("File '${file}' is empty.");
    undef $io;
    return file_info_from_header($line);
  } else {
    confess("Failed to open '${file}'");
  }
}


sub read_file($@) {
  my $file = shift;
  my $info = get_file_info($file);
  my $class = join('::', 'Finance::DST::FAN::Mail::File', $info->{file_class});
  Class::MOP::load_class($class);
  return $class->new(filename => $file, @_);
}


1;
__END__;

=head1 NAME

  Finance::DST::FAN::Mail::Utils - Utilities for interacting with DST FANMail Files

=head1 SYNOPSIS

    use Finance::DST::FAN::Mail::File::Utils qw/parse_date trim read_file/;

    #eliminate leading and trailing whitespace;
    my $trimmed = trim "    XYZ    "; # $trimmed is now "XYZ"

    #inflate a DST date into a datetime object
    my $dt = parse_date "20081231";
    my $dt = parse_date "20081231", "235959";

    #make reading files easier
    read_file $filename;
    read_file($filename, record_callback => sub{ ... });

=head1 EXPORTABLE SUBROUTINES

=head2 trim $string

Simple trim function to delete leading and trailing whitespace from a string.

=head2 parse_date $date, $time

Inflate a date in YYYYMMDD and time in HHMMSS format to a DateTime object. The
time argument is optional.

=head2 read_file $filename, @parser_args

Will determine the file type based on the header record and instantiate and
return the correct Finance::DST::FAN::Mail::File::* object for the filename
provided.

=head2 file_info_from_header $header_record

Will return a hashref containing the following keys

=over 4

=item B<processed_date> - L<DateTime> object of the file's processed date

=item B<file_class> - The type of file contained. The value matches the class
name of the apropriate parser class. (FPR, SF, AMP, APR, DA, DFA, NAA, NFA)

=item B<product_type> - The kind of product contained (VUL, VA, MF, REIT, LP)

=back

=head2 get_file_info $filename

Attempt to open the file, extract the header record and return the results of
C<file_info_from_header>.

=head1 AUTHOR & LICENSE

Please see L<Finance::DST::FAN::Mail> for more information.

=cut
