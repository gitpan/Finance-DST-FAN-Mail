#! /usr/bin/perl -w

# Load the Module::Install bundled in ./inc/
use inc::Module::Install;

# Define metadata
name 'Finance-DST-FAN-Mail';
abstract "Tools to interface with DST's FAN Mail service";
all_from 'lib/Finance/DST/FAN/Mail.pm';

# Specific dependencies
requires 'URI';
requires 'Moose' => '0.28';
requires 'DateTime';
requires 'IO::File';
requires 'Path::Class';
requires 'XML::Simple';
requires 'MIME::Base64';
requires 'Crypt::SSLeay';
requires 'LWP::UserAgent';
requires 'LWP::Protocol::https';
requires 'MooseX::Object::Pluggable'  => '0.0006';
requires 'MooseX::Types::Path::Class' => '0.04';
requires 'IO::Uncompress::Unzip';
requires 'File::Copy';
requires 'Class::MOP';
requires 'Sub::Exporter';

WriteAll;


