package Finance::DST::FAN::Mail::Utils;

use strict;
use warnings;
use IO::File;
use Class::MOP;
use DateTime;
use Carp ();

use Sub::Exporter -setup =>
  { exports => [ qw(
                     trim
                     parse_date
                     read_file
                     file_info_from_remote_filename
                     file_info_from_header
                     get_file_info
                  )
               ],
  };

our $VERSION = '0.005000';

our %type_code_to_name =
(
 '09' => 'ACCT MASTER POS',
 '03' => 'ACCT POSITION',
 '01' => 'DISTRIBUTION',
 '02' => 'FINANCIALDIRECT',
 'SF' => 'SECURITY FILE',
 '08' => 'NEWACCT ACTIVIT',
 '07' => 'NONFINANCIALACT',
 '17' => 'PRICE REFRESHER',
);

our %class_code_to_name =
  (
   AMP => 'ACCT MASTER POS',
   APR => 'ACCT POSITION',
   DA  => 'DISTRIBUTION',
   DFA => 'FINANCIALDIRECT',
   SF  => 'SECURITY FILE',
   NAA => 'NEWACCT ACTIVIT',
   NFA => 'NONFINANCIALACT',
   FPR => 'PRICE REFRESHER',
  );

our %class_code_to_description =
  (
   AMP => 'Account Master Position',
   APR => 'Account Position',
   DA  => 'Distribution Activity',
   DFA => 'Direct Financial Activity',
   SF  => 'Security File',
   NAA => 'New Account Activity',
   NFA => 'Non-Financial Activity',
   FPR => 'Price Refresher',
  );


our %type_name_to_class = ( map { $class_code_to_name{$_} => $_ }
                           keys %class_code_to_name );


