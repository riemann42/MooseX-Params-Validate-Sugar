use strict;
use warnings;

package MooseX::Params::Validate::Sugar;

#ABSTRACT: Sugar for MooseX::Params::Validate
use MooseX::Params::Validate::Sugar::TieHash;
use MooseX::Params::Validate ();
use Moose::Exporter;
use Moose ();
use Moose::Util::TypeConstraints;
#use Scalar::Readonly qw(readonly_on);
use List::MoreUtils qw(natatime pairwise part);
use Carp qw(confess);
use Scalar::Util qw(blessed);

Moose::Exporter->setup_import_methods(
    with_meta => [ 'method' ],
    as_is     => [ 'with_params', 'with_hash_params', 'with_pos_params', 'via', 'with_slurpy_params', 'with_trailing_list' ],
);

=func with_params (%params)

Alias for with_hash_params

=cut

sub with_params (%) { goto \&with_hash_params; }

=func with_hash_params (%params)

Used to create a filter subroutine that uses MooseX::Params::Validate::validated_hash to
convert paramaters.  %params is passed to validated_hash.  To make the syntax a little simplar,
any scalar ref is converted to { isa => $_ }.  

=cut

sub with_hash_params (%) {
    my %params = @_;
    for ( values %params ) {
        if ( ( ! ref ) and not ( $_ eq 'MX_PARAMS_VALIDATE_ALLOW_EXTRA' ) ) {
            $_ = { isa => $_ };
        }
    }
    return sub {
        my ( $name, $args ) = @_;
        MooseX::Params::Validate::validated_hash( $args,
            ( MX_PARAMS_VALIDATE_CACHE_KEY => $name, %params ) );
        }
}

=func with_pos_params (@params)

This allows positional paramaters. It can be combined with with_hash_params If used B<first>.

The syntax is the same as with_hash_params, and from the perspective of your method it is
the same.  In other words, your method will still see a hash.

MX_PARAMS_VALIDATE_ALLOW_EXTRA will generate an error if used.  Please check out
with_slurpy_params and with_trailing_list.

=cut

sub with_pos_params (@) {
    my @params = @_;
    my $odd = natatime 2, @params;
    my ( @names, @values );
    while ( my @pair = $odd->() ) {
        confess 'MX_PARAMS_VALIDATE_ALLOW_EXTRA not permitted. Use with_slurpy_params.' if ($pair[0] eq 'MX_PARAMS_VALIDATE_ALLOW_EXTRA');
        push @names,  $pair[0];
        push @values, ref $pair[1] ? $pair[1] : { isa => $pair[1] };
    }
    return sub {
        my ( $name, $args_in ) = @_;
        my @args = ();
        for (@names) {
            if (@{$args_in}) {
                push @args, shift @{$args_in};
            }
        }
        my @ret =
            MooseX::Params::Validate::pos_validated_list( \@args,
            ( @values, MX_PARAMS_VALIDATE_CACHE_KEY => $name ) );
        return pairwise { $a => $b } @names, @ret;
    }
}

=func with_slurpy_params ($spec)

This will slurp up all remaining items in @_, if any, and check to make sure they match the 
type in the spec listed. 

Currently the spec is limited to only coerce, isa, and optional.  If optional is not set,
then failing to call with at least one item will cause firey death.

The slurped up list is available to the method via $_{LIST}.

=cut

# This is taken from MooseX::Params::Validate, with some parts removed.
sub _convert_to_param_validate_spec {
    my ($spec) = @_;
    my %pv_spec;

    $pv_spec{optional} = $spec->{optional}
        if exists $spec->{optional};

    $pv_spec{default} = $spec->{default}
        if exists $spec->{default};

    $pv_spec{coerce} = $spec->{coerce}
        if exists $spec->{coerce};

    my $constraint;
    if ( defined $spec->{isa} ) {
        $constraint
             = _is_tc( $spec->{isa} )
            || Moose::Util::TypeConstraints::find_or_parse_type_constraint(
            $spec->{isa} )
            || class_type( $spec->{isa} );
    }
    elsif ( defined $spec->{does} ) {
        $constraint
            = _is_tc( $spec->{isa} )
            || find_type_constraint( $spec->{does} )
            || role_type( $spec->{does} );
    }

    $pv_spec{callbacks} = $spec->{callbacks}
        if exists $spec->{callbacks};

    if ($constraint) {
        $pv_spec{constraint} = $constraint;
    }
    delete $pv_spec{coerce}
        unless $pv_spec{constraint} && $pv_spec{constraint}->has_coercion;

    return \%pv_spec;
}

