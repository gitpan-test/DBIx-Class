package Data::Query::Renderer::SQL::Pg;

use Moo;

extends 'Data::Query::Renderer::SQL::Naive';

with 'Data::Query::Renderer::SQL::Slice::LimitOffset';

1;
