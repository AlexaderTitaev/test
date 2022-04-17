#!/usr/bin/perl
use strict;
use JSON;
use utf8;
use Scalar::Util qw(blessed dualvar isdual readonly refaddr reftype);

my (%rep, %rep2);

binmode(STDOUT,':utf8');

open my $fh, '< vault-cloud.json'  or die "Can't open file $!";
my $js_str = do { local $/; <$fh> };

my $hashref = decode_json($js_str);
expand_hash($hashref, "");
close $fh;



for my $proj ( keys %rep )
{
        for my $stend ( keys %{$rep{$proj}} )
        {
                print "$proj,$stend,".$rep{$proj}{$stend}{'host'}.','.$rep{$proj}{$stend}{'login'}."\n";
        }
}
print "=====================================\n";
for my $proj ( keys %rep2 )
{
        for my $stend ( keys %{$rep2{$proj}} )
        {
                print "$proj,$stend,".$rep2{$proj}{$stend}."\n";
        }
}


sub get_data 
{
        my ($int_ref, $desc, $stend) = @_;
        my %int_hash = %{$int_ref};

        for my $item (keys %int_hash)
        {
#               print "get_data $item\n";
                if ( $item =~ /ConnectionStrings__(RabbitMQ|RabbitMqBridge|MqConnectionString|AlfabankRabbitMQ)/i )
                {
                        $rep2{$desc}{$stend} = $int_hash{$item};
                        next;
                }elsif ( $item =~ /(Rabbit|bus-properties)/i )
                {
                        $rep{$desc}{$stend}{'host'}=$int_hash{$item} if $item =~ /RABBIT_MAIL_HOST|RABBIT_HOST|RABBITMQ_?HOST|bus-properties_host/i ;
                        $rep{$desc}{$stend}{'login'}=$int_hash{$item} if $item =~ /LOGIN|USERNAME/i ;
                        $rep{$desc}{$stend}{'password'}=$int_hash{$item} if $item =~ /PASSWORD/i ;
                }
        }

}

sub expand_hash
{
        my ($exp_ref, $desc) = @_;
        my %exp_hash = %{$exp_ref};
        for my $level ( keys %exp_hash )
        {
                my $type = reftype $exp_hash{$level};
                if ( defined($type) and $type eq 'HASH' )
                {
                        my $ref1 = \%{$exp_hash{$level}};
                        if ( expand_hash($ref1,"$desc $level") == 1)
                        {
                                get_data($ref1, $desc, $level);
                        }
                }else
                {
                        return 1;
                }
        }
        return 0;
}
