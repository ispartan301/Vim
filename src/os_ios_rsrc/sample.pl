#!/usr/local/bin/perl -w
use strict;
use warnings;
use Getopt::Long;
use IO::Socket::INET;
use Tellme::Date;
use File::Basename;

my ($uuid, $host, $date, $tel, $asr, $event, $obs, $utter, $verbose);
GetOptions ("uuid=s"  => \$uuid,
            "host=s"  => \$host,
            "date=s"  => \$date,
            "tel"     => \$tel,
            "asr"     => \$asr,
            "event"   => \$event,
            "obs"     => \$obs,
            "utter"   => \$utter,
            "verbose" => \$verbose);


my $ssh_cmd = '/usr/local/bin/ssh -n'.(defined $verbose ? ' -v' : '');
my $scp_cmd = '/usr/local/bin/scp'.(defined $verbose ? ' -v' : ' -q');
my $grep_cmd = '/usr/local/bin/grep -E';
my $tmlogcat_nix = '/usr/local/bin/tmlogcat';
my $tmlogcat_win = "C:\\tools\\local\\tellme\\bin\\tmlogcat.exe";

use constant AUDIT_ONLY => 1;

sub main
{
    #format search date criteria
    my $search_by_day = ($date =~ m/^\d{4}\/\d{2}\/\d{2}$/) if defined $date;
    my $tmdate = Tellme::Date->new(defined $date ? $date : undef);
    logger("searching tmlerrors by date: ".($search_by_day ? $tmdate->to_cdk : $tmdate->to_string));

    #get all matched tmlerrors.log from the telbox
    my @tmlerrors_logs = get_tmlerrors_logs($search_by_day,$tmdate);
    logger("found ".scalar(@tmlerrors_logs)." matched tmlerrors.log:");
    foreach (@tmlerrors_logs) {
        logger("tmlerrors_log=$_");
    }

    #extract correct tel log from tmlerrors.log
    my $tellog = extract_log(\@tmlerrors_logs,$uuid);
    $tmdate = get_date_from_log($tellog);

    #save tel log
    save_log($uuid,$tellog) if (defined $tel || !defined $asr);

    $tmdate->add_hours(7);
    my $gmt_date = sprintf("%4d-%2.2d-%2.2d-%2.2d",$tmdate->year,$tmdate->month,$tmdate->day,$tmdate->hour);

    if (defined $event) {
        my $gmt_file = "/var/tellme/log/eventlog/$gmt_date.gmt";
        my $out_file = "/var/tmp/$uuid\_$host\_event.log";
        get_binlog($uuid,$gmt_file,$out_file);
    }

    if (defined $obs) {
        my $gmt_file = "/var/tellme/log/obslog/$gmt_date.gmt";
        my $out_file = "/var/tmp/$uuid\_$host\_obs.log";
        get_binlog($uuid,$gmt_file,$out_file);
    }
    exit(0)  if (defined $tel && !defined $asr);

    #get all mrcp sessions and corresponding recserver
    my @sessions = ();
    my %mrcp_map = ();
    initialize_mrcp($tellog,\@sessions,\%mrcp_map);
    logger("found ".scalar(@sessions)." sessions:");

    #loop through each recognition (each mrcp session)
    my $asrlog = q{};
    foreach my $session (@sessions) {
        $host = $mrcp_map{$session};
        logger("session:$session on host:$host");
        my @tmasr_logs = get_tmasr_logs(\@tmlerrors_logs,$session);
        logger("found ".scalar(@tmasr_logs)." matched tmasr.log:");
        foreach (@tmasr_logs) {
            logger("tmasr_log=$_");
        }

        #extract correct rec log from tmasr.log and append
        $asrlog .= ">>>>>START OF SESSION:$session HOST:$host<<<<<\n";
        $asrlog .= extract_log(\@tmasr_logs,$session);
        $asrlog .= ">>>>>END OF SESSION:$session HOST:$host<<<<<\n\n";

        if (defined $event) {
            my $gmt_file = "/tellme/log/eventlog/$gmt_date.gmt";
            my $out_file = "/windows/temp/$session\_$host\_event.log";
            get_binlog($session,$gmt_file,$out_file);
        }

        if (defined $obs) {
            my $gmt_file = "/tellme/log/obslog/$gmt_date.gmt";
            my $out_file = "/windows/temp/$session\_$host\_obs.log";
            get_binlog($session,$gmt_file,$out_file);
        }

        if (defined $utter) {
            my $gmt_file = "/tellme/log/utterancelog/$gmt_date.gmt";
            my $out_file = "/windows/temp/$uuid\_$host\_utterance.log";
            get_binlog($uuid,$gmt_file,$out_file);
        }
    }

    #save rec log
    save_log($uuid,$asrlog) if (@sessions && (defined $asr || !defined $tel));

}