our %mgmt_sys_codes =
  (
   'UMTHS' => 'UNITED DEVELOPMENT FUNDING',
   'SGDGT' => 'NATIONWIDE FUNDS',
   'DFECG' => 'COLUMBIA 529 PLAN',
   'ASLST' => 'ALLSTATE/PRUDENTIAL',
   'DTCCR' => 'AMERICAN FUNDS',
   'DTNAT' => 'ALLIANCEBERNSTEIN INVESTMENTS',
   'AEGON' => 'TRANSAMERICA LIFE INSURANCE',
   'DTJWM' => 'PRINCIPAL FUNDS',
   'DFEVE' => 'DAVIS FUNDS',
   'WRLAE' => 'WESTERN RESERVE LIFE',
   'NASHH' => 'JOHN HANCOCK LIFE INS CO (USA)',
   'DTJQA' => 'ROYCE FUNDS, THE',
   'DTJEN' => 'ENTERPRISE/AXA ENTERPRISE FUND',
   'POONT' => 'PROVIDENT MUTUAL',
   'DBFPH' => 'PHOENIX EQUITY PLANNING CORP',
   'ACCES' => 'ACCESSOR FUNDS',
   'SGDVT' => 'VICTORY FUNDS',
   'SCUDS' => 'KEMPER INVESTORS-SCUDDER',
   'FLXFX' => 'FLEX FUNDS',
   'APITR' => 'API FUNDS',
   'DSTPX' => 'OLD MUTUAL FUNDS',
   'DBFNU' => 'NEUBERGER BERMAN',
   'USBTC' => 'EMPIRIC FUNDS INC',
   'DFYWE' => 'WELLS FARGO FUNDS',
   'EVERB' => 'EVERBANK',
   'TIMPL' => 'THE TIMOTHY PLAN',
   'DFRAI' => 'AMERICAN BEACON FUNDS',
   'USBTG' => 'TCW FUNDS',
   'DTPIO' => 'COLLEGE CHOICE 529 INVEST PLAN',
   'OPPHE' => 'OPPENHEIMERFUNDS',
   'USBAL' => 'ALPINE FUNDS',
   'DSTVE' => 'VAN ECK',
   'LEGCO' => 'SCHOLARS CHOICE 529 PLAN',
   'DFIML' => 'JOHN HANCOCK FREEDOM 529',
   'DFZVT' => 'TIAA-CREF 529 PLAN - VERMONT',
   'DBFMC' => 'MAINSTAY',
   'DTJCG' => 'CALVERT FUNDS',
   'DTPSO' => 'FIRST EAGLE FUNDS',
   'PMFPI' => 'PUTNAM INVESTMENTS',
   'PCFPI' => 'PACIFIC LIFE',
   'HRBOR' => 'HARBOR FUNDS',
   'DFESL' => 'SELECTED FUNDS',
   'CTCUS' => 'GENWORTH FINANCIAL ASSET MGMT',
   'JNLIL' => 'JACKSON NATIONAL LIFE 1',
   'DFZKA' => 'TIAA-CREF 529 PLAN - KENTUCKY',
   'GLICV' => 'GUARDIAN LIFE INS. COMPANY',
   'DTJGI' => 'RS INVESTMENTS',
   'DFESN' => 'HIGHMARK FUNDS',
   'SFECO' => 'SYMETRA FINANCIAL',
   'NEWYL' => 'NEW YORK LIFE-MAINSTAY ANNUIT',
   'DFRGI' => 'GOLDMAN SACHS INSTITUTIONAL',
   'AGAPA' => 'AIG LIFE INSURANCE',
   'USBKN' => 'KENSINGTON MUTUAL FUNDS',
   'USBCA' => 'CALAMOS FUNDS',
   'DFEUM' => 'MOST MISSOURI 529 ADVISOR PL',
   'DFYAF' => 'AMERICAN INDEPENDENCE FUNDS',
   'MMSMT' => 'MASS MUTUAL VARIABLE ANNUITY',
   'ALLNZ' => 'ALLIANZ',
   'DFSCM' => 'FEDERATED SERVICES CORP',
   'SEZSC' => 'SE2 COMMONWEALTH',
   'EMRLD' => 'EMERALD FUNDS',
   'AULAM' => 'AMERICAN UNITED LIFE INSURANCE',
   'HARTT' => 'HARTFORD LIFE',
   'WRERE' => 'WELLS LIMITED PARTNERSHIP',
   'REDWD' => 'REDWOOD MORTGAGE INVESTORS',
   'DFZHE' => 'TIAA-CREF 529 PLAN-CONNECTICUT',
   'DFEFS' => 'COLUMBIA FUTURE SCHOLAR 529',
   'DCMLC' => 'DUNBAR CAPITALMGMT LLC',
   'DFZMJ' => 'TIAA-CREF 529 PLAN-MISSISSIPPI',
   'DFHFA' => 'HARTFORD MUTUAL FUNDS',
   'TRPLE' => 'GRUBB & ELLIS REALTY INV  LLC',
   'DFHJB' => 'TAMARACK MUTUAL FUNDS',
   'STEAL' => 'PUTNAM ALLSTATE ADVISOR',
   'CPATR' => 'DIVIDEND CAPITAL TRUST',
   'USBPO' => 'DIREXION FUNDS',
   'DFHLU' => 'THRIVENT FINANCIAL',
   'DTOSB' => 'SECURITY FUNDS',
   'INTGR' => 'INTEGRITY COMPANIES',
   'DBFFA' => 'FIDELITY ADVISOR OFFSHORE FUND',
   'DTJVL' => 'VALUE LINE',
   'WRENY' => 'WELLS REIT',
   'NAWQR' => 'NATIONWIDE',
   'EVGEV' => 'EVERGREEN FUNDS',
   'DTJTH' => 'THORNBURG',
   'LNANN' => 'LINCOLN FINANCIAL GROUP',
   'DFZLF' => 'LAZARD FUNDS',
   'JSCAP' => 'JANUS ASPEN FUNDS',
   'ALNBE' => 'LINCOLN BENEFIT LIFE (FIXED)',
   'DFYMK' => 'MEMBERS MUTUAL FUNDS',
   'DTGSS' => 'DWS SCUDDER',
   'MMAPS' => 'MMA PRAXIS',
   'WRLVA' => 'WESTERN RESERVE LIFE (VA2)',
   'AIGPA' => 'AIG SUNAMERICA (OVATION)',
   'TRAVL' => 'METLIFE OF CONNECTICUT',
   'SEIGG' => 'SEI',
   'JHKJH' => 'JOHN HANCOCK FUNDS',
   'AMERI' => 'AMERITAS VARIABLE ANNUITY',
   'KBSRT' => 'KBS REAL ESTATE TRUST',
   'JSCJM' => 'JANUS RETAIL FUNDS',
   'SGDHE' => 'HERITAGE FUNDS',
   'DBFLS' => 'NATIXIS FUNDS',
   'SEZST' => 'ALLSTATE LEGACY VA',
   'PROFN' => 'PROFUNDS',
   'USBOL' => 'OLSTEIN FUNDS',
   'DFYNV' => 'NUVEEN MUTUAL FUNDS',
   'DFZTI' => 'TIAA-CREF',
   'DTOSF' => 'SENTINEL FUNDS',
   'DTPCM' => 'JP MORGAN FUNDS',
   'DTKAG' => 'VAN KAMPEN FUNDS',
   'GALGA' => 'ING VARIABLE ANNUITIES',
   'DUNAS' => 'DUNHAM & ASSOCIATES',
   'DFIRP' => 'T. ROWE PRICE',
   'EATON' => 'EATON VANCE',
   'DSTEA' => 'ING FUNDS',
   'LBNVU' => 'LINCOLN BENEFIT LIFE (VUL)',
   'WPCAR' => 'WP CAREY',
   'PLONY' => 'ALLIANZ LIFE OF NEW YORK',
   'AEXVA' => 'RIVERSOURCE VA',
   'DFYAL' => 'ALGER FUNDS',
   'JSCCS' => 'JANUS ADVISER CLASS A & C',
   'MDLVA' => 'MIDLAND NATIONAL LIFE VA',
   'MIDMW' => 'TOUCHSTONE FUNDS',
   'JSCAV' => 'JANUS ADVISER CLASS R & S',
   'USBQK' => 'QUAKER FUNDS',
   'EQUIT' => 'AXA EQUITABLE',
   'DFRGO' => 'GOLDMAN SACHS RETAIL FUNDS',
   'ACMLQ' => 'AMERICAN CENTURY KANSAS 529 PL',
   'SBLMM' => 'SECURITY BENEFIT LIFE',
   'DFRFT' => 'FIFTH THIRD FUNDS',
   'USBMS' => 'MADISON MOSAIC FUNDS',
   'MONGR' => 'MONY GROUP',
   'DFZGH' => 'TIAA-CREF 529 PLAN - GEORGIA',
   'MASIC' => 'MFS INSTITUTIONAL FUNDS',
   'FIDFA' => 'FIDELITY ADVISOR FUNDS',
   'INLND' => 'INLAND REIT',
   'DFZEM' => 'TIAA-CREF 529 PLAN - MICHIGAN',
   'DLWDG' => 'DELAWARE INVESTMENTS - DST',
   'STBEN' => 'STEBEN & COMPANY, INC.',
   'ETATS' => 'ALLSTATE VARIABLE ANNUITY',
   'DFRWP' => 'CREDIT SUISSE FUNDS',
   'FTGFF' => 'FRANKLIN/TEMPLETON FUNDS',
   'CONCO' => 'JEFFERSON NATIONAL LIFE INS.',
   'MASFM' => 'MFS',
   'MJRDY' => 'DREYFUS',
   'TRIPA' => 'GRUBB & ELLIS PUBLIC PROGRAMS',
   'PRTLE' => 'PROTECTIVE LIFE',
   'PIMPM' => 'PIONEER INVESTMENTS',
   'DFYFV' => 'FIDELITY DESTINY CONTRACTUALS',
   'DFZOE' => 'TIAA-CREF 529 PLAN - OKLAHOMA',
   'TIAVA' => 'TIAA-CREF VARIABLE ANNUITY',
   'FORTI' => 'UNION/TIME',
   'DFEUI' => 'IOWA ADVISOR 529 PLAN',
   'LTSTN' => 'LIGHTSTONE VALUE PLUS REIT',
   'PXLVA' => 'PHOENIX LIFE INSURANCE COMPANY',
   'DSTLA' => 'LORD ABBETT & CO',
   'SUNPA' => 'AIG SUNAMERICA LIFE ASSURANCE',
   'CORNR' => 'CORNERSTONE CORE PROP REIT INC',
   'DSTHI' => 'HINES REIT',
   'SLFCA' => 'SUN LIFE FINANCIAL',
   'GLAIC' => 'ANNUITY INVESTORS LIFE INS. CO',
   'DTOIM' => 'TRANSAMERICA FUNDS',
   'WRFWF' => 'WELLS FAMILY OF REAL ESTATE FD',
   'DTPMS' => 'JPMORGAN PRIVATE FUNDS',
   'GLAFX' => 'GREAT AMERICAN FINANCIAL RESOU',
   'OHION' => 'OHIO NATIONAL EQUITY SALES/ON',
   'DFSMR' => 'MARSHALL FUNDS',
   'DTJIN' => 'AIG SUNAMERICA ASSET MGMT',
   'ASLAA' => 'PRUDENTIAL ANNUITIES',
   'OPPED' => 'OPPENHEIMER 529 PLANS',
   'DCLLC' => 'DEARBORN CAPITAL MGMT LLC',
   'NYCAL' => 'PUTNAM ALLSTATE ADVISOR OF NY',
   'DTJIC' => 'ICON FUNDS',
   'USBAI' => 'ARIEL CAPITAL MANAGEMENT',
   'CGENE' => 'UNION BANK AND TRUST',
   'USBTI' => 'FUND*X UPGRADER FUNDS',
   'DFZMN' => 'TIAA-CREF 529 PLAN - MINNESOTA',
   'DFEDC' => 'DODGE & COX FUNDS',
   'MASUF' => 'MFS VARIABLE INSURANCE TRUST',
   'METVA' => 'METLIFE INVESTORS',
   'WSTVU' => 'WESTERN RESERVE LIFE (VUL)',
   'FPTOR' => 'FIRST TRUST PORTFOLIOS 2',
   'USBFA' => 'FIRST AMERICAN FUNDS',
   'PPACO' => 'PHOENIX PORTFOLIO ADVISOR',
   'DFYWI' => 'EDVEST / TOMORROW SCHOLAR 529',
   'DFERA' => 'RUSSELL INVESTMENT COMPANY',
   'FTPOR' => 'FIRST TRUST PORTFOLIOS LP',
   'CENTE' => 'CENTENNIAL FUNDS',
   'DFECN' => 'COLUMBIA NY 529 ADVISOR PLAN',
   'AMVAM' => 'INVESCO AIM',
   'GEECA' => 'GENWORTH FINANCIAL',
   'TSVLW' => 'TOUCHSTONE VARIABLE ANNUITY',
   'ALIPA' => 'AM INT LIFE INS. CO OF NY',
   'DTPPI' => 'PIMCO FUNDS',
   'PCMCR' => 'MONUMENTAL/TRANSAMERICA LIFE',
   'ACMAC' => 'AMERICAN CENTURY INVESTMENTS',
   'PCMLL' => 'MONUMENTAL LIFE INSURANCE',
   'WDRWR' => 'WADDELL & REED',
   'PENKK' => 'PENN MUTUAL',
   'LFSLF' => 'COLUMBIA FUNDS',
  );


