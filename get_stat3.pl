#!/usr/bin/perl
use strict;
use RRDs;
use Time::Local;
use MIME::Entity;
use Net::Patricia;

my $pt = new Net::Patricia;


my @path=(
'/var/log/ng_ipacct/'
);

my $output_path='/usr/local/www/data/calamaris/ng/';
my $from='root@materik.com';
my $to='admin@materik.com';
my $top=25;
my $bottom='<a href="http://mail.materik.com/calamaris/ng/';

my ($client_id, $iface, $date_string, $client_ip, $drop_ip)=@ARGV;
my $color;

if (!defined($client_ip))
{
        print STDERR "\t usage:\n\t./get_stat.pl client_id interface 'date_string' 'some clients ip' ['some drop ip']\n";
        print STDERR "for examp.\n\t./get_stat.pl materik.com rl1 '2004-06-01..31, 2004-7-1..8' 195.206.51.150/32\n";
        exit;
}

my @date=get_date($date_string);

print STDERR "calculate  for client ip addr $client_ip\n";
for my $val (split(' ',$client_ip))
{
        $pt->add_string($val, 'my_ip');
}
print STDERR "calculate  for drop ip addr $drop_ip\n";
for my $val (split(' ',$drop_ip))
{
        $pt->add_string($val, 'drop_ip');
}

for my $date ( @date )
{
        $bottom.=$client_id.'_'.$date.'.html">full traffic look this</a>';
        for my $path (@path)
        {
                print $path.$date.'.'.$iface."\n";
                if ( -f $path.$date.'.'.$iface )
                {
                        print STDERR "generate for  $client_id on $date\n";
                        &generate_stat($client_id, $path.$date.'.'.$iface, $date);
                } elsif ( -f $path.$date.'.'.$iface.'.bz2' )
                {
                        print STDERR "generate for  $client_id on $date\n";
                        &generate_stat($client_id, $path.$date.'.'.$iface.'.bz2', $date);
                } else
                {
                        print " NOTHING !\n";
                }
        }
}