sub get_date_from_log
{
    my $tellog = shift;
    my $date_str = q{};
    if ($tellog =~ m/^\[(\d{2})\/(\d{2})\/(\d{4}):(\d{2}):(\d{2}):(\d{2}) (DST|LT)\]/) {
        $date_str = "$3/$2/$1 $4:$5:$6";
    }
    my $tmdate = Tellme::Date->new($date_str) if ($date_str);
    return $tmdate;
}

sub get_binlog
{
    my ($id,$gmt_file,$out_file) = @_;
    logger("getting data from binary log: $gmt_file");
    my $tmlogcat = ($host =~ m/^tel/ ? $tmlogcat_nix : $tmlogcat_win);
    my $cmd = "$ssh_cmd $host '$tmlogcat -U $id $gmt_file > $out_file'".(defined $verbose ? '' : ' 2>/dev/null');
    logger($cmd,AUDIT_ONLY);
    die "[ERROR]: extract bin log failed" if system($cmd);

    logger("saving ".basename($out_file));
    $cmd = "$scp_cmd $host:$out_file ./";
    logger($cmd,AUDIT_ONLY);
    die "[ERROR]: scp bin log failed" if system($cmd);

    $cmd = "$ssh_cmd $host 'rm $out_file'";
    logger($cmd,AUDIT_ONLY);
    die "[ERROR]: rm tmp bin log failed" if system($cmd);
}

sub get_adjacent_logs
{
    my $tmdate = shift;
    my @adjacent_logs = ();

    $tmdate->minute(0);
    $tmdate->add_hours(1) unless defined $date; #new() is one hour earlier than localtime
    my $log = $tmdate->to_cdk.'-'.sprintf("%2.2d%2.2d",$tmdate->hour,$tmdate->minute);

    push (@adjacent_logs,$log);
    for (1..2) {
        $tmdate->add_hours(1);
        $log = $tmdate->to_cdk.'-'.sprintf("%2.2d%2.2d",$tmdate->hour,$tmdate->minute);
        push (@adjacent_logs,$log);
    }

    return @adjacent_logs;
}

sub get_tmlerrors_logs
{
    my ($search_by_day,$tmdate) = @_;
    my @adjacent_logs = get_adjacent_logs($tmdate) unless $search_by_day;
    my @tmlerrors_logs = ();

    foreach (get_telboxes()) {
        $host = $_;
        if ($search_by_day) {
            $date =~ s/\///g;
            my $cmd = "$ssh_cmd $host '$grep_cmd -l $uuid /var/tellme/log/archive/tmlerrors*.log.$date-*00".(defined $verbose ? "'" : " 2>/dev/null'");
            logger($cmd,AUDIT_ONLY);
            my $out = `$cmd`;
            chomp $out;
            my @log = split(/\n/,$out) if $out;
            push (@tmlerrors_logs,@log) if @log;
        } else {
            foreach (@adjacent_logs) {
                my $cmd = "$ssh_cmd $host '$grep_cmd -l $uuid /var/tellme/log/archive/tmlerrors*.log.$_".(defined $verbose ? "'" : " 2>/dev/null'");
                logger($cmd,AUDIT_ONLY);
                my $out = `$cmd`;
                chomp $out;
                push (@tmlerrors_logs,$out) if $out;
            }
        }
        my $today = Tellme::Date->new();
        if ($tmdate->to_cdk eq $today->to_cdk) {
            my $cmd = "$ssh_cmd $host '$grep_cmd -l $uuid /var/tellme/log/tmlerrors*.log".(defined $verbose ? "'" : " 2>/dev/null'");
            logger($cmd,AUDIT_ONLY);
            my $out = `$cmd`;
            chomp $out;
            push (@tmlerrors_logs,$out) if $out;
        }
        last if @tmlerrors_logs;
    }

    die "[ERROR]:uuid not found in any tmlerrors.log" unless @tmlerrors_logs;
    return @tmlerrors_logs;
}

