# Help Us Help You

When you have problems with `/usr/bin/ece`, `/usr/sbin/ece-install` or
any of the other commands on this repository, please provide us with a
couple of things:

## The versions of ece and ece-install

```
$ grep ^ece_scripts_version= /usr/{sbin/ece-install,bin/ece}
```

## The version of your operating system

Just run these three commands and give us the output:
```
$ lsb_release -a
$ cat /etc/debian_version
$ cat /etc/redhat-release
```

## For ece-install problems
Your `ece-install.conf` or `ece-install.yaml` file.

The contents of your sources.list (if you're on Debian/Ubuntu):
```
$ grep -r escenic /etc/apt/sources.list*
```

The log files of both `ece-install` and the instances you're setting up
(here, `engine1` is the instance):

```
/var/log/escenic/ece-install.log

/var/log/escenic/engine1.out
/var/log/escenic/engine1-catalina.out
/var/log/escenic/engine1-tomcat
/var/log/escenic/engine1-messages
```


