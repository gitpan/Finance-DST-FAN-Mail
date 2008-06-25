package Finance::DST::FAN::Mail::Download;

use Moose;

our $VERSION = '0.001000';

use URI;
use XML::Simple;
use Path::Class;
use MIME::Base64 qw/encode_base64/;
use LWP::UserAgent;
use LWP::Protocol::https;

use MooseX::Types::Path::Class qw/Dir/;

with 'MooseX::Object::Pluggable';

has username     => (is => 'ro', isa => 'Str', required => 1);
has password     => (is => 'ro', isa => 'Str', required => 1);
has requester    => (is => 'ro', isa => 'Str', required => 1);
has download_dir => (is => 'rw', isa =>  Dir , required => 1, coerce => 1);

has _tidx => ( is => 'rw', isa => 'Str');
has _base_uri      => (is => 'ro', isa => 'URI', lazy_build => 1);
has _user_agent    => (is => 'ro', isa => 'LWP::UserAgent', lazy_build => 1);
has _encoded_login => (is => 'ro', isa => 'Str', lazy_build => 1);

has file_list =>
  (
   is  => 'ro',
   isa => 'ArrayRef',
   auto_deref => 1,
   lazy_build => 1
  );

has authed =>
  (
   reader   => 'is_authed',
   writer   => '_authed',
   isa      => 'Bool',
   required => 1,
   default  => sub{0}
  );

has delete_on_fail =>
  (
   reader   => 'delete_on_fail',
   writer   => '_delete_on_fail',
   isa      => 'Bool',
   required => 1,
   default  => sub{0}
  );

sub _build__base_uri {
  my $uri = URI->new("https://filetransfer.financialtrans.com/tf/FANMail");
  $uri->query_form(tx => 'RetrieveFile', cz => '415171403');
  return $uri;
}

sub _build__encoded_login {
  my $self = shift;
  encode_base64($self->username . ':' . $self->password);
}

sub _build__user_agent {
  my $self = shift;
  my $ua = LWP::UserAgent->new;
  $ua->default_headers->push_header('X-File-Requester' => $self->requester);
  return $ua;
}

sub _build_file_list{
  my $self = shift;
  my $uri = $self->_base_uri->clone;
  my $req = $self->_authed_request($uri);
  my $files = XMLin( $req->content , ValueAttr => ['name']);
  my $list = $files->{'FileList'}->{'File'};

  #need to implement some kind of connection error checking here
  return [] unless defined $list;
  if(ref $list){
    return $list;
  } elsif(length($list) && $list =~ /\.ZIP$/){
    return [$list];
  } else {
    return [];
  }
  return;
}

sub _authed_request {
  my $self = shift;
  my $ua = $self->_user_agent;

  if($self->is_authed){
    my $uri = blessed $_[0] ? shift(@_)->clone : URI->new(shift(@_));
    $uri->query_form(tidx => $self->_tidx, $uri->query_form);
    return $ua->get($uri, @_);
  }

  #only send the credentials once.
  $ua->default_headers->push_header('X-Dlua' => $self->_encoded_login);
  my $req = $ua->get(@_);
  $ua->default_headers->remove_header('X-Dlua');
  #set the tidx and add it to the default headers
  my $tidx = $req->headers->{"x-tidx"};
  $ua->default_headers->push_header('X-tidx' => $tidx);
  $self->_authed(1);
  $self->_tidx($tidx);
  return $req;
}

sub download {
  my ($self, $file) = @_;
  if( grep {$file eq $_} $self->file_list ){ #yes, yes, hashtable, whatever.
    my $uri = $self->_base_uri->clone;
    $uri->query_form($uri->query_form, file => $file, event => 'RetrieveFile');

    my $filepath = $self->download_dir->file($file);
    if (-e $filepath){
      confess("${filepath} already exists. Will not be overwritten.");
    }

    $self->_authed_request($uri, ':content_file' => "$filepath");
    #check for errors somehow?

    return $filepath;
  } else {
    confess("${file} is not in the file list");
  }
}

sub delete {
  my ($self, $file) = @_;

  if( grep{ $file eq $_} $self->file_list ){
    my $uri = $self->_base_uri->clone;
    $uri->query_form( $uri->query_form, file => $file, event => 'DeleteFile' );
    $self->_authed_request($uri);
    #check for errors somehow?

    $self->clear_file_list;
    if( grep {$file eq $_} $self->file_list ){
      confess("Deletion of file '${file}' appears to have failed");
    }
    return $file;
  } else {
    confess("${file} is not in the file list");
  }
}

1;

__END__;

=head1 NAME

Finance::DST::FAN::Mail::Download - Automate the downloading of FAN Mail files

=head1 DESCRIPTION

Finance::DST::FAN::Mail::Download is a pluggable, object-oriented interface to
DST's FAN Mail service. It does most of the legwork necessary to securely log
in, download, and delete files.

