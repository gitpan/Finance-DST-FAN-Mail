package Finance::DST::FAN::Mail::File::DFA;

our $VERSION = '0.001000';

use Moose;
use Finance::DST::FAN::Mail::Utils qw/trim parse_date/;

extends 'Finance::DST::FAN::Mail::File';

override is_refresh => sub { 0 };
override is_delta => sub { 1 };


#VUL-only fields
has product_code     => (is => 'rw', isa => 'Str');
has contract_num     => (is => 'rw', isa => 'Str');
has policy_value     => (is => 'rw', isa => 'Num');
has surrender_value  => (is => 'rw', isa => 'Num');
has surrender_chg    => (is => 'rw', isa => 'Num');
has loan_value       => (is => 'rw', isa => 'Num');
has collateral_value => (is => 'rw', isa => 'Num');
has premium_paid     => (is => 'rw', isa => 'Num');

our $pth  = qr/^PTH001(.{7})(.{20})(.{15})(.{15})(.{15})(.{15})(.{15})(.{15}).{37}/;

our $dfa1 = qr/^DFA001(.{3})(.{7})(.{9})(.{9})(.{7})(.{20})(?:[F ])(.{7})(.{8})(.{3})(.{3})(.)(.{9})(.{15})(.{15})(.{8})(.{8})(..)(.{9})(.)(.)(.).{7}/;
our $dfa2 = qr/^DFA002(.{9})(.{9})(.{3})(.{3})(.{9})(.{30})(.{15})(.)(.{15})(.{15})(.{3})(.)(.{13})(.{9})(.)(.)(.)(.)(.{9})(.).{5}/;
our $dfa3 = qr/^DFA003(.{4})(.{7})(.{11})(.{26})(.{20})(.)(.{8})(.{9})(.{17})(.)(.)(.{7})(.{11})(.{11})(.{4})(.{4}).{12}/;
our $dfa4 = qr/^DFA004(.{13})(.{40})(.{7})(.{7})(.{15})(.{9})(.)(.{10})(.{10}).{42}/;

after _process_header => sub {
  my $self = shift;
  return unless $self->is_vul;

  defined(my $line = $self->next_line) or
    $self->error("File ended prematurely on RHR001");
  if ($line =~ /$pth/ ){
    $self->product_code(trim $1);
    $self->contract_num(trim $2);
    $self->policy_value($3 / 100);
    $self->surrender_value($4 / 100);
    $self->surrender_chg($5 / 100);
    $self->loan_value($6 / 100);
    $self->collateral_value($7 / 100);
    $self->premium_paid($8 / 100);
  } else {
    $self->error("Expected PTH001 record but got '${line}'");
  }
};

