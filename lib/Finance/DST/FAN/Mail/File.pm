package Finance::DST::FAN::Mail::File;

use Carp ();
use Moose;
use IO::File;
use DateTime;
use MooseX::Types::Path::Class qw/File/;

use Finance::DST::FAN::Mail::Utils qw/trim parse_date/;

our $VERSION = '0.004000';

our $rhr = qr/^RHR001(.{15})(\d{8})(\d{8})([\d\s]{8})(.{8})(\d{3})(\d{7}).(.{3})(..).(.)(.)/;
our $rtr = qr/^RTR001(.{15})(.{9})/;

has filename        => (is => 'ro', isa => File, required => 1, coerce => 1);
has record_callback => (is => 'ro', isa => 'CodeRef', predicate => 'has_record_callback');

has records       => (is => 'ro', isa => 'ArrayRef', lazy_build => 1);
has _file_handle  => (is => 'ro', isa => 'IO::File', lazy_build => 1);
has _current_record_number =>
  (
   is => 'rw',
   isa => 'Int',
   clearer => '_clear_current_record_number',
   predicate => '_has_current_record_number',
  );

has file_type        => (is => 'rw', isa => 'Str');
has super_sheet_date => (is => 'rw', isa => 'DateTime');
has processed_date   => (is => 'rw', isa => 'DateTime');
has job_name         => (is => 'rw', isa => 'Str');
has file_format_code => (is => 'rw', isa => 'Str');
has request_numer    => (is => 'rw', isa => 'Int');
has system_id        => (is => 'rw', isa => 'Str');
has management_code  => (is => 'rw', isa => 'Str');
has product_type     => (is => 'rw', isa => 'Str');
has vul_type         => (is => 'rw', isa => 'Str');
has record_count     => (is => 'rw', isa => 'Int');

# this is future work
#has strictness => (is => 'rw', isa => 'Int', default => sub {3} );

sub is_refresh{  confess "empty prototype" }
sub is_delta{ confess "empty prototype" }

sub error {
  my ($self, $message) = @_;
  my @segments = ($message);
  if( blessed($self) ){
    if($self->_has_file_handle){
      my $file = $self->filename;
      push(@segments, "File: '${file}'");
      if($self->_has_current_record_number){
        my $line = $self->_current_record_number;
        push(@segments, "Line: ${line}");
      }
    }
  }
  Carp::croak(join("; ", @segments));
}

#So, Originally I planned on throwing exceptions when files came without
#trailing whitespace, but the test files sometimes lack trailing whitespace
#so I am tagging it back in. AFAIK all DST FANMail files are 160 bytes in
# length. If they actually mean characters then we might have some breakage
# if we ever encounter characters that are more than one byte since length()
# returns the length in bytes, not characters. cross your fingers suckaaaasss

sub next_line {
  my $self = shift;
  if( defined(my $line = $self->_file_handle->getline) ){
    $self->_current_record_number( $self->_current_record_number + 1 );
    #can't use chomp because we don't know if we are getting \r or \r\n and
    # we can't localize $/ to a file handle. bullshit.
    $line =~ s/(?:\r?\n)$//;
    #this should go away when reading the file in strict mode >= 4
    $line = join("", $line, (" " x (160 - length($line))));
    return $line;
  }
  return;
}


sub _build__file_handle {
  my $self = shift;
  my $file = $self->filename;
  Carp::croak("file $file is not readable by effective uid/gid")
      unless -r $file;

  if( my $io =  IO::File->new("<${file}") ){
    $self->_current_record_number( 0 ); #uhm... $. ?
    return $io;
  } else {
    Carp::croak("Failed to open $file");
  }
}

after _clear_file_handle => sub {
  shift->_clear_current_record_number;
};

sub BUILD{
  my $self = shift;
  $self->_process_header;
}

