# backup-scripts

Small collection of scripts for snapshot backups of:
 - files: using rsync
 - MySQL/MariaDB or PostgreSQL: using default dump tools

## make-snapshot

Create new snapshot of a file system tree using rsync(1). The script creates hard links of unchanged files at the destination, thus limiting the space required more or less to the actual changes. This script was inspired by Mike Rubel's HOWTO [Easy Automated Snapshot-Style Backups with Linux and Rsync](http://www.mikerubel.org/computers/rsync_snapshots/).

The script allows one positional argument: a configuration file, which will be sourced and should set environment variables. This file can source other files, e.g. for global configuration.

The following option arguments can be passed:

  - `-i` or `--initial` creates the initial snapshot.
  - `-v` or `--verbose` increase verbosity.
  - `-n` or `--dry-run` run a simulation, without copying any files.

The following variables need to be set (either in the configuration file or in the environment):

  - `LIB_DIR` defines the state directory, which is used to save the timestamp of the last run.
  - `LOG_DIR` is the directory for logfiles. A subdirectory with the job name will receive one file per run.
  - `BACKUP_TREE` is the root of the directory tree to be snapshotted.
  - `BACKUP_FILTER` is the name of a (per-directory) filter, in the format defined by rsync(1).
  - `REMOTE_BASE` is the target for snapshots, in a format understood by rsync(1).
  - `TAG` is the format for snapshot datestamps (i.e. name of directories created at the target), in the format used by date(1).

These variables are optional:

  - `LOCK_DIR` can specify a directory to have lockfiles, preventing concurrent snapshot runs. Strongly recommended to set.
  - `Job` is the job name and required if no configuration file is given. If configuration file is given and `Job` is not manually set, it defaults to the configuration file basename.
  - `TAG_OPTIONS` can contain additional options to be passed to date(1) for generating tags.
  - `REMOTE_AUTH` can be an array of additional options (passed to rsync), e.g. for authorising.

## snapshot@.service

This is a systemd(1) template service file for file system snapshots. It should be instantiated with the base name of a configuration located in `/etc/backup/snapshots`. The file extension `.conf` will be appended to the instance name.

## database-snapshot

Create and store database snapshot using dump tools. The script has been tested with MariaDB and PostgreSQL tools, but could possibly work well with other systems.

The script allows one positional argument: a configuration file, which will be sourced and should set environment variables. This file can source other files, e.g. for global configuration.

The following option arguments can be passed:

  - `-v` or `--verbose` increase verbosity.
  - `-n` or `--dry-run` run a simulation, without copying any files.

The following variables need to be set (either in the configuration file or in the environment):

  - `DATABASES` is a space-separated list of databases to be dumped.
  - `DB_DUMP` is the database-specific dump command (e.g. `mysqldump` or `pg_dump`). It will be called with optional `DB_ARGS` and a database name as positional argument.
  - `REMOTE_BASE` is the target for snapshots, in a format understood by rsync(1). Each run will create a new directory under that target, containing one file per dumped database.
  - `TAG` is the format for snapshot datestamps (i.e. name of directories created at the target), in the format used by date(1).

These variables are optional:

  - `Job` is the job name and required if no configuration file is given. If configuration file is given and `Job` is not manually set, it defaults to the configuration file basename.
  - `DB_USER` can specify a user under which the dump command should be run. If specified, the dump command is run with sudo(1).
  - `DB_ARGS` can be an array of additional arguments passed to the dump command.
  - `TAG_OPTIONS` can contain additional options to be passed to date(1) for generating tags.
  - `REMOTE_AUTH` can be an array of additional options (passed to rsync), e.g. for authorising.

## database-snapshot@.service

This is a systemd(1) template service file for database snapshots. It should be instantiated with the base name of a configuration located in `/etc/backup/snapshots`. The file extension `.conf` will be appended to the instance name.

## rotate-snapshots.pl

Delete old snapshots

