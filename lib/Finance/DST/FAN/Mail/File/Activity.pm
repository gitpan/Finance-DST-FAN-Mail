package Finance::DST::FAN::Mail::File::Activity;

our $VERSION = '0.001000';

use Moose;
use Finance::DST::FAN::Mail::Utils qw/trim parse_date/;

extends 'Finance::DST::FAN::Mail::File';

override is_refresh => sub { 0 };
override is_delta => sub { 1 };

our $plh1 = qr/^PLH001(.{8})(.{8})(.{7})(.{20})(..)(.{12})(.{12})(.{12})(.{31})(.)(.{30})(.)(..)/;
our $plh2 = qr/^PLH002(.)(.)(.{15})(.{15})(.{15})(.{15})(.{15})(.{15})(.)/;
our $act1 = qr/^(?:NAA|AMP|NFA)001(.{7})(.{9})(.{9})(.{7})(.{20})(?:[F ])(.{8})(.{8})(.)(.{10})(.)(.{3})(.{3})(.{9})(.)(.)(.)(.)(.)(.)(.)(.)(.)(.)(.{3})(.{9})(..)(.{9})(.{9})(.)(.)(.)(.)(.)(.)(.)(.)(.)(.)(.)(.)(.)(.)(.)(.)/;
our $act2 = qr/^(?:NAA|AMP|NFA)002(.)(.)(.)(.)(.{35})(.{35})(.{35})(.{35})(.{8})(.)(.)/;
our $act3 = qr/^(?:NAA|AMP|NFA)003(.{35})(.{35})(.{35})(.{9})(.{30})/;
our $act4 = qr/^(?:NAA|AMP|NFA)004(.{20})(.)(.{15})(.{15})(.{4})(.{4})(.{23})(.{7})(.{7})/;

#review act 1 because of the static F mark. egh!

has anniversary_date => (is => 'rw', isa => 'DateTime');
has issue_date => (is => 'rw', isa => 'DateTime');
has product_code => (is => 'rw', isa => 'Str');
has contract_num => (is => 'rw', isa => 'Str');
has death_benefit_option => (is => 'rw', isa => 'Str');
has current_face_amt => (is => 'rw', isa => 'Num');
has current_sum_of_riders => (is => 'rw', isa => 'Num');
has current_combined_amt => (is => 'rw', isa => 'Num');
has primary_beneficiary => (is => 'rw', isa => 'Str');
has multiple_primary_beneficiary_i => => (is => 'rw', isa => 'Bool');
has policy_status => (is => 'rw', isa => 'Str');

has billing_type => (is => 'rw', isa => 'Str');
has billing_freqency => (is => 'rw', isa => 'Str');
has billing_amount => (is => 'rw', isa => 'Str');
has gl_annual_premium => (is => 'rw', isa => 'Num');
has gl_single_premium => (is => 'rw', isa => 'Num');
has target_premium => (is => 'rw', isa => 'Num');
has no_lapse_guarantee_premium => (is => 'rw', isa => 'Num');
has seven_pay_premium => (is => 'rw', isa => 'Num');
has mec_i => (is => 'rw', isa => 'Bool');

after _process_header => sub {
  my $self = shift;
  return unless $self->is_vul;

  defined(my $line = $self->next_line) or
    $self->error("File ended prematurely on RHR001");
  if ($line =~ /$plh1/ ){
    if(my $date = parse_date($1)){
      $self->anniversary_date($date);
    }
    if(my $date = parse_date($0)){
      $self->issue_date($date);
    }
    $self->product_code(trim $3);
    $self->contract_num(trim $4);
    $self->death_benefit_option($5);
    $self->current_face_amt($6 / 100);
    $self->current_sum_of_riders($7 / 100);
    $self->current_combined_amt($8 / 100);
    $self->primary_beneficiary(trim $9);
    $self->multiple_primary_beneficiary_i($10 eq 'M' ? 1 : 0);
    $self->policy_status($11);
    if ($line =~ /$plh2/ ){
      $self->billing_type($1);
      $self->billing_freqency($2);
      $self->billing_amount(trim $3);
      $self->gl_annual_premium($4 / 100);
      $self->gl_single_premium($5 / 100);
      $self->target_premium($6 / 100);
      $self->no_lapse_guarantee_premium($7 / 100);
      $self->seven_pay_premiu( $8 / 100);
      $self->mec_i( $9 eq 'Y' ? 1 : 0);
    } else {
      $self->error("Expected PPH002 record but got '${line}'");
    }
  } else {
    $self->error("Expected PPH001 record but got '${line}'");
  }
};


