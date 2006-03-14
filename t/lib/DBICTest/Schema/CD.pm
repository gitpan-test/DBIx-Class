package # hide from PAUSE 
    DBICTest::Schema::CD;

use base 'DBIx::Class::Core';

__PACKAGE__->load_components('PK::Auto');

DBICTest::Schema::CD->table('cd');
DBICTest::Schema::CD->add_columns(
  'cdid' => {
    data_type => 'integer',
    is_auto_increment => 1,
  },
  'artist' => {
    data_type => 'integer',
  },
  'title' => {
    data_type => 'varchar',
    size      => 100,
  },
  'year' => {
    data_type => 'varchar',
    size      => 100,
  },
);
DBICTest::Schema::CD->set_primary_key('cdid');
DBICTest::Schema::CD->add_unique_constraint(artist_title => [ qw/artist title/ ]);

1;
