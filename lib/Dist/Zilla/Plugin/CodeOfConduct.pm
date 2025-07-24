package Dist::Zilla::Plugin::CodeOfConduct;

use v5.20;

# ABSTRACT: add a Code of Conduct to a distribution

use Moose;
with qw( Dist::Zilla::Role::FileGatherer Dist::Zilla::Role::PrereqSource Dist::Zilla::Role::FilePruner );

use Dist::Zilla::File::InMemory;
use Dist::Zilla::Pragmas;
use Email::Address 1.910;
use MooseX::Types::Common::String qw( NonEmptyStr );
use MooseX::Types::Moose          qw( HashRef );
use MooseX::Types::Perl           qw( StrictVersionStr );
use Software::Policy::CodeOfConduct v0.4.0;

use namespace::autoclean;

use experimental qw( postderef signatures );

our $VERSION = 'v0.1.1';

=head1 SYNOPSIS

    [CodeOfConduct]
    -version = v0.4.0
    policy   = Contributor_Covenant_1.4
    name     = Perl-Project-Name
    contact  = author@example.org
    filename = CODE_OF_CONDUCT.md

=head1 DESCRIPTION

This is a L<Dist::Zilla> plugin to add a Code of Conduct to a distribution, using L<Software::Policy::CodeOfConduct>.

=cut

=head1 prepend:CONFIGURATION OPTIONS

Any options that do not start with a hyphen (like "-version") will be passed to L<Software::Policy::CodeOfConduct>.

=option name

This is the name of the project.

If you omit it, the distribution name will be used.

=option contact

This is a code of conduct contact. It can be a URL or e-mail address.

If you omit it, the e-mail address of the first author will be used.

=option policy

This is the policy template that you want to use.

If you omit it, the L<Software::Policy::CodeOfConduct/policy> default will be used.

=option -version

You can specify a minimum version of L<Software::Policy::CodeOfConduct>, in case you require a later version than the
default (v0.4.0).

=cut

has version => (
    is      => 'ro',
    isa     => StrictVersionStr,
    default => 'v0.4.0',
);

=option filename

This is the filename that the policy will be saved as.

=cut

has filename => (
    is      => 'ro',
    isa     => NonEmptyStr,
    default => 'CODE_OF_CONDUCT.md',
);

has _policy_args => (
    is      => 'ro',
    isa     => HashRef,
    default => sub { {} },
);

around plugin_from_config => sub( $orig, $class, $name, $args, $section ) {
    my %module_args;

    for my $key ( keys $args->%* ) {
        if ( $key =~ s/^-// ) {
            die "$key cannot be set" if $key eq "_policy_args";
            $module_args{$key} = $args->{"-$key"};
        }
        else {
            $module_args{_policy_args}{$key} = $args->{$key};
        }
    }

    $module_args{filename} = $module_args{_policy_args}{filename} if $module_args{_policy_args}{filename};

    return $class->$orig( $name, \%module_args, $section );
};

sub gather_files($self) {

    my $zilla = $self->zilla;

    my %args = $self->_policy_args->%*;

    my ($author) = Email::Address->parse( $zilla->distmeta->{author}[0] );

    $args{name}     //= $zilla->distmeta->{name};
    $args{contact}  //= $author->address;
    $args{filename} //= $self->filename;

    my $policy = Software::Policy::CodeOfConduct->new(%args);

    $self->add_file(
        Dist::Zilla::File::InMemory->new(
            name    => $policy->filename,
            content => $policy->fulltext,
        )
    );

    return;
}

sub register_prereqs($self) {
    $self->zilla->register_prereqs( { phase => 'develop' }, "Software::Policy::CodeOfConduct" => $self->version );
    return;
}

sub prune_files($self) {
    my @files    = @{ $self->zilla->files };
    my $filename = $self->filename;
    for my $file (@files) {
        $self->zilla->prune_file($file) if $file->name eq $filename && $file->added_by !~ __PACKAGE__;
    }
}

=for Pod::Coverage plugin_from_config

=for Pod::Coverage gather_files

=for Pod::Coverage register_prereqs

=for Pod::Coverage prune_files

=head1 prepend:SUPPORT

Only the latest version of this module will be supported.

This module requires Perl v5.20 or later.  Future releases may only support Perl versions released in the last ten
years.

=head2 Reporting Bugs and Submitting Feature Requests

=head1 append:SUPPORT

If the bug you are reporting has security implications which make it inappropriate to send to a public issue tracker,
then see F<SECURITY.md> for instructions how to report security vulnerabilities.

=cut


__PACKAGE__->meta->make_immutable;