sub generate_stat
{
        my ($client_id, $path, $date)=@_;

        if ( $path =~ /bz2$/ )
        {
                $path = "/usr/bin/bzcat $path | ";
        }

        my ($string_out, $string, %total_in, %total_out, %total_by_proto, %total_by_port, %control_hash);
        my ($all_traff, $who, $year, $month, $day, $hour, $min, $sec, $out_name, $in, $out);
#195.206.53.50   3372    205.188.8.75    5190    6       1       40      1095778780
        my ($SrcIPaddress,$SrcP,$DstIPaddress,$DstP,$P,$Pkts,$Octets,$TimeStamp);
        my $starttime=0;
        my $endtime=0;
        my $count=0;
        my $updatetime=0;
        my $TimeStamp=0;
        ($year, $month, $day)=$date=~/(\d{4})(\d{2})(\d{2})/;
        ($starttime, $endtime)=&create_rrd($year,$month,$day);
        $updatetime=$starttime+60;

        open(IN,$path);
        while(<IN>)
        {
                next if /Accouting exceed thresho/;
                chomp;
                ($SrcIPaddress,$SrcP,$DstIPaddress,$DstP,$P,$Pkts,$Octets,$TimeStamp) = split(' ');
                if ($updatetime <= $TimeStamp )
                {
                        $in*=8;
                        $out*=8;
                        update_rrd($updatetime, $in, $out);
                        $in=0;
                        $out=0;
                        $updatetime=$TimeStamp+60;
                }

                my $whodest=$pt->match_string($DstIPaddress);
                my $whosrc=$pt->match_string($SrcIPaddress);

                next if ( $whodest eq 'drop_ip' or $whosrc eq 'drop_ip' );
                next if ( $whosrc eq 'my_ip' and $whodest eq 'my_ip' );

                if (  $whosrc eq 'my_ip' )
                {
                        $who='from_client_to_'.$DstIPaddress;
                        $all_traff='from_client_to_all';
                        $in+=$Octets;
                        $total_out{$DstIPaddress}+=$Octets;
                        $total_out{'all'}+= $Octets;
                }else
                {
                        $who=$SrcIPaddress;
                        $all_traff='all';
                        $control_hash{$who}+= $Octets;
                        $control_hash{'all'}+= $Octets;
                        $out+=$Octets;
                        $total_in{$SrcIPaddress}+=$Octets;
                        $total_in{'all'}+= $Octets;
                }



#               $total{$who}+= $Octets;


                if ( $P == 1  )
                {
                        $total_by_proto{$who}{'icmp'}+= $Octets;
                        $total_by_proto{$all_traff}{'icmp'}+= $Octets;
                }elsif ( $P == 17 )
                {
                        $total_by_proto{$who}{'udp'}+= $Octets;
                        $total_by_proto{$all_traff}{'udp'}+= $Octets;
                        if( $SrcP == 53 or $DstP == 53 )
                        {
                                $total_by_port{$who}{'named'}+= $Octets;
                                $total_by_port{$all_traff}{'named'}+= $Octets;
                        }
                }elsif ( $P == 6  )
                {

                        $total_by_proto{$who}{'tcp'}+= $Octets;
                        $total_by_proto{$all_traff}{'tcp'}+= $Octets;
                        if( $SrcP == 25 or $DstP == 25 )
                        {
                                $total_by_port{$who}{'smtp'}+= $Octets;
                                $total_by_port{$all_traff}{'smtp'}+= $Octets;
                        }elsif ( $SrcP == 110 or $DstP ==  110 )
                        {
                                $total_by_port{$who}{'pop3'}+= $Octets;
                                $total_by_port{$all_traff}{'pop3'}+= $Octets;
                        }elsif ( $SrcP == 80 or $DstP == 80 )
                        {
                                $total_by_port{$who}{'http'}+= $Octets;
                                $total_by_port{$all_traff}{'http'}+= $Octets;
                        }elsif ( $SrcP == 20 or $SrcP == 21 or $DstP == 20 or $DstP == 21)
                        {
                                $total_by_port{$who}{'ftp'}+= $Octets;
                                $total_by_port{$all_traff}{'ftp'}+= $Octets;
                        }else
                        {
                                $total_by_port{$who}{'others'}+= $Octets;
                                $total_by_port{$all_traff}{'others'}+= $Octets;
                        }
                }else
                {
                        $total_by_proto{$who}{'others'}+= $Octets;
                        $total_by_proto{$all_traff}{'others'}+= $Octets;
                }
        }
        close(IN);

        print STDERR "write png ".$output_path.$client_id."_".$date.".png\n";
        RRDs::graph  $output_path.$client_id."_".$date.".png",
                "--start", $starttime,
                "--end", $endtime,
                "--title='$client_id $date'",
                "--alt-autoscale",
                "--imgformat","PNG",
                "-v Bits per second",
                "--base", 1024,
                "-i",
#               "--width", 800,
#               "--height", 200,
                "--color","CANVAS#000000",
                "--color","BACK#101010",
                "--color","FONT#C0C0C0",
                "--color","MGRID#80C080",
                "--color","GRID#808020",
                "--color","FRAME#808080",
                "--color","ARROW#FFFFFF",
                "--color","SHADEA#404040",
                "DEF:out=tmp.rrd:ds0:MAX",
                "DEF:in=tmp.rrd:ds1:MAX",
                "CDEF:cout=0,out,-",
                "AREA:in#00FF00:\"From internet to $client_id\"",
                "AREA:cout#0000ff:\"From $client_id to internet\"",
                "LINE1:in#FF0000:",
                "LINE1:cout#FF0000:";
                my $ERR=RRDs::error;
                die "ERROR while create graph tmp.rrd: $ERR\n" if $ERR;

        print STDERR "write html\n";

        $string_out = '
<STYLE type="text/css">
        table tr td 
        {
                font-family: Verdana;
                font-size:10pt;
        }
        .w_row
        {
                text-align: right;
                background-color: #ffffff;
        }
        .g_row
        {
                text-align: right;
                background-color: #e2e2f0;
        }
        .f_red
        {
                color: red;
        }
        .ip
        {
                text-align: left;
                padding-left: 5;
        }
        .total
        {
                padding-right: 5;
        }
        .total_red
        {
                color: red;
                padding-right: 5;
        }
        .g_tcp_in
        {
                background-color: #FFCC00;
                padding-right: 5;
        }
        .g_tcp_out
        {
                background-color: #FFCC00;
                padding-right: 5;
                color: red;
        }
        .g_udp_in
        {
                background-color: #00FF66;
                padding-right: 5;
        }
        .g_udp_out
        {
                background-color: #00FF66;
                padding-right: 5;
                color: red;
        }
        .g_icmp_in
        {
                background-color: #00CCFF;
                padding-right: 5;
        }
        .g_icmp_out
        {
                background-color: #00CCFF;
                padding-right: 5;
                color: red;
        }
        .w_tcp_in
        {
                background-color: #FFFFCC;
                padding-right: 5;
        }
        .w_tcp_out
        {
                background-color: #FFFFCC;
                padding-right: 5;
                color: red;
        }
        .w_udp_in
        {
                background-color: #CCFFCC;
                padding-right: 5;
        }
        .w_udp_out
        {
                background-color: #CCFFCC;
                padding-right: 5;
                color: red;
        }
        .w_icmp_in
        {
                background-color: #CCFFFF;
                padding-right: 5;
        }
        .w_icmp_out
        {
                background-color: #CCFFFF;
                padding-right: 5;
                color: red;
        }
</STYLE>
<META http-equiv="Content-Type" content="text/html; charset=koi8-r">
';
        $string_out.= "<P align=\"center\">\n";
        $string_out.= "<b>ate.</b>\n";
        $string_out.= "<P align=\"left\">\n";
        $string_out.= " .\n";
        $string_out.= "<br><img border=0 src=\"".$client_id."_".$date.".png\">\n";
        $string_out.= "<P align=\"left\">\n";
        $string_out.= " ip   .<br>\n";
        $string_out.= "tcp http - www >\n";
        $string_out.= "tcp smtp -  >\n";
        $string_out.= "tcp pop3 - br>\n";
        $string_out.= "tcp ftp - ftp >\n";
        $string_out.= "tcp other - ,  active  p <br>\n";
        $string_out.= "udp named - ip     <br>\n";
        $string_out.= '<table bgcolor=#8080ef border=0 cellpadding=0 cellspacing=1 width="100%">';
        $string_out.= '<tr align=center bgcolor=#87CEFA>
                        <td rowspan=3>ip</TD>
                        <td rowspan=2 colspan=2>total</td>
                        <td COLSPAN=12 bgcolor=#FF9900>tcp</td>
                        <td colspan=4 bgcolor=#99FF00>udp</td>
                        <td rowspan=2  colspan=2 bgcolor=#0066FF>icmp</td>
                        <td rowspan=2 colspan=2>others</td></tr>
                        <tr align=center bgcolor=#87CEFA>
                        <td colspan=2 bgcolor=#FF9900>all</td>
                        <td colspan=2 bgcolor=#FF9900>http</td>
                        <td colspan=2 bgcolor=#FF9900>smtp</td>
                        <td colspan=2 bgcolor=#FF9900>pop3</td>
                        <td colspan=2 bgcolor=#FF9900>ftp</td>
                        <td colspan=2 bgcolor=#FF9900>others</td>
                        <td colspan=2 bgcolor=#99FF00>all</td>
                        <td colspan=2 bgcolor=#99FF00>named</td>
                        </tr>
                        <tr align=center bgcolor=#87CEFA>
                        <td>in</td><td class="f_red">out</td>
                        <td>in</td><td class="f_red">out</td>
                        <td>in</td><td class="f_red">out</td>
                        <td>in</td><td class="f_red">out</td>
                        <td>in</td><td class="f_red">out</td>
                        <td>in</td><td class="f_red">out</td>
                        <td>in</td><td class="f_red">out</td>
                        <td>in</td><td class="f_red">out</td>
                        <td>in</td><td class="f_red">out</td>
                        <td>in</td><td class="f_red">out</td>
                        <td>in</td><td class="f_red">out</td>
                        </tr>';

        open(OUT,">".$output_path.$client_id."_".$date.".html");
        print OUT $string_out;
        for $who (sort{$total_in{$b}<=>$total_in{$a}}( keys %total_in ))
        {
                $out_name='from_client_to_'.$who;
                &ch_color("e2e2f0","ffffff");
                $string = "\n\t<tr ".&color($color).">";
                $string.= '
                <td class="ip">'.$who.'</td>
                <td class="total">'.&kb($total_in{$who}).'</td>
                <td class="total_red">'.&kb($total_out{$who}).'</td>
                <td '.&color("tcp",$color,"in").'>'.&kb($total_by_proto{$who}{'tcp'}).'</td>
                <td '.&color("tcp",$color,"out").'>'.&kb($total_by_proto{$out_name}{'tcp'}).'</td>
                <td '.&color("tcp",$color,"in").'>'.&kb($total_by_port{$who}{'http'}).'</td>
                <td '.&color("tcp",$color,"out").'>'.&kb($total_by_port{$out_name}{'http'}).'</td>
                <td '.&color("tcp",$color,"in").'>'.&kb($total_by_port{$who}{'smtp'}).'</td>
                <td '.&color("tcp",$color,"out").'>'.&kb($total_by_port{$out_name}{'smtp'}).'</td>
                <td '.&color("tcp",$color,"in").'>'.&kb($total_by_port{$who}{'pop3'}).'</td>
                <td '.&color("tcp",$color,"out").'>'.&kb($total_by_port{$out_name}{'pop3'}).'</td>
                <td '.&color("tcp",$color,"in").'>'.&kb($total_by_port{$who}{'ftp'}).'</td>
                <td '.&color("tcp",$color,"out").'>'.&kb($total_by_port{$out_name}{'ftp'}).'</td>
                <td '.&color("tcp",$color,"in").'>'.&kb($total_by_port{$who}{'others'}).'</td>
                <td '.&color("tcp",$color,"out").'>'.&kb($total_by_port{$out_name}{'others'}).'</td>
                <td '.&color("udp",$color,"in").'>'.&kb($total_by_proto{$who}{'udp'}).'</td>
                <td '.&color("udp",$color,"out").'>'.&kb($total_by_proto{$out_name}{'udp'}).'</td>
                <td '.&color("udp",$color,"in").'>'.&kb($total_by_port{$who}{'named'}).'</td>
                <td '.&color("udp",$color,"out").'>'.&kb($total_by_port{$out_name}{'named'}).'</td>
                <td '.&color("icmp",$color,"in").'>'.&kb($total_by_proto{$who}{'icmp'}).'</td>
                <td '.&color("icmp",$color,"out").'>'.&kb($total_by_proto{$out_name}{'icmp'}).'</td>
                <td class="total">'.&kb($total_by_proto{$who}{'others'}).'</td>
                <td class="total_red">'.&kb($total_by_proto{$out_name}{'others'}).'</td>';
                $string.= "\n\t</tr>\n";
                $string_out.=$string if $top > $count;
                $count++;
                print OUT $string;
                delete($total_out{$who});
        }

        for $who ( keys %total_out )
        {
                &ch_color("e2e2f0","ffffff");
                $out_name='from_client_to_'.$who;
                print OUT "\n\t<tr ".&color($color).">\n";
                print OUT '
                <td class="ip">'.$who.'</td>
                <td class="total">'.&kb($total_in{$who}).'</td>
                <td class="total_red">'.&kb($total_out{$who}).'</td>
                <td '.&color("tcp",$color,"in").'>'.&kb($total_by_proto{$who}{'tcp'}).'</td>
                <td '.&color("tcp",$color,"out").'>'.&kb($total_by_proto{$out_name}{'tcp'}).'</td>
                <td '.&color("tcp",$color,"in").'>'.&kb($total_by_port{$who}{'http'}).'</td>
                <td '.&color("tcp",$color,"out").'>'.&kb($total_by_port{$out_name}{'http'}).'</td>
                <td '.&color("tcp",$color,"in").'>'.&kb($total_by_port{$who}{'smtp'}).'</td>
                <td '.&color("tcp",$color,"out").'>'.&kb($total_by_port{$out_name}{'smtp'}).'</td>
                <td '.&color("tcp",$color,"in").'>'.&kb($total_by_port{$who}{'pop3'}).'</td>
                <td '.&color("tcp",$color,"out").'>'.&kb($total_by_port{$out_name}{'pop3'}).'</td>
                <td '.&color("tcp",$color,"in").'>'.&kb($total_by_port{$who}{'ftp'}).'</td>
                <td '.&color("tcp",$color,"out").'>'.&kb($total_by_port{$out_name}{'ftp'}).'</td>
                <td '.&color("tcp",$color,"in").'>'.&kb($total_by_port{$who}{'others'}).'</td>
                <td '.&color("tcp",$color,"out").'>'.&kb($total_by_port{$out_name}{'others'}).'</td>
                <td '.&color("udp",$color,"in").'>'.&kb($total_by_proto{$who}{'udp'}).'</td>
                <td '.&color("udp",$color,"out").'>'.&kb($total_by_proto{$out_name}{'udp'}).'</td>
                <td '.&color("udp",$color,"in").'>'.&kb($total_by_port{$who}{'named'}).'</td>
                <td '.&color("udp",$color,"out").'>'.&kb($total_by_port{$out_name}{'named'}).'</td>
                <td '.&color("icmp",$color,"in").'>'.&kb($total_by_proto{$who}{'icmp'}).'</td>
                <td '.&color("icmp",$color,"out").'>'.&kb($total_by_proto{$out_name}{'icmp'}).'</td>
                <td class=total">'.&kb($total_by_proto{$who}{'others'}).'</td>
                <td class="total_red">'.&kb($total_by_proto{$out_name}{'others'}).'</td>';
                print OUT "\n\t</tr>\n";
        }

        print OUT "</table>\n";
        $string_out.= "</table>\n".$bottom;
        close(OUT);
        send_mail($to, $date, $string_out);
}

