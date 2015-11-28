use strict;
use warnings;
use 5.020;

package Database::Server {

  # ABSTRACT: Base classes and roles for interacting with database server instances

=head1 METHODS

=head2 generate_port

 Database::Server->generate_port;

Returns an unused TCP port number.

=cut

  sub generate_port
  {
    require IO::Socket::IP;
    IO::Socket::IP->new(Listen => 5, LocalAddr => '127.0.0.1')->sockport;
  }

}

package Database::Server::Role::Server {

  use Moose::Role;
  use namespace::autoclean;
  
  requires 'create';
  requires 'init';
  requires 'start';
  requires 'stop';
  requires 'is_up';

  sub run
  {
    my($self, @command) = @_;
    Database::Server::CommandResult->new(@command);
  }
  
  sub restart
  {
    my($self) = @_;
    $self->stop if $self->is_up;
    $self->start;
  }

}

package Database::Server::Role::Result {

  use Moose::Role;
  use namespace::autoclean;
  
  requires 'is_success';

}

package Database::Server::CommandResult {

  use Moose;
  use Capture::Tiny qw( capture );
  use Carp qw( croak );
  use experimental qw( postderef );
  use namespace::autoclean;

  with 'Database::Server::Role::Result';

  sub BUILDARGS
  {
    my $class = shift;
    my %args = ( command => [map { "$_" } @_] );
    
    ($args{out}, $args{err}) = capture { system $args{command}->@* };
    croak "failed to execute @{[ $args{command}->@* ]}: $?" if $? == -1;
    my $signal = $? & 127;
    croak "command @{[ $args{command}->@* ]} killed by signal $signal" if $args{signal};

    $args{exit}   = $args{signal} ? 0 : $? >> 8;
        
    \%args;
  }

  has command => (
    is  => 'ro',
    isa => 'ArrayRef[Str]',
  );

  has out => (
    is  => 'ro',
    isa => 'Str',
  );

  has err => (
    is  => 'ro',
    isa => 'Str',
  );
  
  has exit => (
    is  => 'ro',
    isa => 'Int',
  );
  
  sub is_success
  {
    !shift->exit;
  }
  
  __PACKAGE__->meta->make_immutable;

}

1;
