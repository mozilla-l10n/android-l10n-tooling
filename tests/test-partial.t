  $ . $TESTDIR/helpers.sh

Base target repository with a configuration for two single upstream repos,
but only one present
  $ git init -q target
  $ cd target
  $ cat > config.toml << EOF
  > [[repo]]
  > org = "gh1"
  > name = "android1"
  > branch = "master"
  > [[repo]]
  > org = "gh1"
  > name = "android2"
  > branch = "master"
  > EOF
  $ git add config.toml
  $ git commit -qm'Initial config'
  $ git log  --format='%H %s%n%b'
  09c3e742d7843872cf0d2062a773e4e1ecb899a3 Initial config
  
  $ target_rev
  $ cd ..

Create one upstream repo, with a single commit for a l10n.toml and a strings.xml
  $ mkdir -p upstream/gh1
  $ cd upstream/gh1
  $ git init -q android1
  $ cd android1
  $ $TESTDIR/strings-xml app/src/main/res/values/strings.xml action_cancel=Cancel
  $ $TESTDIR/l10n-toml --locales de he sr-Cyrl
  $ compare-locales --validate l10n.toml .
  en-x-moz-reference:
  unchanged         1
  unchanged_w       1
  0% of entries changed
  $ git add .
  $ git commit -qm'c0'
  $ git log -n1 --format='%H'
  a5643d6afc7bad7e741991d4fcc935146ee27e72
  $ cd ../../..

Convert to target
  $ python -mmozxchannel.git.process --repo gh1/android1 --pull target

Validate some of the results
  $ cd target
  $ git log  --format='%H %s%n%b' $PREVIOUS_TARGET_REV master
  e5155f0de86f773fc8509aed0633a4f95cece6f9 c0
  X-Channel-Converted-Revision: [master] gh1/android1@a5643d6afc7bad7e741991d4fcc935146ee27e72
  
  $ target_rev
  $ cd ..
  $ diff -q -x .git -r upstream/gh1/android1 target/gh1/android1
  $ find gh1 -maxdepth 1 -type d |sort
  gh1
  gh1/android1

Destroy local clones,
  $ rm -rf gh1
 then create other upstream repo, with a slightly different strings.xml
  $ cd upstream/gh1
  $ git init -q android2
  $ cd android2
  $ $TESTDIR/strings-xml app/src/main/res/values/strings.xml action_confirm=Confirm
  $ $TESTDIR/l10n-toml --locales fr
  $ compare-locales --validate l10n.toml .
  en-x-moz-reference:
  unchanged         1
  unchanged_w       1
  0% of entries changed
  $ git add .
  $ git commit -qm'c0'
  $ git log -n1 --format='%H'
  640f5f0aa8d269ba62e7519f407479175a2b3409
  $ cd ../../..

Convert to target
  $ python -mmozxchannel.git.process --repo gh1/android2 --pull target

Validate some of the results
  $ cd target
  $ git log  --format='%H %s%n%b' $PREVIOUS_TARGET_REV master
  9c5afbf4bcfb8c636f4c932f2dc101f8d5246fe0 c0
  X-Channel-Revision: [master] gh1/android1@a5643d6afc7bad7e741991d4fcc935146ee27e72
  X-Channel-Converted-Revision: [master] gh1/android2@640f5f0aa8d269ba62e7519f407479175a2b3409
  
  $ target_rev
  $ cd ..
  $ diff -q -x .git -r upstream/gh1/android2 target/gh1/android2
  $ find gh1 -maxdepth 1 -type d |sort
  gh1
  gh1/android2