sub _process_vul {
  my $self = shift;
  my @records;
  defined(my $line = $self->next_line) or
    $self->error("File ended prematurely on RHR001");

  while ( $line =~ /$dfa1/ ) {
    my $pos = {
               record_code => $1,
               dealer_num => trim $2,
               branch_num => $3,
               cusip => $4,
               product_code => trim $5,
               policy_num => trim $6,
               batch_num => $7,
               txn_code => trim $9,
               txn_suffix => trim $10,
               share_bal_effect_code => $11,
               gross_txn_amt  => $13 / 100,
               unit_txn_count => $14 / 10**6,
               account_type_code => $19,
               dealer_level_control_code => $20,
               payment_method => $21,
              };
    push(@records, $pos);
    if($12 !~ /^\**$/){ $pos->{unit_value} = $12 / 10**6 };
    if ( my $tmp = parse_date($8) ){
      $pos->{maturity_date} = $tmp;
    }
    if ( my $tmp = parse_date($15) ){
      $pos->{trade_date} = $tmp;
    }
    if ( my $tmp = parse_date($16) ){
      $pos->{confirm_payment_date} = $tmp;
    }
    if (length(my $tmp = trim $17 ) ){ $pos->{discount_category} = $tmp; }
    if (length(my $tmp = trim $18 ) ){ $pos->{order_num}         = $tmp; }
    defined($line = $self->next_line) or
      $self->error("File ended prematurely on DFA001");

    if( $line =~ /$dfa2/){
      if(length(my $tmp = trim $1  ) ){ $pos->{cum_discount_num} = $tmp; }
      if(length(my $tmp = trim $2  ) ){ $pos->{loi_num}          = $tmp; }
      if(length(my $tmp = trim $3  ) ){ $pos->{social_code}      = $tmp; }
      if(length(my $tmp = trim $9  ) ){ $pos->{unit_value} ||= $tmp / 10**6 }
      if(length(my $tmp = trim $12 ) ){ $pos->{cert_issued_code} = $tmp; }
      if(length(my $tmp = trim $13 ) ){ $pos->{check_num}        = $tmp; }

      $pos->{resident_loc_code} = trim $4;
      $pos->{rep_num}           = trim $5;
      $pos->{rep_name}          = trim $6;
      $pos->{ssn}               = trim $14;
      $pos->{ssn_status_code}   = $15;
      $pos->{multiple_owner_i}  = 1 if $16 eq 'M';

      defined($line = $self->next_line) or
        $self->error("File ended prematurely on DFA002");

      if( $line =~ /$dfa3/){
        my %tmp;
        $tmp{contribution_year}    = trim $1;
        $tmp{fund_from_code}       = trim $2;
        $tmp{account_from_to}      = trim $3;
        $tmp{voluntary_txn_desc} = trim $4;
        $tmp{customer_account_num} = trim $5;
        $tmp{customer_account_num_code} = trim $6;
        $tmp{super_sheet_date} = parse_date($7);
        $tmp{bank_micr_id}     = trim $8;
        $tmp{bank_account_num} = trim $9;
        $tmp{liquidation_code} = trim $10;
        $tmp{trade_entry_method_code} = trim $11;
        $tmp{trade_origin_id}         = trim $12;
        $tmp{mutual_fund_txn_id_1}  = trim $13;
        $tmp{mutual_fund_txn_id_2}  = trim $14;
        $tmp{trust_company_num}       = trim $15;
        $tmp{third_party_num}         = trim $16;
        map{ $pos->{$_} = $tmp{$_} } grep{ length $tmp{$_} } keys %tmp;
        defined($line = $self->next_line) or
          $self->error("File ended prematurely on DFA003");

        if( $line =~ /$dfa4/){
          my %tmp;
          $tmp{client_reference_num}   = trim $1;
          $tmp{merchant_desc_code}     = trim $2;
          $tmp{trust_custodian_id_num} = trim $3;
          $tmp{third_party_id_num}     = trim $4;
          $tmp{txn_advanced_comm_at} = trim $5;
          $tmp{nscc_branch_id_num}     = trim $6;
          $tmp{nav_reason_code}        = trim $7;
          $tmp{client_defined_text}    = trim $8;
          $tmp{alpha_code}             = trim $9;
          map{ $pos->{$_} = $tmp{$_} } grep{ length $tmp{$_} } keys %tmp;
          defined($line = $self->next_line) or
            $self->error("File ended prematurely on DFA004");
        }
      }
    } else {
      $self->error("Got '$line' where DFA002 record was expected");
    }
    $self->record_callback->($self, $pos) if $self->has_record_callback;
  }

  if ( $self->_process_footer($line) ) {
    return \@records;
  } else {
    $self->error("Got '$line' where DFA001/RTR001 record was expected");
  }
  $self->error("Recieved no trailer record. File possibly truncated");
}