While all methods and attributes are documented, please treat any methods
beginning with an underscore '_' as private methods. If you are using them
directly then you are most likely doing something wrong.

=head1 SYNOPSIS

    use Finance::DST::FAN::Mail::Download;

    my $downloader = Finance::DST::FAN::Mail::Download->new(
                         username     => 'mycompany01',
                         password     => 'oursecret3',
                         requester    => 'My Company',
                         download_dir => '/data/files/dst/fan/mail',
                     );
    $downloader->download($_) for $downloader->file_list;

    #want files automatically unziped ?
    $downloader->load_plugin('Unzip');

    #want more descriptive filenames?
    $downloader->load_plugins(qw/Unzip Rename/); #order is significant...

    #want multiple logical files split into multiple physical files?
    $downloader->load_plugins(qw/Unzip Rename Split/); #order is significant...

=head1 ATTRIBUTES

Unless noted, the accessor (or reader for read-only attributes) is a method of
the same name as the attribute. Required attributes must be passed to the
constructor in a C<key => value> form where the key is the name of the
attribute, unless otherwise noted.

=head2 username

Required read-only string. This is your FAN Mail username.

=head2 password

Required read-only string. This is your FAN Mail password.

=head2 requester

Required read-only string. This is your Requester ID.

=head2 download_dir

Required read-only string. This is the directory where your files will be
downloaded to.

=head2 delete_on_fail

=over 4

=item B<_delete_on_fail> - writer

=back

Boolean. Indicates whether locally created files should be deleted in the event
of failure. This only applies to local files, theremote file will NEVER be
deleted without an explicit call to C<delete>.

=head2 file_list

=over 4

=item B<_file_list> - writer

=item B<_build_file_list> - builder.

The provided builder method will connect to DST, request the available file
listing, and parse the XML response to build the list.

=item B<has_file_list> - predicate

=item B<clear_file_list> - clearer

=back

This lazy building read-write attribute will be automatically filled upon first
request and will return an B<array> of valid file names that can be downloaded.
If you would like to refresh the list of files you may do so by clearing the
attribute via the clearer method. Please note that the reader method will
automatically dereference the interneal arrayref for you and will return a
list, not a reference.

=head2 _base_uri

=over 4

=item B<_build__base_uri> -
Defaults to https://filetransfer.financialtrans.com/tf/FANMail

=item B<_clear_base_uri> - clearer

=item B<_has_base_uri> - predicate

=back

Lazy building read only attribute which holds a URI object with the main
address of DST FAN Mail's web interface.

=head2 _user_agent

=over 4

=item B<_build__user_agent> - Creates a new LWP::UserAgent instance with the
'X-File-Requester' header.

=item B<_clear_user_agenti> - clearer

=item B<_has_user_agent> - predicate

=back

Lazy building read only attribute which holds a LWP::UserAgent object

=head2 _encoded_login

=over 4

=item B<_build__encoded_login> - builder

=item B<_clear_encoded_login> - clearer

=item B<_has_encoded_login> - predicate

=back

Read-only lazy-building string containing a the username and password joined
by a colon and encoded in base64.

=head2 authed

=over 4

=item B<is_authed> - reader

=item B<_authed> - writer

=back

Boolean indicating whether the current instance has authenticated.You will
probably never need to use this.

=head2 _tidx

A transaction string used to mantain state and authentication. It is initially
provided by DST upon the first transaction and after that this module will
handle setting it or refreshing it as necessary as well as attaching it to
requests when necessary.

=head1 METHODS

=head2 new %attributes

Create a new instance of the downloader

=head2 load_plugin $plugin

=head2 load_plugins @plugins

Load additional plugins.

=head2 download $file

Download C<$file> from DST

=head2 delete $file

Delete C<$file> from DST's servers.

=head2 meta

See L<Moose>

=head2 _authed_request $uri, @request_args

Make an URI request  that requires authentication. This method is a thin
wrapper for C<$self-E<gt>user_agent-E<gt>get()> which handles all
authentication details for DST. The arguments passed to it are passed through,
unchanged, to C<get>;

=head1 TODO

=over 4

=item Tests

=item POE integration for async event-triggered processing

=item better error checking capabilities at runtime

=back

=head1 SEE ALSO

L<MooseX::Object::Pluggable>,
L<Finance::DST::FAN::Mail::Download::Plugin::Unzip>,
L<Finance::DST::FAN::Mail::Download::Plugin::Rename>
L<Finance::DST::FAN::Mail::Download::Plugin::Split>

=head1 AUTHOR

Guillermo Roditi (groditi) <groditi@cpan.org>

=head1 BUGS, FEATURE REQUESTS AND CONTRIBUTIONS

Google Code Project Page - L<http://code.google.com/p/finance-dst-fan-mail/>

=head1 LICENSE

You may distribute this code under the same terms as Perl itself.

=cut
