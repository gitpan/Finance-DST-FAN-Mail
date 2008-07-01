package Finance::DST::FAN::Mail::File::NFA;

our $VERSION = '0.005000';

use Moose;
extends 'Finance::DST::FAN::Mail::File::Activity';

__PACKAGE__->meta->make_immutable;

1;

__END__;

=head1 NAME

Finance::DST::FAN::Mail::File::NFA - Read DST FANMail NFA records into data structures

=head1 DESCRIPTION

This is an empty subclass of L<Finance::DST::FAN::Mail::File::Activity>,
For Usage information please refer to L<Finance::DST::FAN::Mail::File>.

=head1 SEE ALSO

L<Finance::DST::FAN::Mail::File>, L<Finance::DST::FAN::Mail::Utils>

=head1 AUTHOR & LICENSE

Please see L<Finance::DST::FAN::Mail> for more information.

=cut

