  $ . $TESTDIR/helpers.sh

Base target repository with a configuration for a single upstream repo
  $ git init -q target
  $ cd target
  $ cat > config.toml << EOF
  > [[repo]]
  > org = "gh1"
  > name = "android1"
  > branch = "master"
  > EOF
  $ git add config.toml
  $ git commit -qm'Initial config'
  $ git log  --format='%H %s%n%b'
  aafc5e0cb34ba3c6c5fc70f001f60e8320a1c153 Initial config
  
  $ target_rev
  $ cd ..

Create upstream repo, with a single commit for a l10n.toml and a strings.xml
  $ mkdir -p upstream/gh1
  $ cd upstream/gh1
  $ git init -q android1
  $ cd android1
  $ $TESTDIR/strings-xml app/src/main/res/values/strings.xml action_cancel=Cancel
  $ $TESTDIR/l10n-toml --locales de he sr-Cyrl
  $ git add .
  $ git commit -qm'c0'
  $ git log -n1 --format='%H'
  a5643d6afc7bad7e741991d4fcc935146ee27e72
  $ cd ../../..

Convert to target
  $ python -mmozxchannel.git.process --pull target

Validate some of the results
  $ cd target
  $ git log  --format='%H %s%n%b' $PREVIOUS_TARGET_REV master
  2c64ce4712e30d4169adcd92dc04a44b126c3a9d c0
  X-Channel-Converted-Revision: [master] gh1/android1@a5643d6afc7bad7e741991d4fcc935146ee27e72
  
  $ target_rev
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
  5786f17160793278f5aa226ddfdbb1f770deb008
  $ RELEASE_REV=`git log -n1 --format='%H'`
  $ cd ../../..

Convert to target
  $ python -mmozxchannel.git.process --pull target

Validate new results
  $ cd target
  $ git log  --format='%H %s%n%b' $PREVIOUS_TARGET_REV master
  16f596c35608460113a2edd0ea367e848873b25f c2
  X-Channel-Converted-Revision: [master] gh1/android1@5786f17160793278f5aa226ddfdbb1f770deb008
  
  $ target_rev
  $ cd ..

Create quarantine
  $ cd target
  $ git checkout -qb quarantine
  $ cd ..

Add more content to convert
  $ cd upstream/gh1/android1
  $ $TESTDIR/strings-xml app/src/main/res/values/strings.xml \
  > action_cancel=Cancel \
  > action_ok=OK \
  > action_submit=Submit
  $ git commit -qam'c3'
  $ git log -n1 --format='%H'
  16fa5cc02f003ee888c2f4d5d5b3b2bd56de01c5
  $ cd ../../..

Convert to target
  $ python -mmozxchannel.git.process --pull --branch=quarantine target

Validate new results
  $ cd target
  $ git log  --format='%H %s%n%b' $PREVIOUS_TARGET_REV quarantine
  c6649d7a4ecf60375e89131e6d440ac67913e2ee c3
  X-Channel-Converted-Revision: [master] gh1/android1@16fa5cc02f003ee888c2f4d5d5b3b2bd56de01c5
  
  $ target_rev

Merge quarantine
  $ git checkout -q master
  $ git merge -q quarantine
  $ git checkout -q quarantine
  $ git branch -v
    master     c6649d7 c3
  * quarantine c6649d7 c3
  $ cd ..

Add a release fork
  $ cd upstream/gh1/android1
  $ git checkout -qb release $RELEASE_REV
  $ git checkout -q master
Modify development branch
  $ $TESTDIR/strings-xml app/src/main/res/values/strings.xml \
  > action_cancel=Cancel \
  > "action_submit=Submit it" \
  > action_other=Other
  $ git commit -qam'c4'
Add release branch to config
  $ $TESTDIR/l10n-toml --locales de he sr-Cyrl --branches master release
  $ git commit -qam'Add release'
  $ git log -n1 --format='%H'
  3019e75148c22667de4241888dbf327cba1f0488
  $ git branch -v
  * master  3019e75 Add release
    release 5786f17 c2
  $ cd ../../..

