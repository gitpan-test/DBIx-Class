package Data::Query::Constants;

use strictures 1;
use Exporter 'import';

use constant +{
  (our %CONST = (
    DQ_IDENTIFIER => 'Identifier',
    DQ_OPERATOR => 'Operator',
    DQ_VALUE => 'Value',
    DQ_SELECT => 'Select',
    DQ_ALIAS => 'Alias',
    DQ_LITERAL => 'Literal',
    DQ_JOIN => 'Join',
    DQ_ORDER => 'Order',
    DQ_WHERE => 'Where',
    DQ_DELETE => 'Delete',
    DQ_UPDATE => 'Update',
    DQ_INSERT => 'Insert',
    DQ_GROUP => 'Group',
    DQ_SLICE => 'Slice',
  ))
};

our @EXPORT = keys our %CONST;

1;
