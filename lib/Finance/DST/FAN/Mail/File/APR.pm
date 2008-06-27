package Finance::DST::FAN::Mail::File::APR;

our $VERSION = '0.002000';

use Moose;
use Finance::DST::FAN::Mail::Utils qw/trim parse_date/;

extends 'Finance::DST::FAN::Mail::File';

override is_refresh => sub { 1 };
override is_delta => sub { 0 };

#VUL-only fields
has product_code     => (is => 'rw', isa => 'Str');
has contract_num     => (is => 'rw', isa => 'Str');
has policy_value     => (is => 'rw', isa => 'Num');
has surrender_value  => (is => 'rw', isa => 'Num');
has surrender_chg    => (is => 'rw', isa => 'Num');
has loan_value       => (is => 'rw', isa => 'Num');
has collateral_value => (is => 'rw', isa => 'Num');
has premium_paid     => (is => 'rw', isa => 'Num');

our $pph  = qr/^PPH001(\d{7})(.{20})(.{15})(.{15})(.{15})(.{15})(.{15})(.{15}).{37}/;
our $apr1 = qr/^APR001(.{7})(.{9})(.{9})(.{7})(.{20})(?:[F ])(.{15})(.{15})(.{15})(.{9})(.{15})(.{4})(.{4})(.{7})(.{7}).{10}/;

our $apr2 = qr/^APR002(.{15})(.{15})(.{15})(.{10})(.{9})(.{30})(.{9})(.{3})(.)(.{9})(.{9})(.)(.)(.)(.)(.{9})(.{15})./;

after _process_header => sub {
  my $self = shift;
  return unless $self->is_vul;

  defined(my $line = $self->next_line) or
    $self->error("File ended prematurely on RHR001");
  if ($line =~ /$pph/ ){
    $self->product_code(trim $1);
    $self->contract_num(trim $2);
    $self->policy_value($3 / 100);
    $self->surrender_value($4 / 100);
    $self->surrender_chg($5 / 100);
    $self->loan_value($6 / 100);
    $self->collateral_value($7 / 100);
    $self->premium_paid($8 / 100);
  } else {
    $self->error("Expected PPH001 record but got '${line}'");
  }
};

sub _process_vul {
  my $self = shift;
  my @records;
  defined(my $line = $self->next_line) or
    $self->error("File ended prematurely on RHR001");

  while ($line =~ /$apr1/ ){
    my $pos = {
               dealer_num => trim $1,
               branch_num => trim $2,
               cusip => $3,
               product_code => trim $4,
               policy_num => trim $5,
               total_units => $6 / 10**6,
               ($7 != 0 ? (unissued_units => $7 / 10**6) : ()),
               ($8 != 0 ? (issued_units => $8 / 10**6) : ()),
               unit_value => ($9 =~ /^\**$/ ? $10 : $9)/ 10**6,
              };
    push(@records, $pos);

    if (length(my $tmp = trim $11) ){ $pos->{nscc_trust_co_num}    = $tmp; }
    if (length(my $tmp = trim $12) ){ $pos->{nscc_third_party_num} = $tmp; }
    if (length(my $tmp = trim $13) ){ $pos->{custodian_id_num}     = $tmp; }
    if (length(my $tmp = trim $14) ){ $pos->{third_party_id_num}   = $tmp; }
    defined($line = $self->next_line) or
      $self->error("File ended prematurely on APR001");

    if ( $line =~ /$apr2/) {
      my($irate,$mdate) = (substr($1,0,7),substr($1,7,8));
      $pos->{interest_rate}       = $irate / 10**4 if trim $irate;
      $pos->{escrow_shares_count} = $2 / 10**4 if trim $2;
      $pos->{collected_balance}   = $3 / 100;
      $pos->{rep_num}             = trim $5;
      $pos->{rep_name}            = trim $6;
      $pos->{ssn}                 = $11;
      $pos->{ssn_status_code}     = $12;
      $pos->{multiple_owner_i}    = 1  if $13 eq 'M';
      $pos->{sub_account_type}    = $14;
      $pos->{collected_bal_neg_i} = 1  if $15 eq 'N';
      $pos->{total_units_2}       = $17 / 10**6; #XXX SOMETHING AWFUL

      if ( my $tmp = parse_date($mdate) ) {
        $pos->{maturity_date} = $tmp;
      }
      if (length(my $tmp = trim $4) ) { $pos->{alpha_code} = $tmp; }
      if (length(my $tmp = trim $7) ) { $pos->{cum_discount_num} = $tmp; }
      if (length(my $tmp = trim $8) ) { $pos->{social_code} = $tmp; }
      if (length(my $tmp = trim $10) ) { $pos->{loi_num} = $tmp; }
      defined($line = $self->next_line) or
        $self->error("File ended prematurely on APR002");
    }
    $self->record_callback->($self, $pos) if $self->has_record_callback;
  }
  if ( $self->_process_footer($line) ) {
    return \@records;
  } else {
    $self->error("Got '$line' where APR001/RTR001 record was expected");
  }
  $self->error("Recieved no trailer record. File possibly truncated");
}

