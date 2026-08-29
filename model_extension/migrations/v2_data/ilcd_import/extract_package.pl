#!/usr/bin/env perl
# extract_package.pl <extracted-package-dir>  (dir that contains ILCD/processes/…)
# Emits three TSVs to <dir>/_parsed/ :
#   meta.tsv       key<TAB>value
#   exchanges.tsv  internalId<TAB>direction<TAB>amount<TAB>flowUuid<TAB>shortDesc
#   flowdefs.tsv   flowUuid<TAB>baseName<TAB>cas<TAB>flowType<TAB>categoryPath
# Pure-Perl, no XML libs (ILCD files are regular enough).
use strict; use warnings;
my $dir = shift or die "usage: extract_package.pl <extracted-package-dir>\n";
$dir =~ s{/$}{};
my ($proc) = glob("$dir/ILCD/processes/*.xml");
die "no process XML under $dir/ILCD/processes/\n" unless $proc && -f $proc;

local $/; open my $fh, '<:raw', $proc or die $!; my $x = <$fh>; close $fh;

sub g1 { my ($re) = @_; return ($x =~ $re) ? $1 : '' }

my %meta;
$meta{processUuid}      = g1(qr{<common:UUID>([0-9a-fA-F-]{36})</common:UUID>});
$meta{dataSetVersion}   = g1(qr{<common:dataSetVersion>([^<]+)</common:dataSetVersion>});
$meta{baseName}         = g1(qr{<baseName[^>]*>([^<]+)</baseName>});
$meta{referenceYear}    = g1(qr{<common:referenceYear>([^<]+)</common:referenceYear>});
$meta{validUntil}       = g1(qr{<common:dataSetValidUntil>([^<]+)</common:dataSetValidUntil>});
$meta{location}         = g1(qr{location="([^"]+)"});
$meta{typeOfDataSet}    = g1(qr{<typeOfDataSet>([^<]+)</typeOfDataSet>});
$meta{lciMethodPrinciple}= g1(qr{<LCIMethodPrinciple>([^<]+)</LCIMethodPrinciple>});
$meta{refFlowInternalId}= g1(qr{<referenceToReferenceFlow>(\d+)</referenceToReferenceFlow>});
{ my $t = g1(qr{<technologyDescriptionAndIncludedProcesses[^>]*>(.{1,400}?)</}s);
  $t =~ s/\s+/ /g; $t =~ s/^\s+|\s+$//g; $meta{technology} = $t; }
{ my $c = g1(qr{<common:generalComment[^>]*>(.{1,400}?)</}s);
  $c =~ s/\s+/ /g; $c =~ s/^\s+|\s+$//g; $meta{generalComment} = $c; }

# exchanges
my @ex;
while ($x =~ m{<exchange\b[^>]*dataSetInternalID="(\d+)"[^>]*>(.*?)</exchange>}gs) {
  my ($id, $b) = ($1, $2);
  my ($ro)  = $b =~ m{<referenceToFlowDataSet\b[^>]*refObjectId="([0-9a-fA-F-]{36})"};
  my ($sd)  = $b =~ m{<referenceToFlowDataSet\b.*?<common:shortDescription[^>]*>(.*?)</common:shortDescription>}s;
  my ($dir2)= $b =~ m{<exchangeDirection>([^<]+)</exchangeDirection>};
  my ($ra)  = $b =~ m{<resultingAmount>([^<]+)</resultingAmount>};
  my ($ma)  = $b =~ m{<meanAmount>([^<]+)</meanAmount>};
  $sd //= ''; $sd =~ s/\s+/ /g; $sd =~ s/^\s+|\s+$//g;
  push @ex, [ $id, $dir2//'', (defined $ra && $ra ne '' ? $ra : ($ma//'')), $ro//'', $sd ];
}

# product flow (reference)
my ($prodRow) = grep { $_->[0] eq $meta{refFlowInternalId} } @ex;
$meta{productFlowUuid} = $prodRow ? $prodRow->[3] : '';
$meta{productAmount}   = $prodRow ? $prodRow->[2] : '';

# flow definitions: parse every flows/*.xml once
my %fdef;
for my $ff (glob("$dir/ILCD/flows/*.xml")) {
  local $/; open my $g, '<:raw', $ff or next; my $fx = <$g>; close $g;
  my ($u)  = $fx =~ m{<common:UUID>([0-9a-fA-F-]{36})</common:UUID>};
  next unless $u;
  my ($bn) = $fx =~ m{<baseName[^>]*>([^<]+)</baseName>};
  my ($cas)= $fx =~ m{<CASNumber>([^<]+)</CASNumber>};
  my ($ty) = $fx =~ m{<typeOfDataSet>([^<]+)</typeOfDataSet>};
  my @cls;
  while ($fx =~ m{<class[^>]*>([^<]+)</class>}g) { push @cls, $1 }
  $bn //= ''; $cas //= ''; $ty //= '';
  $cas =~ s/^0+//;                       # 000124-38-9 -> 124-38-9
  $fdef{$u} = [ $bn, $cas, $ty, join(' / ', @cls) ];
}

my $out = "$dir/_parsed";
mkdir $out unless -d $out;
open my $m, '>:raw', "$out/meta.tsv" or die $!;
print $m "$_\t$meta{$_}\n" for sort keys %meta;
close $m;
open my $e, '>:raw', "$out/exchanges.tsv" or die $!;
print $e join("\t", @$_), "\n" for @ex;
close $e;
open my $d, '>:raw', "$out/flowdefs.tsv" or die $!;
for my $u (sort keys %fdef) { print $d join("\t", $u, @{$fdef{$u}}), "\n" }
close $d;

printf STDERR "parsed: %s  | %d exchanges | %d flow defs | product=%s\n",
  $meta{baseName}, scalar(@ex), scalar(keys %fdef), $meta{productFlowUuid};
