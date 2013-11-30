package Data::Query::Renderer::SQL::Slice::FirstSkip;

use Moo::Role;

my %handle = (limit => 'FIRST', offset => 'SKIP');

sub slice_subquery { }

sub slice_stability { }

sub _slice_order { qw(limit offset) }

sub _render_slice {
  my ($self, $dq) = @_;
  my $basic = $self->_render($dq->{from});
  return [
    $basic->[0], # SELECT keyword
    (map +(
      $dq->{$_}
        ? ($self->_format_keyword($handle{$_}), $self->_render($dq->{$_}))
        : ()
      ), $self->_slice_order
    ),
    @{$basic}[1..$#$basic]
  ];
};

1;
