#!/usr/bin/perl

use Data::Dumper;
use Params::Validate qw(:all);

use strict;
use warnings;

our @all_systems = (qw/ds01 ds02 ds03 ds04 ds05 ds13/);
our $ssh = "ssh -q";

our $required = {
		GROUP => {	bluegrp	=>	{ 	gid		=>	761,
																users =>	[ qw/hp-nonstop ds bluelite cps/ ] },
																bshare	=>	{ 	gid		=>	762,
																users =>	[ qw/ds bluelite/ ] },
								dba			=>	{ 	gid		=>	503,
																users =>	[ qw/bluelite oracle/ ] }
							},
		USER	=> {	oracle		=> {	uid						=> 502,
																default_group	=> 'dba',
																groups				=> [ ],
																comment				=> 'Oracle Administrator' },
								bluelite	=> {	uid						=> 502,
																default_group	=> 'bluegrp',
																groups				=> [ qw/bshare users dba/],
																comment				=> 'Oracle Administrator' }
							}
	};

our $groupmod = "/usr/sbin/groupmod";
our $groupadd = "/usr/sbin/groupadd";
our $useradd = "/usr/sbin/useradd";
our $usermod = "/usr/sbin/usermod";

our $current = {};

sub group_name ($$)
{
	my $group_id = shift;
	my $system = shift;
	my $group_name;

	if (! exists($current->{$system}))
	{
		print STDERR "group_name: Unknown system \"$system\"\n";
		exit(1);
	}

	if ($group_id !~ /^\d+$/)
	{
		print STDERR "group_name: Group ID \"$group_id\" is not a group_id\n";
		exit(1);
	}

	foreach $group_name (keys %{$current->{$system}->{GROUP}})
	{
		if ($current->{$system}->{GROUP}->{$group_name}->{gid} == $group_id)
		{
			return $group_name;
		}
	}
	return undef;
}

sub group_id ($$)
{
	my $group_name = shift;
	my $system = shift;

	if (! exists($current->{$system}))
	{
		print STDERR "group_id: Unknown system \"$system\"\n";
		exit(1);
	}

	if (! exists($current->{$system}->{GROUP}->{$group_name}))
	{
		print STDERR "Unknown group \"$group_name\" on system \"$system\"\n";
		exit(1);
	}

	return $current->{$system}->{GROUP}->{$group_name}->{gid};
}

sub group_exists ($$)
{
	my $group = shift;
	my $system = shift;
	my $group_name;

	if (! exists($current->{$system}))
	{
		print STDERR "group_exists: Unknown system \"$system\"\n";
		exit(1);
	}

	if ($group =~ /^\d+$/)
	{

		foreach $group_name (keys %{$current->{$system}->{GROUP}})
		{
			if ($current->{$system}->{GROUP}->{$group_name}->{gid} == $group)
			{
				return 1;
			}
		}

	}
	else
	{

		if (exists($current->{$system}->{GROUP}->{$group}))
		{
			return 1;
		}
	}

	return 0;

}

sub user_exists ($$)
{
	my $user = shift;
	my $system = shift;
	my $user_name;

	if (! exists($current->{$system}))
	{
		print STDERR "user_exists: Unknown system \"$system\"\n";
		exit(1);
	}

	if ($user =~ /^\d+$/)
	{
		foreach $user_name (keys %{$current->{$system}->{USER}})
		{
			if ($current->{$system}->{USER}->{$user_name}->{uid} == $user)
			{
				return 1;
			}
		}
	}
	else
	{
		if (exists($current->{$system}->{USER}->{$user}))
		{
			return 1;
		}
	}

	return 0;

}

sub user_name ($$)
{
	my $user_id = shift;
	my $system = shift;
	my $user_name;

	if (! exists($current->{$system}))
	{
		print STDERR "user_name: Unknown system \"$system\"\n";
		exit(1);
	}

	foreach $user_name (keys %{$current->{$system}->{USER}})
	{
		if ($current->{$system}->{USER}->{$user_name}->{uid} == $user_id)
		{
			return $user_name;
		}
	}
	return undef;
}