sub _process_vul {
  my $self = shift;
  my @records;
  defined(my $line = $self->next_line) or
    $self->error("File ended prematurely on PLH002");

  while ( $line =~ /$act1/ ) {
    my $pos = {
               dealer_num => trim $1,
               branch_num => $2,
               cusip => $3,
               product_code => trim $4,
               policy_num =>trim $5,
               line_code    => $8,
               resident_loc_code => trim $12,
               ssn               => trim $13,
               ssn_status_code   => $14,
               multiple_owner_i  => $18 eq 'M' ? 1 : 0,
               zip_code          => trim $25,
               closed_account_i  => $39,
              };
    push(@records, $pos);

    if (my $tmp = parse_date($6) ){
      $pos->{issue_date} = $tmp;
    }
    if (my $tmp = parse_date($7) ){
      $pos->{last_maintenance_date} = $tmp;
    }
    if (length(my $tmp = trim $9  ) ){ $pos->{alpha_code}  = $tmp; }
    if (length(my $tmp = trim $11 ) ){ $pos->{social_code} = $tmp; }
    if (length(my $tmp = trim $15 ) ){ $pos->{swp_i}       = $tmp; }
    if (length(my $tmp = trim $16 ) ){ $pos->{pre_auth_checking_i} = $tmp; }
    if (length(my $tmp = trim $17 ) ){ $pos->{ach_i}       = $tmp; }
    if (length(my $tmp = trim $21 ) ){ $pos->{check_writting_i} = $tmp; }
    if (length(my $tmp = trim $22 ) ){ $pos->{expedited_redemption_i} = $tmp; }
    if (length(my $tmp = trim $24 ) ){ $pos->{foreign_tax_rate} = $tmp / 1000; }
    if (length(my $tmp = trim $27 ) ){ $pos->{cum_discount_num} = $tmp; }
    if (length(my $tmp = trim $28 ) ){ $pos->{loi_num}     = $tmp; }
    if (length(my $tmp = trim $29 ) ){ $pos->{timer_i}     = $tmp; }
    if (length(my $tmp = trim $30 ) ){ $pos->{listbill_i}  = $tmp; }
    if (length(my $tmp = trim $34 ) ){ $pos->{cert_issued_code} = $tmp; }
    if (length(my $tmp = trim $38 ) ){ $pos->{fiduciary_i}  = $tmp; }
    if (length(my $tmp = trim $41 ) ){ $pos->{mailing_i}  = $tmp; }
    if (length(my $tmp = trim $42 ) ){ $pos->{interested_party_i} = $tmp eq 'Y' ? 1 : 0; }

    defined($line = $self->next_line) or
      $self->error("File ended prematurely on NAA/AMP/NFA001");

    if ($line =~ /$act2/ ) {
      $pos->{registration_line1} = trim $5;
      $pos->{registration_line2} = trim $6;
      $pos->{registration_line3} = trim $7;
      $pos->{registration_line4} = trim $8;
      #9 - UNUSED
      defined($line = $self->next_line) or
        $self->error("File ended prematurely on NAA/AMP/NFA002");

      if ($line =~ /$act3/ ) {
        $pos->{registration_line5}     = trim $1;
        $pos->{primary_insured_name}   = trim $2;
        $pos->{secondary_insured_name} = trim $3;
        $pos->{rep_num}  = trim $4;
        $pos->{rep_name} = trim $5;
        defined($line = $self->next_line) or
          $self->error("File ended prematurely on NAA/AMP/NFA003");

        if ($line =~ /$act4/ ) {
          #7 UNUSED
          my %tmp;
          $tmp{cust_account_num}         = trim $1;
          $tmp{account_num_code}         = trim $2;
          $tmp{primary_investor_phone}   = trim $3;
          $tmp{secondary_investor_phone} = trim $4;
          $tmp{nscc_trust_co_num}        = trim $5;
          $tmp{nscc_third_party_num}     = trim $6;
          $tmp{custodian_id_num}         = trim $8;
          $tmp{third_party_id_num}       = trim $9;
          map{ $pos->{$_} = $tmp{$_} } grep{ length $tmp{$_} } keys %tmp;
          defined($line = $self->next_line) or
            $self->error("File ended prematurely on NAA/AMP/NFA004");
        }
      } else {
        $self->error("Got '$line' where NAA/AMP/NFA003 record was expected"); 
      }
    } else {
      $self->error("Got '$line' where NAA/AMP/NFA002 record was expected");
    }
    $self->record_callback->($self, $pos) if $self->has_record_callback;
  }

  if ( $self->_process_footer($line) ) {
    return \@records;
  } else {
    $self->error("Got '$line' where NAA/AMP/NFA001 record was expected");
  }

  $self->error("Recieved no Trail record. File possibly truncated");
}

