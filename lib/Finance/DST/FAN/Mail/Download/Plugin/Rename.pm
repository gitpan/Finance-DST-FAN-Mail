package Finance::DST::FAN::Mail::Download::Plugin::Rename;

use Moose::Role;

our $VERSION = '0.003000';

use File::Copy;
use Finance::DST::FAN::Mail::Utils qw/get_file_info/;

requires '_unzip';

around download => sub{
  my $orig = shift;
  my $self = shift;
  my $file = $self->$orig(@_);
  if( $file->basename =~ /^.+?\.ZIP$/ ){
    $file = $self->_unzip($file);
  }
  return $self->_rename( $file );
};

sub _rename {
  my ($self, $file) = @_;
  if(my($provider, $ind) = ($file->basename =~ /^(.+?)\.([A-Z])\d+\.\w+$/) ){
    my $resend = $ind eq 'R' ? 1 : 0; #1 comes after 0 in ordering...
    my $info = get_file_info($file);
    my $stem = join("_", (
                          $provider,
                          $info->{file_class},
                          $info->{processed_date}->ymd(''),
                          $info->{product_type},
                          $resend,
                         )
                   );
    my $cnt = 0;
    my $new;
    do {
      $new = $file->dir->file(join("_", $stem, sprintf('%.2d',$cnt)));
      $cnt++;
    } while(-e $new);

    #todo check for errors
    move $file => $new;
    return $new;
  } else {
    die("Couldn't decompose filename for ${file}");
  }
}

1;

=head1 NAME

Finance::DST::FAN::Mail::Download::Plugin::Rename - Rename files after downloading

=head1 DESCRIPTION

This role is a plugin for L<Finance::DST::FAN::Mail::Download>. It builds on top of
L<Finance::DST::FAN::Mail::Download::Plugin::Unzip> and renames the file after the
unzip operation is completed successfully. All methods and attributes will be
automatically consumed by that class at load time.

=head1 METHODS

=head2 _download

C<around '_download'>. Wraps the download method, calls unzip if necessary and
calls C<_rename> after downloading.

=head2 _rename $unziped_file

Will rename the file to the following format:

    # eg ACMECO_APR_20081231_REIT_0_00
    ${provider}_${file_type}_${date_ymd}_${product_type}_${resend_indicator}_${counter}

Returns the new filename upon success and throws an exception on failure.

=head1 SEE ALSO

L<Finance::DST::FAN::Mail::Download>,
L<Finance::DST::FAN::Mail::Download::Plugin::Unzip>
L<Finance::DST::FAN::Mail::Download::Plugin::Split>

=head1 AUTHOR & LICENSE

Please see L<Finance::DST::FAN::Mail> for more information.

=cut
