  $ . $TESTDIR/helpers.sh

Base target repository with a configuration for the first upstream repo
  $ git init -q target
  $ cd target
  $ cat > config.toml << EOF
  > [[repo]]
  > org = "gh1"
  > name = "android1"
  > branches = [
  >     "master",
  > ]
  > target = "browsers"
  > EOF
  $ git add config.toml
  $ git commit -qm'Initial config'
  $ git log  --format='%H %s%n%b'
  9dba9fd166aa8a2d953e703b3458df88c3688a22 Initial config
  
  $ target_rev
  $ cd ..

Start creating the original repository and it's conversion.
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
  cf19889319a240d861e42b248fdcad7e99251c58
  $ cd ../../..

Convert to target
  $ python -mmozxchannel.git.process --pull target

Validate some of the results
  $ cd target
  $ git log  --format='%H %s%n%b' $PREVIOUS_TARGET_REV master
  5b6f0ae83aac1e84e9bbdf620fe9937cd2909b1a c0
  X-Channel-Converted-Revision: [master] gh1/android1@cf19889319a240d861e42b248fdcad7e99251c58
  
  $ target_rev
  $ cd ..
  $ diff -q -x .git -r upstream/gh1/android1 target/browsers

Create a fork of the project, create independent new strings in each.
  $ cd upstream/gh1/
  $ cp -r android1 android2
  $ cd android1
  $ $TESTDIR/strings-xml app/src/main/res/values/strings.xml \
  > action_cancel=Cancel \
  > action_one=One
  $ git add .
  $ git commit -qm'c11'
  $ git log -n1 --format='%H'
  51042d60bdfdd96afa8bb32f60b4ac288eccc222
  $ cd ../android2
  $ $TESTDIR/strings-xml app/src/main/res/values/strings.xml \
  > action_cancel=Cancel \
  > action_two=Two
  $ git add .
  $ git commit -qm'c21'
  $ git log -n1 --format='%H'
  225b91312a02097fcca6e38ae6383afb8b1e3fca
  $ cd ../../../gh1
  $ git clone -q ../upstream/gh1/android2
  $ cd ..

Add android2 to config
  $ cd target
  $ cat > config.toml << EOF
  > [[repo]]
  > org = "gh1"
  > name = "android1"
  > branches = [
  >     "master",
  > ]
  > target = "browsers"
  > [[repo]]
  > org = "gh1"
  > name = "android2"
  > branches = [
  >     "master",
  > ]
  > target = "browsers"
  > EOF
  $ cd ..

Convert to target
  $ python -mmozxchannel.git.process --pull target

Validate some of the results
  $ cd target
  $ git log  --format='%H %s%n%b' $PREVIOUS_TARGET_REV master
  ddef50e884633fc8e915ba1fc1861673b3a8ba7b c11
  X-Channel-Converted-Revision: [master] gh1/android1@51042d60bdfdd96afa8bb32f60b4ac288eccc222
  X-Channel-Revision: [master] gh1/android2@225b91312a02097fcca6e38ae6383afb8b1e3fca
  
  77256dd518753afe725847f1755527d5e4815d64 c21
  X-Channel-Revision: [master] gh1/android1@cf19889319a240d861e42b248fdcad7e99251c58
  X-Channel-Converted-Revision: [master] gh1/android2@225b91312a02097fcca6e38ae6383afb8b1e3fca
  
  $ target_rev
  $ cd ..
