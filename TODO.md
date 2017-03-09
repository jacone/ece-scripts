
# Version 3.x aka "akbash"

## /usr/sbin/ece-install

### Install ECE from APT 
Support for installing ECE & plugins using the escenic APT
repositories.

- ✔ Editor profile
- ✔ Presentation profile
- ✔ Search profile
- ✔ DB profile, ECE
- ✔ DB profile, ECE plugins
- Create publication(s) profile
- Cache server profile

### YAML configuration file format

#### ✔ Credentials (good old `technet_user`++)
```
credentials:
  - site: maven.example.com
    user: foo
    password: bar
```

#### ✔ Editor profile
```
profiles:
  editor:
    install: yes
```

#### ✔ Presentation profile
```
profiles:
  presentation:
    install: yes
```
#### ✔ Search profile
```
profiles:
  search:
    install: yes
```
#### ✔ DB profile
Minimum:
```
profiles:
  db:
    install: yes
```

All supported options
```
profiles:
  db:
    install: yes
    user: dbuser
    password: dbpassword
    schema: dbpassword
    host: db1
    port: 3396
```

#### ✔ Create publication(s) profile
```
profiles:
   create_publications:
     - name: apple
       war: apple.war
       domain: apple.domain.com
       aliases:
         - apple_alias1
         - apple_alias2
     - name: orange
       war: orange.war
       domain: orange.domain.com
       aliases:
          - orange_alias1
          - orange_alias2
```
#### Cache server profile
#### Monitoring settings
#### EAR to deploy

###  ✔ Remove the interactive mode. 

It's rarely used and complicates the source code and configuration
options unnecessarily.

## /usr/bin/ece

- Easier to extend, e.g. put `create-publication.sh` in a directory,
  e.g.`ece.d`, and get `ece create-publication`. The
  `create-publication` sub command is then included in TAB completion,
  help screens and `man` pages.
  

## Version 4.x
###  Easier to extend `ece-install`

Preferably in any language. Put a file in a directory and
`ece-install` will execute that file at a predictable point in time.

