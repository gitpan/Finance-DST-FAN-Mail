package Finance::DST::FAN::Mail::File::AMP;

our $VERSION = '0.003000';

use Moose;
extends 'Finance::DST::FAN::Mail::File::Activity';

1;

__PACKAGE__->meta->make_immutable;

__END__;

=head1 NAME

Finance::DST::FAN::Mail::File::AMP - Read DST FANMail AMP records into data structures

=head1 DESCRIPTION

This is an empty subclass of L<Finance::DST::FAN::Mail::File::Activity>,
For Usage information please refer to L<Finance::DST::FAN::Mail::File>.

=head1 SEE ALSO

L<Finance::DST::FAN::Mail::File>, L<Finance::DST::FAN::Mail::Utils>

=head1 AUTHOR & LICENSE

Please see L<Finance::DST::FAN::Mail> for more information.

=cut

