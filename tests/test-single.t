  $ . $TESTDIR/helpers.sh

Base target repository with a configuration for a single upstream repo
  $ git init -q target
  $ cd target
  $ cat > config.toml << EOF
  > [[repo]]
  > org = "gh1"
  > name = "android1"
  > branches = [
  >     "master",
  > ]
  > EOF
  $ git add config.toml
  $ git commit -qm'Initial config'
  $ git log  --format='%H %s%n%b'
  d2b396073ea22d136cb636797a4bce9e02936681 Initial config
  
  $ cd ..

Create upstream repo, with a single commit for a l10n.toml and a strings.xml
  $ mkdir -p upstream/gh1
  $ cd upstream/gh1
  $ git init -q android1
  $ cd android1
  $ $TESTDIR/strings-xml app/src/main/res/values/strings.xml action_cancel=Cancel
  $ $TESTDIR/l10n-toml
  $ compare-locales --validate l10n.toml .
  en-x-moz-reference:
  unchanged         1
  unchanged_w       1
  0% of entries changed
  $ git add .
  $ git commit -qm'c0'
  $ cd ../../..
  $ mkdir gh1
  $ cd gh1
  $ git clone -q ../upstream/gh1/android1
  $ cd ..

Convert to target
  $ python -mmozxchannel.git.process --pull target

Validate some of the results
  $ cd target
  $ git log  --format='%H %s%n%b' ^d2b396073ea22d136cb636797a4bce9e02936681 master
  220c172534a238026314c7193053b96f304c522f c0
  X-Channel-Converted-Revision: [master] gh1/android1@28f8ea05feac63c5f3836603297a3bc9f3e2d544
  
  $ cd ..
  $ diff -q -x .git -r upstream/gh1/android1 target/gh1/android1

Add more content to upstream
  $ cd upstream/gh1/android1
  $ cat > README.md << EOF
  > This is just a file
  > EOF
  $ git add README.md
  $ git commit -qm'c1'
  $ $TESTDIR/strings-xml app/src/main/res/values/strings.xml \
  > action_cancel=Cancel \
  > action_ok=OK
  $ git commit -qam'c2'
  $ git log -n1 --format='%H'
  3f2cc03f88ccec09e1e2c57a1b785753fa382a57
  $ cd ../../..

Convert to target
  $ python -mmozxchannel.git.process --pull target

Validate new results
  $ cd target
  $ git log  --format='%H %s%n%b' ^220c172534a238026314c7193053b96f304c522f master
  69ab3c00e0258372f46da0ec3e4426d9b733ae93 c2
  X-Channel-Converted-Revision: [master] gh1/android1@3f2cc03f88ccec09e1e2c57a1b785753fa382a57
  
  $ cd ..

Create quarantine
  $ cd target
  $ git checkout -b quarantine
  Switched to a new branch 'quarantine'
  $ cd ..

Add more content to convert
  $ cd upstream/gh1/android1
  $ $TESTDIR/strings-xml app/src/main/res/values/strings.xml \
  > action_cancel=Cancel \
  > action_ok=OK \
  > action_submit=Submit
  $ git commit -qam'c3'
  $ git log -n1 --format='%H'
  45a2654fdb8e62b504eb63cea8d26125028e2c09
  $ cd ../../..

Convert to target
  $ python -mmozxchannel.git.process --pull --branch=quarantine target

Validate new results
  $ cd target
  $ git log  --format='%H %s%n%b' ^69ab3c00e0258372f46da0ec3e4426d9b733ae93 quarantine
  92799739ffb1140d899d50eb2ba3bb440625f27c c3
  X-Channel-Converted-Revision: [master] gh1/android1@45a2654fdb8e62b504eb63cea8d26125028e2c09
  
Merge quarantine
  $ git checkout -q master
  $ git merge -q quarantine
  $ git checkout -q quarantine
  $ git branch -v
    master     9279973 c3
  * quarantine 9279973 c3
  $ cd ..

Add a release fork
  $ cd upstream/gh1/android1
  $ git checkout -qb release 3f2cc03f88ccec09e1e2c57a1b785753fa382a57
  $ git checkout -q master
Modify development branch
  $ $TESTDIR/strings-xml app/src/main/res/values/strings.xml \
  > action_cancel=Cancel \
  > "action_submit=Submit it" \
  > action_other=Other
  $ git commit -qam'c4'
  $ git log -n1 --format='%H'
  d676c69ed791624b06c5cc0f510c5204dbc0d9e0
  $ git branch -v
  * master  d676c69 c4
    release 3f2cc03 c2
  $ cd ../../..

Add release branch to config
  $ cd target
  $ cat > config.toml << EOF
  > [[repo]]
  > org = "gh1"
  > name = "android1"
  > branches = [
  >     "master",
  >     "release",
  > ]
  > EOF
  $ git commit -qam'Add release'
  $ cd ..

Convert to target
  $ python -mmozxchannel.git.process --pull --branch=quarantine target

Validate new results
  $ cd target
  $ git log  --format='%H %s%n%b' ^92799739ffb1140d899d50eb2ba3bb440625f27c quarantine
  97af06b7126a9ea307f2576ac27de5bf8bb13bd9 c4
  X-Channel-Converted-Revision: [master] gh1/android1@d676c69ed791624b06c5cc0f510c5204dbc0d9e0
  X-Channel-Revision: [release] gh1/android1@3f2cc03f88ccec09e1e2c57a1b785753fa382a57
  
  9e4c15747fecea0f9ad377e75f407ca783cf71fc Add release
  
  $ cd ..

Recreate target repo in batch
  $ git init -q batched-target
  $ cp target/config.toml batched-target/config.toml
  $ cd batched-target
  $ git add config.toml
  $ git commit -qm'Initial config'
  $ git log --format='%H %s%n%b'
  f9f62493b7c3550e514bdf0baed5b7eb8457f301 Initial config
  
  $ cd ..

#Batch convert to new target
#  $ python -mmozxchannel.git.process batched-target
#
#Validate batched results
#  $ diff -x .git -qr target batched-target
#  $ cd batched-target
#  $ git log --format='%H %s%n%b'