sub _process_va {
  my $self = shift;
  my @records;
  defined(my $line = $self->next_line) or
    $self->error("File ended prematurely on RHR001");

  while ($line =~ /$apr1/ ){
    my $pos = {
               dealer_num   => trim $1,
               branch_num   => $2,
               cusip        => $3,
               product_code => trim $4,
               policy_num   => trim $5,
              };

    push(@records, $pos);
    $pos->{total_units}    = $6 / 10**6;
    $pos->{unissued_units} = $7 / 10**6 if $7 != 0;
    $pos->{issued_units}   = $8 / 10**6 if $8 != 0;
    $pos->{unit_value}     = ($9 =~ /^\**$/ ? $10 : $9)/ 10**6;
    if (length(my $tmp = trim $11) ){ $pos->{nscc_trust_co_num}    = $tmp; }
    if (length(my $tmp = trim $12) ){ $pos->{nscc_third_party_num} = $tmp; }
    if (length(my $tmp = trim $13) ){ $pos->{custodian_id_num}     = $tmp; }
    if (length(my $tmp = trim $14) ){ $pos->{third_party_id_num}   = $tmp; }

    defined($line = $self->next_line) or
      $self->error("File ended prematurely on APR001");

    if( $line =~ /$apr2/){
      my($irate,$mdate) = (substr($1,0,7),substr($1,7,8));
      $pos->{interest_rate}       = $irate / 10**4     if trim $irate;
      $pos->{escrow_shares_count} = $2 / 10**4     if trim $2;
      $pos->{collected_balance}   = $3 / 100;
      $pos->{rep_num}             = trim $5;
      $pos->{rep_name}            = trim $6;
      $pos->{ssn}                 = $11;
      $pos->{ssn_status_code}     = $12;
      $pos->{sub_account_type}    = $14;
      $pos->{collected_bal_neg_i} = 1  if $15 eq 'N';
      $pos->{total_units_2}       = $17 / 10**6; #XXX SOMETHING AWFUL
      if ( my $tmp = parse_date($mdate) ) {
        $pos->{maturity_date} = $tmp;
      }
      if (length(my $tmp = trim $4) ){ $pos->{alpha_code} = $tmp; }
      if (length(my $tmp = trim $7) ){ $pos->{cum_discount_num} = $tmp; }
      if (length(my $tmp = trim $8) ){ $pos->{social_code} = $tmp; }
      if (length(my $tmp = trim $10) ){ $pos->{loi_num} = $tmp; }
      defined($line = $self->next_line) or
        $self->error("File ended prematurely on APR002");

    }
    $self->record_callback->($self, $pos) if $self->has_record_callback;
  }
  if ( $self->_process_footer($line) ) {
    return \@records;
  } else {
    $self->error("Got '$line' where APR001/RTR record was expected");
  }
  $self->error("Recieved no Trail record. File possibly truncated");
}

sub _process_mf {
  my $self = shift;
  my @records;
  defined(my $line = $self->next_line) or
    $self->error("File ended prematurely on RHR001");

  while ($line =~ /$apr1/ ){
    my $pos = {
               dealer_num  => trim $1,
               branch_num  => $2,
               cusip       => $3,
               fund_code   => trim $4,
               account_num => trim $5,
              };
    push(@records, $pos);

    $pos->{total_shares}    = $6 / 10**4;
    $pos->{unissued_shares} = $7 / 10**4 if $7 != 0;
    $pos->{issued_shares}   = $8 / 10**4 if $8 != 0;
    $pos->{nav}             = $9 / 10**4;
    if (length(my $tmp = trim $11) ){ $pos->{nscc_trust_co_num}    = $tmp; }
    if (length(my $tmp = trim $12) ){ $pos->{nscc_third_party_num} = $tmp; }
    if (length(my $tmp = trim $13) ){ $pos->{custodian_id_num}     = $tmp; }
    if (length(my $tmp = trim $14) ){ $pos->{third_party_id_num}   = $tmp; }

    defined($line = $self->next_line) or
      $self->error("File ended prematurely on APR001");

    if ( $line =~ /$apr2/){
      $pos->{escrow_shares_count} = $2 / 10**4     if trim $2;
      $pos->{collected_balance}   = $3 / 100;
      $pos->{rep_num}             = trim $5;
      $pos->{rep_name}            = trim $6;
      $pos->{ssn}                 = $11;
      $pos->{ssn_status_code}     = $12;
      $pos->{collected_shares}    = $17 / 10**4;
      if( length(my $tmp = trim $1) ){ $pos->{accrued_dividend}  = $tmp / 100; }
      if( length(my $tmp = trim $4) ){ $pos->{alpha_code} = $tmp; }
      if( length(my $tmp = trim $7) ){ $pos->{cum_discount_num} = $tmp; }
      if( length(my $tmp = trim $8) ){ $pos->{social_code} = $tmp; }
      if( length(my $tmp = trim $10) ){ $pos->{loi_num} = $tmp; }
      if( length(my $tmp = trim $13) ){ $pos->{nav_i}             = $tmp; }
      if( length(my $tmp = trim $14) ){ $pos->{reduced_pricing_i} = $tmp; }
      if( length(my $tmp = trim $15) ){ $pos->{employee_i} = $tmp eq 'Y' ? 1 : 0; }
      if( length(my $tmp = trim $16) ){ $pos->{external_plan_id}  = $tmp; }
      $pos->{dealer_control_level_code} = $13;
      defined($line = $self->next_line) or
        $self->error("File ended prematurely on APR002");
    }
    $self->record_callback->($self, $pos) if $self->has_record_callback;
  }
  if ( $self->_process_footer($line) ) {
    return \@records;
  } else {
    $self->error("Got '$line' where APR001/RTR record was expected");
  }
  $self->error("Recieved no Trail record. File possibly truncated");
}

