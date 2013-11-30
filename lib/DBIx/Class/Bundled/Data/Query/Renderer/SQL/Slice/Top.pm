package Data::Query::Renderer::SQL::Slice::Top;

use Moo::Role;

with 'Data::Query::Renderer::SQL::Slice::FetchFirst';

sub _render_slice_limit {
  my ($self, $dq) = @_;
  my $basic = $self->_render($dq->{from});
  return [
    $basic->[0],
    $self->_format_keyword('TOP'),
    sprintf("%i", $dq->{limit}{value}),
    @{$basic}[1..$#$basic]
  ];
}

sub _slice_type { 'Top' }

1;
