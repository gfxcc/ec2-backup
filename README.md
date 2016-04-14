EC2-BACKUP(1)		  BSD General Commands Manual		 EC2-BACKUP(1)

NAME
ec2-backup -- backup a directory into Elastic Block Storage (EBS)

SYNOPSIS
ec2-backup [-h] [-m method] [-v volume-id] dir

DESCRIPTION
The ec2-backup tool performs a backup of the given directory into Amazon
Elastic Block Storage (EBS).  This is achieved by creating a volume of
the appropriate size, attaching it to an EC2 instance and finally copying
the files from the given directory into this volume.

OPTIONS
ec2-backup accepts the following command-line flags:

-h 	   Print a usage statement and exit.

-m method	   Use the given method to perform the backup.	Valid methods
are 'dd' and 'rsync'; default is 'dd'.

-v volume-id  Use the given volume instead of creating a new one.

DETAILS
ec2-backup will perform a backup of the given directory to an ESB volume.
The backup is done in one of two ways: via direct write to the volume as
a block device (utilizing tar(1) on the local host and dd(1) on the
remote instance), or via a (possibly incremental) filesystem sync (uti-
lizing rsync(1)).

Unless the -v flag is specified, ec2-backup will create a new volume, the
size of which will be at least two times the size of the directory to be
backed up.

ec2-backup will create an instance suitable to perform the backup, attach
the volume in question and then back up the data from the given directory
using the specified method and then shut down and terminate the instance
it created.

OUTPUT
By default, ec2-backup prints the volume ID of the volume to which it
backed up the data as the only output.  If the EC2_BACKUP_VERBOSE envi-
ronment variable is set, it may also print out some useful information
about what steps it is currently performing.

Any errors encountered cause a meaningful error message to be printed to
STDERR.

ENVIRONMENT
ec2-backup assumes that the user has set up their environment for general
use with the EC2 tools.  That is, it will not set or modify any environ-
ment variables.

ec2-backup allows the user to add custom flags to the commands related to
starting a new EC2 instance via the EC2_BACKUP_FLAGS_AWS environment
variable.

ec2-backup also assumes that the user has set up their ~/.ssh/config file
to access instances in EC2 via ssh(1) without any additional settings.
It does allow the user to add custom flags to the ssh(1) commands it
invokes via the EC2_BACKUP_FLAGS_SSH environment variable.

As noted above, the EC2_BACKUP_VERBOSE variable may cause ec2-backup to
generate informational output as it runs.

EXIT STATUS
The ec2-backup will exit with a return status of 0 under normal circum-
stances.  If an error occurred, ec2-backup will exit with a value >0.

EXAMPLES
The following examples illustrate common usage of this tool.

To back up the entire filesystem using rsync(1):

$ ec2-backup -m rsync /
vol-a1b2c3d4
$ echo $?
0
$

To create a complete backup of the current working directory using
defaults (and thus not requiring a filesystem to exist on the volume) to
the volume with the ID vol-1a2b3c4d:

ec2-backup -v vol-1a2b3c4d .

Suppose a user has their ~/.ssh/config set up to use the private key
~/.ec2/stevens but wishes to use the key ~/.ssh/ec2-key instead:

$ export EC2_BACKUP_FLAGS_SSH="-i ~/.ssh/ec2-key"
$ ec2-backup .
vol-a1b2c3d4
$

To force creation of an instance type of t1.micro instead of whatever
defaults might apply

$ export EC2_BACKUP_FLAGS_AWS="--instance-type t1.micro"
$ ec2-backup .
vol-a1b2c3d4
$

SEE ALSO
aws help, dd(1), tar(1), rsync(1)

HISTORY
ec2-backup was originally assigned by Jan Schaumann
<jschauma@cs.stevens.edu> as a homework assignment for the class "Aspects
of System Administration" at Stevens Institute of Technology in the
Spring of 2011.

BSD				March 27, 2016				   BSD