sub parse_date($;$) {
  my $date = shift;
  if( $date =~ /\d{8}/ ){
    return if 0+$date == 0;
    my $year = substr($date,0,4);
    my $month = substr($date,4,2);
    my $day = substr($date,6,2);
    Carp::croak if (@_ && !defined($_[0]));
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

sub file_info_from_remote_filename($) {
  my $filename = shift;
  if ($filename =~ /^([A-Z\d]{5})([A-Z\d]{2})\.([A-Z])\d{4}\.ZIP$/){
    my($mgmt_code, $type, $resend) = ($1, $2, $3);
    my $file_type = $type_code_to_name{$type};
    my $file_class = $type_name_to_class{$file_type};
    return +{
             is_resend    => ($resend eq 'R'? 1 : 0),
             company_code => $mgmt_code,
             company_name => $mgmt_sys_codes{$mgmt_code},
             file_class   => $file_class,
             file_type    => $file_type,
             file_description => $class_code_to_description{$file_class},
            };
  }
}

sub file_info_from_header{
  my $line = shift;
  my $type = trim(substr($line,6,15));

  my $file_class;
  if (exists $type_name_to_class{$type}) {
    $file_class = $type_name_to_class{$type};
  } else {
    Carp::croak "File type '${type}' not supported.",
  }

  my $file_date = parse_date(substr($line,29,8));
  my $mgmt_code = substr($line,64,5);
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
           file_class => $file_class,
           file_type    => $type,
           file_description => $class_code_to_description{$file_class},
           product_type => $product_type,
           company_code => $mgmt_code,
           company_name => $mgmt_sys_codes{$mgmt_code},
          };

}

sub get_file_info {
  my $file = shift;
  if(my $io = IO::File->new("<${file}")){
    defined(my $line = $io->getline) or Carp::croak("File '${file}' is empty.");
    undef $io;
    return file_info_from_header($line);
  } else {
    Carp::croak("Failed to open '${file}'");
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

=head2 file_info_from_remote_filename $remote_name

=over 4

=item B<company_code> - The SystemID and Management Code (as described in 
Chapter 1, "Header Record") concatenated into a 5-character code.

=item B<company_name> - Legible version of the company name as provided by DST

=item B<is_resend> - 1 for resent file, 0 otherwise

=item B<file_class> - The type of file contained. The value matches the class
name of the apropriate parser class. (FPR, SF, AMP, APR, DA, DFA, NAA, NFA)

=item B<file_type> - The natural-language code used internally by DST

=item B<file_description> - The more legible version of file_type.

=back

=head2 file_info_from_header $header_record

Will return a hashref containing the following keys

=over 4

=item B<company_code> - The SystemID and Management Code (as described in 
Chapter 1, "Header Record") concatenated into a 5-character code.

=item B<company_name> - Legible version of the company name as provided by DST

=item B<processed_date> - L<DateTime> object of the file's processed date

=item B<file_class> - The type of file contained. The value matches the class
name of the apropriate parser class. (FPR, SF, AMP, APR, DA, DFA, NAA, NFA)

=item B<file_type> - The natural-language code used internally by DST

=item B<file_description> - The more legible version of file_type.

=item B<product_type> - The kind of product contained (VUL, VA, MF, REIT, LP)

=back

=head2 get_file_info $filename

Attempt to open the file, extract the header record and return the results of
C<file_info_from_header>.

=head1 AUTHOR & LICENSE

Please see L<Finance::DST::FAN::Mail> for more information.

=cut