sub get_telboxes
{
    my @telboxes = ();
    my $sock = IO::Socket::INET->new($host.':4000');
    if (defined $sock) {
        push (@telboxes, $host) if defined $sock;
    } else {
        my $index = 0;
        while (++$index) {
            my $num = ($index < 10 ? '0'.$index : $index);
            my $host = "tel$num.$host";
            my $sock = IO::Socket::INET->new($host.':4000');
            push (@telboxes, $host) if defined $sock;
            last unless (defined $sock);
        }
    }
    die "[ERROR]: Invalid telbox or pod names" unless @telboxes;
    return @telboxes;
}

sub extract_log
{
    my ($log_aref,$id) = @_;
    my $log = q{};
    my @keywords = ();
    foreach (@$log_aref) {
        my $flag = 0;
        logger("extracting data from $_...");
        my $tmp = duplicate_remotelog($_);
        open (TMP, "<$tmp") || die "[ERROR]:Can't read file $tmp";
        my $keywords_aref = get_keywords($tmp,$id);
        push (@keywords,@$keywords_aref);
        logger("found ".scalar(@keywords)." matched keywords in tmlerrors.log:",AUDIT_ONLY);
        foreach (@keywords) {
            logger("keyword: $_",AUDIT_ONLY);
        }
        while (my $line = <TMP>) {
            foreach my $pattern (@keywords) {
                if ($line =~ m/$pattern/) {
                    $log .= $line;
                    $flag++;
                    last;
                }
            }
        }
        close TMP;
        logger("extracted data from $tmp",AUDIT_ONLY) if $flag;

        my $cmd = "rm ./$tmp";
        logger($cmd,AUDIT_ONLY);
        die "[ERROR]: rm tmp file failed" if system($cmd);
    }
    return $log;
}

sub get_keywords
{
    my ($tmp,$id) = @_;
    my @keywords = ();

    if ($tmp =~ m/tmlerrors/) {
        my $cmd = "$grep_cmd '\\[c=[0-9]+\\] CCBIND: s=\\[[0-9]+\\], sid=\\[[0-9]+\\], rtp=\\[[0-9]+\\], hash=\\[[0-9]+\\], callid=\\[$id\\]' $tmp";
        logger($cmd,AUDIT_ONLY);
        my $out = `$cmd`;
        chomp $out;
        if ($out =~ m/\[c=(\d+)\] CCBIND: s=\[(\d+)\], sid=\[(\d+)\], rtp=\[(\d+)\], hash=\[\d+\]/) {
            push (@keywords,$id);
            push (@keywords,"c=$1");
            push (@keywords,"ph=$1");
            push (@keywords,"s=$2");
            push (@keywords,"sid=$3");
            push (@keywords,"sid=".rm_pre_zero($3));
            push (@keywords,"aTelId=".rm_pre_zero($3));
            push (@keywords,"telId=".rm_pre_zero($3));
            push (@keywords,"tel=".rm_pre_zero($3));
            push (@keywords,"id=$3");
            push (@keywords,"sid ".rm_pre_zero($3));
            push (@keywords,"id ".rm_pre_zero($3));
            push (@keywords,"p=$4");
        }

        $cmd = "$grep_cmd 'ACCESS NEW CALL \\(.*UUID:$id\\)' $tmp";
        logger($cmd,AUDIT_ONLY);
        chomp($out = `$cmd`);
        if ($out =~ m/ : (\d+) ACCESS NEW CALL \(.*UUID:$id\)/) {
            push (@keywords,"$1");
            push (@keywords,"reqid=".rm_pre_zero($1));
        }

        if (@keywords > 10) {
            my $sid = $keywords[10];
            $cmd = "$grep_cmd 'INF \\[p=[0-9]+\\].* $sid' $tmp";
            logger($cmd,AUDIT_ONLY);
            chomp($out = `$cmd`);
            if ($out =~ m/INF \[p=(\d+)\].* $sid/) {
                push (@keywords,"p=$1");
            }
        }

        $cmd = "$grep_cmd 'INF mrcp\\[.*\\/[0-9]+\\] MRCP session=.* uuid=$id' $tmp";
        logger($cmd,AUDIT_ONLY);
        chomp($out = `$cmd`);
        my $mid = q{};
        if ($out =~ m/INF mrcp\[(.*)\/\d+\] MRCP session=/) {
            push (@keywords,$1);
            $mid = $1;
        }

        $cmd = "$grep_cmd 'INF mrcp\\[$mid\\/[0-9]+\\] Set RTP server port to [0-9]+' $tmp";
        logger($cmd,AUDIT_ONLY);
        chomp($out = `$cmd`);
        foreach (split(/\n/,$out)) {
            if (m/INF mrcp\[$mid\/\d+\] Set RTP server port to (\d+)/) {
                my $port = $1;
                my $cmd = "$grep_cmd 'INF \\[p=[0-9]+\\].* successfully activated; talking to [0-9]+\\.[0-9]+\\.[0-9]+\\.[0-9]+:$port' $tmp";
                logger($cmd,AUDIT_ONLY);
                my $out = `$cmd`;
                chomp $out;
                if ($out =~ m/INF \[p=(\d+)\].* successfully activated; talking to \d+\.\d+\.\d+\.\d+:$port/) {
                    push (@keywords,"p=$1");
                }
            }
        }

        $cmd = "$grep_cmd 'INF garr\\[$mid\\/[0-9]+\\] deactivateAndRelease recoResource=' $tmp";
        logger($cmd,AUDIT_ONLY);
        chomp($out = `$cmd`);
        if ($out =~ m/INF garr\[$mid\/\d+\] deactivateAndRelease recoResource=(\w+)/) {
            push (@keywords,"rr=$1");
        }

    } elsif ($tmp =~ m/tmasr/) {
        my $cmd = "$grep_cmd 'INF \\[$id,[0-9]+\\] uuid $id' $tmp";
        logger($cmd,AUDIT_ONLY);
        my $out = `$cmd`;
        chomp $out;
        if ($out =~ m/INF \[$id,\d+\] uuid $id/) {
            push (@keywords,$id);
        }

        $cmd = "$grep_cmd 'INF \\[$id,[0-9]+\\] Link \\[[0-9]+\\]\\[[0-9]+\\]' $tmp";
        logger($cmd,AUDIT_ONLY);
        chomp($out = `$cmd`);
        if ($out =~ m/INF \[$id,\d+\] Link \[\d+\]\[(\d+)\]/) {
            push (@keywords,"$1");
        }
    }

    return \@keywords;
}

