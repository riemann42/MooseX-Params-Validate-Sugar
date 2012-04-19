use strict;
use warnings;

use Test::More tests => 3;    # last test to print

{

    package MyApp;
    use MooseX::Params::Validate::Sugar;

    method 'multiply' => 
        ( first  => { isa => 'Int' }, second => { isa => 'Int', default => 7 }),
        sub {
            my ( $self, %params ) = @_;
            return $params{first} * $params{second};
        };

    method 'divide' => 
        ( first  => { isa => 'Int' }, second => { isa => 'Int', default => 7 }),
        sub { return $_{first} / $_{second}; };

    method 'simple' => sub { 42 };
    1;
}

my $app = MyApp->new();

is( $app->multiply( first => 6 ), 42, 'test of unpack' );
is( $app->divide( first => 42 ), 6, 'test of %_' );
is( $app->simple, 42, 'test of simple' );

