#!/usr/bin/perl

$VERSION = '1.16' ;

# bftp.pl - reliably transfers files in batch mode to a remote server via ftp protocol
#
# Author: Galileo Technologies (jmh, jtd)
# Version: 1.14
# Release date: 3/19/2003
#
# See seperate program document (Batch FTP.doc) for detailed usage information
#
# Revision history:
# 1/12/2001	- Version 1.00 - Initial release
#
# 1/30/2001 - Version 1.01 - Added earlier detection of transfer type for AUTO so
# that it can be displayed in log file.
# - Added elapsed time and transfer rate stats to log file at file, fileset
# and collection levels. Only successful transfers are included in stats.
# - Added warning for unable to detect transfer type, defaulting to BINARY.
#
# 2/5/2001 - Version 1.02 - Added check for empty message in log_mesg
# routine. Will not print anything to log file if message is empty.
# - Restricted circumstances in which remote file will be removed.
# Will only be removed if original and new (after transfer attempt) remote
# file sizes differ.
# - Changed method used to determine whether remote file already exists.
# Now uses ftp->size() method instead of ftp->ls() method since
# ftp->ls() may return lines of data even when the file does not exist.
#
# 2/6/2001 - Version 1.03 - Added ability to specify stdout for log file
# by specifying "-l -" on the command line.
#
# 3/13/2001 - Version 1.04 - Remove requirement of setting DEST_DIR parameter.
# DEST_DIR will effectively be set to "." (e.g. current directory) if no
# DEST_DIR parameter is specified.
#
# 3/22/2001 - Version 1.05 - Transfer rate is no longer displayed in log file
# for skipped transfers.
#
# 7/25/2001 - Version 1.06 - Fixed 2 bugs:
# 1) Mismatched local and remote file sizes for ASCII transfers returned
# 	200 (success) to parent instead of 99 (warning).
#
# 2) Mismatched local and remote file sizes for BINARY transfers returned
# 	200 (success) to parent instead of 1 (error). This was due to incorrect
#	case being used in transfer type value comparison (i.e. 'binary' instead
#	of 'BINARY').
#
# 8/27/2001 - Version 1.07 - Made 2 changes:
# 1) Removed PIPE (i.e. SIGPIPE) from list of signals handled by sig_handler(),
# as remote file could not be removed, and Net::FTP is supposed to be able
# to detect this error and return error code from put(). The signal handler
# should be reserved for events outside of the control of Net:FTP. SIGPIPE
# may have happened due to remote server closing socket (pipe) before
# transfer was complete. Removing SIGPIPE handler may increase chances
# of being able to remove partial remote file.
#
# 2) Added attempt to remove remote file if binary transfer resulted in
# file size mismatch between remote file and size of local file at
# time of bftp.pl invokation.
#
# 5/10/2002 - Version 1.08 - Fixed remaining files counter problem when
# fork() fails.  Was being decremented twice on fork() failure.
# Simple fix, but untested.
#
# 6/28/2002 - Version 1.09 - Added a newline character to the end of a few
# log message calls.
#
# 7/2/2002 - Version 1.10 - Made 2 changes:
# 1) Removed attempt to display error message in ftp
# object after unsuccessful attempt to establish initial connection with
# ftp server.  When connection attempt fails, the ftp object is undefined
# and thus, no error message can be displayed from the ftp object.  This
# was causing a confusing "perl" error message to display.
#
# 2) Changed wording of error message when child process cannot get a
# connection to ftp server.  Was "cannot allocate new ftp object".
# Now says "cannot open a connection to ..."
#
# 7/3/2002 - Version 1.11 - Added -V option to display program version
#
# 9/4/2002 - Version 1.12 - Added two similar command line options:
#
# -s num_seconds : If a file has been modified in the last num_seconds
# seconds, it will be intentionally skipped and not considered an error
# condition.
#
# -e num_seconds : If a file has been modified in the last num_seconds
# seconds, it will be intentionally skipped and WILL BE considered an
# error condition (i.e. failed transfer).
#
# 11/27/2002 - Version 1.13
# 1) Fixed bug where removal of remote file would always fail when remote and
# local file sizes differed after binary transmission.
#
# 2) Added usage info for -e and -s options, and reformatted usage display.
#
# 3) Made -c file_collection optional if only one collection defined in config_file
#
# 3/19/2003 - Version 1.14
# 1) Added -t option which simply sends sample configuration file to standard output
#
# 4/29/2004 -Version 1.15
# 1) Added attempt to remove remote file before retransfer in recovery mode.
#	This was done because some ftp servers are setup to allow files to be
#	deleted, but not overwritten.
#
# 5/5/2004 - Version 1.16
# 1) If the put call returns success, but size info cannot be obtained from remote
#	server, it is now considered a warning instead of an error.
#

use Getopt::Std;	# for parsing command line arguments
use Net::FTP;	# ftp client protocol library
use Parse::Lex;	# used for scanning config file into tokens
use Cwd;	# for getting the current directory
use File::Basename;	# for extracting components of a absolute pathname

require 5.005;


# signal handler routine for abnormal termination of process
sub sig_handler {
	my($sig) = $_[0];

	log_mesg("Error: Received signal $sig.\n");

	# attempt to remove remote file (only) IF the signal interrupted a file transfer process
	if ($TRANSFERRING == 1) {
		remove_remote_file($source_filename, $destination_dir);
		$TRANSFERRING = 0;
	}

	exit_process(254, "Exiting.\n");
}

$PGM = $0;	# the name of this perl script

sub usage {
	print "Usage: $PGM -f config_file [-c file_collection] [-l log_file] [-ardVtp] [-s num_secs] [-e num_secs] [-v var1=value1[,var2=value2...]]
-f	config_file : Name of configuration file.
-c	file_collection : Name of collection to process within config_file. Optional if only one collection in config_file exists.
-a	append to log file
-r	turn on recovery mode
-d	turn on debug output
-V	report program version
-v	comma-seperated list of variable assignments to be substituted by \$VAR (or \${VAR}) references in the config file.
-l	log file name : If -l log_file is not specified or log_file is - , logging info will be written to standard output.
-e	num_secs : Do not transfer any files that have been modified within the last num_secs seconds. Any such files will be treated as failed transfers.
-s	num_secs : Skip transfer of any files that have been modified within the last num_secs seconds. These files will NOT be treated as failed transfers (i.e. they will simply be skipped).
-t	write sample configuration file to standard output (no files transferred)
-p	use passive mode for transfers
\n";

}

sub log_mesg {

# General message logging routine for this program.
# Simply writes message passed to LOG filehandle with
# a date and time stamp prefixing the mesage.

	my ($mesg) = ($_[0]);
	my (@num_text, @nums, $ni, $mesg_to_print);
	my ($sec,$min,$hour,$mday,$mon,$year,$wday,$yday,$isdst) = localtime(time);
	my @nums = ($mon + 1, $mday, $hour, $min, $sec);

	if (length($mesg) == 0) {
		return;
	}

	for ($ni = 0; $ni <= $#nums; $ni++) {
		if ($nums[$ni] < 10 and $nums[$ni] >= 0) {
			$num_text[$ni] = "0" . $nums[$ni];
		} else {
			$num_text[$ni] = $nums[$ni];
		}
	}

	($mon, $mday, $hour, $min, $sec) = @num_text;

	$mesg_to_print = (1900 + $year) . "/$mon/$mday $hour:$min:$sec - $mesg";
	print LOG $mesg_to_print;
}

sub debug_out {

# General debug routine for this program.
#
# Simply uses the log_mesg routine to
# log the debug message passed, but only IF $debug is turned on
# (via -d command line switch).

	if ($debug) {
		log_mesg($_[0]);
	};
}

sub convert_elapsed {

	my($start_time, $end_time) = @_;
	my($time_diff) = $end_time - $start_time;
	my($hours) = int($time_diff / (60 * 60));
	my($min) = int(($time_diff - $hours * 60 * 60) / 60);
	my($sec) = $time_diff - $hours * 60 * 60 - $min * 60;
	my($n, @time);

	foreach $n ($hours, $min, $sec) {
		if ($n < 10) {
			push(@time, "0" . $n);
		} else {
			push(@time, $n);
		}
	}

	($h, $m, $s) = @time;
	return @time;

}