sub user_id ($$)
{
	my $user_name = shift;
	my $system = shift;

	if (! exists($current->{$system}))
	{
		print STDERR "user_id: Unknown system \"$system\"\n";
		exit(1);
	}

	if (! exists($current->{$system}->{USER}->{$user_name}))
	{
		print STDERR "Unknown user \"$user_name\" on system \"$system\"\n";
		exit(1);
	}

	return $current->{$system}->{USER}->{$user_name}->{uid};
}


sub user_info ($$$)
{
	my $user = shift;
	my $system = shift;
	my $info = shift;
	my $user_name;

	my $the_user_name;

	if (! exists($current->{$system}))
	{
		print STDERR "user_exists: Unknown system \"$system\"\n";
		exit(1);
	}

	if ($user =~ /^\d+$/)
	{
		foreach $user_name (keys %{$current->{$system}->{USER}})
		{
			if ($current->{$system}->{USER}->{$user_name}->{uid} == $user)
			{
				$the_user_name = $user_name;
			}
		}
	}
	else
	{
		if (exists($current->{$system}->{USER}->{$user}))
		{
			$the_user_name = $user;
		}
	}

	if (! defined($the_user_name))
	{
		#print STDERR "user_$info: Cannot locate the user \"$user\" on system $system\n";
		return "";
	}


	return defined($current->{$system}->{USER}->{$user}->{$info}) ? $current->{$system}->{USER}->{$user}->{$info} : "";

}

sub user_comment ($$)
{
	my $user = shift;
	my $system = shift;

	return user_info($user, $system, 'comment');
}

sub user_default_group ($$)
{
	my $user = shift;
	my $system = shift;

	return user_info($user, $system, 'default_gid');

}

sub user_passwd ($$)
{
	my $user = shift;
	my $system = shift;

	return user_info($user, $system, 'passwd');
}

sub user_homedir ($$)
{
	my $user = shift;
	my $system = shift;

	return user_info($user, $system, 'homedir');
}

sub user_login_prog ($$)
{
	my $user = shift;
	my $system = shift;

	return user_info($user, $system, 'login_prog');
}

sub info_collected($)
{
my $system = shift;

	if (exists($current->{$system}))
	{
		return 1;
	}
	else
	{
		return 0;
	}
}

sub collect_user_and_group_info($)
{
my $system = shift;
my ($username, $passwd, $uid, $default_gid, $comment, $gid, $homedir, $login_prog);
my ($groupname, $users_field, $users);

	delete($current->{$system});
 
	print "Collecting user and group information from system $system\n";

	open (DATA, "$ssh -q $system cat /etc/passwd |" ) || die $!;

	while (<DATA>)
	{
		chomp;
		next if (! /[:].*[:]/);
		($username, $passwd, $uid, $default_gid, $comment, $homedir, $login_prog) = split("[:]", $_);

		$current->{$system}->{USER}->{$username} = {	uid						=>	$uid,
																									default_gid		=> $default_gid,
																									comment				=> $comment,
																									homedir				=> $homedir,
																									login_prog		=> $login_prog } ;
	}

	close (DATA);

	open (DATA, "$ssh -q $system cat /etc/group |" ) || die $!;

	while (<DATA>)
	{
		chomp;
		next if (! /[:].*[:]/);
		($groupname, $passwd, $gid, $users_field) = split("[:]", $_);
		@{$users} = split(",", $users_field);

		$current->{$system}->{GROUP}->{$groupname} = {	gid						=>	$gid,
																								users					=>	$users};

	}

	close (DATA);

	open (DATA, "$ssh -q $system cat /etc/shadow |" ) || die $!;

	while (<DATA>)
	{
		chomp;
		next if (! /[:].*[:]/);
		($username, $passwd) = split("[:]", $_, 3);

		$current->{$system}->{USER}->{$username}->{passwd} = $passwd;

	}

	close (DATA);


#	print "DUMP of $system\n";
#	print Dumper ($current->{$system});
}