sub _process_va {
  my $self = shift;
  my @records;
  defined(my $line = $self->next_line) or
    $self->error("File ended prematurely on RHR001");

  while ($line =~ /$act1/ ) {
    my $pos = {
               dealer_num   => trim $1,
               branch_num   => $2,
               cusip        => $3,
               product_code => trim $4,
               policy_num   => trim $5,
               line_code         => $8,
               resident_loc_code => trim $12,
               ssn               => trim $13,
               ssn_status_code   => $14,
               zip_code          => trim $25,
               closed_account_i  => $39,
              };
    push(@records, $pos);

    if (my $tmp = parse_date($6) ){
      $pos->{established_date} = $tmp;
    }
    if (my $tmp = parse_date($7) ){
      $pos->{last_maintenance_date} = $tmp;
    }
    if (length(my $tmp = trim $9  ) ){ $pos->{alpha_code}  = $tmp; }
    if (length(my $tmp = trim $11 ) ){ $pos->{social_code} = $tmp; }
    if (length(my $tmp = trim $15 ) ){ $pos->{swp_i}       = $tmp; }
    if (length(my $tmp = trim $16 ) ){ $pos->{pre_auth_checking_i} = $tmp; }
    if (length(my $tmp = trim $17 ) ){ $pos->{ach_i}       = $tmp; }
    if (length(my $tmp = trim $21 ) ){ $pos->{check_writting_i} = $tmp; }
    if (length(my $tmp = trim $22 ) ){ $pos->{expedited_redemption_i} = $tmp; }
    if (length(my $tmp = trim $24 ) ){ $pos->{foreign_tax_rate} = $tmp / 1000; }
    if (length(my $tmp = trim $27 ) ){ $pos->{cum_discount_num} = $tmp; }
    if (length(my $tmp = trim $28 ) ){ $pos->{loi_num}     = $tmp; }
    if (length(my $tmp = trim $29 ) ){ $pos->{timer_i}     = $tmp; }
    if (length(my $tmp = trim $30 ) ){ $pos->{listbill_i}  = $tmp; }
    if (length(my $tmp = trim $34 ) ){ $pos->{cert_issued_code} = $tmp; }
    if (length(my $tmp = trim $38 ) ){ $pos->{fiduciary_i}  = $tmp; }
    if (length(my $tmp = trim $41 ) ){ $pos->{mailing_i}  = $tmp; }
    if (length(my $tmp = trim $42 ) ){ $pos->{interested_party_i} = $tmp eq 'Y' ? 1 : 0; }
    defined($line = $self->next_line) or
      $self->error("File ended prematurely on NAA/AMP/NFA001");

    if ($line =~ /$act2/ ) {
      $pos->{registration_line1} = trim $5;
      $pos->{registration_line2} = trim $6;
      $pos->{registration_line3} = trim $7;
      $pos->{registration_line4} = trim $8;
      defined($line = $self->next_line) or
        $self->error("File ended prematurely on NAA/AMP/NFA002");

      if ($line =~ /$act3/ ) {
        $pos->{registration_line5} = trim $1;
        $pos->{registration_line6} = trim $2;
        $pos->{registration_line7} = trim $3;
        $pos->{rep_num}  = trim $4;
        $pos->{rep_name} = trim $5;
        defined($line = $self->next_line) or
          $self->error("File ended prematurely on NAA/AMP/NFA003");

        if ($line =~ /$act4/ ) {
          #7 UNUSED
          my %tmp;
          $tmp{cust_account_num}         = trim $1;
          $tmp{account_num_code}         = trim $2;
          $tmp{primary_investor_phone}   = trim $3;
          $tmp{secondary_investor_phone} = trim $4;
          $tmp{nscc_trust_co_num}        = trim $5;
          $tmp{nscc_third_party_num}     = trim $6;
          $tmp{custodian_id_num}         = trim $8;
          $tmp{third_party_id_num}       = trim $9;
          map{ $pos->{$_} = $tmp{$_} } grep{ length $tmp{$_} } keys %tmp;
          defined($line = $self->next_line) or
            $self->error("File ended prematurely on NAA/AMP/NFA004");
        }
      } else {
        $self->error("Got '$line' where NAA/AMP/NFA003 record was expected");
      }
    } else {
      $self->error("Got '$line' where NAA/AMP/NFA002 record was expected");
    }
    $self->record_callback->($self, $pos) if $self->has_record_callback;
  }
  if ( $self->_process_footer($line) ) {
    return \@records;
  } else {
    $self->error("Got '$line' where NAA/AMP/NFA001/RTR001 record was expected"); 
  }
  $self->error("Recieved no Trail record. File possibly truncated");
}