sub get_xfer_stats {
	my($start_time, $end_time, $filesize, $report_xfer_rate) = @_;
	my($hours, $min, $sec, $elapsed, $transfer_seconds, $successful_bytes, $xfer_rate, $xfer_rate_mesg);

	($hours, $min, $sec) = convert_elapsed($start_time, $end_time);
	$elapsed = "$hours:$min:$sec";
	$transfer_seconds = $end_time - $start_time;

	if ($transfer_seconds <= 0) {
		$report_xfer_rate = 0;
	}

	if ($report_xfer_rate) {
		$xfer_rate = sprintf("%.2f", ($filesize / $transfer_seconds) / 1024);
		$xfer_rate_mesg = "$xfer_rate Kbyte/s";
	} else {
		$xfer_rate = "N/A";
		$xfer_rate_mesg = "N/A";
	}

	return ($elapsed, $xfer_rate_mesg);
}

sub Any_Case {
# allows scanner to recognize case insensitive tokens
# returns converted RE that effectively ignores case

	my (@Params) = @_;
	my ($String, $RE, $char, $Final_RE);
	my (@Or_List);

	foreach $String (@Params)
	{
		$RE = "";
		foreach $char (split("", $String))
		{
			$RE = $RE . "[" . uc($char) . lc($char) . "\]";
		}

		push(@Or_List, $RE);
	}

	$Final_RE = '\b(' . join("|", @Or_List) . ')\b';

	return $Final_RE;
}

sub Start_Section {
# Used to put scanner in a new state for a specified section

	my (@Sections) = @_;
	my ($Section);

	foreach $Section (@Sections) {
		$Section = uc($Section);
		$Section_Status{$Section} = 'ACTIVE';
		$lexer->start($Section);
	}
}

sub End_Section {
# used to remove scanner from state
	my (@Sections) = @_;
	my ($Section);

	foreach $Section (@Sections)
	{
		$Section = uc($Section);

		$Section_Status{$Section} = 'INACTIVE';
		$lexer->end($Section);
	}
}

sub Section_Active {
# Determine whether scanner is in a particular state
	my ($Section) = @_;
	my ($Active);

	$Section = uc($Section);

	if ($Section_Status{$Section} eq 'ACTIVE')
	{
		$Active = 1;
	}
	else
	{
		$Active = 0;
	}

	return $Active;
}

sub Get_Active_Sections {
# Return a list of the currently active states of the scanner
	my (@Active);
	my ($State);

	@Active = ();
	foreach $State (@States)
	{
		push( @Active, $State) if $lexer->state($State);
	}

	return @Active;

}

sub add_to_data_struct {

	my ($text);

# Add the parm and value to the appropriate level of the collection data structure

	if (! defined($initialized_add_to_data_struct)) {
		@length_sorted_user_vars = sort { length($user_vars{$b}) <=> length($user_vars{$a}) } keys(%user_vars);
		@length_sorted_env_vars = sort { length($ENV{$b}) <=> length($ENV{$a}) } keys(%ENV);
		$initialized_add_to_data_struct = 1;
	}

	$_ = $token->name;

	if ($lexer->state('VAL')) {
		if ($token->name =~ /^TRUE$/|/^FALSE$/|/^ASCII$/|/^BINARY$/|/^AUTO$/|/^FILESIZE_ASC$/|/^FILESIZE_DESC$/|/^CONFIG_FILE$/) {
			$text = $token->name;
		}
		else {
			$text = $token->text;
			foreach $var_name (@length_sorted_user_vars) {
				$text =~ s/[\$][{]${var_name}[}]/$user_vars{$var_name}/gi;
				$text =~ s/[\$]${var_name}/$user_vars{$var_name}/gi;
			}

			foreach $var_name (@length_sorted_env_vars) {
				$text =~ s/[\$][{]${var_name}[}]/$ENV{$var_name}/gi;
				$text =~ s/[\$]${var_name}/$ENV{$var_name}/gi;
			}

			$text =~ s/[\$][{][^}]*[}]//gi;
			$text =~ s/[\$][A-Z_0-9]*//gi;
		}

		if ($lexer->state('CSF')) {

			$Collection[$collection_num]{"FILESET"}[$fileset_num]{"FILES"}[$filespec_num]{$current_parm} = $text;
			debug_out "new file parm: collection = $collection_num, fileset_num = $fileset_num, filespec_num = $filespec_num, $current_parm = " . $text . "\n";
		}
		elsif ($lexer->state('CS')) {
			$Collection[$collection_num]{"FILESET"}[$fileset_num]{'KEYS'}{$current_parm} = $text;
			debug_out "new fileset: collection = $collection_num, fileset_num = $fileset_num, $current_parm = " . $token->text . "\n";
		}
		elsif ($lexer->state('C')) {
			if ($current_parm eq 'LOGIN') {
				push(@{$Collection[$collection_num]{'LOGIN'}}, $text);
			} else {
				$Collection[$collection_num]{$current_parm} = $text;
			}
			debug_out "new collection: collection num = $collection_num, $current_parm = " . $text . "\n";
		}
	}
	elsif ($lexer->state('PARM')) {
		$current_parm = $token->name;
	}
	elsif ($lexer->state('PF')) {
		$filespec_num++;
	}
	elsif ($lexer->state('PS')) {
		$filespec_num = -1;
		$fileset_num++;
		debug_out "reset filespec num = -1\n";
	}
	elsif ($lexer->state('PC')) {
		$filespec_num = -1;
		$fileset_num = -1;
		$collection_num++;
		debug_out "reset filespec num = -1 and fileset num = -1\n";
	}

}


sub print_raw_data_struct {
# Print the data structure populated from reading in the configuration file

	my ($cnum, $ckey, $li, $i, $f, $fskey, $flkey);

	debug_out "PRINTING RAW DATA STRUCTURE\n";

	for ($cnum = 0; $cnum <= $#Collection; $cnum++) {
		debug_out "Collection $cnum\n";
		foreach $ckey (keys %{$Collection[$cnum]}) {
			if (ref($Collection[$cnum]{$ckey}) ne 'ARRAY') {
					  debug_out "	Collection key: $ckey = " . $Collection[$cnum]{$ckey} . "\n";
			} elsif ($ckey eq 'LOGIN') {
				$num_logins = scalar @{$Collection[$collection_num]{'LOGIN'}};
				for ($li = 0; $li < $num_logins; $li++) {
					debug_out "	Collection key: login $li = " . $Collection[$collection_num]{'LOGIN'}[$li] . "\n";
				}
			}
		}
		for ($i = 0; $i < @{$Collection[$cnum]{"FILESET"}}; $i++) {
			debug_out "	fileset $i\n";
			foreach $fskey (keys %{$Collection[$cnum]{"FILESET"}[$i]{'KEYS'}}) {
				if (ref($Collection[$cnum]{"FILESET"}[$i]{'KEYS'}{$fskey}) ne 'ARRAY') {
					debug_out "		fileset key: $fskey = " . $Collection[$cnum]{"FILESET"}[$i]{'KEYS'}{$fskey} . "\n";
				}
			}
			for ($f = 0; $f < @{$Collection[$cnum]{"FILESET"}[$i]{"FILES"}}; $f++) {
				debug_out "		files list $f\n";
				foreach $flkey (keys %{$Collection[$cnum]{"FILESET"}[$i]{"FILES"}[$f]}) {
					debug_out "			file key: $flkey = " . $Collection[$cnum]{"FILESET"}[$i]{"FILES"}[$f]{$flkey} . "\n";
				}
			}
		}
	}
}

