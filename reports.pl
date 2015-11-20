#!/usr/bin/perl
use strict;
use warnings;
use Scalar::Util qw(looks_like_number);
use File::Copy;
use utf8;

#define variables
my $app = "<app bundle>";
my $app_name = "<app display name>";
my $dev = "<your dev number>";
my $from = "...";
my $to = "...";
my %versions = (2, "1.0.1", 4, "1.0.2", 5, "2.0.0", 6 ,"2.0.1", 7, "2.0.2");

#$date is typically 2 days ago
my $date = $ARGV[0] or die "Date missing! <yyyy-MM-dd>\n";
(my $time = $date) =~s/-//g;
my $month = substr $time, 0, 6;

#get stored accumulated upgrades
my %upgrades = ();
my $file = $app."_acc.txt";
my $latest_acc = 0;
if (-e $file) {
	open FILE, "<$file";
	while (my $line = <FILE>) {
		chomp $line;
		my @fields = split "," , $line;
		#check if there's a record for today
		$latest_acc = $fields[0];
		#die "Report for $date is already sent!" if $latest_acc == $time;
		$upgrades{$fields[1]} = $fields[2];
	}
	close FILE;
}

#fetch
#copy($app."/.boto", ".boto") or die "Could not load .boto file: $!"; for multiple accounts
system "python C:/gsutil/gsutil cp -r gs://pubsite_prod_rev_".$dev."/stats/installs/installs_".$app."_".$month."_app_version.csv ".$app."/";

$file = $app."/installs_".$app."_".$month."_app_version.csv";
open my $data, '<:encoding(UTF-16)', $file or die "Cannot open '$file': $!\n";

#parse
my @today = ();
my @all = ();
my $latest_vcode = 0;
my $acc = "-";
while (my $line = <$data>) {
	chomp $line;
	my @fields = split "," , $line;
	next if !looks_like_number($fields[2]);
	
	my $timex = $fields[0];	#get date
	$timex=~s/-//g;
	
	my $vcode = $fields[2];
	$upgrades{$vcode} = $fields[6] + ($upgrades{$vcode} or 0) if $latest_acc < $timex && $timex <= $time;
	
	if ($fields[0] eq $date) {
		my $vname = ($versions{$vcode} or "?");
		#get latest version accumulated upgrades
		if ($vcode > $latest_vcode) {
			$acc = ($upgrades{$vcode} or "-");
			$latest_vcode = $vcode;
		}
		
		push @today, "Versión $vname:		$fields[9]		$fields[6]\n" if $fields[9] > 0 || $fields[6] > 0;
		
		my $ret = $fields[8] > 0? sprintf "%.1f%%", 100*$fields[7]/$fields[8]: "?";
		push @all, "Versión $vname:		$fields[8]		-		$fields[7]		$ret\n";
	}
}
die "No info for today's report!\n" unless scalar(@all);
@all = sort {$b cmp $a} @all;	#order by version, to get the last 3
@today = sort {$b cmp $a} @today;
$all[0]=~s/-/$acc/g; 	#add accumulated upgrades to latest version

#make email body
my $body = "Reporte de descargas y actualizaciones $app_name\n\n";
$body .= "$date		Descargas	Actualizaciones por dispositivo\n";
$body .= ($today[0] or "Versión $versions{$latest_vcode}:		0		0\n");
$body .= $today[1] if scalar(@today) > 0;
$body .= $today[2] if scalar(@today) > 1;
$body .= "\nTotal (acumulado)	Descargas	(Actualizac.)	Retenciones	% retención\n";
$body .= $all[0];
$body .= $all[1] if scalar(@all) > 0;
$body .= $all[2] if scalar(@all) > 1;
print "\n\n$body";

#send email
system "./sendEmail -f interactive\@sky.com.mx -t $to -u Reporte Android $app_name $date -m '$body\n' -s mailrelay1";

#store upgrades for tomorrow's report
$file = $app."_acc.txt";
open (FILE, ">>$file") or die "Cannot modify '$file': $!";
foreach my $v (sort keys %upgrades) {
	print FILE "$time,$v,$upgrades{$v}\n" if $upgrades{$v};
}
close(FILE);