sub _process_reit {
  my $self = shift;
  my @records;
  defined(my $line = $self->next_line) or
    $self->error("File ended prematurely on RHR001");

  while ($line =~ /$act1/ ) {
    my $pos = {
               dealer_num   => trim $1,
               branch_num   => $2,
               cusip        => $3,
               fund_code    => trim $4,
               account_num  => trim $5,
               account_num_code => 'F', #XXX todo: translate to rest of records / files
               line_code         => $8,
               resident_loc_code => trim $12,
               ssn               => trim $13,
               ssn_status_code   => $14,
               zip_code          => trim $25,
               plan_status_code => $39,
              };
    push(@records, $pos);

    if (my $tmp = parse_date($6) ){
      $pos->{established_date} = $tmp;
    }
    if (my $tmp = parse_date($7) ){
      $pos->{last_maintenance_date} = $tmp;
    }
    if (length(my $tmp = trim $9  ) ){ $pos->{alpha_code}  = $tmp; }
    if (length(my $tmp = trim $10 ) ){ $pos->{dealer_level_control_code}  = $tmp; }
    if (length(my $tmp = trim $11 ) ){ $pos->{social_code} = $tmp; }
    if (length(my $tmp = trim $15 ) ){ $pos->{swp_i}       = $tmp; }
    if (length(my $tmp = trim $16 ) ){ $pos->{pre_auth_checking_i} = $tmp; }
    if (length(my $tmp = trim $17 ) ){ $pos->{ach_i}       = $tmp; }
    if (length(my $tmp = trim $18 ) ){ $pos->{reinv_to_other_account_i} = $tmp; }
    if (length(my $tmp = trim $19 ) ){ $pos->{capital_gains_dist} = $tmp; }
    if (length(my $tmp = trim $20 ) ){ $pos->{dividend_dist} = $tmp; }
    if (length(my $tmp = trim $21 ) ){ $pos->{check_writting_i} = $tmp; }
    if (length(my $tmp = trim $22 ) ){ $pos->{expedited_redemption_i} = $tmp; }
    if (length(my $tmp = trim $23 ) ){ $pos->{sub_account_i} = $tmp; }
    if (length(my $tmp = trim $24 ) ){ $pos->{foreign_tax_rate} = $tmp / 1000; }
    if (length(my $tmp = trim $27 ) ){ $pos->{cum_discount_num} = $tmp; }
    if (length(my $tmp = trim $28 ) ){ $pos->{loi_num}     = $tmp; }
    if (length(my $tmp = trim $29 ) ){ $pos->{timer_i}     = $tmp; }
    if (length(my $tmp = trim $30 ) ){ $pos->{listbill_i}  = $tmp; }
    if (length(my $tmp = trim $31 ) ){ $pos->{monitored_vip_i} = $tmp; }
    if (length(my $tmp = trim $32 ) ){ $pos->{expedited_exchange_i} = $tmp; }
    if (length(my $tmp = trim $33 ) ){ $pos->{penalty_withholding_i} = $tmp; }
    if (length(my $tmp = trim $34 ) ){ $pos->{cert_issued_code} = $tmp; }
    if (length(my $tmp = trim $35 ) ){ $pos->{stop_transfer_i} = $tmp; }
    if (length(my $tmp = trim $36 ) ){ $pos->{blue_sky_exemption_i} = $tmp; }
    if (length(my $tmp = trim $37 ) ){ $pos->{bank_card_issued_i} = $tmp; }
    if (length(my $tmp = trim $38 ) ){ $pos->{fiduciary_i}  = $tmp; }
    if (length(my $tmp = trim $40 ) ){ $pos->{nav_account_i} = $tmp; }
    if (length(my $tmp = trim $41 ) ){ $pos->{mailing_i}  = $tmp; }
    if (length(my $tmp = trim $42 ) ){ $pos->{interested_party_i} = $tmp eq 'Y' ? 1 : 0; }
    if (length(my $tmp = trim $43 ) ){ $pos->{phone_check_redemption_i} = $tmp eq 'Y' ? 1 : 0; }
    if (length(my $tmp = trim $44 ) ){ $pos->{house_account_i} = $tmp eq 'Y' ? 1 : 0; }
    defined($line = $self->next_line) or
      $self->error("File ended prematurely on NAA/AMP/NFA001");

    if ($line =~ /$act2/ ) {
      $pos->{registration_line1} = trim $5;
      $pos->{registration_line2} = trim $6;
      $pos->{registration_line3} = trim $7;
      $pos->{registration_line4} = trim $8;

      if (length(my $tmp = trim $1  ) ){ $pos->{dividend_mail_account_i} = $tmp; }
      if (length(my $tmp = trim $2  ) ){ $pos->{stop_purchase_account_i} = $tmp; }
      if (length(my $tmp = trim $3  ) ){ $pos->{stop_mail_account_i} = $tmp; }
      if (length(my $tmp = trim $4  ) ){ $pos->{fractional_check_i}  = $tmp; }
      if (length(my $tmp = trim $10 ) ){ $pos->{reduced_pricing_i}   = $tmp eq '1' ? 1 : 0; }
      if (length(my $tmp = trim $11 ) ){ $pos->{employee_i} = $tmp eq '1' ? 1 : 0; }
      defined($line = $self->next_line) or
        $self->error("File ended prematurely on NAA/AMP/NFA002");

      if ($line =~ /$act3/ ) {
        $pos->{registration_line5} = trim $1;
        $pos->{registration_line6} = trim $2;
        $pos->{registration_line7} = trim $3;
        $pos->{rep_num}  = trim $4;
        $pos->{rep_name} = trim $5;
        defined($line = $self->next_line) or
          $self->error("File ended prematurely on NAA/AMP/NFA003");

        if ($line =~ /$act4/ ) {
          #7 UNUSED
          my %tmp;
          $tmp{cust_account_num}         = trim $1;
          $tmp{account_num_code}         = trim $2;
          $tmp{primary_investor_phone}   = trim $3;
          $tmp{secondary_investor_phone} = trim $4;
          $tmp{nscc_trust_co_num}        = trim $5;
          $tmp{nscc_third_party_num}     = trim $6;
          $tmp{custodian_id_num}         = trim $8;
          $tmp{third_party_id_num}       = trim $9;
          map{ $pos->{$_} = $tmp{$_} } grep{ length $tmp{$_} } keys %tmp;
          defined($line = $self->next_line) or
            $self->error("File ended prematurely on NAA/AMP/NFA004");
        }
      } else {
        $self->error("Got '$line' where NAA/AMP/NFA003 record was expected");
      }
    } else {
      $self->error("Got '$line' where NAA/AMP/NFA002 record was expected");
    }
    $self->record_callback->($self, $pos) if $self->has_record_callback;
  }
  if ( $self->_process_footer($line) ) {
    return \@records;
  } else {
    $self->error("Got '$line' where NAA/AMP/NFA001/RTR001 record was expected");
  }
  $self->error("Recieved no Trail record. File possibly truncated");
}

