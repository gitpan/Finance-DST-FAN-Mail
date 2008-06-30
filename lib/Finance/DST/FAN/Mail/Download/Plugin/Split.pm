package Finance::DST::FAN::Mail::Download::Plugin::Split;

use Moose::Role;

our $VERSION = '0.004000';

use Finance::DST::FAN::Mail::Utils qw/trim file_info_from_header/;

requires '_unzip';
requires '_rename';

sub download_and_split {
  my($self, $file) = @_;
  return ($self->_split( $self->download($file) ));
}

sub _split {
  my ($self, $orig_file) = @_;

  if (my $io = IO::File->new("<${orig_file}")) {
    my $line = $io->getline  or confess("File '${orig_file}' is empty.");
    unless($line =~ /^RHR001/){
      confess("First record is not Header record on file '${orig_file}'");
    }

    my $contents = [$line];
    my @files = ({file => $orig_file, contents => $contents});
    my %used_names = ($orig_file => 1);
    my $dir = $orig_file->dir;
    while (defined($line = $io->getline)) {
      if ($line =~ /^RHR001/) {
        my $info = file_info_from_header($line);
        my @parts = split(/_/, $orig_file->basename);
        $parts[1] = $info->{file_class};
        $parts[2] = $info->{processed_date}->ymd('');
        $parts[3] = $info->{product_type};
        my $cnt = pop(@parts) + 0;
        my $new_file;
        do {
          $new_file = $dir->file(join('_', @parts, sprintf('%.2d', $cnt)));
          $cnt++;
        } while(-e $new_file || exists $used_names{$new_file});
        $used_names{$new_file} = 1;
        $contents = [$line];
        push(@files, {file => $new_file, contents => $contents});
      } else {
        push(@$contents, $line);
      }
    }

    #shortcut in case of a single file
    return ($orig_file) if @files == 1;

    unlink $orig_file;
    my @created_files;
    for my $file (@files){
      my $curr_file = $file->{file};
      if (-e $curr_file){
        if($self->delete_on_fail){
          unlink $_ for @created_files;
        }
        confess("${curr_file} already exists. Will not be overwritten.");
      }
      if(my $io = IO::File->new(">${curr_file}")){
        push(@created_files, $curr_file);
        $io->print(@{ $file->{contents} });
      } else {
        if($self->delete_on_fail){
          unlink $_ for @created_files; 
        }
        confess("Failed to open '${curr_file}' for writting.");
      }
    }

    return @created_files;

  } else {
    unlink $orig_file if $self->delete_on_fail;
    confess("Failed to open ${orig_file}");
  }
}

1;


1;

=head1 NAME

Finance::DST::FAN::Mail::Download::Plugin::Split - Split files after download

=head1 DESCRIPTION

This role is a plugin for L<Finance::DST::FAN::Mail::Download>. After
downloading, it will read a file to determine if there is more than one logical
file type in the physical file and if so, split it into multiple files.

=head1 METHODS

=head2 _split $file

Open C<$file> (a C<Path::Class::File>) and split it into multiple files if
necessary. Returns a list of C<Path::Class::File> objects representing the
new set of files. Files will be use the same naming scheme C<Rename> uses.

=head2 download_and_split

Will performa normal download operation and then return a list of
 C<Path::Class::File> objects representing all the new files.

=head1 SEE ALSO

L<Finance::DST::FAN::Mail::Download>,
L<Finance::DST::FAN::Mail::Download::Plugin::Unzip>
L<Finance::DST::FAN::Mail::Download::Plugin::Rename>

=head1 AUTHOR & LICENSE

Please see L<Finance::DST::FAN::Mail> for more information.

=cut
