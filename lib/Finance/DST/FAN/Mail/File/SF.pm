package Finance::DST::FAN::Mail::File::SF;

our $VERSION = '0.001000';

use Moose;
use Finance::DST::FAN::Mail::Utils qw/trim/;

extends 'Finance::DST::FAN::Mail::File';

override is_refresh => sub { 1 };
override is_delta => sub { 0 };

our $sfr =  qr/^SFR001(.{9})(.{7})(.{40})(.{38})(.{8})(..).{50}?/;

sub _process_vul{ shift->_process_va }

sub _process_va{
  my $self = shift;
  my @records;
  defined(my $line = $self->next_line) or
    $self->error("File ended prematurely on RHR001");

  while ( $line =~ /$sfr/ ){
    my $pos = {
               cusip         => $1,
               product_code  => trim $2,
               symbol        => trim $5,
               fund_name     => trim $3,
               product_name  => trim $4,
               security_type => $6,
              };
    push(@records, $pos);
    defined($line = $self->next_line) or
      $self->error("File ended prematurely on SFR001");
  }
  if ( $self->_process_footer($line) ) {
    return \@records;
  } else {
    $self->error("Got '$line' where SFR001/RTR001 record was expected");
  }
  $self->error("Recieved no Trail record. File possibly truncated");
}

sub _process_lp{ shift->_process_mf }
sub _process_reit{ shift->_process_mf }

sub _process_mf{
  my $self = shift;
  my @records;
  defined(my $line = $self->next_line) or
    $self->error("File ended prematurely on RHR001");

  while ( $line =~ /$sfr/ ){
    my $pos = {
               cusip         => $1,
               fund_code     => trim $2,
               symbol        => trim $5,
               fund_name     => trim $3,
               security_type => $6,
              };
    push(@records, $pos);
    defined($line = $self->next_line) or
      $self->error("File ended prematurely on SFR001");
  }
  if ( $self->_process_footer($line) ) {
    return \@records;
  } else {
    $self->error("Got '$line' where SFR001/RTR001 record was expected");
  }
  $self->error("Recieved no Trail record. File possibly truncated");
}

1;

__END__;

=head1 NAME

Finance::DST::FAN::Mail::File::SFR -
Read DST FANMail SFR records into data structures

=head1 DESCRIPTION

For Usage information please refer to L<Finance::DST::FAN::Mail::File>.

=head1 DATA KEYS

=head2 VUL

=head2 Variable Annuity

=head2 Mutual Fund

=head2 Real Estate Investment Trust / Limited Partnership

=head1 PRIVATE METHODS

=head2 _process_vul

Process variable universal life records.

=head2 _process_reit

Process real estate investment trust records.

=head2 _process_lp

Process limited partnership records.

=head2 _process_va

Process variable annuity records.

=head2 _process_mf

Process mutual fund records.

=head1 SEE ALSO

L<Finance::DST::FAN::Mail::File>, L<Finance::DST::FAN::Mail::Utils>

=head1 AUTHOR

Guillermo Roditi (groditi) <groditi@cpan.org>

=head1 LICENSE

You may distribute this code under the same terms as Perl itself.

=cut
