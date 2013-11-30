package Data::Query::Renderer::SQL::Slice::SkipFirst;

use Moo::Role;

with 'Data::Query::Renderer::SQL::Slice::FirstSkip';

sub _slice_order { qw(offset limit) }

1;
