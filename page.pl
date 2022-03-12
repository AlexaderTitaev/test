#!/usr/bin/perl
use strict;
use JSON;
#use Data::Dumper;
use utf8;

binmode(STDOUT,':utf8');

my ($json_file)=@ARGV;

my (%rep, %pid);

opendir(my $dh, '.') || die "Can't open .: $!";
while (readdir $dh) {
	if ( /page.*json$/ )
	{
		open my $fh, '<', $_  or die "Can't open file $!";
		my $js_str = do { local $/; <$fh> };
		
		my $hashref = decode_json($js_str);
		#print Data::Dumper->Dump(${$hashref}[0]);
		#print ${$hashref}[0]{'id'};
		#print ${$hashref}[0]{'web_url'};
		foreach my $item ( @{$hashref} )
		{
			my %hash = %$item;
		#	print $hash{'project_id'}." ".$hash{'filename'}."\n";
			my ($ext) = $hash{'filename'} =~ /.+\.(\w+)$/;
#			$rep{$ext}{$hash{'project_id'}}  = $rep{$ext}{$hash{'project_id'}}."\t\t".$hash{'filename'}."\n";
			$rep{$ext}{$hash{'project_id'}}  = 1;
		}
		close $fh;
	}
	if ( /projects.*json$/ )
	{
		open my $fh, '<', $_  or die "Can't open file $!";
		my $js_str = do { local $/; <$fh> };
		
		my $hashref = decode_json($js_str);
		#print Data::Dumper->Dump(${$hashref}[0]);
		#print ${$hashref}[0]{'id'};
		#print ${$hashref}[0]{'web_url'};
		foreach my $item ( @{$hashref} )
		{
		        my %hash = %$item;
		        $pid{$hash{'id'}} = '<b>'.$hash{'name_with_namespace'}.'</b> <a href="https://'.$hash{'web_url'}.'">'.$hash{'web_url'};
		}
		close $fh;
	}
}
closedir $dh;
print '<STYLE type="text/css">
        table tr td 
        {
                font-family: Verdana;
                font-size:12pt;
        }
        .w_row
        {
                text-align: left;
                background-color: #ffffff;
        }
        .g_row
        {
                text-align: left;
                background-color: #e2e2f0;
        }
        .f_red
        {
                color: red;
        }
</STYLE>
<META http-equiv="Content-Type" content="text/html" charset="utf-8">
<table bgcolor=#8080ef border=0 cellpadding=0 cellspacing=1 width="100%">';
for my $ext ( keys %rep )
{
	print '<tr align=center bgcolor=#87CEFA>';
	print '<td class="f_red">'.$ext."<td>\n";
	print '<td><table width="100%">';
	my $tpl;
	for my $project_id ( keys %{$rep{$ext}} )
	{
		if ( $tpl == 0 )
		{
			$tpl=1;
		}else
		{
			$tpl=0;
		} 
		print "<tr><td ".&color($tpl).">".$pid{$project_id}."</td></tr>\n";
	}
	print "</table><td></tr>\n";
}
print "</table>";

sub color
{
        my ($template) =@_;
                if ($template eq "1")
                {
                        return 'class="g_row"';
                }else
                {
                        return 'class="w_row"';
                }
}
