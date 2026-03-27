#!/usr/bin/perl

use Data::Dumper;

$fs = {
	'/oracle' => '6006016021F616001E33151F99E6DA11',
	'/ds' => '6006016021F616006EB157B5CCDEDA11',
	'/fast1' => '6006016021F61600708D418CC9DEDA11',
	'/oracle_logs' => '6006016021F6160071B157B5CCDEDA11',
	'/med2' => '6006016021F61600B6D01A2FC4DEDA11',
	'/med1' => '6006016021F61600F8FB1819C4DEDA11'
};


foreach $sys (qw/ds01 ds02 ds03 ds04 ds05 ds13/)
{

	print "Working on system $sys\n";

	print "     Getting Mount Info\n";

	system("ssh -q $sys mount > /tmp/info_mount_$sys.dat");

	open (DATA, "< /tmp/info_mount_$sys.dat") || die $!;

	while (<DATA>)
	{
		chomp;
		next if (! /emcpower/);
		@data = split("[ ]+", $_);

		$data[0] =~ s/^.*\///;

		$mount->{$sys}->{$data[0]} = $data[2];
	}

	close (DATA);

	print "     Getting Mount Info\n";

	system("ssh -q $sys /sbin/powermt display dev=all > /tmp/info_powermt_$sys.dat");

	open (DATA, "< /tmp/info_powermt_$sys.dat") || die $!;

	$device = "";
	while (<DATA>)
	{
		chomp;
		if (/Pseudo name=([^\s]+)/)
		{
			$device = $1;
			$device_id = "";
			$name = "";
		}

		if (/Logical device ID=([^\s]+)\s+[[](.*)[]]/)
		{
			$device_id = $1;
			$name = $2;


			if (exists($mount->{$sys}->{$device}))
			{
				$fs_name = $mount->{$sys}->{$device};
				if ($device_id eq $fs->{$fs_name})
				{
					print "$sys:$device:$device_id:$name:$mount->{$sys}->{$device}:Good\n";
				}
				else
				{
					print "$sys:$device:$device_id:$name:$mount->{$sys}->{$device}:Cross Mounted!\n";
				}
			}
			else
			{
				print "$sys:$device:$device_id:$name:$mount->{$sys}->{$device}:Not mounted!\n";
			}
	

			$powermt->{$sys}->{$device} = $name;
		}
	}

	close (DATA);

}