sub rm_pre_zero
{
    my $str = shift;
    $str =~ s/^0+//;
    return $str;
}

sub initialize_mrcp
{
    my ($tellog,$sessions_aref,$mrcp_href) = @_;
    my $session = q{};
    foreach (split(/\n/,$tellog)) {
        $session = $1 if (/MRCP session=(.*) uuid=$uuid/);
        if ($session && /successfully activated; talking to \d+\.\d+\.\d+\.\d+:\d+ {(.*)\.tellme\.com}/) {
            push (@$sessions_aref,$session);
            $mrcp_href->{$session} = $1;
            $session = q{};
        }
    }
}

sub save_log
{
    my ($id,$content) = @_;
    my $type = ($host =~ m/^tel/ ? 'tmlerrors' : 'tmasr');
    my $logfile = $id.'_'.$host.'_'.$type.'.log';
    open (FILE, ">$logfile") || die "[ERROR]:Can't write file $logfile";
    print FILE "$content";
    logger("saving $logfile");
    close FILE;
}

sub get_tmasr_logs
{
    my ($tmlerrors_aref,$session) = @_;
    my @tmasr_logs = ();
    my $log = q{};
    foreach (@$tmlerrors_aref) {
        $log = $_;
        if (m/^\/var\/tellme\/log\/tmlerrors.*\.log$/) {
            my $cmd = "$ssh_cmd $host 'select-string -pattern $session -list /tellme/log/tmasr.log'".(defined $verbose ? '' : ' 2>/dev/null');
            logger($cmd,AUDIT_ONLY);
            my $out = `$cmd`;
            push (@tmasr_logs,"/tellme/log/tmasr.log") if $out;
        } elsif (m/^\/var\/tellme\/log\/archive\/tmlerrors.*\.log\.(\d{8}-\d{4})$/) {
            my $cmd = "$ssh_cmd $host 'select-string -pattern $session -list /tellme/log/archive/tmasr.log.$1'".(defined $verbose ? '' : ' 2>/dev/null');
            logger($cmd,AUDIT_ONLY);
            my $out = `$cmd`;
            push (@tmasr_logs,"/tellme/log/archive/tmasr.log.$1") if $out;
        }
    }
    while ($log =~ m/\.log\.(\d{8}-\d{4})$/) {
        my $date = get_next_date($1);
        my $cmd = "$ssh_cmd $host 'ls /tellme/log/archive/tmasr.log.$date' >/dev/null 2>&1";
        logger($cmd,AUDIT_ONLY);
        if (system($cmd)) { 
            $log = "/tellme/log/tmasr.log";
        } else {
            $log = "/tellme/log/archive/tmasr.log.$date";
        }

        $cmd = "$ssh_cmd $host 'select-string -pattern $session -list $log'".(defined $verbose ? '' : ' 2>/dev/null');
        logger($cmd,AUDIT_ONLY);
        my $out = `$cmd`;
        if ($out) {
            push (@tmasr_logs,$log);
        } else {
            last;
        }
    }
    die "[ERROR]:session not found in any tmasr.log" unless @tmasr_logs;
    return (@tmasr_logs);
}

