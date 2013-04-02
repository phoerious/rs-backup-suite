# rs-backup-suite

rs-backup-suite is a set of shell scripts for setting up a custom NAS on a computer in the network. It uses [rsync](http://rsync.samba.org/) and [rsnapshot](http://www.rsnapshot.org/).

## How it works
rs-backup-suite is designed for push backups, which means the client pushes its files to the server. This is ideal for computers which are not always on such as most desktop PCs.

It is also a user-centric backup system. That means each user creates his own backup on the NAS instead of root backing up the whole machine at once (although this is possible). That also means that each user has a UNIX account on the NAS. The NAS username is usually <hostname>-<local user name> (e.g. mymachine-johndoe).

On the client machine(s) each user can create a file called `.rs-backup-include` (name is configurable) inside his home directory which includes the list of files to that should be considered by the backup. Additionally root can maintain a similar file located at `/usr/local/etc/rs-backup/include-files` for the system files.

## Setup (please read this carefully before performing any actions!)
rs-backup-suite is split into two parts: a client part for pushing the backup to the NAS and a server part which runs on the NAS itself.

### Server
For the server part simply copy the contents of the `server` directory to your root directory and all the necessary files will be in place. Make sure that all files that are copied to `/usr/local/bin` and `/usr/local/sbin` are executable. Furthermore make sure that `/usr/local/bin` and `/usr/local/sbin` are in your `$PATH` environment variable as root. Finally rename the file `/usr/local/etc/server-config.example` to `/usr/local/etc/server-config`.

#### Adding a backup user
A backup user can be created by running

    rs-add-user hostname username [ssh-public-key-file]

where `hostname` is the name of the client host and `username` is the name of the user on that machine for whom this account is made. Of course you can use any other names for `hostname` and `username` as well, but it's generally a good idea to stick to this naming convention. The resulting UNIX username will be the combination of both.

The optional third parameter specifies the path to the SSH public key file which the user will use to log into the NAS. If you don't specify it, the user won't be able to log in at all. But you can add one later at any time by running

    rs-add-ssh-key hostname username ssh-public-key-file

`hostname` and `username` are the same as above and mandatory for identifying the user that should get the new key.

**TIP:** If you don't remember the parameters for all these commands, simply run them without any and you'll get simple usage instructions.

#### Making the chroot work
rs-backup-suite can chroot backup users into the backup home base directory. For this to work you need to add the following to your `/etc/fstab` and run `mount -a` afterwards:

    # Chroot
    /bin                    /bkp/bin                none    bind             0       0
    /lib                    /bkp/lib                none    bind             0       0
    /usr/bin                /bkp/usr/bin            none    bind             0       0
    /usr/lib                /bkp/usr/lib            none    bind             0       0
    /usr/local/bin          /bkp/usr/local/bin      none    bind             0       0
    /usr/share/perl5        /bkp/usr/share/perl5    none    bind             0       0
    /dev                    /bkp/dev                none    bind             0       0

Then add this to the end of your `/etc/ssh/sshd_config`:
    
    Match Group backup 
        ChrootDirectory /bkp/

Then restart OpenSSH. Your backup users are now chrooted into `/bkp`.

**NOTE:** When using a chroot environment and you change anything in your user configuration (e.g. the username) you need to run `rs-update-passwd` or your user might not be able to log in anymore.

#### Tweaking the configuration file
The configuration file is `/usr/local/etc/server-config`. There you can configure the following directives:

* `BACKUP_ROOT`: The directory under which the home directories of the backup users are stored. The default is `/bkp`
* `FILES_DIR`: The directory under which the actual backups are kept (relative to the backup user's home directory). The default is `files`.
* `SET_QUOTA`: Whether to set disk quota for the users or not (for Ext3/4 file systems). Default is `false`.
* `QUOTA_SOFT_LIMIT`, `QUOTA_HARD_LIMIT`, `QUOTA_INODE_SOFT_LIMIT`, `QUOTA_INODE_HARD_LIMIT`: The individual limits for disk quota. Ignored, if `SET_QUOTA` is `false`.

**WARNING:** Adjust these settings *before* you create backup users, because they won't be re-applied for already existing users!

### Client
On the client machines the script `/usr/local/bin/rs-backup-run` is used for performing the backups. This script can either be run as root or as an unprivileged user. The behavior differs in both cases:

* If run as root, all files and folder specified in `/usr/local/etc/rs-backup/include-files` will be backed up. The backup user used for logging into the NAS is `hostname-root` by default (where `hostname` is the hostname of the current machine). Additionally the home directories of all users will be scanned. If a home directory contains a file called `.rs-backup-include` all files and folders specified inside that file will be backed up under this user's privileges. The username user for logging into the NAS is `hostname-username` by default (where `hostname` is again substituted by the hostname of the current machine and `username` is substituted by the user whose home directory is being backed up).
* If run as a normal user, only the files that are specified in the `.rs-backup-include` file inside the own home directory will be backed up.

`rs-backup-run` takes several command line arguments. To get a description for all of them run `rs-backup-run --help`.