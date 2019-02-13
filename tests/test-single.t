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
  
  $ target_rev
  $ cd ..

Create upstream repo, with a single commit for a l10n.toml and a strings.xml
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
  $ cd ../../..

Convert to target
  $ python -mmozxchannel.git.process --pull target

Validate some of the results
  $ cd target
  $ git log  --format='%H %s%n%b' $PREVIOUS_TARGET_REV master
  bdfe66ae95025e139b117da3a84b904c71961382 c0
  X-Channel-Converted-Revision: [master] gh1/android1@cf19889319a240d861e42b248fdcad7e99251c58
  
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
  3ada024309d03ce6a8c4dd0b53cea787ee599518
  $ RELEASE_REV=`git log -n1 --format='%H'`
  $ cd ../../..

Convert to target
  $ python -mmozxchannel.git.process --pull target

Validate new results
  $ cd target
  $ git log  --format='%H %s%n%b' $PREVIOUS_TARGET_REV master
  95c3aca5c2bc8b32060af88f559146c22b80cee2 c2
  X-Channel-Converted-Revision: [master] gh1/android1@3ada024309d03ce6a8c4dd0b53cea787ee599518
  
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
  879fbd2737b3cef4b5eda759ec218fd9a27ae971
  $ cd ../../..

Convert to target
  $ python -mmozxchannel.git.process --pull --branch=quarantine target

Validate new results
  $ cd target
  $ git log  --format='%H %s%n%b' $PREVIOUS_TARGET_REV quarantine
  49d2fa5c01664dad2c5ee903142e760bac7a9457 c3
  X-Channel-Converted-Revision: [master] gh1/android1@879fbd2737b3cef4b5eda759ec218fd9a27ae971
  
  $ target_rev

Merge quarantine
  $ git checkout -q master
  $ git merge -q quarantine
  $ git checkout -q quarantine
  $ git branch -v
    master     49d2fa5 c3
  * quarantine 49d2fa5 c3
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
  $ git log -n1 --format='%H'
  44de42136b8f29e85e296b5438949716004b0447
  $ git branch -v
  * master  44de421 c4
    release 3ada024 c2
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
  $ git log  --format='%H %s%n%b' $PREVIOUS_TARGET_REV quarantine
  67a1b6a6deea2ddb798d6e95df72a89a650a5187 c4
  X-Channel-Converted-Revision: [master] gh1/android1@44de42136b8f29e85e296b5438949716004b0447
  X-Channel-Revision: [release] gh1/android1@3ada024309d03ce6a8c4dd0b53cea787ee599518
  
  cbbb6d84a93bf7ac48e18448d97919426bc5aa46 Add release
  
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

Batch convert to new target
  $ python -mmozxchannel.git.process batched-target

Validate batched results
  $ diff -x .git -qr target batched-target
  $ git -C target log --format='%H %s%n%b'
  67a1b6a6deea2ddb798d6e95df72a89a650a5187 c4
  X-Channel-Converted-Revision: [master] gh1/android1@44de42136b8f29e85e296b5438949716004b0447
  X-Channel-Revision: [release] gh1/android1@3ada024309d03ce6a8c4dd0b53cea787ee599518
  
  cbbb6d84a93bf7ac48e18448d97919426bc5aa46 Add release
  
  49d2fa5c01664dad2c5ee903142e760bac7a9457 c3
  X-Channel-Converted-Revision: [master] gh1/android1@879fbd2737b3cef4b5eda759ec218fd9a27ae971
  
  95c3aca5c2bc8b32060af88f559146c22b80cee2 c2
  X-Channel-Converted-Revision: [master] gh1/android1@3ada024309d03ce6a8c4dd0b53cea787ee599518
  
  bdfe66ae95025e139b117da3a84b904c71961382 c0
  X-Channel-Converted-Revision: [master] gh1/android1@cf19889319a240d861e42b248fdcad7e99251c58
  
  d2b396073ea22d136cb636797a4bce9e02936681 Initial config
  
  $ git -C batched-target log --format='%H %s%n%b'
  33b4ea650d910b390eeee3ae656edaf992ea9279 c4
  X-Channel-Converted-Revision: [master] gh1/android1@44de42136b8f29e85e296b5438949716004b0447
  X-Channel-Revision: [release] gh1/android1@3ada024309d03ce6a8c4dd0b53cea787ee599518
  
  7ec1d5b969de026daf59d3a94b5ca82a7de76caa c3
  X-Channel-Converted-Revision: [master] gh1/android1@879fbd2737b3cef4b5eda759ec218fd9a27ae971
  
  04e2c17ee89288b0e606f8c0b3a5c70cc0d04323 c2
  X-Channel-Converted-Revision: [master] gh1/android1@3ada024309d03ce6a8c4dd0b53cea787ee599518
  
  14fe5bc4ffda1c39d695e15431cefe97c0a267c1 c0
  X-Channel-Converted-Revision: [master] gh1/android1@cf19889319a240d861e42b248fdcad7e99251c58
  
  f9f62493b7c3550e514bdf0baed5b7eb8457f301 Initial config
  
Run compare-locales on the output
  $ compare-locales target/l10n.toml target
  gh1/android1/app/src/main/res
    values-b+sr+Cyrl/strings.xml
        // add and localize this file
    values-de/strings.xml
        // add and localize this file
    values-iw/strings.xml
        // add and localize this file
  de:
  missing           4
  missing_w         5
  0% of entries changed
  he:
  missing           4
  missing_w         5
  0% of entries changed
  sr-Cyrl:
  missing           4
  missing_w         5
  0% of entries changed
  $ compare-locales batched-target/l10n.toml batched-target
  gh1/android1/app/src/main/res
    values-b+sr+Cyrl/strings.xml
        // add and localize this file
    values-de/strings.xml
        // add and localize this file
    values-iw/strings.xml
        // add and localize this file
  de:
  missing           4
  missing_w         5
  0% of entries changed
  he:
  missing           4
  missing_w         5
  0% of entries changed
  sr-Cyrl:
  missing           4
  missing_w         5
  0% of entries changed