sub color
{
        my ($template, $tr_color, $i_o) =@_;
        if ( !defined($tr_color) )
        {
                if ($template eq "e2e2f0")
                {
                        return 'class="g_row"';
                }else
                {
                        return 'class="w_row"';
                }
        }else
        {
                if ($tr_color eq "e2e2f0")
                {
                        return 'class="g_'.$template.'_'.$i_o.'"';
                }else
                {
                        return 'class="w_'.$template.'_'.$i_o.'"';
                }
        } 
}

sub kb
{
        return sprintf("%.02f", $_[0]/1024);
}

sub mb
{
        return sprintf("%.02f", $_[0]/1024/1024);
}

sub ch_color
{
        if ( $color eq $_[0] )
        {
                $color=$_[1];   
        }else
        {
                $color=$_[0];
        }
}

sub create_rrd
{
        my ($year,$month,$day)=@_;
        $month--;
        $year-=1900;
        my $up_abs='ABSOLUTE';
        my $minhb=1800;
        my $absi='U';
        my $abso='U';
        my $starttime=timelocal(0,0,0,$day,$month,$year);
        my $endtime=$starttime+86400;
        my $createtime=$starttime-300;


        unlink('tmp.rrd');

        RRDs::create ("tmp.rrd", "--start",  "$createtime",
                        "--step", 300,
                        "DS:ds0:$up_abs:$minhb:0:$absi",
                        "DS:ds1:$up_abs:$minhb:0:$abso",
                        "RRA:AVERAGE:0.5:1:600",
                        "RRA:AVERAGE:0.5:6:700",
                        "RRA:AVERAGE:0.5:24:775",
                        "RRA:AVERAGE:0.5:288:797",
                        "RRA:MAX:0.5:1:600",
                        "RRA:MAX:0.5:6:700",
                        "RRA:MAX:0.5:24:775",
                        "RRA:MAX:0.5:288:797");

        my $ERR=RRDs::error;
        die "ERROR while creating tmp.rrd: $ERR\n" if $ERR;
        return ($starttime, $endtime);
}

