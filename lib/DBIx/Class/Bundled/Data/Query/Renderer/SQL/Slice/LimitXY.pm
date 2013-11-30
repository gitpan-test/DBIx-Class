package Data::Query::Renderer::SQL::Slice::LimitXY;

use Moo::Role;

sub slice_subquery { }

sub slice_stability { }

sub _render_slice {
  my ($self, $dq) = @_;
  [ ($dq->{from} ? $self->_render($dq->{from}) : ()),
    $self->_format_keyword('LIMIT'),
    ($dq->{offset}
      ? ($self->_render($dq->{offset}), ',')
      : ()),
    $self->_render($dq->{limit}),
  ];
}

1;
