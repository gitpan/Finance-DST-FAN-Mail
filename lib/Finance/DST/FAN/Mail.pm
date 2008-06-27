package Finance::DST::FAN::Mail;

our $VERSION = '0.002000';

1;

=head1 NAME

Finance::DST::FAN::Mail - Tools for interfacing with DST FAN Mail

=head1 DESCRIPTION

C<Finance::DST::FAN::Mail> is a set of tools designed for interacting with
the Financial Advisor's network FANMail service. FANMail is a way to distribute
financial information data files from carriers to individual broker-dealer firms

=head1 COMPONENTS

This package is composed of 2 major and one minor component. The two main
components are L<Finance::DST::FAN::Mail::Download> and the
L<Finance::DST::FAN::Mail::File> modules, which you will primarily interact
with through  L<Finance::DST::FAN::Mail::Utils>. In the future there may be a
storage component added to the package, but for the time being that is left as
an exercise to the developer.

=head2 L<Utils|Finance::DST::FAN::Mail::Utils>

The recommended way to read incoming files is through the C<read_file>
function provided by this library.

=head2 L<Download|Finance::DST::FAN::Mail::Download>

A pluggable, subclassable downloader that interacts with the DST FAN Mail
site to retrieve file-listings, download files and delete files. Included
plugins allow for automatic unzipping, renaming, and splitting of files for
ease of archival and processing. This is considered to be a complete
implementation of the FAN Mail hhtp download interface as described in
the FAN Mail HTTP Doownload User Guide.

=head2 L<File parsers|Finance::DST::FAN::Mail::File>

The classes read and parse the contents of the DST FAN Mail files, providing
file-level data as object attributes, while record-level data is held as a
list of records (in the same order as the file). All file parsers contain
the predicate methods necessary for idenitfying REIT, LP, Mutual Fund, VUL,
and Variable Annuity data. In addition convenience predicates are present to
identify files as delta files or full data refreshers. Currently the following
file types are supported:

=over 4

=item L<Base File Parser Class|Finance::DST::FAN::Mail::File> - Implements the
basic methods shared by all file parsers and reads header and footer records
as described by Chapter 1 & 2 "Header Record" and "Footer Record" of the FAN Mail
Manual

=item L<Account Position|Finance::DST::FAN::Mail::File::APR> - Will parse APR
files as described by Chapter 3 "Account Position" of the FAN Mail
Manual

=item L<Direct Financial Activity|Finance::DST::FAN::Mail::File::DFA> - Will 
parse DFA files as described by Chapter 4 "Direct Financial Activity" of the FAN
Mail Manual

=item New Account Activity, Account Master Position, Non-Finalcial Activity -
Implemented by the L<Activity|Finance::DST::FAN::Mail::File::Activity> parser,
which will handle NAA, AMP and NFA files as described by Chapter 5 
"Account Activity, Account Master Position, Non-Finalcial Activity" of the FAN
Mail Manual

=item L<Distribution Activity|Finance::DST::FAN::Mail::File::DA> - Will parse
DA files as described by Chapter 6 "Distribution Activity" of the FAN Mail
Manual

=item L<Security File (Master)|Finance::DST::FAN::Mail::File::SF> - Will parse
SF files as described by Chapter 7 "Security File" of the FAN Mail Manual

=item L<Fund Price|Finance::DST::FAN::Mail::File::FPR> - Will parse
FPR files as described by Chapter 8 "Fund Price File" of the FAN Mail Manual

=back

=head1 AUTHOR

Guillermo Roditi (groditi) E<lt>groditi@cpan.orgE<gt>

=head1 COMMERCIAL SUPPORT AND FEATURE / ENHANCEMENT REQUESTS

This software is developed as free software and is distributed free of charge,
but if you or your organization would like to contribute to the further
development, maintenance and QA of this project we ask that you sponsor the
development of one ore more of these areas. Please contact groditi@cantella.com
for more information.

Commercial support and sponsored development are available for this project
through Cantella & Co., Inc. If you or your organization would like to use this
package and need help customising it or new functionality added please
contact groditi@cantella.com or jlanstein@cantella.com for rates.

=head1 BUGS AND CONTRIBUTIONS

Google Code Project Page - L<http://code.google.com/p/finance-dst-fan-mail/>

=head1 COPYRIGHT AND LICENSE

Copyright 2008 by Cantella & Co., Inc.

L<<a href="http://www.cantella.com/">http://www.cantella.com/</a>>.

This library is free software; you can redistribute it and/or modify it under 
the same terms as Perl itself

=cut