sub update_rrd
{
        my ($updatetime, $in, $out)=@_;
        RRDs::update "tmp.rrd", "$updatetime:$in:$out";
        my $ERR=RRDs::error;
        die "ERROR while updating tmp.rrd: $ERR\n" if $ERR;
}

sub get_date
{
        my ($i, @date_arr, $date);
        my @sub_string=split(',',$_[0]);
        for my $val (@sub_string)
        {
                $val =~ /(\d{4})-(\d{1,2})-(\d{1,2}).?.?(\d{1,2})?/;
                if ( defined($4) )
                {
                        for ($i=$3;$i<=$4;$i++)
                        {
                                $date=sprintf("%d-%02d-%02d", $1, $2, $i);
                                push(@date_arr, $date);
                        }
                }else
                {
                        $date=sprintf("%d%02d%02d", $1, $2, $3);
                        push(@date_arr, $date);
                }
        }
        return @date_arr;
}


sub send_mail
{
        my ($to, $date, $string)=@_;
        my $path=$output_path;
        my $tpl=$client_id.'_';

        my $top = MIME::Entity->build(
                                From    => $from,
                                To      => $to,
                                Type    => "multipart/mixed",
                                Subject => "Detail stat on $date, top$top");
        $top->attach(Data        => $string,
                     Type       => 'text/html;',
                     Filename    => $tpl.$date.".html",
                     Encoding    => "quoted-printable");
          
        $top->attach(Path       => $path.$tpl.$date.".png",
                     Type       => "image.png",
                     Filename    => $tpl.$date.".png",
                     Encoding    => "base64");
        open SENDMAIL, "|/usr/sbin/sendmail -t" or die "sendmail: $!";
        $top->print(\*SENDMAIL);
        close SENDMAIL or die "sendmail failed: $!";
}