sub update_group($;@)
{
	my %option;
	my $group_id;
	my $group_name;
	my @systems;
	my $system;

	%option = validate_with
							( params  => \@_,
								spec    => {  group_id			=>  { type => SCALAR, optional => 1 },
															sys						=>  { type => SCALAR|ARRAYREF, optional => 1 },
															group_name		=>  { type => SCALAR, optional => 1 }
							},
								called  => 'update group',
								normalize_keys => sub { my $k = shift; $k =~ s/^-//; return uc $k }
							);

	if (! exists($option{GROUP_ID}))
	{
		print STDERR "update_group: No group id given\n";
		exit(1);
	}
	$group_id = $option{GROUP_ID};

	if (! exists($option{GROUP_NAME}))
	{
		print STDERR "update_group: No group name given\n";
		exit(1);
	}

	$group_name = $option{GROUP_NAME};

	if (exists($option{SYS}))
	{
		if (ref($option{SYS}) eq "ARRAY")
		{
			@systems = @{$option{SYS}};
		}
		else
		{
			@systems = split (",", $option{SYS});
			foreach (@systems) { s/^\s+//; s/\s*$//; } ;
		}
	}
	else
	{
		@systems = @all_systems;
	}

print "SYSTEMS: " . join(", ", @systems) . "\n";

	foreach $system (@systems)
	{

		if (! info_collected($system))
		{
			collect_user_and_group_info($system);
		}
			
		if (group_exists($group_name, $system))
		{

			# Check if the group is correct

			if (group_id($group_name, $system) != $group_id) 
			{
			
				# Mod the group
				print "Mod group $group_id ($group_name) to system $system\n";

				if (group_exists($group_id, $system))
				{
					printf STDERR "update_group: Unable to change group \"%s\" id from %s to %s on system $system because that group_id already exists as \"%s\"\n", 
										$group_name,
										group_id($group_name, $system),
										$group_id,
										group_name($group_id, $system);
				}
				else
				{
					print "CMD: $ssh $system $groupmod -g $group_id $group_name\n";
				}
			}
			else
			{
				printf "group_mod: Group \"%s\" is correct on system \"%s\" with id of %s\n",
							$group_name,
							$system,
							$group_id;
			}
		}
		else
		{
			# Add the group
			print "Add group $group_id ($group_name) to system $system\n";
			print "CMD: $ssh $system $groupadd -f -g $group_id $group_name\n";
		}
	}
}

sub update_user($;@)
{
	my %option;
	my $user_id;
	my $user_name;
	my @systems;
	my $system;
	my @groups;
	my $mod;
	my $add_user;
	my $required_option;

	%option = validate_with
							( params  => \@_,
								spec    => {  user_id					=>  { type => SCALAR, optional => 1 },
															sys							=>  { type => SCALAR|ARRAYREF, optional => 1 },
															homedir					=>  { type => SCALAR, optional => 1 },
															user_name				=>  { type => SCALAR, optional => 1 },
															login_prog						=>  { type => SCALAR, optional => 1 },
															comment					=>  { type => SCALAR, optional => 1 },
															passwd					=>  { type => SCALAR, optional => 1 },
															default_group		=>  { type => SCALAR, optional => 1 },
															groups					=>  { type => SCALAR|ARRAYREF, optional => 1 }
							},
								called  => 'update user',
								normalize_keys => sub { my $k = shift; $k =~ s/^-//; return uc $k }
							);


	if (! exists($option{USER_NAME}))
	{
		print STDERR "update_user: No user name given\n";
		exit(1);
	}

	$user_name = $option{USER_NAME};

	if ($user_name eq "root")
	{
		print STDERR "Very unwilling to modify the root user - what are you doing?\n";
		exit(1);	
	}



	print "CMD:\n";
	print "CMD:# Configuring user $user_name\n";
	print "CMD:\n";


	if (exists($option{SYS}))
	{
		if (ref($option{SYS}) eq "ARRAY")
		{
			@systems = @{$option{SYS}};
		}
		else
		{
			@systems = split (",", $option{SYS});
			foreach (@systems) { s/^\s+//; s/\s*$//; } ;
		}
	}
	else
	{
		@systems = @all_systems;
	}

	if (exists($option{GROUPS}))
	{
		if (ref($option{GROUPS}) eq "ARRAY")
		{
			@groups = @{$option{GROUPS}};
		}
		else
		{
			@groups = split (",", $option{GROUPS});
			foreach (@groups) { s/^\s+//; s/\s*$//; } ;
		}
	}
	else
	{
		@groups = ();
	}

	if (defined($option{LOGIN_PROG}))
	{
		if ($option{LOGIN_PROG} =~ /^\s*no\s?login\s*$/i)
		{
			$option{LOGIN_PROG} = "/sbin/nologin";
		}
		elsif ($option{LOGIN_PROG} =~ /^\s*bash\s*$/i)
		{
			$option{LOGIN_PROG} = "/bin/bash";
		}
	}

	foreach $system (@systems)
	{

		if (! info_collected($system))
		{
			collect_user_and_group_info($system);
		}

		if (user_exists($user_name, $system))
		{
			$add_user = 0;
		}
		else
		{
			$add_user = 1;
		}

		# Check if the user is correct

		$mod = "";

		if (defined($option{COMMENT}) && (	$add_user ||
																				user_comment($user_name, $system) ne $option{COMMENT}))
		{
			$mod .= " -c \\'$option{COMMENT}\\'";
		}

		if (defined($option{USER_ID}) && (	$add_user ||
																				user_id($user_name, $system) != $option{USER_ID}) )
		{
		
			if (!$add_user && user_exists($option{USER_ID}, $system))
			{
				printf STDERR "update_user: Unable to change user \"%s\" id from %s to %s on system $system because that user_id already exists as \"%s\"\n", 
									$user_name,
									user_id($user_name, $system),
									$option{USER_ID},
									user_name($option{USER_ID}, $system);
			}
			else
			{
				$mod .= " -u $option{USER_ID}";
			}
		}

print "DEBUG: " . join(", ", user_default_group($user_name, $system), $option{DEFAULT_GROUP}) . "\n";
		if (defined($option{DEFAULT_GROUP}))
		{
			if ($option{DEFAULT_GROUP} =~ /^\d+$/)
			{
print "DEBUG: " . join(", ", user_default_group($user_name, $system), $option{DEFAULT_GROUP}) . "\n";
				if  (	$add_user || user_default_group($user_name, $system) ne $option{DEFAULT_GROUP})
				{
					if (group_exists($option{DEFAULT_GROUP}, $system))
					{
						$mod .= " -g $option{DEFAULT_GROUP}";
					}
					else
					{
						print STDERR "update_user: Cannot modify user's default group to '$option{DEFAULT_GROUP}' because it does not exists on $system\n";
					}
				}
			}
			else
			{
print "DEBUG: " . join(", ", user_default_group($user_name, $system), group_id($option{DEFAULT_GROUP}, $system)) . "\n";
				if  (	$add_user || !group_exists($option{DEFAULT_GROUP}, $system) || user_default_group($user_name, $system) ne group_id($option{DEFAULT_GROUP}, $system))
				{
					if (group_exists($option{DEFAULT_GROUP}, $system))
					{
						$mod .= " -g $option{DEFAULT_GROUP}";
					}
					else
					{
						print STDERR "update_user: Cannot modify user's default group to '$option{DEFAULT_GROUP}' because it does not exists on $system\n";
					}
				}
				elsif (!group_exists($option{DEFAULT_GROUP}, $system))
				{
					print STDERR "update_user: Cannot modify user's default group to '$option{DEFAULT_GROUP}' because it does not exists on $system\n";
				}
			}

		}

		if (defined($option{PASSWD}) && 	(	$add_user ||
																				user_passwd($user_name, $system) ne $option{PASSWD}))
		{
			$mod .= " -p \\'$option{PASSWD}\\'";
		}

		if (defined($option{LOGIN_PROG}) && 	(	$add_user ||
																			user_login_prog($user_name, $system) ne $option{LOGIN_PROG}))
		{
			$mod .= " -s \\'$option{LOGIN_PROG}\\'";
		}

			
		if (! $add_user)
		{

			if ($mod !~ /^\s*$/)
			{
					print "CMD: $ssh $system $usermod $mod $user_name\n";
			}
			else
			{
				printf "user_mod: User \"%s\" is correct on system \"%s\"\n",
							$user_name,
							$system;
			}
		}
		else
		{
			# Add user
			foreach $required_option (qw/USER_ID HOMEDIR LOGIN_PROG PASSWD DEFAULT_GROUP/)
			{
				if (! exists($option{USER_ID}))
				{
					print STDERR "update_user: Option \"$required_option\" required during an add of a user \"$user_name\" on system \"$system\"\n";
					exit(1);
				}
			}

			if ($mod !~ /^\s*$/)
			{
				print "CMD: $ssh $system $useradd -n $mod $user_name\n";
			}
			else
			{
				printf "user_mod: User \"%s\" is correct on system \"%s\"\n",
							$user_name,
							$system;
			}
		}
	}
}


update_group(group_id => 550, group_name => 'dba', sys => 'ds01');
update_group(group_id => 761, group_name => 'bluegrp');
update_group(group_id => 762, group_name => 'bshare');

update_user(	user_id => 505, 
							user_name => 'cps', 
							default_group => 'bluegrp', 
							login_prog => 'bash',
							comment => 'CPS Data Source Incoming', 
							passwd => '8fs.F4.mgcud6');

update_user(	user_id => 3761, 
							user_name => 'bluelite', 
							default_group => 'bluegrp', 
							comment => 'Data Services Administrator', 
							passwd => 'P6B6BINU0ukHQ');

update_user(	user_id => 502, 
							user_name => 'oracle', 
							default_group => 'dba', 
							comment => 'Oracle Administrator',
							passwd => 'P6B6BINU0ukHQ');

update_user(	user_id => 501, 
							user_name => 'vftp', 
							default_group => 'bluegrp', 
							comment => 'VFTP Data Source Incoming',
							passwd => '');

update_user(	user_id => 503, 
							user_name => 'hp-nonstop', 
							default_group => 'bluegrp', 
							comment => 'AuditLog Data Source Incoming',
							passwd => '/lFFpYqTmp5GQ');

update_user(	user_id => 504, 
							user_name => 'tulsa', 
							default_group => 'bluegrp', 
							comment => 'Tulsa Data Source Incoming',
							passwd => 'Oa..zaY6kz51o');

update_user(	user_id => 3762, 
							user_name => 'ds', 
							default_group => 'bluegrp', 
							comment => 'Data Service Ad-Hoc',
							passwd => 'JGxyCAWuFTVyU');

update_user(	user_id => 3763, 
							user_name => 'walmart', 
							default_group => 'bluegrp', 
							comment => 'Walmart Incoming',
							passwd => 'JGxyCAWuFTVyU');

exit(0);








__END__

adallas:x:500:501:Aaron Dallas x2883:/home/adallas:/bin/bash
bluelite:x:3761:761:Data Service:/home/bluelite:/bin/bash
ds:x:3762:761:Data Service Production:/home/ds:/bin/bash
vftp:x:501:761:VFTP Incoming Data Sources:/ds/data_sources/incoming/vftp:/sbin/nologin
oracle:x:502:100:Oracle Admin:/home/oracle:/bin/bash
cps:x:505:761:CPS System:/ds/data_sources/incoming/cps:/sbin/nologin
tulsa:x:504:761:Tulsa Data Source:/ds/data_sources/incoming/tulsa:/sbin/nologin
hp-nonstop:x:503:761:Tandem Data Sources:/ds/data_sources/incoming/tandem:/sbin/nologin

bluelite:$1$fu1MagOa$gDoq3ixn9vbs/YcJtnTgc1:13298:0:99999:7:::
ds:$1$y3z/D.Hm$BgGa7iJlyPAl6rByXF0Ei.:13306:0:99999:7:::
vftp:$1$MT09ATCt$ytMXUz1lG1TqN1F39BmRU0:13301:0:99999:7:::
oracle:$1$IvtcHl.1$AH6S98sZ3DG0VMP3M5SME.:13300:0:99999:7:::
cps:$1$msccOsRr$HPKd55MAb1OZ2NahR1FnB.:13305:0:99999:7:::
tulsa:$1$4igYQUOK$afiPbKd6UGiaAqIaceZF41:13305:0:99999:7:::
hp-nonstop:$1$4GnEMRK2$mob4FappC6LABHjgMg3/q1:13304:0:99999:7:::



