use strict;
use warnings;

package MooseX::Params::Validate::Sugar;
#ABSTRACT: Sugar for MooseX::Params::Validate
use MooseX::Params::Validate ();
use Moose::Exporter;
use Moose ();

Moose::Exporter->setup_import_methods( with_meta => ['method'], also => ['Moose'] );

=func method $name => ( @params ), sub { ... }

Define a method.  @params are the params for MooseX::Params::Validate::validated_hash.  
Please see L<MooseX::Params::Validate> for details.

For the sub, the @_ variable is populated with the instance, then a hash containing the
validated / coerced options.

    # Unpack @_
    my ($self, %params ) = @_

You can also access these via the global variable %_.  $_{self} is the instance.

    #Perform division
    return $params{numerator} / $params{divisor};

=cut

sub method {
    my ( $meta,$name, @params ) = @_;
    my $sub = pop @params;
    if (@params) {
        push @params, ( MX_PARAMS_VALIDATE_CACHE_KEY => $meta->name . '::' . $name);
        $meta->add_method(
            $name => sub {
                my $self = shift;
                local %_  = MooseX::Params::Validate::validated_hash( \@_, @params );
                $_{self} = $self;
                $self->$sub(%_);

            }
        );
     }
     else {
        $meta->add_method($name => $sub);
     }
}

1;

__END__

=head1 SYNOPSIS

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
    }

    my $app = MyApp->new();
    say $app->multiply( first => 6 );  # Says 42
    say $app->divide( first => 42 );   # Says 6
    say $app->simple;                  # Says 42

=head1 DESCRIPTION

This adds some pretty sugar to L<MooseX::Params::Validate>.  

=cut