sub get_next_date
{
    my $date = shift;
    if ($date =~ m/(\d{4})(\d{2})(\d{2})-(\d{2})(\d{2})/) {
        my $tmdate = Tellme::Date->new("$1/$2/$3 $4:$5");
        $tmdate->add_hours(1);
        $date = $tmdate->to_cdk.'-'.sprintf("%2.2d%2.2d",$tmdate->hour,$tmdate->minute);
    }
    return $date;
}

sub duplicate_remotelog
{
    my $log = shift;
    my $tmp = basename($log).'.tmp';

    if ($log =~ m/log\.\d{8}-\d{4}/) {
        my $cmd = "$scp_cmd $host:$log ./$tmp";
        logger($cmd,AUDIT_ONLY);
        die "[ERROR]: scp file failed" if system($cmd);
    } else {
        my $rlog = ($log =~ m/tmasr/ ? 'C:\\tellme\\log\\tmasr.log' : $log);
        my $rtmp = ($log =~ m/tmasr/ ? 'C:\\Windows\\Temp\\tmasr.log.tmp' : '/var/tmp/tmlerrors.log.tmp');
        my $rtmp2 = ($log =~ m/tmasr/ ? '/Windows/Temp/tmasr.log.tmp' : '/var/tmp/tmlerrors.log.tmp');

        my $cmd = "$ssh_cmd $host 'cp $rlog $rtmp'";
        logger($cmd,AUDIT_ONLY);
        die "[ERROR]: cp file failed" if system($cmd);
        $cmd = "$scp_cmd $host:$rtmp2 ./$tmp";
        logger($cmd,AUDIT_ONLY);
        die "[ERROR]: scp file failed" if system($cmd);
        $cmd = "$ssh_cmd $host 'rm $rtmp'";
        logger($cmd,AUDIT_ONLY);
        die "[ERROR]: rm file failed" if system($cmd);
    }
    return $tmp;
}

sub logger
{
    my ($line,$audit_only) = @_;
    open AUDITLOG, ">>$uuid\_audit.log" || die $!;
    print "$line\n" unless(defined $audit_only);
    print AUDITLOG "$line\n";
    close AUDITLOG;
}

sub usage
{
    print <<"__END_OF_USAGE__";
Description:
    Grab the tel log and asr log by uuid and the hostname. Date parameter is optional, it searches 3 hours around the specified datetime. It searches by current datetime if no specific date is provided.

Usage: callsearch.pl --uuid <uuid> -h <hostname> [-d <datetime>] [-taeov --utter]
Options:     --uuid    (required) specify call uuid
          -h --host    (required) specify telbox or POD name
          -d --date    (optional) specify datetime in format yyyy/mm/dd[ hh:mm]
          -t --tel     (optional) output tel log only
          -a --asr     (optional) output asr log only
          -e --event   (optional) output event log
          -o --obs     (optional) output observe log
             --utter   (optional) output utterance log
          -v --verbose (optional) verbose mode, cause to print debug message

Sample:
    callsearch.pl --uuid 57fbe680-bdf5-11e0-0280-001517c0bde4 -h tel03.p208.sv2
    callsearch.pl --uuid 57fbe680-bdf5-11e0-0280-001517c0bde4 -h tel03.p208.sv2 -d 2011/08/03
    callsearch.pl --uuid 0d7f008c-c2ec-11e0-0280-001517c0bde4 -h p210.sv2 -d '2011/08/09 17:56' -e -o --utter
__END_OF_USAGE__
    exit(0);
}

usage() unless (defined $uuid && defined $host);
main();

=head1 NAME

callsearch.pl - utility script to get a variety of call logs

=head1 AUTHOR

Victor Lu E<lt>victorl@tellme.comE<gt>

=head1 COPYRIGHT

Copyright (c) 2011 Microsoft Tellme.

=cut
