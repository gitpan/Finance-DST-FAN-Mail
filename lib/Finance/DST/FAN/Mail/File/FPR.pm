package Finance::DST::FAN::Mail::File::FPR;

our $VERSION = '0.002000';

use Moose;
use Finance::DST::FAN::Mail::Utils qw/trim parse_date/;

extends 'Finance::DST::FAN::Mail::File';

override is_refresh => sub { 1 };
override is_delta => sub { 0 };

our $rhr  = qr/^RHR001(.{15})(\d{8})(\d{8}).(...)(..).(.)(.).{114}/;
our $fpr1 = qr/^FPR001(.{9})(.{7})(.{8})(.{9})(.{9})(.{11})(.{38})(.{15}).{14}(.{4}).{30}/;

sub _process_header {
  my $self = shift;
  $self->clear_file_handle if $self->_has_file_handle;

  defined(my $line = $self->next_line) or $self->error("File is empty.");

  if( $line =~ /$rhr/){
    $self->file_type( trim $1 );
    $self->system_id($4);
    $self->management_code($5);
    my $type_ind = trim $6;
    my $vul_ind  = trim $7;
    $self->processed_date( parse_date $3 );
    $self->super_sheet_date( parse_date $2 );

    if($type_ind =~ /[RLV]/) {
      $self->product_type($type_ind);
    } elsif($type_ind eq '') {
      if($vul_ind eq 'E'){
        $self->product_type('U');
      } else {
        $self->product_type('M');
      }
    }
  } else {
    $self->error("Expected Header but got: '$line'");
  }
}


sub _process_vul{
  my $self = shift;
  my @records;
  defined(my $line = $self->next_line) or
    $self->error("File ended prematurely on RHR001");

  while ($line =~ /$fpr1/ ){
    my $pos = {
               cusip        => $1,
               product_code => trim $2, #vul va
               po_price     => $5 / 10000,
               share_class  => trim $9,
              };
    push(@records, $pos);
    if (length(my $tmp = trim $3) ){ $pos->{price_date} = $tmp if(0 + $tmp > 0); }
    if (length(my $tmp = trim $7) ){ $pos->{name} = $tmp; }
    $pos->{unit_price} = ($4 =~ /^\**$/ ? $8 : $4)/ 10**6;
    defined($line = $self->next_line) or
      $self->error("File ended prematurely on FPR001");

  }
  if ( $self->_process_footer($line) ) {
    return \@records;
  } else {
    $self->error("Got '$line' where FPR001/RTR001 record was expected");
  }
  $self->error("Recieved no trailer record. File possibly truncated");
}


sub _process_va{
  my $self = shift;
  my @records;
  defined(my $line = $self->next_line) or
    $self->error("File ended prematurely on RHR001");

  while ($line =~ /$fpr1/ ){
    my $pos = {
               cusip        => $1,
               product_code => trim $2, #vul va
               po_price     => $5 / 10000,
               share_class  => trim $9,
              };
    push(@records, $pos);
    if (length(my $tmp = trim $3) ){ $pos->{price_date} = $tmp if(0 + $tmp > 0); }
    if (length(my $tmp = trim $7) ){ $pos->{name} = $tmp; }
    $pos->{unit_price} = ($4 =~ /^\**$/ ? $8 : $4)/ 10**6;
    defined($line = $self->next_line) or
      $self->error("File ended prematurely on FPR001"); 
  }
  if ( $self->_process_footer($line) ) {
    return \@records;
  } else {
    $self->error("Got '$line' where FPR001/RTR001 record was expected");
  }
  $self->error("Recieved no trailer record. File possibly truncated");
}


sub _process_mf{
  my $self = shift;
  my @records;
  defined(my $line = $self->next_line) or
    $self->error("File ended prematurely on RHR001");

  while ($line =~ /$fpr1/ ){
    my $pos = {
               cusip        => $1,
               fund_code    => trim $2, #fund reitlp
               nav          => $4 / 10000, #fund reit
               po_price     => $5 / 10000,
               share_class  => trim $9,
              };
    push(@records, $pos);
    if (length(my $tmp = trim $3) ){ $pos->{price_date} = $tmp if(0 + $tmp > 0); }
    if (length(my $tmp = trim $7) ){ $pos->{name} = $tmp; }
    if (length(my $tmp = trim $6) ){ $pos->{daily_dividend_rate} = $tmp; }
    defined($line = $self->next_line) or
      $self->error("File ended prematurely on FPR001");

  }
  if ( $self->_process_footer($line) ) {
    return \@records;
  } else {
    $self->error("Got '$line' where FPR001/RTR001 record was expected");
  }
  $self->error("Recieved no trailer record. File possibly truncated");
}

sub _process_lp{ shift->_process_mf(@_) }
sub _process_reit{ shift->_process_mf(@_) }

__PACKAGE__->meta->make_immutable;

1;

__END__;

=head1 NAME

Finance::DST::FAN::Mail::File::FPR -
Read DST FANMail FPR records into data structures

=head1 DESCRIPTION

For Usage information please refer to L<Finance::DST::FAN::Mail::File>.

=head1 DATA KEYS

=head2 VUL

=head2 Variable Annuity

=head2 Mutual Fund

=head2 Real Estate Investment Trust / Limited Partnership

=head1 PRIVATE METHODS

=head2 _process_header

The FPR file has overrides the  inherited C<_process_header> method because the
file features a non standard header record.

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

=head1 AUTHOR & LICENSE

Please see L<Finance::DST::FAN::Mail> for more information.

=cut