sub populate_ftp_data_struct {
# Use the raw populated data structure to populate the ftp (transfer) data structure
# (i.e. the transfer routine will only use the $xfer structure, not the $Collection structure)

	debug_out "POPULATING FTP DATA STRUCTURE\n";
	my %defaults = ('MAX_CONNECTIONS', '1', 'OVERWRITE', 'FALSE', 'TYPE', 'AUTO', 'DEPEND', 'FALSE', 'TRANSFER_ORDER', 'CONFIG_FILE');
	my ($cnum, $default_key, $collect_key, $li, $i, $fs_file_index, $default_key, $inherit_key, $fs_name, $cdir, $flkey, $fspec, $dup_check_index, $duplicate_found, $fname, $file_key, @temp_list, $fn, $num);

	for ($cnum = 0; $cnum <= $#Collection; $cnum++) {
		debug_out "Collection $cnum\n";

		# defaults
		foreach $default_key (keys %defaults) {
			if (! defined($Collection[$cnum]{$default_key})) {
				$Collection[$cnum]{$default_key} = $defaults{$default_key};
			}
		}

		# copy keys at collection level from $Collection to $xfer
		foreach $collect_key (keys %{$Collection[$cnum]}) {
			if (ref($Collection[$cnum]{$collect_key}) ne 'ARRAY') {
				$xfer[$cnum]{$collect_key} = $Collection[$cnum]{$collect_key};
				debug_out "copying collection key $collect_key = " . $Collection[$cnum]{$collect_key} . "\n";
			} elsif ($collect_key eq 'LOGIN') {
				$num_logins = scalar @{$Collection[$collection_num]{'LOGIN'}};
				for ($li = 0; $li < $num_logins; $li++) {
					push(@{$xfer[$cnum]{'LOGIN'}}, $Collection[$cnum]{'LOGIN'}[$li]);
				}
			}
		}

		for ($i = 0; $i < @{$Collection[$cnum]{"FILESET"}}; $i++) {

			$fs_file_index = 0;
			debug_out "	fileset $i\n";

			#
			### Make each fileset inherit unpopulated attributes from collection
			#
			foreach $inherit_key ('MAX_CONNECTIONS', 'OVERWRITE', 'TYPE', 'SOURCE_DIR', 'DEST_DIR', 'DEPEND', 'TRANSFER_ORDER') {
				if (! defined($Collection[$cnum]{"FILESET"}[$i]{'KEYS'}{$inherit_key})) {
					if (defined($Collection[$cnum]{$inherit_key})) {
						$Collection[$cnum]{"FILESET"}[$i]{'KEYS'}{$inherit_key} = $Collection[$cnum]{$inherit_key};
					}
				}
				if (defined($Collection[$cnum]{'FILESET'}[$i]{'KEYS'}{$inherit_key})) {
					$xfer[$cnum]{'FILESET'}[$i]{'KEYS'}{$inherit_key} = $Collection[$cnum]{'FILESET'}[$i]{'KEYS'}{$inherit_key};
				}
			}

			foreach $copy_key ('NAME') {
				if (defined($Collection[$cnum]{'FILESET'}[$i]{'KEYS'}{$copy_key})) {
					$xfer[$cnum]{'FILESET'}[$i]{'KEYS'}{$copy_key} = $Collection[$cnum]{'FILESET'}[$i]{'KEYS'}{$copy_key};
				}
			}

			debug_out "		fileset key NAME = " . $Collection[$cnum]{'FILESET'}[$i]{'KEYS'}{'NAME'} . "\n";
			debug_out "		fileset key DEPEND = " . $Collection[$cnum]{'FILESET'}[$i]{'KEYS'}{'DEPEND'} . "\n";
			if (! defined($xfer[$cnum]{'FILESET'}[$i]{'KEYS'}{'NAME'})) {
				 $xfer[$cnum]{'FILESET'}[$i]{'KEYS'}{'NAME'} = ($i + 1) . ' of ' . @{$Collection[$cnum]{"FILESET"}};
			}

			$fs_name = $xfer[$cnum]{'FILESET'}[$i]{'KEYS'}{'NAME'};

			#
			### Make each Files() clause inherit unpopulated attributes from fileset
			#
			for ($f = 0; $f < @{$Collection[$cnum]{"FILESET"}[$i]{"FILES"}}; $f++) {
				foreach $inherit_key ('OVERWRITE', 'TYPE', 'SOURCE_DIR', 'DEST_DIR') {
					if (! defined($Collection[$cnum]{"FILESET"}[$i]{"FILES"}[$f]{$inherit_key})) {
						$Collection[$cnum]{"FILESET"}[$i]{"FILES"}[$f]{$inherit_key} = $Collection[$cnum]{"FILESET"}[$i]{'KEYS'}{$inherit_key};
					}
				}

				debug_out "		files list $f\n";
				foreach $flkey (keys %{$Collection[$cnum]{"FILESET"}[$i]{"FILES"}[$f]}) {
					$cdir = $Collection[$cnum]{'FILESET'}[$i]{'FILES'}[$f]{'SOURCE_DIR'};
					if (! chdir($cdir) ) {
						log_mesg("Error: can't cd to $cdir\n");
						exit(1);
					}

					if ($flkey eq 'FILENAME') {
						@file_list = split('[\n\t ]+', $Collection[$cnum]{"FILESET"}[$i]{"FILES"}[$f]{$flkey});

						foreach $fspec (@file_list) {
							foreach $fname (glob($fspec)) {
								debug_out "				fname = $fname\n";

								# check to make sure file does not match multiple specs in this fileset
								$duplicate_found = 0;
								for ($dup_check_index = 0; $dup_check_index < scalar(@{$xfer[$cnum]{'FILESET'}[$i]{'FILES'}}); $dup_check_index++) {
									if ( ($xfer[$cnum]{'FILESET'}[$i]{'FILES'}[$dup_check_index]{'FILENAME'} eq $fname) and ($xfer[$cnum]{'FILESET'}[$i]{'FILES'}[$dup_check_index]{'DEST_DIR'} eq $Collection[$cnum]{"FILESET"}[$i]{"FILES"}[$f]{'DEST_DIR'})) {
										$duplicate_found = 1;
										log_mesg("Warning: the file $fname (DEST_DIR=" . $Collection[$cnum]{"FILESET"}[$i]{"FILES"}[$f]{'DEST_DIR'} . ") matches multiple file specifications in the $fs_name fileset. The file will only be transferred once for this fileset.\n");
										last;
									}
								}

								if ($duplicate_found == 0) {
									$xfer[$cnum]{'FILESET'}[$i]{'FILES'}[$fs_file_index]{'FILENAME'} = $fname;
									foreach $file_key ('OVERWRITE', 'SOURCE_DIR', 'DEST_DIR') {
										$xfer[$cnum]{'FILESET'}[$i]{'FILES'}[$fs_file_index]{$file_key} = $Collection[$cnum]{"FILESET"}[$i]{"FILES"}[$f]{$file_key};
									}

									$trans_type = $Collection[$cnum]{"FILESET"}[$i]{"FILES"}[$f]{'TYPE'};

									if ($trans_type =~ /^binary$/i  ) {
										$transfer_type_assign = 'BINARY';
									} elsif ($trans_type =~ /^ascii$/i ) {
										$transfer_type_assign = 'ASCII';
									} elsif ($trans_type =~ /^auto$/i ) {
										# automatically determine whether binary or ascii transfer should be used
									   $stdout = `file $fname`;

										if ($stdout =~ /compress|tar archive|executable|binary/i ) {
											$transfer_type_assign = 'BINARY';
										} else {
											$transfer_type_assign = 'ASCII';
										}
									} else {
										$transfer_type_assign = 'BINARY';
										log_mesg("Warning: could not determine a file transfer type for $fname (DEST_DIR=" . $xfer[$cnum]{'FILESET'}[$i]{'FILES'}[$fs_file_index]{'DEST_DIR'} . "). Assuming BINARY.\n");
									}

									$xfer[$cnum]{'FILESET'}[$i]{'FILES'}[$fs_file_index]{'TYPE'} = $transfer_type_assign;

  								 	($dev,$ino,$mode,$nlink,$uid,$gid,$rdev,$source_file_size,$atime,$mtime,$ctime,$blksize,$blocks) = stat($fname);
									$xfer[$cnum]{'FILESET'}[$i]{'FILES'}[$fs_file_index]{'SOURCE_FILE_SIZE'} = $source_file_size;
									$fs_file_index++;
								}
							}
						}
					}
				}
			}

			# determine what order files in this fileset should be transferred
			$num = scalar(@{$xfer[$cnum]{"FILESET"}[$i]{'FILES'}});
			@temp_list = ();

			for ($fn = 0; $fn < $num; $fn++) {
				push(@temp_list, $fn);
			}

			if ($xfer[$cnum]{'FILESET'}[$i]{'KEYS'}{'TRANSFER_ORDER'} eq 'FILESIZE_ASC') {
				# sort all files in fileset according to their file sizes (ascending order)
				@{$xfer[$cnum]{'FILESET'}[$i]{'FILE_ORDER'}} = sort { $xfer[$cnum]{'FILESET'}[$i]{'FILES'}[$a]{'SOURCE_FILE_SIZE'} <=> $xfer[$cnum]{'FILESET'}[$i]{'FILES'}[$b]{'SOURCE_FILE_SIZE'} } @temp_list;
			} elsif ($xfer[$cnum]{'FILESET'}[$i]{'KEYS'}{'TRANSFER_ORDER'} eq 'FILESIZE_DESC') {
				# sort all files in fileset according to their file sizes (descending order)
				@{$xfer[$cnum]{'FILESET'}[$i]{'FILE_ORDER'}} = sort { $xfer[$cnum]{'FILESET'}[$i]{'FILES'}[$b]{'SOURCE_FILE_SIZE'} <=> $xfer[$cnum]{'FILESET'}[$i]{'FILES'}[$a]{'SOURCE_FILE_SIZE'} } @temp_list;
			} else {
				@{$xfer[$cnum]{'FILESET'}[$i]{'FILE_ORDER'}} = @temp_list;
			}

			# debug output
			$num = scalar(@{$xfer[$cnum]{"FILESET"}[$i]{'FILES'}});
			debug_out "scalar = $num, i = $i\n";
			for ($fn = 0; $fn < $num; $fn++) {
				debug_out "--- file $fn : " . $xfer[$cnum]{"FILESET"}[$i]{'FILES'}[$fn]{'FILENAME'} . "\n";
			}

			# end of fileset loop
		}
	}
}

