package Finance::DST::FAN::Mail::Download::Plugin::Unzip;

use Moose::Role;

our $VERSION = '0.003000';

use IO::Uncompress::Unzip qw(unzip $UnzipError) ;

has unlink_after_unzip => (is => 'rw', isa => 'Bool', require => 1, default => sub{1});

around download => sub {
  my $orig = shift;
  my $file = $orig->(@_);
  return $file->basename =~ /^.+?\.ZIP$/ ? $_[0]->_unzip($file) : $file;
};

sub _unzip {
  my ($self,$zip) = @_;

  if(my ($output) = ($zip->basename =~ /^(.+?)\.ZIP$/)){
    my $dir = $zip->dir;
    $output = $dir->file("${output}.TXT");
    if (-e $output){
      unlink $zip if $self->delete_on_fail;;
      confess("${output} already exists. Will not be overwritten.");
    }
    if(unzip("$zip", "$output")){
      unlink $zip if $self->unlink_after_unzip;
      return $output;
    } else {
      unlink $zip    if $self->delete_on_fail;
      unlink $output if $self->delete_on_fail;
      confess("unzip failed: $UnzipError\n");
    }
  }
  unlink $zip if $self->delete_on_fail;;
  confess("Could not get name from ZIP $zip");
  return;
}

1;

__END__;

=head1 NAME

Finance::DST::FAN::Mail::Download::Plugin::Unzip - Unzip files after downloading

=head1 DESCRIPTION

This role is a plugin for L<Finance::DST::FAN::Mail::Download>. It extends the
download operation and automatically unzips the file after the download is complete.
All methods and attributes will be automatically consumed by that class at load time.

=head1 ATTRIBUTES

=head2 unlink_after_unzip

Read-write required boolean, defaults to true. When set to true the zip file will
be deleted after successful extraction.

=head1 METHODS

=head2 download

C<around '_download'>. Wraps the download method and calls C<_unzip> after downloading.
the value returned by C<_download> will be the name of the unziped file.

=head2 _unzip $ziped_file

Will decompress the ziped file and return the unziped filename. Will also delete
the ziped file if C<unlink_after_download> is true

=head1 SEE ALSO

L<Finance::DST::FAN::Mail::Download>,
L<Finance::DST::FAN::Mail::Download::Plugin::Rename>
L<Finance::DST::FAN::Mail::Download::Plugin::Split>

=head1 AUTHOR & LICENSE

Please see L<Finance::DST::FAN::Mail> for more information.

=cut
