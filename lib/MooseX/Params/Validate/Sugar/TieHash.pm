use strict;
use warnings;


package MooseX::Params::Validate::Sugar::TieHash;


#ABSTRACT: make the %_ hash die when you access it wrong.


use Carp qw(croak);
use Tie::Hash;
use vars qw(@ISA $VERSION);
 
use Attribute::Handlers autotie => { "__CALLER__::FixedKeys" => __PACKAGE__ };
 
@ISA = qw(Tie::StdHash);
 
 
sub TIEHASH {
    my $class = shift;
    my %hash = @_;
    bless \%hash, $class;
}
         
sub STORE {
    croak "Can't modify parameter hash"
}
sub DELETE {
    croak "Can't modify parameter hash"
}
sub CLEAR {
    croak "Can't modify parameter hash"
}
sub FETCH {
    my ( $self, $key)  = @_;
    if (exists $self->{$key} ) {
        return $self->{$key};
    }
    else {
        croak "Can't modify parameter hash"
    }
}

__END__

=head1 SYNOPSIS

    This is a helper module for MooseX::Params::Validate::Sugar. 

=head1 DESCRIPTION

Please see L<MooseX::Params::Validate::Sugar>.



