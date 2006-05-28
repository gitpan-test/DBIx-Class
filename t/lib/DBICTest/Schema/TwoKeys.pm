package # hide from PAUSE
    DBICTest::Schema::TwoKeys;

use base 'DBIx::Class::Core';

__PACKAGE__->table('twokeys');
__PACKAGE__->add_columns(
  'artist' => { data_type => 'integer' },
  'cd' => { data_type => 'integer' },
);
__PACKAGE__->set_primary_key(qw/artist cd/);

__PACKAGE__->belongs_to( artist => 'DBICTest::Schema::Artist' );
__PACKAGE__->belongs_to( cd => 'DBICTest::Schema::CD' );

1;
