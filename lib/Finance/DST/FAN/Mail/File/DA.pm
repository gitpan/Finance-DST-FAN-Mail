package Finance::DST::FAN::Mail::File::DA;

our $VERSION = '0.004000';

use Moose;
use Finance::DST::FAN::Mail::Utils qw/trim parse_date/;

extends 'Finance::DST::FAN::Mail::File';

override is_refresh => sub { 0 };
override is_delta => sub { 1 };

sub _process_va {
  shift->error("This file type is only for REIT/LPs and mutual funds");
}
sub _process_vul {
  shift->error("This file type is only for REIT/LPs and mutual funds");
}

our $dah = qr/^(CGH|DVH|FTH)001(.{8})(.{8})(.{8})(.{9})(.{7})(.{15})(.{15})(.)(.{9})(.{15}).{59}/;
our $da1 = qr/^(?:CGR|DVR|FTR)001(.{7})(.{9})(.{20})([F ])(.{15})(.)(.{9})(.)(.)(.{15})(.{15})(.{15})(.{15})(.{9})(.{9})(.{4})(.{4}).{4}/;
our $da2 = qr/^(?:CGR|DVR|FTR)002(.{3})(.{15})(.{15})(.{9})(.)(.{9})(.{30})(.{9})(.{7})(.{7})(.)(.{3})(.{3})(.{26})(.{7})(.{7}).{2}/;

sub _process_mf { shift->_process_reit }
sub _process_lp { shift->_process_reit }
sub _process_reit {
  my $self = shift;
  my @records;
  defined(my $line = $self->next_line) or
    $self->error("File ended prematurely on RHR001");

  if ($line =~ /$dah/ ){
    my $dist_type = $1;
    my $dist = {
                cusip     => $5,
                fund_code => $6,
                dist_rate_per_share => $7 / 10**10,
                dist_type_code      => $9,
                reinv_share_price   => $10 / 10000,
               };
    $dist->{dist_type} = $1 eq 'CGH' ? "Gain" : ($1 eq 'DVH' ? "Div" : "Tax");


    if (my $tmp = parse_date($2)){
      $dist->{record_date} = $tmp;
    }
    if (my $tmp = parse_date($3)){
      $dist->{dist_payable_date} = $tmp;
    }
    if (my $tmp = parse_date($4)){
      $dist->{dist_reinv_date} = $tmp;
    }
    push(@records, $dist);
    if (length(my $tmp = trim $8  ) ){ $dist->{fund_expense_rate} = $tmp / 10**10; }
    if (length(my $tmp = trim $11 ) ){ $dist->{penalty_withholding_rate} = $tmp / 10**10; }
    defined($line = $self->next_line) or
      $self->error("File ended prematurely on CGH/DVH/FTH001");

    while( $line =~ /$da1/){
      $dist->{dealer_num}  = trim $1;
      $dist->{branch_num}  = trim $2;
      $dist->{account_num} = trim $3;
      #$dist->{account_num_code} = trim $4;
      $dist->{ssn} = trim $7;
      $dist->{status_code} = trim $8;
      $dist->{dist_code}   = $9;
      $dist->{shares_reinvested}    = $10 / 10000;
      $dist->{share_bal_after_dist} = $11 / 10000;
      $dist->{issued_shares} = $12 / 10000;
      $dist->{dist_amount}   = $13 / 100;

      if (length(my $tmp = trim $8  ) ){ $dist->{fund_expense} = $tmp / 100;      }
      if (length(my $tmp = trim $11 ) ){ $dist->{fund_expense_alloc_code} = $tmp; }
      if (length(my $tmp = trim $14 ) ){ $dist->{subaccounting_fee} = $tmp / 100; }
      if (length(my $tmp = trim $15 ) ){ $dist->{other_fees}        = $tmp / 100; }
      if (length(my $tmp = trim $16 ) ){ $dist->{nscc_trust_co_num}    = $tmp;    }
      if (length(my $tmp = trim $17 ) ){ $dist->{nscc_third_party_num} = $tmp;    }
      defined($line = $self->next_line) or
        $self->error("File ended prematurely on CGR/DVR/FTR001 record");

      if( $line =~ /$da2/){
        $dist->{dealer_control_level_code} = $9;
        $dist->{rep_num}  = trim $6;
        $dist->{rep_name} = trim $7;
        $dist->{fund_from_to} = trim $9;

        if (length(my $tmp = trim $1  ) ){ $dist->{foreign_tax_rate}   = $tmp / 1000;}
        if (length(my $tmp = trim $2  ) ){ $dist->{foreign_tax_amount} = $tmp / 100; }
        if (length(my $tmp = trim $3  ) ){ $dist->{us_withholding_amount} = $tmp / 100; }
        if (length(my $tmp = trim $4  ) ){ $dist->{cum_discount_num} = $tmp / 100; }
        if (length(my $tmp = trim $8  ) ){ $dist->{external_fund_id} = $tmp; }
        if (length(my $tmp = trim $10 ) ){ $dist->{wire_group_num} = $tmp; }
        if (length(my $tmp = trim $11 ) ){ $dist->{balance_i}  = $tmp; }
        if (length(my $tmp = trim $12 ) ){ $dist->{txn_code}   = $tmp; }
        if (length(my $tmp = trim $13 ) ){ $dist->{txn_suffix} = $tmp; }
        if (length(my $tmp = trim $14 ) ){ $dist->{voluntary_txn_desc} = $tmp; }
        if (length(my $tmp = trim $15 ) ){ $dist->{trust_custodian_id_num} = $tmp; }
        if (length(my $tmp = trim $16 ) ){ $dist->{third_party_id_num} = $tmp; }
        defined($line = $self->next_line) or
          $self->error("File ended prematurely on CGR/DVR/FTR002");
      } else {
        $self->error("Got '$line' where CGR/DVR/FTR002 record was expected.");
      }
    }
  } else {
    $self->error("Got '$line' where CGH/DVH/FTH001 record was expected.");
  }

  if ( $self->_process_footer($line) ) {
    return \@records;
  } else {
    $self->error("Got '$line' where CGR/DVR/FTR/RTR001 record was expected");
  }
  $self->error("Recieved no Trail record. File possibly truncated");
}

1;

__PACKAGE__->meta->make_immutable;

__END__;

=head1 NAME

Finance::DST::FAN::Mail::File::DA -
Read DST FANMail Distribution records into data structures

=head1 DESCRIPTION

For Usage information please refer to L<Finance::DST::FAN::Mail::File>.

=head1 DATA KEYS

=head2 VUL

=head2 Variable Annuity

=head2 Mutual Fund

=head2 Real Estate Investment Trust / Limited Partnership

=head1 PRIVATE METHODS

=head2 _process_vul

=head2 _process_va

Throws exception. Not valid types for this file.

=head2 _process_reit

Process real estate investment trust records.

=head2 _process_lp

Process limited partnership records.

=head2 _process_mf

Process mutual fund records.

=head1 SEE ALSO

L<Finance::DST::FAN::Mail::File>, L<Finance::DST::FAN::Mail::Utils>

=head1 AUTHOR & LICENSE

Please see L<Finance::DST::FAN::Mail> for more information.

=cut