sub _process_va {
  my $self = shift;
  my @records;
  defined(my $line = $self->next_line) or
    $self->error("File ended prematurely on RHR001");

  while ($line =~ /$dfa1/ ){
    my $pos = {
               record_code  => $1,
               dealer_num   => trim $2,
               branch_num   => $3,
               cusip        => $4,
               product_code => trim $5,
               policy_num   => trim $6,
               batch_num    => $7,
               txn_code     => trim $9,
               txn_suffix   => trim $10,
               share_bal_effect_code => $11,
               gross_txn_amt       => $13 / 100,
               unit_txn_count      => $14 / 10**6,
               account_type_code     => $19,
               dealer_level_control_code => $20,
               payment_method            => $21,
              };

    push(@records, $pos);

    if (my $tmp = parse_date($8)){
      $pos->{maturity_date} = $tmp;
    }
    if (my $tmp = parse_date($15)){
      $pos->{trade_date} = $tmp;
    }
    if (my $tmp = parse_date($16)){
      $pos->{confirm_payment_date} = $tmp;
    }
    if (length(my $tmp = trim $17 ) ){ $pos->{discount_category} = $tmp; }
    if (length(my $tmp = trim $18 ) ){ $pos->{order_num} = $tmp; }
    my $u_value = $12;
    $pos->{unit_value} = $u_value / 10**6 if $u_value =~ /^\**$/;
    defined($line = $self->next_line) or
      $self->error("File ended prematurely on APR001");

    if( $line =~ /$dfa2/){
      if(length(my $tmp = trim $1 ) ){ $pos->{cum_discount_num} = $tmp; }
      if(length(my $tmp = trim $2 ) ){ $pos->{loi_num}          = $tmp; }
      if(length(my $tmp = trim $3 ) ){ $pos->{social_code}      = $tmp; }
      if(length(my $tmp = trim $9 ) ){ $pos->{unit_value} ||= $tmp / 10**6 }
      if(length(my $tmp = trim $12 ) ){ $pos->{cert_issued_code} = $tmp; }
      if(length(my $tmp = trim $13 ) ){ $pos->{check_num}        = $tmp; }

      $pos->{resident_loc_code} = trim $4;
      $pos->{rep_num}           = trim $5;
      $pos->{rep_name}          = trim $6;
      $pos->{ssn}               = trim $14;
      $pos->{ssn_status_code}   = $15;

      defined($line = $self->next_line) or
        $self->error("File ended prematurely on DFA002");

      if( $line =~ /$dfa3/){
        my %tmp;
        $tmp{contribution_year}    = trim $1;
        $tmp{fund_from_code}       = trim $2;
        $tmp{account_from_to}      = trim $3;
        $tmp{voluntary_txn_desc} = trim $4;
        $tmp{customer_account_num} = trim $5;
        $tmp{customer_account_num_code} = trim $6;
        $tmp{super_sheet_date} = parse_date($7);
        $tmp{bank_micr_id}     = trim $8;
        $tmp{bank_account_num} = trim $9;
        $tmp{liquidation_code} = trim $10;
        $tmp{trade_entry_method_code} = trim $11;
        $tmp{trade_origin_id}         = trim $12;
        $tmp{mutual_fund_txn_id_1}  = trim $13;
        $tmp{mutual_fund_txn_id_2}  = trim $14;
        $tmp{trust_company_num}       = trim $15;
        $tmp{third_party_num}         = trim $16;
        map{ $pos->{$_} = $tmp{$_} } grep{ length $tmp{$_} } keys %tmp;
        defined($line = $self->next_line) or
          $self->error("File ended prematurely on DFA003");

        if( $line =~ /$dfa4/){
          my %tmp;
          $tmp{client_reference_num}   = trim $1;
          $tmp{merchant_desc_code}     = trim $2;
          $tmp{trust_custodian_id_num} = trim $3;
          $tmp{third_party_id_num}     = trim $4;
          $tmp{txn_advanced_comm_at} = trim $5;
          $tmp{nscc_branch_id_num}     = trim $6;
          $tmp{nav_reason_code}        = trim $7;
          $tmp{client_defined_text}    = trim $8;
          $tmp{alpha_code}             = trim $9;
          map{ $pos->{$_} = $tmp{$_} } grep{ length $tmp{$_} } keys %tmp;
          defined($line = $self->next_line) or
            $self->error("File ended prematurely on DFA004");
        }
      }
    } else {
      $self->error("Got '$line' where DFA002 record was expected");
    }
    $self->record_callback->($self, $pos) if $self->has_record_callback;
  }
  if ( $self->_process_footer($line) ) {
    return \@records;
  } else {
    $self->error("Got '$line' where DFA001/RTR001 record was expected");
  }

  $self->error("Recieved no Trail record. File possibly truncated");
}

sub _process_reit { shift->_process_mf(@_) }
sub _process_lp   { shift->_process_mf(@_) }

