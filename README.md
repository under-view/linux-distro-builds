# Underview Linux Distro Builds

Repo that handles building underview linux distro's

**Clone Repo Command**
```sh
$ curl "https://storage.googleapis.com/git-repo-downloads/repo" > repo
$ chmod a+x repo
```

**Initialize Repos**
```sh
$ ./repo init -u "https://github.com/under-view/linux-distro-builds.git"
$ ./repo sync
```

**Build**
```sh
$ ./build.sh --machine udoo-bolt-emmc
# Building Project North Star Demo distro
$ ./build.sh --machine udoo-bolt-emmc --distro north-star-demo
```

**Flashing**
```sh
$ ./build.sh --machine udoo-bolt-live-usb --flash <block device>
```

**Inotify Errors/Solutions**

If you see the bellow error increase max_user_watches appropriately. For more info on inotify in linux go to [here](https://transang.me/enospc-inotify-in-ubuntu/).
```
ERROR: No space left on device or exceeds fs.inotify.max_user_watches?
```

One can increase inotify.max_user_watches by running the bellow
```sh
$ sudo sysctl -n -w fs.inotify.max_user_watches=$((1<<20))
```
