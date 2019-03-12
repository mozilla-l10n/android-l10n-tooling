  $ . $TESTDIR/helpers.sh

Base target repository with a configuration for the first upstream repo
  $ git init -q target
  $ cd target
  $ cat > config.toml << EOF
  > [[repo]]
  > org = "gh1"
  > name = "android1"
  > branch = "master"
  > target = "browsers"
  > EOF
  $ git add config.toml
  $ git commit -qm'Initial config'
  $ git log  --format='%H %s%n%b'
  bfd39b6816be975b5d62d247104e52951f9acc76 Initial config
  
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
  a5643d6afc7bad7e741991d4fcc935146ee27e72
  $ cd ../../..

Convert to target
  $ python -mmozxchannel.git.process --pull target

Validate some of the results
  $ cd target
  $ git log  --format='%H %s%n%b' $PREVIOUS_TARGET_REV master
  f12737a0296e18536718ee1203ba7e8a1d3e3dff c0
  X-Channel-Converted-Revision: [master] gh1/android1@a5643d6afc7bad7e741991d4fcc935146ee27e72
  
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
  1d91a5bb326114cf1876450fe0f4a5586e1a1927
  $ cd ../android2
  $ $TESTDIR/strings-xml app/src/main/res/values/strings.xml \
  > action_cancel=Cancel \
  > action_two=Two
  $ git add .
  $ git commit -qm'c21'
  $ git log -n1 --format='%H'
  d50c15729413735daea8a7148d8c761dd44bb6a2
  $ cd ../../../gh1
  $ git clone -q ../upstream/gh1/android2
  $ cd ..

Add android2 to config
  $ cd target
  $ cat > config.toml << EOF
  > [[repo]]
  > org = "gh1"
  > name = "android1"
  > branch = "master"
  > target = "browsers"
  > [[repo]]
  > org = "gh1"
  > name = "android2"
  > branch = "master"
  > target = "browsers"
  > EOF
  $ cd ..

Convert to target
  $ python -mmozxchannel.git.process --pull target

Validate some of the results
  $ cd target
  $ git log  --format='%H %s%n%b' $PREVIOUS_TARGET_REV master
  070ce48b0e909bc6446acb11023d5eb5a642361c c11
  X-Channel-Converted-Revision: [master] gh1/android1@1d91a5bb326114cf1876450fe0f4a5586e1a1927
  X-Channel-Revision: [master] gh1/android2@d50c15729413735daea8a7148d8c761dd44bb6a2
  
  b7cb505fa5f244e2b8f7481915b8184e6ecfa3f3 c21
  X-Channel-Revision: [master] gh1/android1@a5643d6afc7bad7e741991d4fcc935146ee27e72
  X-Channel-Converted-Revision: [master] gh1/android2@d50c15729413735daea8a7148d8c761dd44bb6a2
  
  $ target_rev
  $ cd ..

Add independent project
  $ cd upstream/gh1
  $ git init -q single-android
  $ cd single-android
  $ $TESTDIR/strings-xml app/src/main/res/values/strings.xml action_ok=OK
  $ $TESTDIR/l10n-toml --locales de fr zh-TW
  $ compare-locales --validate l10n.toml .
  en-x-moz-reference:
  unchanged         1
  unchanged_w       1
  0% of entries changed
  $ git add .
  $ git commit -qm'c0'
  $ git log -n1 --format='%H'
  8fe4596cb5611b0c8a805f9d20a7741a29c26140
  $ cd ../../..

Add single-android to config
  $ cd target
  $ cat >> config.toml << EOF
  > 
  > [[repo]]
  > org = "gh1"
  > name = "single-android"
  > branch = "master"
  > EOF
  $ git add .
  $ git commit -qm'Add single-android'
  $ git log -n1 --format='%H'
  aa0aa0dc90b30114f4919024d12623438bb48845
  $ cd ..

Convert to target
  $ python -mmozxchannel.git.process --repo gh1/single-android --pull target

Validate some of the results
  $ cd target
  $ git log  --format='%H %s%n%b' $PREVIOUS_TARGET_REV master
  08d2ada5814af6964379db0df5fc2d5c5afff15c c0
  X-Channel-Revision: [master] gh1/android1@1d91a5bb326114cf1876450fe0f4a5586e1a1927
  X-Channel-Revision: [master] gh1/android2@d50c15729413735daea8a7148d8c761dd44bb6a2
  X-Channel-Converted-Revision: [master] gh1/single-android@8fe4596cb5611b0c8a805f9d20a7741a29c26140
  
  aa0aa0dc90b30114f4919024d12623438bb48845 Add single-android
  
  $ compare-locales -qq l10n.toml .
  de:
  missing           4
  missing_w         4
  0% of entries changed
  fr:
  missing           1
  missing_w         1
  0% of entries changed
  he:
  missing           3
  missing_w         3
  0% of entries changed
  sr-Cyrl:
  missing           3
  missing_w         3
  0% of entries changed
  zh-TW:
  missing           1
  missing_w         1
  0% of entries changed
