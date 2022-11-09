#!/usr/bin/perl
use strict;
#use YAML::XS 'LoadFile';
use YAML qw(LoadFile);
use utf8;
use Scalar::Util qw(blessed dualvar isdual readonly refaddr reftype);
use Data::Dumper;

binmode(STDOUT,':utf8');
my $hashref = LoadFile($ARGV[0]);
#my %hash = %{$hashref};
#print Dumper($hashref);

expand_hash($hashref, "", 1);

sub get_data 
{
        my ($int_ref, $desc, $stend) = @_;
        my %int_hash = %{$int_ref};

        for my $item (keys %int_hash)
        {
               print '"'.$desc."_".$item.'": "'.$int_hash{$item}."\",\n";
        }

}

sub expand_hash
{
        my ($exp_ref, $desc, $base_level) = @_;
        my %exp_hash = %{$exp_ref};
        for my $level ( keys %exp_hash )
        {
                my $type = reftype $exp_hash{$level};
                if ( defined($type) and $type eq 'HASH' )
                {
                        my $ref1 = \%{$exp_hash{$level}};
                        my $desc2;
                        if ( $desc eq "" )
                        {
                                $desc2=$level;
                        }else
                        {
                                $desc2=$desc.'_'.$level;
                        }
                        if ( expand_hash($ref1,$desc2, 0) == 1)
                        {
                                get_data($ref1, $desc2);
                        }
                }else
                {
                        return 1 if $base_level == 0;
                }
        }
        return 0;
}
