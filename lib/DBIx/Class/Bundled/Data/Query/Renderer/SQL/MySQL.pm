package Data::Query::Renderer::SQL::MySQL;

use Data::Query::Constants;
use Data::Query::ExprHelpers;
use Moo;

extends 'Data::Query::Renderer::SQL::Naive';

with 'Data::Query::Renderer::SQL::Slice::LimitXY';

has needs_inner_join => (is => 'ro', default => sub { 0 });

around _format_join_keyword => sub {
  my ($orig, $self) = (shift, shift);
  my ($dq) = @_;
  if ($dq->{'Data::Query::Renderer::SQL::MySQL.straight_join'}) {
    return $self->_format_keyword('STRAIGHT_JOIN');
  } elsif ($self->needs_inner_join and $dq->{on} and !$dq->{outer}) {
    return $self->_format_keyword('INNER JOIN');
  }
  return $self->$orig(@_);
};

sub _insert_default_values {
  my ($self) = @_;
  $self->_format_keyword('VALUES'), qw( ( ) );
}

foreach my $type (qw(update delete)) {
  around "_render_${type}" => sub {
    my ($orig, $self) = (shift, shift);
    $self->$orig($self->_maybe_double_subquery(@_));
  };
}

sub _maybe_double_subquery {
  my ($self, $dq) = @_;
  my $target = $dq->{target};
  my $new = { %$dq };
  foreach my $key (qw(set where)) {
    next unless $dq->{$key};
    $new->{$key} = map_dq_tree {
      if (is_Select) {
        my $found;
        scan_dq_nodes(do {
          if (is_Identifier($target)) {
            my $ident = $target->{elements}[0];
            +{ DQ_IDENTIFIER ,=> sub {
                 my @el = @{$_[0]->{elements}};
                 $found = 1 if @el == 1 and $el[0] eq $ident;
               }
            };
          } elsif (is_Literal($target)) {
            my $ident = $target->{literal} or die "Can't handle complex literal";
            +{ DQ_LITERAL ,=> sub {
                 my $lit = $_[0]->{literal};
                 $found = 1 if $lit and $lit eq $ident;
               }
            };
          } else {
            die "Can't handle target type ".$target->{type};
          }
        }, $_);
        if ($found) {
          \Select([ Identifier('*') ], Alias('_forced_double_subquery', $_));
        } else {
          $_
        }
      } else {
        $_
      }
    } $dq->{$key};
  }
  $new;
}

1;