sub _is_tc {
    my $maybe_tc = shift;

    return $maybe_tc
        if defined $maybe_tc
            && blessed $maybe_tc
            && $maybe_tc->isa('Moose::Meta::TypeConstraint');
}

sub with_slurpy_params ($$) {
    my ($attr, $spec) = @_;
    if ( ! ref $spec ) { $spec = { isa => $spec } }
    my $pv_spec = _convert_to_param_validate_spec($spec);
    return sub {
       my ($name, $args_in) = @_;
       if ( !@{$args_in} && ! $pv_spec->{optional}) {
            confess "$name called with empty list.";
       }
       if ($pv_spec->{constraint}) {
           if ($pv_spec->{coerce}) {
               $_ = $pv_spec->{constraint}->coerce($_);
           }
           $pv_spec->{constraint}->assert_valid($args_in); 
       }
       my @out = @{$args_in};
       return ( $attr => \@out )
    }
}

=func with_trailing_list

This populates $_{LIST} with all remaining items.

=cut


sub with_trailing_list () {
    return sub {
       my ($name, $args_in) = @_;
       my @out = @{$args_in};
       @{$args_in} = ();
       return ( LIST => \@out );
    }
}


=func method $name, $param_filter, $sub_reference;

Define a method.  This is usually called as:

    method $name => with_params (%params), via { ... };


For the method created, the @_ variable is populated with the instance, then a hash containing the
validated / coerced options.

    # Unpack @_
    my ($self, %params ) = @_

You can also access these via the global variable %_.  $_{self} is the instance.

    #Perform division
    return $params{numerator} / $params{denominator};

Please note that %_ is a tied hash.  Trying to change it or access
non-existant keys will generate an error.  Because
of this, it is recommened to generally use this method, rather than the params method.

Via is imported from Moose::Util::TypeConstraints to avoid a conflict.

=cut

sub method {
    my ( $meta, $name, @params ) = @_;
    my $sub       = pop @params;
    my $full_name = $meta->name . '::' . $name;
    if (@params) {
        $meta->add_method(
            $name => sub {
                my %p = ( self => shift );
                my $count = 0;
                for (@params) {
                    %p = ( %p, &{$_}( $full_name . '::test' . $count++, \@_ ) );
                }
                local %_;
                tie %_, 'MooseX::Params::Validate::Sugar::TieHash', %p;
                $_{self}->$sub(%_);
            }
        );
    }
    else {
        $meta->add_method(
            $name => sub {
                my %p = ( self => shift );
                local %_;
                tie %_, 'MooseX::Params::Validate::Sugar::TieHash', %p;
                $_{self}->$sub(@_);
            }
        );
    }
}

1;

__END__

=head1 SYNOPSIS

    {

        package MyApp;
        use MooseX::Params::Validate::Sugar;

        method 'multiply' => 
            with_params ( first  => { isa => 'Int' }, second => { isa => 'Int', default => 7 }),
            via {
                my ( $self, %params ) = @_;
                return $params{first} * $params{second};
            };

        method 'divide' => 
            with_params ( first  => { isa => 'Int' }, second => { isa => 'Int', default => 7 }),
            via { return $_{first} / $_{second}; };

        method 'simple' => sub { 42 };
    }

    my $app = MyApp->new();
    say $app->multiply( first => 6 );  # Says 42
    say $app->divide( first => 42 );   # Says 6
    say $app->simple;                  # Says 42

=head1 DESCRIPTION

This adds some pretty sugar to L<MooseX::Params::Validate>.  It allows you to do a few things with MX:P:V
that are normally a little cumbersome (such as mixing positional and named paramaters). 



