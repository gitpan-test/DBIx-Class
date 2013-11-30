package Data::Query::Renderer::SQL::Dialect::ReturnInto;

use Data::Query::ExprHelpers;
use Moo::Role;

around _render_insert => sub {
  my ($orig, $self) = (shift, shift);
  my ($dq) = @_;
  if (my $into = $dq->{__PACKAGE__.'.into'}) {
    my @ret = @{$self->$orig(@_)};
    return [
      @ret, $self->_format_keyword('INTO'), 
      intersperse(',', map $self->_render($_), @$into)
    ];
  } else {
    return $self->$orig(@_);
  }
};

1;
