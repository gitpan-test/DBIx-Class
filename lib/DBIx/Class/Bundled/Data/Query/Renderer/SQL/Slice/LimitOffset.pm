package Data::Query::Renderer::SQL::Slice::LimitOffset;

use Moo::Role;

sub slice_subquery { }

sub slice_stability { }

sub _render_slice {
  my ($self, $dq) = @_;
  [ ($dq->{from} ? $self->_render($dq->{from}) : ()),
    $self->_format_keyword('LIMIT'), $self->_render($dq->{limit}),
    ($dq->{offset}
      ? ($self->_format_keyword('OFFSET'), $self->_render($dq->{offset}))
      : ()),
  ];
}

1;
