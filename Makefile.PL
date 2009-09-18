use strict;
use warnings;
use ExtUtils::MakeMaker;

WriteMakefile(
    NAME                => 'Data::Patch',
    AUTHOR              => 'Ktat <atusi@pure.ne.jp>',
    VERSION_FROM        => 'lib/Data/Patch.pm',
    ABSTRACT_FROM       => 'lib/Data/Patch.pm',
    PL_FILES            => {},
    PREREQ_PM => {
        'Test::More' => 0,
        'Test::Base' => 0,
    },
    dist                => { COMPRESS => 'gzip -9f', SUFFIX => 'gz', },
    clean               => { FILES => 'Data-Patch-*' },
);