sub print_ftp_data_struct {
# Print the ftp data structure that will be used to transfer files

	my ($cnum, $ckey, $num_logins, $li, $i, $fsname, $fskey, $num, $fnum, $fkey);

	debug_out "PRINTING FTP DATA STRUCTURE\n";

	if (! ($#xfer >= 0)) {
		log_mesg("Error: No collections found!\n");
		exit(1);
	}

	for ($cnum = 0; $cnum <= $#xfer; $cnum++) {
		debug_out "Collection $cnum\n";

		$cname = $xfer[$cnum]{'NAME'};

		foreach $ckey (keys %{$xfer[$cnum]}) {
			if (ref($xfer[$cnum]{$ckey}) ne 'ARRAY') {
					  debug_out "	Collection key: $ckey = " . $xfer[$cnum]{$ckey} . "\n";
			} elsif ($ckey eq 'LOGIN') {
				$num_logins = scalar @{$xfer[$cnum]{'LOGIN'}};
				for ($li = 0; $li < $num_logins; $li++) {
					debug_out "	Collection key: login $li = " . $xfer[$cnum]{'LOGIN'}[$li] . "\n";
				}
			}
		}

		for ($i = 0; $i < @{$xfer[$cnum]{"FILESET"}}; $i++) {
			debug_out "	fileset $i\n";

			$fsname = $xfer[$cnum]{'FILESET'}[$i]{'KEYS'}{'NAME'};

			foreach $fskey (keys %{$xfer[$cnum]{'FILESET'}[$i]{'KEYS'}}) {
				if (ref($xfer[$cnum]{'FILESET'}[$i]{'KEYS'}{$fskey}) ne 'ARRAY') {
					debug_out "		fileset key: $fskey = " . $xfer[$cnum]{'FILESET'}[$i]{'KEYS'}{$fskey} . "\n";
				}
			}
			$num = scalar @{$xfer[$cnum]{"FILESET"}[$i]{'FILES'}}; 
			for ($fnum = 0; $fnum < $num; $fnum++) {
				debug_out "			fnum $fnum: \n";

				foreach $fkey (keys %{$xfer[$cnum]{"FILESET"}[$i]{'FILES'}[$fnum]}) {
					debug_out "				$fkey = " . $xfer[$cnum]{"FILESET"}[$i]{'FILES'}[$fnum]{$fkey} . "\n";
				}
			}
		}
	}
}

sub check_ftp_data_struct {

# Perform some sanity checking on the $xfer data structure

	my ($cname, $ckey, $check_dir, $i, $fsname, $fskey, $num);
	$cname = $_[0];

	if (! ($#xfer >= 0)) {
		log_mesg("Error: No collections found!\n");
		exit(1);
	}

	for ($cnum = 0; $cnum <= $#xfer; $cnum++) {
		if ($xfer[$cnum]{'NAME'} eq $cname) {
			$ftp_cnum = $cnum;
			last;
		}
	}

		if (! defined($xfer[$ftp_cnum]{'NAME'})) {
			log_mesg("Error: No NAME value defined for collection # " . $ftp_cnum + 1 . "\n");
			exit(1);
		}


		foreach $ckey ('HOST', 'LOGIN') {
			if (! defined($xfer[$ftp_cnum]{$ckey})) {
				log_mesg("Error: No $ckey value defined for $cname collection\n");
				exit(1);
			}
		}

		if (defined($xfer[$ftp_cnum]{'SOURCE_DIR'})) {
			$check_dir = $xfer[$ftp_cnum]{'SOURCE_DIR'};
			if (! chdir($check_dir))  {
				log_mesg("Error: Unable to cd to source directory $check_dir in collection $cname \n");
				exit(1);
			}
		}

		if (! (@{$xfer[$ftp_cnum]{'FILESET'}} >= 0)) {
			log_mesg("Error: No filesets found in collection $cname\n");
			exit(1);
		}

		for ($i = 0; $i < @{$xfer[$ftp_cnum]{"FILESET"}}; $i++) {
			if (! defined($xfer[$ftp_cnum]{'FILESET'}[$i]{'KEYS'}{'NAME'})) {
				log_mesg("Error: Fileset # " . ($i + 1) . " in collection $cname has no NAME value\n");
				exit(1);
			}

			$fsname = $xfer[$ftp_cnum]{'FILESET'}[$i]{'KEYS'}{'NAME'};

			foreach $fskey ('MAX_CONNECTIONS', 'OVERWRITE', 'TYPE', 'DEPEND', 'TRANSFER_ORDER') {
				if (! defined($xfer[$ftp_cnum]{'FILESET'}[$i]{'KEYS'}{$fskey})) {
					log_mesg("Error: No $fskey value in $fsname fileset of $cname collection\n");
					exit(1);
				}
			}

			$num = scalar @{$xfer[$ftp_cnum]{"FILESET"}[$i]{'FILES'}}; 
		}
}

sub Read_Config {
# Read config file that describes which collection of files to transfer

	my ($config_file) = @_;

	@Sections = ('fileset', 'file');

	@Parameters = ( 'name', 'host', 'source_dir', 'dest_dir', 'login', 'max_connections', 
			'overwrite', 'filename', 'type');

	@States = ('C', 'CS', 'CSF', 'PC', 'PS', 'PF', 'PARM', 'EQ', 'VAL', 'D', 'CLOSE_PAREN');

	@token = (
   'PC:LEFTPC',         qw([\(]),   sub { &Start_Section('C', 'D'); &End_Section('PC'); $_[1] },
   'PS:LEFTPS',         qw([\(]),   sub { &Start_Section('CS', 'D'); &End_Section('C','PS'); $_[1] },
   'PF:LEFTPF',         qw([\(]),   sub { &Start_Section('CSF', 'D'); &End_Section('CS', 'PF'); $_[1] },
   'CSF:RIGHTP_F',     qw([\)]),   sub { &End_Section('CSF', 'VAL'); &Start_Section('CS', 'CLOSE_PAREN'); $_[1] },
   'CS:RIGHTP_S',      qw([\)]),   sub { &End_Section('CS', 'VAL'); &Start_Section('C', 'CLOSE_PAREN'); $_[1] },
   'C:RIGHTP_C',    qw([\)]),   sub { &End_Section('C', 'VAL'); $_[1] },
   'EQ:NVALUE',         qw([0-9]+), sub { &Start_Section('VAL'); &End_Section('EQ'); $_[1] },
   'PARM:EQUAL',        qw([=]), sub { &Start_Section('EQ'); &End_Section('PARM'); $_[1] },
   'VAL,CLOSE_PAREN:COMMA',         qw([,]), sub { &Start_Section('D'); &End_Section('VAL', 'CLOSE_PAREN'); $_[1] },
   'ALL:NEWLINE',       qw(\n), sub { $_[1]},
   'ALL:COMMENT',       '[ ]*[#].*', sub { $_[1]},
   'ALL:COLLECTION',    &Any_Case('COLLECTION'),   sub { &Start_Section('PC'); $_[1] },
   'C:D:FILESET',         &Any_Case('FILESET'),      sub { &Start_Section('PS'); &End_Section('VAL'); $_[1] },
   'CS:D:FILES',        &Any_Case('FILES'),     sub { &Start_Section('PF'); &End_Section('VAL', 'D'); $_[1] },
   'C:D:NAME',       &Any_Case('NAME'),      sub { &Start_Section('PARM'); &End_Section('D'); $_[1] },
   'CS:D:NAME',         &Any_Case('NAME'),      sub { &Start_Section('PARM'); &End_Section('D'); $_[1] },
   'CSF:D:NAME',     &Any_Case('NAME'),      sub { &Start_Section('PARM'); &End_Section('D'); $_[1] },
   'C:D:HOST',          &Any_Case('HOST'),      sub { &Start_Section('PARM'); &End_Section('D'); $_[1] },
   'C:D:SOURCE_DIR',    &Any_Case('SOURCE_DIR'),   sub { &Start_Section('PARM'); &End_Section('D'); $_[1] },
   'CS:D:SOURCE_DIR',      &Any_Case('SOURCE_DIR'),   sub { &Start_Section('PARM'); &End_Section('D'); $_[1] },
   'CSF:D:SOURCE_DIR',      &Any_Case('SOURCE_DIR'),   sub { &Start_Section('PARM'); &End_Section('D'); $_[1] },
   'C:D:LOGIN',         &Any_Case('LOGIN'),     sub { &Start_Section('PARM'); &End_Section('D'); $_[1] },
   'C:D:DEST_DIR',      &Any_Case('DEST_DIR'),     sub { &Start_Section('PARM'); &End_Section('D'); $_[1] },
   'CS:D:DEST_DIR',     &Any_Case('DEST_DIR'),     sub { &Start_Section('PARM'); &End_Section('D'); $_[1] },
   'CSF:D:DEST_DIR',    &Any_Case('DEST_DIR'),     sub { &Start_Section('PARM'); &End_Section('D'); $_[1] },
   'C:D:MAX_CONNECTIONS',     &Any_Case('MAX_CONNECTIONS'), sub { &Start_Section('PARM'); &End_Section('D'); $_[1] },
   'CS:D:MAX_CONNECTIONS',    &Any_Case('MAX_CONNECTIONS'), sub { &Start_Section('PARM'); &End_Section('D'); $_[1] },
   'C:D:DEPEND',     &Any_Case('DEPEND'), sub { &Start_Section('PARM'); &End_Section('D'); $_[1] },
   'CS:D:DEPEND',    &Any_Case('DEPEND'), sub { &Start_Section('PARM'); &End_Section('D'); $_[1] },
   'C:D:TRANSFER_ORDER',     &Any_Case('TRANSFER_ORDER'), sub { &Start_Section('PARM'); &End_Section('D'); $_[1] },
   'CS:D:TRANSFER_ORDER',    &Any_Case('TRANSFER_ORDER'), sub { &Start_Section('PARM'); &End_Section('D'); $_[1] },
   'C:D:OVERWRITE',     &Any_Case('OVERWRITE'),    sub { &Start_Section('PARM'); &End_Section('D'); $_[1] },
   'CS:D:OVERWRITE',    &Any_Case('OVERWRITE'),    sub { &Start_Section('PARM'); &End_Section('D'); $_[1] },
   'CSF:D:OVERWRITE',      &Any_Case('OVERWRITE'),    sub { &Start_Section('PARM'); &End_Section('D'); $_[1] },
   'CSF:D:FILENAME',       &Any_Case('FILENAME'),     sub { &Start_Section('PARM'); &End_Section('D'); $_[1] },
   'C:D:TYPE',       &Any_Case('TYPE'),      sub { &Start_Section('PARM'); &End_Section('D'); $_[1] },
   'CS:D:TYPE',         &Any_Case('TYPE'),      sub { &Start_Section('PARM'); &End_Section('D'); $_[1] },
   'CSF:D:TYPE',        &Any_Case('TYPE'),      sub { &Start_Section('PARM'); &End_Section('D'); $_[1] },
   'EQ:BINARY',      &Any_Case('BINARY', 'IMAGE'),  sub { &Start_Section('VAL'); &End_Section('EQ'); $_[1] },
   'EQ:AUTO',     &Any_Case('AUTO'),  sub { &Start_Section('VAL'); &End_Section('EQ'); $_[1] },
   'EQ:SVALUE',            [qw(" (?:[^"]+|"")* ")],   sub { &Start_Section('VAL'); &End_Section('EQ'); $_[1] =~ s/^"//g; $_[1] =~ s/"$//g; $_[1] },
   'EQ:TRUE',     &Any_Case('TRUE', 'YES', 'Y', 'T'),  sub { &Start_Section('VAL'); &End_Section('EQ'); $_[1] },
   'EQ:FALSE',       &Any_Case('FALSE', 'NO', 'N', 'F'),  sub { &Start_Section('VAL'); &End_Section('EQ'); $_[1] },
   'EQ:ASCII',       &Any_Case('ASCII'),  sub { &Start_Section('VAL'); &End_Section('EQ'); $_[1] },
   'EQ:FILESIZE_ASC',       &Any_Case('FILESIZE', 'FILESIZE_ASC'),  sub { &Start_Section('VAL'); &End_Section('EQ'); $_[1] },
   'EQ:FILESIZE_DESC',       &Any_Case('FILESIZE_DESC'),  sub { &Start_Section('VAL'); &End_Section('EQ'); $_[1] },
   'EQ:CONFIG_FILE',       &Any_Case('CONFIG_FILE'),  sub { &Start_Section('VAL'); &End_Section('EQ'); $_[1] },
   'C,CS,CSF:INVALID_PARAMETER', &Any_Case(@Parameters), sub { $_[1]},
   'C,CS,CSF:UNKNOWN_PARAMETER', '[A-Za-z0-9_]+', sub { $_[1]},
   'ALL:ERROR',         qw(.*), sub { $_[1]},
         );

	if (! open(CFG, "<$config_file") ) {
		log_mesg("Error: Unable to open config file $config_file\n");
		exit(1);
	}

 	Parse::Lex->inclusive(@States);
   $lexer = Parse::Lex->new(@token);
   $lexer->from(*CFG);

	TOKEN:while (1) 
	{
		$token = $lexer->next;
		if (not $lexer->eoi)
		{
			if ($token->name eq "NEWLINE")
        	    	{
				next TOKEN;
			}

			if ($token->name eq 'UNKNOWN_PARAMETER')
			{
				log_mesg("Error: Unknown parameter \"" . $token->text . "\" on line " . $. . "\n");
				exit(1);
			} 

			if ($token->name eq 'INVALID_PARAMETER')
			{
				log_mesg("Error: Invalid parameter \"" . $token->text . "\" on line " . $. . "\n");
				exit(1);
			}
 
			
			if ($token->name eq 'ERROR')
			{
				log_mesg("(" . join(",", &Get_Active_Sections()) . "):\n");
				log_mesg("Syntax Error: near \"" . $token->text . "\" on line " . $. . "\n");

				print"State of C " . $lexer->state('C') . "\n";
				exit(1);
			}

			add_to_data_struct();

		}
		else 
		{
			last TOKEN;
		}
	}
}

sub remove_remote_file {
	my($fname, $dir) = (@_);
	my($num_deleted, $i);
	my($del_ftp);

	$del_ftp = Net::FTP->new($host, Passive => $passive, Timeout => $connect_timeout);

	if (! $del_ftp) {
		log_mesg("$fname: Warning: Cannot create new ftp object to remove remote file\n");
		$del_ftp->quit;
		return 0;
	}

	for ($i = 0; $i < @userid; $i++) {
		if (! ($del_ftp->login($userid[$i], $password[$i]))) {
			log_mesg("$fname: Warning: Cannot login with userid " . $userid[$i] . " to remove remote file : " . $del_ftp->message . "\n");
			$del_ftp->quit;
			return 0;
		}
	}

	if (! ($del_ftp->cwd($dir))) {
		log_mesg("$fname: Warning: Cannot cd to $dir to remove remote file : " . $del_ftp->message . "\n");
		$del_ftp->quit;
		return 0;
	}

	$num_deleted = $del_ftp->delete($fname);

	if ($num_deleted == 1) {
		log_mesg("$fname: Remote file removed\n");
		$del_ftp->quit;
		return 1;
	} else {
		log_mesg("$fname: Warning: Unable to remove remote file : " . $del_ftp->message . "\n");
		$del_ftp->quit;
		return 0;
	}
}

sub exit_child_process {
# close ftp connection and exit process
	$ftp->quit;
	exit_process(@_);

}

sub exit_process {
# log message, close log file, and exit process
	my($p_status, $p_message) = (@_);

	log_mesg($p_message);
	close(LOG);
	exit($p_status);

}

# setup signal handler for this (parent) and child processes

foreach $sig ('INT', 'QUIT', 'HUP', 'INT', 'TERM', 'ABRT', 'BUS', 'EMT', 'FPE', 'ILL', 'QUIT', 'SEGV', 'SYS', 'TRAP') {
	# assign signal handler for signal unless it is being ignored
	if ($SIG{$sig} ne 'IGNORE') {
		$SIG{$sig} = \&sig_handler;
	}
}

# Parse command line options

getopts('f:c:dl:av:r?hVs:e:tp');

if (defined($opt_p)) {
	$passive = 1;
} else {
	$passive = 0;
}

if (defined($opt_t)) {
	print '# Example bftp configuration file template
#

Collection (

        Name = "ftp",
        Login = "username/password",
        Host = "hostname",
        source_dir = "/download",
        max_connections = 2,
        type = binary,

        Fileset (
                Files (Filename = "deliverable*.dat.gz")
        )

)

';
	exit(0);
}

if (defined($opt_s)) {
	$file_age_requirement_flag = 1;
	$skip_on_failed_file_age = 1;
	$minimum_file_age = $opt_s;
}

if (defined($opt_e)) {
	$file_age_requirement_flag = 1;
	$skip_on_failed_file_age = 0;
	$minimum_file_age = $opt_e;
}

if (defined($opt_V)) {
	print "This is bftp.pl, version $VERSION\n";
	print "See 'Batch FTP.doc' for full documentation\n";
	exit(0);
}

if (defined($opt_h)) {
	usage;
	exit(0);
}

if (defined($opt_f)) {
	$config_file = $opt_f;

	if (! -f $config_file) {
		print STDERR "$PGM: Error: Unable to access configuration file $config_file\n";
		exit(1);
	}
} else {
	print STDERR "$PGM: Error: Must specify configuration file via -f option\n";
	usage;
	exit(1);
}


if (defined($opt_d)) {
	$debug = 1;
}

if (defined($opt_l) and ($opt_l ne '-')) {
	$main_logfile = $opt_l;

	# convert . current dir reference to absolute path reference
	if (dirname($main_logfile) eq '.') {
		$main_logfile = cwd() . "/$main_logfile";
	}

	$child_logdir = dirname($main_logfile);
} else {
	$main_logfile = '-';	# use STDOUT instead of log "file"

	# figure out where to put temporary child process log files
	# (environment variable or just default to current directory)

   undef $child_logdir;

   foreach $env_var ('TMPDIR', 'TMP', 'TEMP') {
      if ( (-d $ENV{$env_var}) and (-w $ENV{$env_var}) ) {
         $child_logdir = $ENV{$env_var};
         last;
      }
   }

	if (! defined($child_logdir)) {
		$child_logdir = cwd();
		if ( ! ((-d $child_logdir) and (-w $child_logdir) ) ) {
			print STDERR "$PGM: Error: Cannot find writable directory for temp files\n";
			exit(1);
		}
	}
}

if (defined($opt_r)) {
	$RECOVERY_MODE = 1;
} else {
	$RECOVERY_MODE = 0;
}

if (defined($opt_v)) {
	@variable_assigns = split(/\,/, $opt_v);
	foreach $var_asgn (@variable_assigns) {
		($var, $value) = split(/=/, $var_asgn);
		$user_vars{$var} = $value;
	}
}

# create log file
if (defined($opt_a)) {
	$logfile_mode = ">>";
} else {
	$logfile_mode = ">";
}

if (! open(LOG, "${logfile_mode}${main_logfile}") ) {
	print STDERR "Error: Could not open log file $main_logfile\n";
	exit(1);
}

# force lines to be immediately written to log file as they are printed
autoflush LOG;

# thread_adjust_factor will reduce max connections by a safe margin if
# parallel connection testing hits a lower limit than that requested
# in the configuration file. For example, if the config file says
# "max_connections = 10" and thread_adjust_factor = 0.7, 
# but connection testing reveals that only 9 connections could be established,
# then max_connections will be throttled down to 9 * 0.7 = 6.
# Otherwise it will remain at 10.

$thread_adjust_factor = 0.7;
$connect_timeout = 30; # how long to wait for ftp connection to establish

# initialize index values
$filespec_num = -1;
$fileset_num = -1;
$collection_num = -1;

# read the configuration file
&Read_Config($config_file);

&print_raw_data_struct;	# for debug only

# Use raw data structure from config file to populate $xfer data structure for transfers
&populate_ftp_data_struct;

if (defined($opt_c)) {
	$collection = $opt_c;
} else {
	if ($#xfer == 0) {
		$collection = $xfer[$cnum]{'NAME'};
	} else {
		print STDERR "$PGM: Error: Must specify collection name via -c option since config file contains more than one collection\n";
		usage;
		exit(1);
	}
}

# Perform sanity checking on transfer data structure ($xfer)
&check_ftp_data_struct($collection);	# sets $ftp_cnum

&print_ftp_data_struct;	# debug only

if (! defined($ftp_cnum)) {
	log_mesg("$0: Error: Unable to find $collection collection in $config_file config file\n");
	exit(1);
}

# initialize $host variable and userid/password array

$host = $xfer[$ftp_cnum]{"HOST"};
foreach $login (@{$xfer[$ftp_cnum]{"LOGIN"}}) {
	($user, $pass) = split(/\//, $login);
	push(@userid, $user);
	push(@password, $pass);
}

# find the largest max_connections setting among all filesets to be processed
# and set max_threads equal to that number.

for ($fs_num = 0; $fs_num < scalar(@{$xfer[$ftp_cnum]{'FILESET'}}); $fs_num++) {
   if (($xfer[$ftp_cnum]{'FILESET'}[$fs_num]{'KEYS'}{'MAX_CONNECTIONS'} > $max_threads) or (! defined($max_threads))) {
      $max_threads = $xfer[$ftp_cnum]{'FILESET'}[$fs_num]{'KEYS'}{'MAX_CONNECTIONS'};
   }
}

debug_out "HOST = $host \n";

log_mesg("*** Begin: collection=$collection, host=$host\n");
log_mesg("***\n");

# test/verify level of parallel connectivity allowed,
# ability to cd to destination directory, and
# ability to login

for ($i = 1; $i <= $max_threads; $i++) {

	$ftp[$i] = Net::FTP->new($host, Passive => $passive, Timeout => $connect_timeout);

	# note: above Timeout parameter not known to work yet, may block indefinitely
	# (also tried eval/die/alarm/SIG{ALRM} solution as workaround and that did
	# not work either!)

   # connection ok
   if ($ftp[$i]) {

      # if 1st connection, test cd to dest directory and ability to login
      if ($i == 1) {
         for ($c = 0; $c < @userid; $c++) {
            if (! ($ftp[$i]->login($userid[$c], $password[$c]))) {
					log_mesg("Error: Unable to login with userid $userid[$c] : " . $ftp[$i]->message . "\n");
					exit(1);
				}
         }
			log_mesg("*** Test login worked\n");

			undef $last_ddir;

			# for each fileset
			for ($fs_num = 0; $fs_num < scalar(@{$xfer[$ftp_cnum]{'FILESET'}}); $fs_num++) {

				# for each file in the fileset
				for ($f_num = 0; $f_num < scalar(@{$xfer[$ftp_cnum]{'FILESET'}[$fs_num]{'FILES'}}); $f_num++) {

					# test doing a cd to the destination directory, unless it's the same directory as
					# the last one tested (to avoid gross duplication of test effort)

					if (defined($xfer[$ftp_cnum]{'FILESET'}[$fs_num]{'FILES'}[$f_num]{'DEST_DIR'})) {
						$ddir = $xfer[$ftp_cnum]{'FILESET'}[$fs_num]{'FILES'}[$f_num]{'DEST_DIR'}; 
						if (($ddir ne $last_ddir) or (! defined($last_ddir))) {
							if (! $ftp[$i]->cwd($ddir)) {
								log_mesg("Error: Cannot cd to destination directory $ddir : " . $ftp[$i]->message . "\n");
								exit(1);
							}
							log_mesg("*** test cd to $ddir worked\n");
							$last_ddir = $ddir;
						}
					}
				}
			}
      }
   }
   # connection failure
   else {
		# if this is the 1st connection attempt, then we can't get ANY connections and
		# must exit with an error status
      if ($i == 1) {
         log_mesg("Error: Cannot open any connections to $host : " . $@ . "\n");
         exit(1);
      } else {
			# adjust max threads using adjustment factor and max connections achieved
         $new_max_threads = int($i * $thread_adjust_factor);
         log_mesg("Max_connections configuration of $max_threads not possible at this time. Only able to establish " . ($i - 1) . " connections. Max connections adjusted to $new_max_threads.\n");
         $max_threads = $new_max_threads;

         last;
      }
   }
}

# close off opened test connections
for ($ci = 1; $ci < $i; $ci++) {
	$ftp[$ci]->quit;
}

# initialize status indicators and counters for collection
$col_rc = 0;	# collection return code
$col_num_completed = 0;	# number of successfully completed file transfers for collection
$col_num_failed = 0;	# number of failed file transfers for collection
$col_num_warning = 0; # number of file transfers with warnings for collection
$col_num_skipped = 0; # number of file transfers skipped for collection
$col_start_time = time;	# start time for collection
$col_report_xfer_rate = 1;	# assume transfer rate will be reported for collection

# BEGIN XFER

# loop through each fileset
for ($fileset_num = 0; $fileset_num < scalar(@{$xfer[$ftp_cnum]{'FILESET'}}); $fileset_num++) {
	# initialize status indicators and counters for fileset
	$fs_num_failed = 0;	# number of failed file transfers for fileset
	$fs_num_warning = 0;	# number of completed file transfers with warnings for fileset
	$fs_num_skipped = 0;	# number of skipped file transfers for fileset
	$fs_rc = 0;	# fileset return code
	$fs_num_completed = 0; # number of successfully completed file transfers for fileset
	$fs_successful_bytes = 0; # number of bytes successfully transferred for fileset
	$fs_start_time = time;	# start time for fileset
	$fs_report_xfer_rate = 1;	# assume transfer rate will be reported for fileset

	$fileset_name = $xfer[$ftp_cnum]{'FILESET'}[$fileset_num]{'KEYS'}{'NAME'};
	$fileset_depend = $xfer[$ftp_cnum]{'FILESET'}[$fileset_num]{'KEYS'}{'DEPEND'};

	# keep max_connections from getting higher than tested maximum ($max_threads) for this fileset
	if ($xfer[$ftp_cnum]{'FILESET'}[$fileset_num]{'KEYS'}{'MAX_CONNECTIONS'} <= $max_threads) {
		$max_connections = $xfer[$ftp_cnum]{'FILESET'}[$fileset_num]{'KEYS'}{'MAX_CONNECTIONS'};
	} else {
		$max_connections = $max_threads;
	}

	log_mesg("**\n");
	log_mesg("**  Begin: fileset=$fileset_name, max_connections=$max_connections\n");

	if ( ($col_num_failed > 0) and ($fileset_depend eq 'TRUE') ) {
		$fs_rc = 1;
		$fs_num_skipped++;
		$col_num_skipped += $fs_num_skipped;
		log_mesg("Note: Dependant fileset $fileset_name will be intentionally skipped due to transfer error(s) in previous fileset(s).\n");
		log_mesg("**  End: fileset=$fileset_name, return_code=$fs_rc, completed=$fs_num_completed, failed=$fs_num_failed, warned=$fs_num_warning, skipped=$fs_num_skipped\n");
		next;
	}

	$threads = 0; # current number of concurrent child processes (transfers) running
	$file_num_index = 0; # file number index for current fileset
	$num_remaining_files = scalar(@{$xfer[$ftp_cnum]{'FILESET'}[$fileset_num]{'FILES'}});

	# repeat transfer loop until there are no more files being transferred and
	# there are no more files remaining in the fileset to transfer
	until ( ($threads == 0) and ($num_remaining_files <= 0) ) {

		# transfer next file if there are any left to transfer
		if ($num_remaining_files > 0) {

			$file_num = $xfer[$ftp_cnum]{'FILESET'}[$fileset_num]{'FILE_ORDER'}[$file_num_index];

			# obtain file name to transfer and other file attributes
			$source_filename = $xfer[$ftp_cnum]{"FILESET"}[$fileset_num]{"FILES"}[$file_num]{"FILENAME"};
			$source_dir = $xfer[$ftp_cnum]{"FILESET"}[$fileset_num]{"FILES"}[$file_num]{"SOURCE_DIR"};

			$destination_dir = $xfer[$ftp_cnum]{'FILESET'}[$fileset_num]{'FILES'}[$file_num]{'DEST_DIR'};
			if ($destination_dir eq "") {
				$destination_dir = ".";
			}

			$transfer_type = $xfer[$ftp_cnum]{"FILESET"}[$fileset_num]{"FILES"}[$file_num]{"TYPE"};
			$overwrite = $xfer[$ftp_cnum]{"FILESET"}[$fileset_num]{"FILES"}[$file_num]{"OVERWRITE"};

			# grab source file size for subsequent comparison to remote file size after transfer
			$source_file_size = $xfer[$ftp_cnum]{'FILESET'}[$fileset_num]{'FILES'}[$file_num]{'SOURCE_FILE_SIZE'};

			$file_num_index++;

			log_mesg("start: file=$source_filename, local_size=$source_file_size, type=$transfer_type, source_dir=$source_dir, dest_dir=$destination_dir\n");

			# create child process in which to transfer file in background

			# spawn child process for next file transfer
			$pid = fork;


			if ($pid == 0) {

				# child process executes in here
				close(LOG);
				$child_logfile = "$child_logdir/ftp.$source_filename.$$.out";

				$status = 1; # won't be set to success (0) until the file is xferred successfully
				if (! open(LOG, ">$child_logfile") ) {
					log_mesg("Error: Could not create log file $child_logfile for $source_filename\n");
					exit_process(1, "Error: Could not create log file $child_logfile for $source_filename\n");
				}
				autoflush LOG;

				if (! chdir($source_dir) ) {
					exit_process(1, "$source_filename: Error: Can't cd to source directory $source_dir for file $source_filename\n");
				}

				if (! -r $source_filename) {
					exit_process(1, "$source_filename: Error: Source file is not accessible or does not exist on $source_dir directory\n");
				}
# xxx
				if ($file_age_requirement_flag) {
					($dev,$ino,$mode,$nlink,$uid,$gid,$rdev,$fsize,$atime,$mtime,$ctime,$blksize,$blocks) = stat($source_filename);
					$curr_time = time;
					if ($mtime > ($curr_time - $minimum_file_age)) {
						if ($skip_on_failed_file_age) {
							exit_process(100, "$source_filename: file skipped because it has been modified less than $minimum_file_age seconds ago\n");
						} else {
							exit_process(1, "$source_filename: Error: file not ready to be transferred because it has been modified less than $minimum_file_age seconds ago\n");
						}
					}
				}

				log_mesg("$source_filename: Connecting to remote ftp server $host...\n");

				if (! ($ftp = Net::FTP->new($host, Passive => $passive))) {
					exit_process(1, "$source_filename: Error: Cannot open a connection to $host: " . $@ . "\n");
				}

				# note: start using exit_child_process from here one in the child

				for ($i = 0; $i < @userid; $i++) {
					if (! ($ftp->login($userid[$i], $password[$i]))) {
						exit_child_process(1, "$source_filename: Error: Cannot login with userid " . $userid[$i] . " : " . $ftp->message . "\n");
					}
				}

				if (! ($ftp->cwd($destination_dir))) {
					exit_child_process(1, "$source_filename: Error: Cannot cd to $destination_dir : " . $ftp->message . "\n");
				}

				if ($transfer_type eq 'BINARY' ) {
					$ret_type = $ftp->binary();
				} elsif ($transfer_type eq 'ASCII' ) {
					$ret_type = $ftp->ascii();
				}

				if (! defined($ret_type)) {
					exit_child_process(1, "$source_filename: Error: Unable to set transfer type to $transfer_type\n");
				}

				$destination_size = $ftp->size($source_filename);

				if ($destination_size =~ /[0-9]/) {
					# file already exists on remote server

					if ($RECOVERY_MODE) {
						# $destination_size = $ftp->size($source_filename);
						if ($source_file_size == $destination_size) {
							exit_child_process(100, "$source_filename: file of same size already exists ($source_file_size bytes). No need to transfer in recovery mode.\n");
						} else {
							log_mesg("$source_filename: file of different size already exists (local=$source_file_size, remote=$destination_size). Retransfer necessary in recovery mode.\n");
							remove_remote_file($source_filename, $destination_dir);
						}
					} elsif ($overwrite eq 'TRUE') {
						log_mesg("$source_filename: file already exists and will be overwritten.\n");
					} else {
						exit_child_process(1, "$source_filename: file already exists and OVERWRITEs not allowed for this file.\n");
					}
				}


				log_mesg("$source_filename: $transfer_type transfer beginning...\n");

				undef $put_result;
				$TRANSFERRING = 1;

				$put_result = $ftp->put($source_filename);

				if (not ($put_result)) {
					$remove_attempted = 0;
					log_mesg("$source_filename: Error: Could not transfer file: " . $ftp->message . "\n");
					$new_destination_size = $ftp->size($source_filename);

					if (($destination_size =~ /[0-9]/) and ($new_destination_size =~ /[0-9]/)) {
						if ($new_destination_size != $destination_size) {
							log_mesg("$source_filename: partial or erroneous file transferred to remote server.\n");
							remove_remote_file($source_filename, $destination_dir);
							$remove_attempted = 1;
						}
					}

					if (! ($remove_attempted)) {
						log_mesg("$source_filename: did not attempt to remove remote file.\n");
					}

					exit_child_process(1, "");
				}

				$TRANSFERRING = 0;

				# determine size of remote file
				$new_destination_size = $ftp->size($source_filename);
	
				if (! defined($new_destination_size) ) {
					exit_child_process(99, "$source_filename: Warning: Unable to determine size of remote file. Remote file will not be removed : " . $ftp->message . "\n");
				}

  			 	($dev,$ino,$mode,$nlink,$uid,$gid,$rdev,$source_file_size,$atime,$mtime,$ctime,$blksize,$blocks) = stat($source_filename);

				# compare sizes of remote and local files
				if ($source_file_size != $new_destination_size) {
					if ($transfer_type eq 'BINARY') {
						log_mesg("$source_filename: Error: binary file transferred, but local and remote file sizes do not match. Local size  = $source_file_size and remote size = $new_destination_size.\n");
				remove_remote_file($source_filename, $destination_dir);
						exit_child_process(1, "");
					}
					else {
						exit_child_process(99, "$source_filename: Warning: ascii file transferred, but local and remote file sizes do not match. Local size  = $source_file_size and remote size = $new_destination_size . This may or may not indicate a transfer problem.\n");
					}
				}
				else {
					exit_child_process(200, "$source_filename: successfully transferred.\n");
				}
			}
			else {
				if (! defined($pid)) {
					log_mesg("Error: Unable to fork process for $source_filename\n");
				} else {
					$threads++;
				}

				$child_logfile = "$child_logdir/ftp.$source_filename.$pid.out";
				$num_remaining_files--;
				$children{$pid}{'FILENAME'} = $source_filename;
				$children{$pid}{'LOGFILE'} = $child_logfile;
				$children{$pid}{'STARTTIME'} = time;
				$children{$pid}{'FILESIZE'} = $source_file_size;
			}
		}

		# this is also parent process code

		# wait for a transfer process to exit IF thread limit reached or no more files to transfer

		if ( ($threads == $max_connections) or ($num_remaining_files <= 0) ) {
			# wait for any child transfer process to complete
			$waited_pid = wait;

			$child_returncode = ($? >> 8); # return code must be decoded from $?
			$end_time = time;
			$start_time = $children{$waited_pid}{'STARTTIME'};
			$report_xfer_rate = 1; # assume xfer rate will be OK to report

			# check return code of child process (200 means success)
			if ($child_returncode != 200) {
				if ($child_returncode == 99) {
					log_mesg("Warning: Process $waited_pid ($children{$waited_pid}{'FILENAME'}) completed with a warning.\n");
				} elsif ($child_returncode == 100) {
					log_mesg("Note: Process $waited_pid ($children{$waited_pid}{'FILENAME'}) intentionally skipped the file transfer.\n");
				} else {
					log_mesg("Error: Process $waited_pid ($children{$waited_pid}{'FILENAME'}) failed with return code $child_returncode.\n");
				}

				log_mesg("Process log follows:\n");
				if (open CHILDLOG, "< $children{$waited_pid}{'LOGFILE'}" ) {
					while (<CHILDLOG>) {
						log_mesg($_);
					}
					close(CHILDLOG);
				} else {
					log_mesg("Could not read log file $children{$pid}{'LOGFILE'}\n");
				}

				# count as a failed transfer unless it was a warning (99) or a skipped transfer (100)
				if ($child_returncode == 99) {
					$fs_num_warning++;
					$return_mesg = 'completed with warning';
					$fs_successful_bytes += $children{$waited_pid}{'FILESIZE'};
				} elsif ($child_returncode == 100) {
					$fs_num_skipped++;
					$return_mesg = 'transfer skipped';
					$report_xfer_rate = 0; # do not report xfer rate
				} else {
					$fs_num_failed++;
					$fs_rc = 1;	# fileset return code
					$return_mesg = 'failed';
					$report_xfer_rate = 0; # do not report xfer rate
				}

				# remove temp child log file (no longer needed)
				$num_deleted = unlink $children{$waited_pid}{'LOGFILE'};
				if ($num_deleted != 1) {
					log_mesg("Error: Unable to remove child log file $children{$waited_pid}{'LOGFILE'} - $!\n");
				}

			} else {
				$fs_num_completed++;
				$return_mesg = 'success';
				$num_deleted = unlink $children{$waited_pid}{'LOGFILE'};
				if ($num_deleted != 1) {
					log_mesg("Error: Unable to remove child log file $children{$waited_pid}{'LOGFILE'} - $!\n");
				}
				$fs_successful_bytes += $children{$waited_pid}{'FILESIZE'};
			}

			($elapsed, $xfer_rate_mesg) = get_xfer_stats($start_time, $end_time, $children{$waited_pid}{'FILESIZE'}, $report_xfer_rate);

			log_mesg("finish: file=$children{$waited_pid}{'FILENAME'}, return_code=$child_returncode, return_mesg=$return_mesg, elapsed=$elapsed, rate=$xfer_rate_mesg\n");
			$threads--;
		}
	}

	$fs_end_time = time;	# get end time for fileset
	$col_successful_bytes += $fs_successful_bytes;

	($fs_elapsed, $fs_xfer_rate_mesg) = get_xfer_stats($fs_start_time, $fs_end_time, $fs_successful_bytes, $fs_report_xfer_rate);

	log_mesg("**  End: fileset=$fileset_name, return_code=$fs_rc, completed=$fs_num_completed, failed=$fs_num_failed, warned=$fs_num_warning, skipped=$fs_num_skipped, elapsed=$fs_elapsed, rate=$fs_xfer_rate_mesg\n");

	if ($fs_rc > 0) {
		$col_rc = 1;
	}
	$col_num_completed += $fs_num_completed;
	$col_num_failed += $fs_num_failed;
	$col_num_warning += $fs_num_warning;
	$col_num_skipped += $fs_num_skipped;
}

$col_end_time = time;	# get end time for collection

($col_elapsed, $col_xfer_rate_mesg) = get_xfer_stats($col_start_time, $col_end_time, $col_successful_bytes, $col_report_xfer_rate);

log_mesg("*** End: collection=$collection, return_code=$col_rc, completed=$col_num_completed, failed=$col_num_failed, warned=$col_num_warning, skipped=$col_num_skipped, elapsed=$col_elapsed, rate=$col_xfer_rate_mesg\n");

exit($col_rc);

