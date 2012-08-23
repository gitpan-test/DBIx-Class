# generate the inherit pods as both a clone-dir step, and a makefile distdir step

# if the author doesn't have them, don't fail the initial "perl Makefile.pl" step
eval "require Pod::Inherit;";
$@ or do {
   require DBIx::Class::Optional::Dependencies;
   DBIx::Class::Optional::Dependencies->_gen_inherit_pods();
};

postamble <<"EOP";

.PHONY: dbic_clonedir_gen_inherit_pods

create_distdir : dbic_clonedir_gen_inherit_pods

dbic_clonedir_gen_inherit_pods :
\t\$(ABSPERL) -Ilib -MDBIx::Class::Optional::Dependencies -e "DBIx::Class::Optional::Dependencies->_gen_inherit_pods()"

EOP

# keep the Makefile.PL eval happy
1;