sub _process_mf {
  my $self = shift;
  my @records;
  defined(my $line = $self->next_line) or
    $self->error("File ended prematurely on RHR001");

  while ($line =~ /$dfa1/ ){
    my $pos = {
               record_code  => $1,
               dealer_num   => trim $2,
               branch_num   => $3,
               cusip        => $4,
               product_code => trim $5,
               policy_num   => trim $6,
               batch_num    => $7,
               txn_code     => trim $9,
               txn_suffix   => trim $10,
               share_bal_effect_code => $11,
               share_value           => $12 / 10**4,
               gross_txn_amt       => $13 / 100,
               share_txn_count     => $14 / 10**4,
               account_type_code     => $19,
               dealer_level_control_code => $20,
               payment_method        => $21,
              };
    push(@records, $pos);

    if (my $tmp = parse_date($8)){
      $pos->{maturity_date} = $tmp;
    }
    if (my $tmp = parse_date($15)){
      $pos->{trade_date} = $tmp;
    }
    if (my $tmp = parse_date($16)){
      $pos->{confirm_payment_date} = $tmp;
    }
    if (length(my $tmp = trim $17 ) ){ $pos->{discount_category} = $tmp; }
    if (length(my $tmp = trim $18 ) ){ $pos->{order_num} = $tmp; }
    defined($line = $self->next_line) or
      $self->error("File ended prematurely on APR001");

    if( $line =~ /$dfa2/){
      if(length(my $tmp = trim $1  ) ){ $pos->{cum_discount_num} = $tmp; }
      if(length(my $tmp = trim $2  ) ){ $pos->{loi_num}          = $tmp; }
      if(length(my $tmp = trim $3  ) ){ $pos->{social_code}      = $tmp; }
      if(length(my $tmp = trim $7  ) ){ $pos->{pct_sales_chg}    = $tmp / 10**10; }
      if(length(my $tmp = trim $8  ) ){ $pos->{dealer_comm_code} = $tmp }
      if(length(my $tmp = trim $9  ) ){ $pos->{dealer_comm_amt}  = $tmp / 100 }
      if(length(my $tmp = trim $10 ) ){ $pos->{underwriter_comm_amt} = (($20 eq '-' ? $tmp * -1 : $tmp) / 100) }
      if(length(my $tmp = trim $11 ) ){ $pos->{asof_reason_code} = $tmp }
      if(length(my $tmp = trim $12 ) ){ $pos->{cert_issued_code} = $tmp; }
      if(length(my $tmp = trim $13 ) ){ $pos->{check_num}        = $tmp; }
      if(length(my $tmp = trim $16 ) ){ $pos->{nav_i}            = $tmp; }

      $pos->{resident_loc_code} = trim $5;
      $pos->{rep_num}           = trim $5;
      $pos->{rep_name}          = trim $6;
      $pos->{ssn}               = trim $14;
      $pos->{ssn_status_code}   = $15;
      defined($line = $self->next_line) or
        $self->error("File ended prematurely on DFA002");

      if( $line =~ /$dfa3/){
        my %tmp;
        $tmp{contribution_year}    = trim $1;
        $tmp{fund_from_code}       = trim $2;
        $tmp{account_from_to}      = trim $3;
        $tmp{voluntary_txn_desc} = trim $4;
        $tmp{customer_account_num} = trim $5;
        $tmp{customer_account_num_code} = trim $6;
        $tmp{super_sheet_date} = parse_date($7);
        $tmp{bank_micr_id}     = trim $8;
        $tmp{bank_account_num} = trim $9;
        $tmp{liquidation_code} = trim $10;
        $tmp{trade_entry_method_code} = trim $11;
        $tmp{trade_origin_id}         = trim $12;
        $tmp{mutual_fund_txn_id_1}  = trim $13;
        $tmp{mutual_fund_txn_id_2}  = trim $14;
        $tmp{trust_company_num}       = trim $15;
        $tmp{third_party_num}         = trim $16;
        map{ $pos->{$_} = $tmp{$_} } grep{ length $tmp{$_} } keys %tmp;
        defined($line = $self->next_line) or
          $self->error("File ended prematurely on DFA003");

        if( $line =~ /$dfa4/){
          my %tmp;
          $tmp{client_reference_num}   = trim $1;
          $tmp{merchant_desc_code}     = trim $2;
          $tmp{trust_custodian_id_num} = trim $3;
          $tmp{third_party_id_num}     = trim $4;
          $tmp{txn_advanced_comm_at} = trim $5;
          $tmp{nscc_branch_id_num}     = trim $6;
          $tmp{nav_reason_code}        = trim $7;
          $tmp{client_defined_text}    = trim $8;
          $tmp{alpha_code}             = trim $9;
          map{ $pos->{$_} = $tmp{$_} } grep{ length $tmp{$_} } keys %tmp;
        defined($line = $self->next_line) or
          $self->error("File ended prematurely on DFA004");
        }
      }
    } else {
      $self->error("Got '$line' where DFA002 record was expected.");
    }
    $self->record_callback->($self, $pos) if $self->has_record_callback;
  }
  if ( $self->_process_footer($line) ) {
    return \@records;
  } else {
    $self->error("Got '$line' where DFA001/RTR001 record was expected");
  }
  $self->error("Recieved no trailer record. File possibly truncated");
}

1;

__END__;

=head1 NAME

  Finance::DST::FAN::Mail::File::DFA - Read DST FANMail DFA records into data structures

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
