
use strict;
use warnings;
use Test::More tests => 13;
use Test::Exception;
use Finance::DST::FAN::Mail::Utils qw/trim parse_date
                                      file_info_from_remote_filename
                                      file_info_from_header
                                     /;

dies_ok { parse_date('20080515',undef) };
{
  my $date;
  lives_ok{ $date = parse_date('20080515'); };
  ok($date->isa('DateTime'), 'value isa DateTime');
  is($date->ymd(''), '20080515', 'date matches');
}

{
  my $date;
  lives_ok{ $date = parse_date('20080515','101010'); };
  ok($date->isa('DateTime'), 'value isa DateTime');
  is($date->ymd(''), '20080515', 'date matches');
  is($date->hms(''), '101010', 'time matches');
}

is(trim('  x  '),'x','trim');
{
  my %infos = (
               'EQUIT17.X0022.ZIP' =>
               {
                company_code => 'EQUIT',
                company_name => 'AXA EQUITABLE',
                file_class => 'FPR',
                file_type => 'PRICE REFRESHER',
                file_description => 'Price Refresher',
                is_resend => 0,
               },
               'EQUITSF.R0022.ZIP' =>
               {
                company_code => 'EQUIT',
                company_name => 'AXA EQUITABLE',
                file_class => 'SF',
                file_type => 'SECURITY FILE',
                file_description => 'Security File',
                is_resend => 1,
               },
              );

  is_deeply(file_info_from_remote_filename($_), $infos{$_}, "${_} info")
    foreach keys %infos;
}

{
  my @headers =
    (
     {
      header =>
      'RHR001ACCT POSITION  200806302008063000000000ILDMU1440140001038*INLND*R                                                                                         ',

      company_code => 'INLND',
      company_name => 'INLAND REIT',
      processed_date => '20080630',
      product_type => 'REIT',
      file_class => 'APR',
      file_type => 'ACCT POSITION',
      file_description => 'Account Position',
     },
     {
      header =>
      'RHR001FINANCIALDIRECT200806272008062800000000EUDMU1170150007231*EQUIT*V                                                                                         ',

      company_code => 'EQUIT',
      company_name => 'AXA EQUITABLE',
      processed_date => '20080628',
      product_type => 'VA',
      file_class => 'DFA',
      file_type => 'FINANCIALDIRECT',
      file_description => 'Direct Financial Activity',
     },
    );
  for my $head (@headers){
    my $line = delete $head->{header};
    my $got = file_info_from_header($line);
    $got->{processed_date} = $got->{processed_date}->ymd('');
    is_deeply($got, $head, "header");
  }
}
