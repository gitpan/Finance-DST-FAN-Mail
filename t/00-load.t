#!perl

use Test::More tests => 15;

BEGIN {
    use_ok( 'Finance::DST::FAN::Mail' );
    use_ok( 'Finance::DST::FAN::Mail::Utils' );

    use_ok( 'Finance::DST::FAN::Mail::File' );
    use_ok( 'Finance::DST::FAN::Mail::File::Activity' );
    use_ok( 'Finance::DST::FAN::Mail::File::AMP' );
    use_ok( 'Finance::DST::FAN::Mail::File::APR' );
    use_ok( 'Finance::DST::FAN::Mail::File::DA' );
    use_ok( 'Finance::DST::FAN::Mail::File::DFA' );
    use_ok( 'Finance::DST::FAN::Mail::File::FPR' );
    use_ok( 'Finance::DST::FAN::Mail::File::NAA' );
    use_ok( 'Finance::DST::FAN::Mail::File::NFA' );
    use_ok( 'Finance::DST::FAN::Mail::File::SF' );

    use_ok( 'Finance::DST::FAN::Mail::Download' );
    use_ok( 'Finance::DST::FAN::Mail::Download::Plugin::Unzip' );
    use_ok( 'Finance::DST::FAN::Mail::Download::Plugin::Rename' );
}

diag( "Testing Finance::DST::FAN::Mail $Finance::DST::FAN::Mail::VERSION, Perl $], $^X" );