sub _process_mf {
  my $self = shift;
  my @records;
  defined(my $line = $self->next_line) or
    $self->error("File ended prematurely on RHR001");

  while ($line =~ /$act1/ ) {
    my $pos = {
               dealer_num   => trim $1,
               branch_num   => $2,
               cusip        => $3,
               fund_code    => trim $4,
               account_num  => trim $5,
               line_code    => $8,
               dealer_level_control_code => $10,
               resident_loc_code => trim $12,
               ssn               => trim $13,
               ssn_status_code   => $14,
               zip_code          => trim $25,
               closed_account_i  => $39,
              };
    push(@records, $pos);

    if (my $tmp = parse_date($6) ){
      $pos->{established_date} = $tmp;
    }
    if (my $tmp = parse_date($7) ){
      $pos->{last_maintenance_date} = $tmp;
    }
    if (length(my $tmp = trim $9  ) ){ $pos->{alpha_code}  = $tmp; }
    if (length(my $tmp = trim $11 ) ){ $pos->{social_code} = $tmp; }
    if (length(my $tmp = trim $15 ) ){ $pos->{swp_i}       = $tmp; }
    if (length(my $tmp = trim $16 ) ){ $pos->{pre_auth_checking_i} = $tmp; }
    if (length(my $tmp = trim $17 ) ){ $pos->{ach_i}       = $tmp; }
    if (length(my $tmp = trim $18 ) ){ $pos->{reinv_to_other_account_i} = $tmp; }
    if (length(my $tmp = trim $19 ) ){ $pos->{capital_gains_dist} = $tmp; }
    if (length(my $tmp = trim $20 ) ){ $pos->{dividend_dist} = $tmp; }
    if (length(my $tmp = trim $21 ) ){ $pos->{check_writting_i} = $tmp; }
    if (length(my $tmp = trim $22 ) ){ $pos->{expedited_redemption_i} = $tmp; }
    if (length(my $tmp = trim $23 ) ){ $pos->{sub_account_i} = $tmp; }
    if (length(my $tmp = trim $24 ) ){ $pos->{foreign_tax_rate} = $tmp / 1000; }
    if (length(my $tmp = trim $27 ) ){ $pos->{cum_discount_num} = $tmp; }
    if (length(my $tmp = trim $28 ) ){ $pos->{loi_num}     = $tmp; }
    if (length(my $tmp = trim $29 ) ){ $pos->{timer_i}     = $tmp; }
    if (length(my $tmp = trim $30 ) ){ $pos->{listbill_i}  = $tmp; }
    if (length(my $tmp = trim $31 ) ){ $pos->{monitored_vip_i} = $tmp; }
    if (length(my $tmp = trim $32 ) ){ $pos->{expedited_exchange_i} = $tmp; }
    if (length(my $tmp = trim $33 ) ){ $pos->{penalty_withholding_i} = $tmp; }
    if (length(my $tmp = trim $34 ) ){ $pos->{cert_issued_code} = $tmp; }
    if (length(my $tmp = trim $35 ) ){ $pos->{stop_transfer_i} = $tmp; }
    if (length(my $tmp = trim $36 ) ){ $pos->{blue_sky_exemption_i} = $tmp; }
    if (length(my $tmp = trim $37 ) ){ $pos->{bank_card_issued_i} = $tmp; }
    if (length(my $tmp = trim $38 ) ){ $pos->{fiduciary_i}  = $tmp; }
    if (length(my $tmp = trim $40 ) ){ $pos->{nav_account_i} = $tmp; }
    if (length(my $tmp = trim $41 ) ){ $pos->{mailing_i}  = $tmp; }
    if (length(my $tmp = trim $42 ) ){ $pos->{interested_party_i} = $tmp eq 'Y' ? 1 : 0; }
    if (length(my $tmp = trim $43 ) ){ $pos->{phone_check_redemption_i} = $tmp eq 'Y' ? 1 : 0; }
    if (length(my $tmp = trim $44 ) ){ $pos->{house_account_i} = $tmp eq 'Y' ? 1 : 0; }
    defined($line = $self->next_line) or
      $self->error("File ended prematurely on NAA/AMP/NFA001");

    if ($line =~ /$act2/ ) {
      $pos->{registration_line1} = trim $5;
      $pos->{registration_line2} = trim $6;
      $pos->{registration_line3} = trim $7;
      $pos->{registration_line4} = trim $8;
      #9 - UNUSED

      if (length(my $tmp = trim $1  ) ){ $pos->{dividend_mail_account_i} = $tmp; }
      if (length(my $tmp = trim $2  ) ){ $pos->{stop_purchase_account_i} = $tmp; }
      if (length(my $tmp = trim $3  ) ){ $pos->{stop_mail_account_i} = $tmp; }
      if (length(my $tmp = trim $4  ) ){ $pos->{fractional_check_i}  = $tmp; }
      if (length(my $tmp = trim $10 ) ){ $pos->{reduced_pricing_i}   = $tmp eq '1' ? 1 : 0; }
      if (length(my $tmp = trim $11 ) ){ $pos->{employee_i} = $tmp eq '1' ? 1 : 0; }
      defined($line = $self->next_line) or
        $self->error("File ended prematurely on NAA/AMP/NFA002");

      if ($line =~ /$act3/ ) {
        $pos->{registration_line5} = trim $1;
        $pos->{registration_line6} = trim $2;
        $pos->{registration_line7} = trim $3;
        $pos->{rep_num}  = trim $4;
        $pos->{rep_name} = trim $5;
        defined($line = $self->next_line) or
          $self->error("File ended prematurely on NAA/AMP/NFA003");

        if ($line =~ /$act4/ ) {
          #7 UNUSED
          my %tmp;
          $tmp{cust_account_num}         = trim $1;
          $tmp{account_num_code}         = trim $2;
          $tmp{primary_investor_phone}   = trim $3;
          $tmp{secondary_investor_phone} = trim $4;
          $tmp{nscc_trust_co_num}        = trim $5;
          $tmp{nscc_third_party_num}     = trim $6;
          $tmp{custodian_id_num}         = trim $8;
          $tmp{third_party_id_num}       = trim $9;
          map{ $pos->{$_} = $tmp{$_} } grep{ length $tmp{$_} } keys %tmp;
          defined($line = $self->next_line) or
            $self->error("File ended prematurely on NAA/AMP/NFA004");
        }
      } else {
        $self->error("Got '$line' where NAA/AMP/NFA003 record was expected");
      }
    } else {
      $self->error("Got '$line' where NAA/AMP/NFA002 record was expected");
    }
    $self->record_callback->($self, $pos) if $self->has_record_callback;
  }
  if ( $self->_process_footer($line) ) {
    return \@records;
  } else {
    $self->error("Got '$line' where NAA/AMP/NFA001/RTR001 record was expected");
  }
  $self->error("Recieved no Trail record. File possibly truncated");
}

1;

__END__;

=head1 NAME

Finance::DST::FAN::Mail::File::Activity - Read DST FANMail Activity records into data structures

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

