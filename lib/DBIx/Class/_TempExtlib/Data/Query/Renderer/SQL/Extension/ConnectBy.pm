package Data::Query::Renderer::SQL::Extension::ConnectBy;

use Moo::Role;

around _default_simple_ops => sub {
  my ($orig, $self) = (shift, shift);
  +{ %{$self->$orig(@_)}, PRIOR => 'unop' };
};

1;