sub _process_reit {
  my $self = shift;
  my @records;
  defined(my $line = $self->next_line) or
    $self->error("File ended prematurely on RHR001");

  while ($line =~ /$apr1/ ){
    my $pos = {
               dealer_num   => trim $1,
               branch_num   => $2,
               cusip        => $3,
               fund_code    => trim $4,
               account_num  => trim $5,
              };
    push(@records, $pos);

    $pos->{total_units}    = $6 / 10**4;
    $pos->{unissued_units} = $7 / 10**4 if $7 != 0;
    $pos->{issued_units}   = $8 / 10**4 if $8 != 0;
    $pos->{nav}           = $9 / 10**4;
    if (length(my $tmp = trim $11) ){ $pos->{nscc_trust_co_num}    = $tmp; }
    if (length(my $tmp = trim $12) ){ $pos->{nscc_third_party_num} = $tmp; }
    if (length(my $tmp = trim $13) ){ $pos->{custodian_id_num}     = $tmp; }
    if (length(my $tmp = trim $14) ){ $pos->{third_party_id_num}   = $tmp; }

    defined($line = $self->next_line) or
      $self->error("File ended prematurely on APR001");

    if( $line =~ /$apr2/){
      $pos->{escrow_shares_count} = $2 / 10**4 if trim $2;
      $pos->{collected_balance}   = $3 / 100;
      $pos->{rep_num}         = trim $5;
      $pos->{rep_name}        = trim $6;
      $pos->{ssn}             = $11;
      $pos->{ssn_status_code} = $12;
      $pos->{collected_units} = $17 / 10**4;
      if (length(my $tmp = trim $1) ){ $pos->{accrued_dividend}  = $tmp / 100; }
      if (length(my $tmp = trim $4) ){ $pos->{alpha_code}        = $tmp; }
      if (length(my $tmp = trim $7) ){ $pos->{cum_discount_num}  = $tmp; }
      if (length(my $tmp = trim $8) ){ $pos->{social_code}       = $tmp; }
      if (length(my $tmp = trim $9) ){ $pos->{dealer_control_level_code} = $tmp; }
      if (length(my $tmp = trim $10) ){ $pos->{loi_num}           = $tmp; }
      if (length(my $tmp = trim $13) ){ $pos->{nav_i}             = $tmp; }
      if (length(my $tmp = trim $14) ){ $pos->{reduced_pricing_i} = $tmp; }
      if (length(my $tmp = trim $15) ){ $pos->{employee_i} = $tmp eq 'Y' ? 1 : 0; }
      if (length(my $tmp = trim $16) ){ $pos->{external_plan_id}  = $tmp; }
      defined($line = $self->next_line) or
        $self->error("File ended prematurely on APR002");
    }
    $self->record_callback->($self, $pos) if $self->has_record_callback;
  }
  if ( $self->_process_footer($line) ) {
    return \@records;
  } else {
    $self->error("Got '$line' where APR001 / RTR record was expected");
  }
  $self->error("Recieved no trailer record. File possibly truncated.");
}

__PACKAGE__->meta->make_immutable;

1;

__END__;

=head1 NAME

  Finance::DST::FAN::Mail::File::APR - Read DST FANMail APR records into data structures

=head1 DESCRIPTION

This module provides an interface for reading the Account Position File (APR) into more
meaningful data structures as well as some basic tests of file integrity. The APR file
contains all accounts mantained by the data provider. A file will only contain
information on a single type of financial product type.

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

=head1 AUTHOR & LICENSE

Please see L<Finance::DST::FAN::Mail> for more information.

=cut