sub _build_records {
  my $self = shift;
  my $type = $self->product_type;
  if($type eq 'M'){
    return $self->_process_mf;
  } elsif($type eq 'V'){
    return $self->_process_va;
  } elsif($type eq 'R'){
    return $self->_process_reit;
  } elsif($type eq 'L'){
    return $self->_process_lp;
  } elsif($type eq 'U'){
    return $self->_process_vul;
  }
}

#Move this to an external module..
##fuck this. the RHR header is not consistent accross to the Fund Price refresher
#so we are going to have to search using the string file_type. ugh!

sub _process_header {
  my $self = shift;
  $self->clear_file_handle if $self->_has_file_handle;

  defined(my $line = $self->next_line) or $self->error("File is empty.");

  if( $line =~ /$rhr/){
    my $ss_date = $2;
    my $p_date  = $3;
    my $p_time  = $4;
    my $type_code = $10;
    my $vul_type = trim $11;
    $self->file_type( trim $1 );
    $self->job_name($5);
    $self->file_format_code($6);
    $self->request_numer($7);
    $self->system_id($8);
    $self->management_code($9);
    $self->super_sheet_date( parse_date($ss_date) );
    $self->processed_date
      ($p_time > 0 ? parse_date($p_date, $p_time) : parse_date($p_date));
    if($type_code =~ /[RLV]/) {
      $self->product_type($type_code);
      $self->vul_type($vul_type) if $vul_type;
    } elsif($type_code eq ' ') {
      if($vul_type){
        $self->product_type('U');
        $self->vul_type($vul_type);
      } else {
        $self->product_type('M');
      }
    }
  } else {
    $self->error("Expected Header but got: '$line'");
  }
}

sub _process_footer {
  my $self = shift;
  my $line = shift;
  if( $line =~ /$rtr/){
    my $target = $2;
    $self->record_count($target);
    my $record_count = $self->_current_record_number;
    $self->error("Record count mismatch expected ${target} but got ${record_count}")
      unless $target == $record_count;
    while(defined($line = $self->next_line)){
      $self->error("File has data '${line}' after footer")
        if trim($line) ne ''; #ignore empty lines at the end of the file
    }
    $self->_clear_file_handle; #close the filehandle
    return 1;
  }
  return;
}

sub is_mf   { shift->product_type eq 'M' }
sub is_va   { shift->product_type eq 'V' }
sub is_lp   { shift->product_type eq 'L' }
sub is_vul  { shift->product_type eq 'U' }
sub is_reit { shift->product_type eq 'R' }

__PACKAGE__->meta->make_immutable;

1;

__END__;

=head1 NAME

  Finance::DST::FAN::Mail::File - Read DST FANMail Files into data structures

=head1 SYNOPSIS

  my $file = Finance::DST::FAN::Mail::File
      ->new(
            filename        => $path_to_file,
            record_callback => sub{ ... }, #optional
           );
    my $file_date = $file->processed_date;
    my $records = eval { $file->records };
    die("There was an error reading the file: $@") unless defined $records;

   if($file->is_mf){              #Mutual Fund Records
     # ...
   } elsif($file->is_va){         #Variable Annuity Records
     # ...
   } elsif($file->is_reit){       #REIT Records
     # ...
   } elsif($file->is_lp){         #Limited Partnership Records
     # ...
   } elsif($file->is_vul){        #VUL records
     # ...
   }

    for my $record ( @$records ){
       #insert records into database or whatever
       my $cusip = $record->{cusip}; #etc..
    }

=head1 DESCRIPTION

This module provides a basic interface for easily reading DST FANMail data files into more
meaningful data structures as well as some basic tests of file integrity. A file will
only contain information on a single type of financial product type.

For more detailed information on the data keys associated with each file type please
see the relevant file's description. The Finance::DST::FAN::Mail::File::* hierarchy
is composed of subclasses of this module and all information provided here will also
be true of this class' subclasses.

=over 4

=item B<Finance::DST::FAN::Mail::File::APR> - Account Position Records (format code 014)

=back

