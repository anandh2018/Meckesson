#!/usr/bin/perl

use BLUELITE::QAS;
use Data::Dumper;

my $qas = BLUELITE::QAS->new();
print Dumper $qas->validate(qq{1743 Saint Lawrence Cv\nTucker, GA 30084});
