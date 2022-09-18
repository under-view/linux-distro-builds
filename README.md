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
```