=head1 ATTRIBUTES

=head2 filename

Required read-only string that represents the path to the file you wish to read.

=head2 record_callback

=over 4

=item B<has_record_callback> - predicate

=back

Optional read-only code reference that will be called after every logical record is
read. Will be passed two arguments, the current instance of the file
parser (so you can access file properties) and a hashref representing the record
as described above.

You can use this to reduce the memory foot print of your program by keeping only
the current account record in memory. Example:

    my $callback = sub{
        my($instance, $rec) = @_;
        #process data here;
        %$rec = ();
    };
    my $file = Finance::DST::FAN::Mail::File:XYZ
      ->load( filename => $file, record_callback => $callback);

    #by the time this returns a callback will have been executed for each account
    my $recs = eval { $balance->records };
    defined($recs) && !$@ ? commit() : rollback() and die($@);

The downside of this method is that if the file is currupted, you will have
to catch the exception and rollback changes. Partially transmitted files are NOT that
uncommon! Make sure you have a rollback mechanism.

=head2 records

=over 4

=item B<clear_records> - clearer

=item B<has_records> - predicate

=item B<_build_records> - builder

=back

An array reference containing all of the positions contained in the file.
This read-only attribute builds lazyly the first time it is requested by actually
going through the while file and reading it. If any errors are encountered while
reading the file or the file appears to be truncated an exception will be thrown.

=head2 File Properties

The following attributes are automatically filled the header is read:

=over 4

=item B<file_type> - String

=item B<super_sheet_date> - DateTime (date only)

=item B<processed_date> - DateTime (date and, if provided, time)

=item B<job_name> - String

=item B<file_format_code> -Numeric String

=item B<request_numer> - Numeric String

=item B<system_id> - String

=item B<management_code> - String

=item B<product_type> - String (M, R, L, U or V)
B<M>utual Fund, B<R>EIT, B<L>P, VB<U>L, B<V>ariable Annuity

=item B<vul_type> - String, applies to VULs only.

=back

The following attribute is automatically filled the trailer is read:

=over 4

=item B<record_count> - Integer, number of records in file including all header,
detail and trailer records. (essentially C<wc -l>)

=back

=head2 _file_handle

=over 4

=item B<_clear_file_handle> - clearer

=item B<_has_file_handle> - predicate

=item B<_build__file_handle> - builder

=back

This is the IO::File object that holds our filehandle. DO NOT TOUCH THIS. If you mess
with this I can almost guarantee you will break something.

=head1 PUBLIC METHODS

=head2 load key => val

Will load a file and return an instance of the proper file parser. Proper key / value
pairs are filename (required), and record_callback (optional).

=head2 Informational Predicates

You can use these to easily determine what type of data the file contains.

=over 4

=item B<is_mf> - Returns true if data is Mutual Fund

=item B<is_va> - Returns true if data is Variable Annuity

=item B<is_lp> - Returns true if data is Limited Partnership

=item B<is_vul> - Returns true if data is Variable Universal Life

=item B<is_reit> - Returns true is data is Real Estate Investment Trust

=item B<is_delta> - Returns true if the file only contains information for the
changed records. The opposite of C<is_refresh>.

=item B<is_refresh> - Returns true if the file contains information for all
records. The opposite of C<is_delta>.

=back

=head2 meta

See L<Moose>

=head1 PRIVATE METHODS

=head2 BUILD

At instantiation time this method is called and it opens the file handle and reads
the header of the file to get the file date.

See L<Moose> for more information about how C<BUILD> works.

=head2 _process_header

This private method reads the first line of the file and processes the header.
It also sets the file_date attribute.

=head2 _process_footer

Extract the record_count from the footer records for integirity checking.

=head2 error

=head2 next_line

=head1 SEE ALSO

L<Finance::DST::FAN::Mail::Utils>

=head1 AUTHOR & LICENSE

Please see L<Finance::DST::FAN::Mail> for more information.

=cut
