use strict;
use warnings;

use Test::More tests => 10;    # last test to print
use Try::Tiny;

{

    package MyApp;
    use MooseX::Params::Validate::Sugar;
    use List::Util qw(reduce);
    use Moose::Util::TypeConstraints;


    method 'multiply' => 
         with_params ( first  => 'Int', second => { isa => 'Int', default => 7 }),
         via {
            my ( $self, %params ) = @_;
            return $params{first} * $params{second};
         };

    method 'divide' => 
        with_pos_params ( first  => { isa => 'Int' }, second => { isa => subtype ('Int' => where { $_ > 0 }), default => 7 }),
        via { return $_{first} / $_{second}; };


    method 'subtract' =>
        with_pos_params  ( by => { isa => 'Int' } ),
        with_hash_params ( from => { isa => 'Int' } ),
        via { return $_{from} - $_{by} };

    method 'simple' => sub { my ($self, $ret) = @_; return $ret };

    method 'sum' =>
        with_slurpy_params ( list => 'ArrayRef[Int]'),
        via { return reduce { $a + $b } @{$_{list}} };

    method 'lsum' =>
        with_trailing_list,
        via { return reduce { $a + $b } @{$_{LIST}} };

    1;
}

sub do_tests {
    my $app = MyApp->new();

    is( $app->multiply( first => 6 ), 42, 'test of unpack' );
    eval { $app->multiply( first => 4.3 ) };
    ok ($@ =~ /did not pass/, 'Test of bad value');
    is( $app->divide(42), 6, 'test of list' );
    eval { $app->divide(6,0) };
    ok ($@ =~ /did not pass/, 'test of custom type');
    is( $app->simple(42), 42, 'test of simple' );
    is( $app->subtract(6, from => 7), 1, 'test of combined' );
    is( $app->sum(6,7,8,6,7,8), 42, 'test of slurpy' );
    eval { $app->multiply() };
    ok ($@ =~ /Mandatory parameter 'first' missing in call/, 'test of missing params');
    eval { $app->sum('1', 'apples', 'oranges') };
    ok ($@ =~ /Validation failed/, 'test of bad value');
    is( $app->lsum(5.5,6.5,7.5,5.5,6.5,7.5,2.2,.8), 42, 'test of with_trailing_list');
    $app = undef;
}

do_tests();


