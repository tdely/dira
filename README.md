# dira

Manage git profiles through symlinks.

You can create profiles, and set basic config values at the same time.

```
$ dira new --set steward-alpha
setting up profile, leave empty to skip
user.name: Etienne Steward
user.email: steward@coherentlight.com
core.editor:
new profile created at /home/steward/.config/git/steward-alpha.prf
```

It's also possible to clone an existing profile if you want to base the new
profile on another.

```
$ dira clone steward-alpha steward-beta
new profile created at /home/steward/.config/git/steward-beta.prf
```

Review a profiles settings with `show`.

```
$ dira show steward-beta
[user]
        name = Etienne Steward
        email = steward@coherentlight.com
[core]
```

List available profiles, current profile is indicated by `*`.

```
$ dira list
* steward-alpha
  steward-beta
```

Change profile with `become`.

```
$ dira become steward-beta
```

Remove a profile.

```
$ dira remove steward-alpha
removing profile 'steward-alpha', continue? [y/N] y
```

Show details using `status`.

```
$ dira status --verbose
profile: tdely
symlink: /home/steward/.config/git/config
source: /home/steward/.config/git/tdely.prf
  [user]
        name = Etienne Steward
        email = steward@coherentlight.com
  [core]

repository .git/config:
  [core]
        repositoryformatversion = 0
        filemode = true
        bare = false
        logallrefupdates = true
  [remote "origin"]
        url = git@github.com:tdely/dira.git
        fetch = +refs/heads/*:refs/remotes/origin/*
  [branch "master"]
        remote = origin
        merge = refs/heads/master
```

Rename a profile.

```
$ dira rename steward-beta steward
```