Convert to target
  $ python -mmozxchannel.git.process --pull --branch=quarantine target

Validate new results
  $ cd target
  $ git log  --format='%H %s%n%b' $PREVIOUS_TARGET_REV quarantine
  8cf595b7404e422b08aaea53d3290b453a2ef783 Add release
  X-Channel-Converted-Revision: [master] gh1/android1@3019e75148c22667de4241888dbf327cba1f0488
  X-Channel-Revision: [release] gh1/android1@5786f17160793278f5aa226ddfdbb1f770deb008
  
  a5ad84a0e638aa5c58158fc5779ed7859b4fab6f c4
  X-Channel-Converted-Revision: [master] gh1/android1@8e8adde7fb54427b9585415cd424923c25c7a18a
  
  $ cd ..

Recreate target repo in batch
  $ git init -q batched-target
  $ cp target/config.toml batched-target/config.toml
  $ cd batched-target
  $ git add config.toml
  $ git commit -qm'Initial config'
  $ git log --format='%H %s%n%b'
  aafc5e0cb34ba3c6c5fc70f001f60e8320a1c153 Initial config
  
  $ cd ..

Batch convert to new target
  $ python -mmozxchannel.git.process batched-target

Validate batched results
  $ diff -x .git -qr target batched-target
  $ git -C target log --format='%H %s%n%b'
  8cf595b7404e422b08aaea53d3290b453a2ef783 Add release
  X-Channel-Converted-Revision: [master] gh1/android1@3019e75148c22667de4241888dbf327cba1f0488
  X-Channel-Revision: [release] gh1/android1@5786f17160793278f5aa226ddfdbb1f770deb008
  
  a5ad84a0e638aa5c58158fc5779ed7859b4fab6f c4
  X-Channel-Converted-Revision: [master] gh1/android1@8e8adde7fb54427b9585415cd424923c25c7a18a
  
  c6649d7a4ecf60375e89131e6d440ac67913e2ee c3
  X-Channel-Converted-Revision: [master] gh1/android1@16fa5cc02f003ee888c2f4d5d5b3b2bd56de01c5
  
  16f596c35608460113a2edd0ea367e848873b25f c2
  X-Channel-Converted-Revision: [master] gh1/android1@5786f17160793278f5aa226ddfdbb1f770deb008
  
  2c64ce4712e30d4169adcd92dc04a44b126c3a9d c0
  X-Channel-Converted-Revision: [master] gh1/android1@a5643d6afc7bad7e741991d4fcc935146ee27e72
  
  aafc5e0cb34ba3c6c5fc70f001f60e8320a1c153 Initial config
  
  $ git -C batched-target log --format='%H %s%n%b'
  8cf595b7404e422b08aaea53d3290b453a2ef783 Add release
  X-Channel-Converted-Revision: [master] gh1/android1@3019e75148c22667de4241888dbf327cba1f0488
  X-Channel-Revision: [release] gh1/android1@5786f17160793278f5aa226ddfdbb1f770deb008
  
  a5ad84a0e638aa5c58158fc5779ed7859b4fab6f c4
  X-Channel-Converted-Revision: [master] gh1/android1@8e8adde7fb54427b9585415cd424923c25c7a18a
  
  c6649d7a4ecf60375e89131e6d440ac67913e2ee c3
  X-Channel-Converted-Revision: [master] gh1/android1@16fa5cc02f003ee888c2f4d5d5b3b2bd56de01c5
  
  16f596c35608460113a2edd0ea367e848873b25f c2
  X-Channel-Converted-Revision: [master] gh1/android1@5786f17160793278f5aa226ddfdbb1f770deb008
  
  2c64ce4712e30d4169adcd92dc04a44b126c3a9d c0
  X-Channel-Converted-Revision: [master] gh1/android1@a5643d6afc7bad7e741991d4fcc935146ee27e72
  
  aafc5e0cb34ba3c6c5fc70f001f60e8320a1c153 Initial config
