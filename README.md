# OpenZFS Configuration

I use this to configure my OpenZFS installation. The current config has a single pool
with three separate file systems, that are all encrypted. The use-case is to provide
encrypted storage on a server that is using a distinct, unencrypted, file system to
boot and house `/home`; the intention is that this system have no "real" users, and no
sensitive data is to be stored in `/home`.

This config works for me, and this is here to remind me of some of the details. This
probably won't map to exactly your use-case, but I hope it provides a good starting
point.

## Dependencies

Mostly just the ZFS package for your distribution. I built this on and for my Ubuntu
22.04-based server, but imagine it will work with little or no adjustments on other
unix-like platforms with a working, recent, OpenZFS installation. Of particular note
for the scripts, however, is that I probably used GNU-specific features on a number of
the commands; I didn't try to generalize or POSIX-ify anything. I'm also using
[ripgrep](https://github.com/BurntSushi/ripgrep) instead of `grep`; it might run if you
try `alias rg=grep` in the shell before running things, but this is speculative. I also
don't currently run any BSD systems, so there may be something in the shell commands
that doesn't work with the BSD-flavor of various commands.

## Usage

Note: all paths are relative to the root of the repository, unless otherwise stated.

If you are new to ZFS, it might be worth reading up on it first:

- [OpenZFS - Getting Started](https://openzfs.github.io/openzfs-docs/Getting%20Started/index.html)
- [TrueNAS ZFS Primer](https://www.truenas.com/docs/references/zfsprimer/)

### Create pool-to-disk mapping

File: `{poolname}.disks`

Example: `pool-1.disks`

Hypothetically, any path from under `/dev/disk` can appear in this file, however, I
strongly recommend using a strictly consistent path/name, such as the disk id; I've
been using values under `/dev/disk/by-id`. To find values to include, install the disks
in your system, and run:

```shell
find /dev/disk/by-id -type l
```

On my disks, a bunch of SSDs, their serial number corresponds to their id value here.
If this value isn't obvious on the physical disk, I recommend writing the id value
directly onto the drive casing with a permanent marker. This way, if you have a failed
drive to replace, it's easier to determine which one to replace based on the
information in ZFS.

Also, disk partitions will appear under `/dev/disk/...`. I recommend only using whole
disks and not partitions. If you're experimenting to familiarize with ZFS, it should
create the pool even with partitions, however, this can prevent ZFS from creating a
reliable RAID file system. Imagine having all of your redundant containers running on a
single host...

### Create features listing

Stored in file: `zpool-features.csv`

This file stores the list of features that can be enabled on a pool. The included file
is, as of this writing, incomplete. It contains only the features I was looking at and
interested in. It is designed to enable toggling features on and off to rebuild the
pool repeatedly to experiment with different settings.

Sample:

```csv
option,ro-compatible,enable,dependencies
allocation_classes,yes,no,
async_destroy,yes,yes,
blake3,no,no,extensible_dataset
bookmarks,yes,no,extensible_dataset
bookmark_v2,no,no,bookmark;extensible_dataset
```

Fields:

| Field           | Description                                                                                                                                                                                 |
|-----------------|---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|
| `option`        | This is the specific name of the feature, as it will be passed to the `zpool create` command.                                                                                               |
| `ro-compatible` | Informational. Describes if this is compatible with mounting a pool read-only.                                                                                                              |
| `enable`        | Either `yes` or `no`. If `yes`, include this feature when creating the pool.                                                                                                                |
| `dependencies`  | Informational. Which features this feature depends on. If a feature is enabled, any features it depends on will automatically be enabled, even if they are not set to enabled in this file. |

### Generate run-time "features" configuration file

The `zpool-features.csv` file has to be pre-processed to generate the format expected
by the `zpool-create.sh` script:

```shell
0010-generate-features.sh
```

This assumes it is being run from the root of this project, and that the
`zpool-features.csv` file exists. It isn't very smart, so double check everything
before running. Also, it will overwrite the contents of `zpool-features-enabled.txt`;
don't edit this `.txt` file manually, or you will lose your changes.

### Create Pool Options configuration file

File: `zpool-options-enabled.txt`

This has essentially the same format as the above generated features file. For my case,
I didn't need to enable many options, so I didn't script out transforming a CSV file.
The format requires one entry per line, as it would be included in a call to the
`zpool` command. For example:

```text
-o autotrim=on
```

### Define the file systems to create

File: `zfs-create/file-systems.txt`

This file contains the resulting ZFS file system paths/names that will be created. Each
file system named will also have a `{filesystem-name}.settings` file. As file systems
can be nested, these are stored in a directory hierarchy that reflects the final
structure as it will be created in ZFS.

Example `file-systems.txt`:

```text
encrypted
encrypted/8k-lz4
encrypted/128k-zstd
encrypted/1024k-lz4
```

In this case, I named the file systems following the pattern:
`{parent-fs}/{record-size}-{compression}`

Also note that the parent file system, `encrypted` in this case, must be listed and
come before any of the children that will be nested under it.

#### Example `.settings` files

File: `zfs-create/encrypted.settings`

```text
-o encryption=on
-o keylocation=file:///dev/shm/openzfs.key
-o keyformat=passphrase
```

File: `zfs-create/encrypted/1024k-lz4.settings`

```text
-o compression=lz4
-o primarycache=metadata
-o recordsize=1m
```

Regarding the settings included with this repo, I wanted to enable encryption for all
file systems, so I have a parent file system, named `encrypted`, and create the other
file systems under it with their various block and compression settings specific to the
intended use.

### Modify shell variables in the scripts, as needed

File: `zpool-create.sh`

This script has several environment variables it sets at the top to control some
settings. The main variables you should consider changing, or keep them as defaults if
they work for you:

| Variable        | Default                | Purpose                                                                             |
|-----------------|------------------------|-------------------------------------------------------------------------------------|
| ZFS_ROOT        | `/zfs`                 | The ZFS pool and datasets will be mounted here. Directory must exist and be empty.  |
| POOL_NAME       | `pool-1`               | Like it sounds, the name of the pool in ZFS.                                        |
| ZPOOL_VDEV_TYPE | `raidz2`               | Essentially, what level of redundancy to use. Read the OpenZFS docs for more info.  |
| KEYFILE         | `/dev/shm/openzfs.key` | Temporary location to store the key when creating or opening the encrypted dataset. |

File: `zfs-create-keyfile.sh`

Similarly, this script needs to be modified so it's value for `KEYFILE` matches the
script above.

***WARNING*** The **KEYFILE** must be kept secret. This file **must never be stored in
the clear!**

Do not write this file to an unencrypted volume on the server; this would effectively
mean your ZFS file systems are not encrypted since anyone that gains access to the
server would have access to it. Also be mindful of the ability to recover deleted
files, especially if working with SSDs, which don't really delete anything physically.
Even for magnetic drives, supposedly with enough time, money, and technical resources,
even fully deleted files can be recovered unless you "shred" the disk blocks that used
to contain it. I recommend keeping the file or it's data in a password safe, or keeping
it in a location you plan to manually decrypt in order to unlock the ZFS file systems,
such as an LVM volume protected with LUKS. My scripts put this in `/dev/shm` because on
Linux (Ubuntu in my case), it's a commonly available RAM-only location so it should
disappear irrecoverably when the system is shut down. It's a good idea to also delete
the file when you're done, as a precaution; it is only needed until the encryption
process loads it into memory.

There are other ways to provide the key, but this fit my use-case and allows me to
start the server remotely. Check the docs to see what other options are available.

*To do: Move these out of the script, maybe to a `.env` type of file.*

### Deploy to the target server

To deploy, run `bin/push.sh {target-server}`. It uses `tar ` to gather all files in the
project and drop them in the default directory on the target. It uses the parent
directory name and delivers the files into such a directory on the target. For example,
if this project is checked out to `~/openzfs-config`, then it will create the
`openzfs-config` directory when pushing the files. You can spell `{target-server}` any
way that the `ssh` program will understand it.

The script doesn't attempt to filter anything out; it's easy to include additional
scripts or data. Also, it has no safeties or validity checks. Any existing files on the
target should get overwritten when this runs, but it won't remove other files in the
directory it writes to if they already exist on the target, probably, it isn't safe to
rely on this.

### Create the keyfile on the target

Create the KEYFILE by running this script:

```shell
zfs-create-keyfile.sh
```

It will prompt for the password when run; either type or paste the password into the
terminal. It takes reasonable care to protect it, such as running the prompt and such
in a sub-shell inside the script, and it does not echo back to the terminal. The script
uses `sudo` when working with the file, and sets permissions so that only `root` can
read or write it, before putting the key material in it. Review the script and if you
see improvements, please let me know.

Also, this script is intended to be used when opening the encrypted file systems later,
so it has some tips it prints to the console after it runs.

### Run create script on the target

Again, using `ssh`, etc... to run this script:

```shell
zpool-create.sh
```

This will create the pool using the storage devices specified in the `.disks` file,
then create each of the ZFS datasets (file systems) in `zfs-create/file-systems.txt`.

## Organizing and Using the File Systems

My use-case was primarily to create a backup location on my local network, run some
other packages as services, and share files on my network. Accordingly, I used a bunch
of symlinks into directories created under the ZFS file systems to abstract the
physical storage paths in ZFS from the logical storage paths exposed by the server. I
have a double-layer of indirection and while this isn't strictly necessary, it would
make it easy to migrate some existing data to a newly created pool, without having to
redirect a lot of the links.

I'm following the convention that things the server exposes should be under `/srv/`...

My layout:

**ZFS Pool and File Systems**

```text
/zfs/pool-1/encrypted/1024k-lz4
/zfs/pool-1/encrypted/128k-zstd
/zfs/pool-1/encrypted/8k-lz4
```

**Local ZFS Links**

```text
/zfs/mount/db -> /zfs/pool-1/encrypted/8k-lz4/
/zfs/mount/files -> /zfs/pool-1/encrypted/128k-zstd/
/zfs/mount/media -> /zfs/pool-1/encrypted/1024k-lz4/
```

**Exposed Directories**

```text
/srv/backups -> /zfs/mount/files/backups
/srv/db -> /zfs/mount/db
/srv/documents -> /zfs/mount/files/documents/
/srv/media -> /zfs/mount/media
/srv/pypi-server -> /zfs/mount/files/pypi-server/
/srv/rsync -> /zfs/mount/files/rsync/
/srv/user -> /zfs/mount/files/user/
```

## Design Considerations

One interesting point to consider when designing your layout, is that you may want to
focus on putting boundaries around things that you would want to snapshot
independently, for instance. Specifically, I created a single location for databases to
house my local Postgres databases, but if I were doing this "for work", I would create
a separate dataset for each database to maintain boundaries between them. My local
approach has the advantage that its easy to create new database instances; the "for
work" approach means going through the ZFS create process for each new one. It depends
on what your design criteria are and what guarantees you have to meet.

Another main design goal to have in mind is to have the right "record size" defined for
the kind of files you expect to be storing. From my understanding, 8k is a good size
for Postgres databases because of the page size it uses when interacting with disk
blocks. Conversely, large media file can benefit (slightly?) from a large record size,
so I used 1024k there. And when you don't know what to expect, I've read that 128k is a
reasonable default, hence the "files" mount.

## Tips

### Compression (probably do, but only lz4)

I think this is an easy win. On slow storage, it would even potentially improve
performance in cases that it reduces the number of disk blocks read. `lz4` is also
cheap and fast, and ZFS is smart enough to not use it when it wouldn't help. I have
enabled `zstd` on the dataset that I thought it might help, and while I haven't
thoroughly tested it, it doesn't have much of an additional effect in my case.
Everything is still fast enough and my server is no where near CPU bound, but if
CPU/RAM were to be less available on it, I think this would be the first thing I would
tune away. YYMV.

### Deduplication (probably don't)

This sounds cool, but I think it only helps in special cases. Out of curiosity, I ran
the command to simulate deduplication results on my pool, and it would not have
benefited me to use it, but it enabling it would require significant amounts of memory
and impact performance.

```shell
zdb --simulate-dedup {pool-name} 
```

### RAID Levels (only if you care about your data)

I used RAIDz with parity 2, meaning I can lose two disks and the array will not suffer
data loss. For me, this provides the right balance of safety, cost, performance, and
capacity; your needs may differ.

Mirroring is also good, and is fast, but uses a lot of capacity.

The new kid on the block now is "dRAID" which has some improvements over RAIDz, but you
would want to look into the details before using it.

### Research ZFS

If your data matter, read into what it takes to have a reliable and performant ZFS
storage layer. And I'll repeat what a lot of people write about ZFS... "Having a RAID
is not the same has having backups." Conflate the two at your own peril.

## References

- [OpenZFS: Feature Flags](https://openzfs.github.io/openzfs-docs/Basic%20Concepts/Feature%20Flags.html)
- [OpenZFS: zpool-features](https://openzfs.github.io/openzfs-docs/man/master/7/zpool-features.7.html)
- https://arstechnica.com/gadgets/2021/06/a-quick-start-guide-to-openzfs-native-encryption/
- [ripgrep](https://github.com/BurntSushi/ripgrep)
- [dRAID](https://openzfs.github.io/openzfs-docs/Basic%20Concepts/dRAID%20Howto.html)
