package Dist::Zilla::Plugin::CodeOfConduct;

use v5.20;

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

has policy_args => (
    is      => 'ro',
    isa     => HashRef,
    default => sub { {} },
);

has policy_version => (
    is      => 'ro',
    isa     => StrictVersionStr,
    default => 'v0.4.0',
);

has filename => (
    is       => 'ro',
    isa      => NonEmptyStr,
                 default => 'CODE_OF_CONDUCT.md',
);

around plugin_from_config => sub( $orig, $class, $name, $args, $section ) {
    my %module_args;

    for my $key ( keys $args->%* ) {
        if ( $key =~ s/^-// ) {
            $module_args{$key} = $args->{"-$key"};
        }
        else {
            $module_args{policy_args}{$key} = $args->{$key};
        }
    }

    return $class->$orig( $name, \%module_args, $section );
};

sub gather_files($self) {

    my $zilla = $self->zilla;

    my %args = $self->policy_args->%*;

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
    $self->zilla->register_prereqs( { phase => 'develop' }, "Software::Policy::CodeOfConduct" => $self->policy_version );
    return;
}

sub prune_files($self) {
    my @files    = @{ $self->zilla->files };
    my $filename = $self->filename;
    for my $file (@files) {
        $self->zilla->prune_file($file) if $file->name eq $filename && $file->added_by !~ __PACKAGE__;
    }
}

__PACKAGE__->meta->make_immutable;
