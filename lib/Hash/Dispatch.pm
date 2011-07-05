package Hash::Dispatch;
# ABSTRACT: Find CODE in a hash (or hashlike)

use strict;
use warnings;

use Any::Moose;

use List::MoreUtils qw/ natatime /;

has map => qw/ is ro required 1 isa ArrayRef /;

sub dispatch {
    my $self = shift;
    if ( blessed $self && $self->isa( 'Hash::Dispatch' ) ) {
        return $self->_dispatch_object( @_ );
    }
    else {
        return $self->_dispatch_class( @_ );
    }
}

sub _dispatch_class {
    my $self = shift;
    return $self->new( map => [ %{ $_[0] } ] ) if 1 == @_ && ref $_[0] eq 'HASH';
    return $self->new( map => [ @_ ] );
}

sub _dispatch_object {
    my $self = shift;
    my $query = shift;

    my $original_query = $query;
    my ( $value, $captured, %seen );
    while ( 1 ) {
        ( $value, $captured ) = $self->_lookup( $query );
        return unless defined $value;
        last if ref $value eq 'CODE';
        if ( $seen{ $value } ) {
            die "*** Dispatch loop detected on query ($original_query => $query)";
        }
        $seen{ $query } = 1;
        $query = $value;
    }

    return $self->_result( $value, $captured );
}

sub _lookup {
    my $self = shift;
    my $query = shift;

    my $each = natatime 2, @{ $self->map };
    while ( my ( $key, $value ) = $each->() ) {
        if ( ref $key eq '' ) {
            if ( $key eq $query ) {
                return ( $value );
            }
        }
        elsif ( ref $key eq 'Regexp' ) {
            if ( my @captured = ( $query =~ $key ) ) {
                return ( $value, \@captured );
            }
        }
        else {
            die "*** Invalid dispatch key ($key)";
        }
    }

    return;
}

sub _result {
    my $self = shift;
    
    return Hash::Dispatch::Result->new( value => $_[0], captured => $_[1] );
}

package Hash::Dispatch::Result;

use Any::Moose;

has value => qw/ is ro required 1 isa CodeRef /; 
has captured => qw/ reader _captured /;

sub captured {
    my $self = shift;
    return @{ $self->_captured || [] };
}

1;
