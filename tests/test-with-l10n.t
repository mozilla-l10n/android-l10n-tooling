  $ . $TESTDIR/helpers.sh

Base target repository with a configuration for the first upstream repo
  $ git init -q target
  $ cd target
  $ cat > config.toml << EOF
  > [[repo]]
  > org = "gh1"
  > name = "android1"
  > branch = "master"
  > EOF
  $ git add config.toml
  $ git commit -qm'add android1'
  $ git log  --format='%H %s%n%b'
  c31813ebf3655d1205bba6f3bc8f7c9343082f21 add android1
  
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
  $ git commit -qm'a1-c0'
  $ git log -n1 --format='%H'
  9cc0ec22e2f8085665c2297e3f76da1c6a80be11
  $ cd ../../..

Convert to target quarantine
  $ python -mmozxchannel.git.process --pull --repo gh1/android1 --branch a1-q target

Validate some of the results
  $ cd target
  $ git log  --format='%H %s%n%b' $PREVIOUS_TARGET_REV a1-q
  ac9a4d8ec3124c0344a188893bc08d8cb76733d6 a1-c0
  X-Channel-Converted-Revision: [master] gh1/android1@9cc0ec22e2f8085665c2297e3f76da1c6a80be11
  
  $ git checkout master
  Switched to branch 'master'
  $ target_rev

Merge a1 into master
  $ git merge --no-ff -q -m'Merge android1 quarantine' a1-q
  $ git branch -qd a1-q
  $ git log -n1 --format='%H %s%n%b'
  c98ed99762562f0e2f846a60d0ee461e2635ed1e Merge android1 quarantine
  
  $ target_rev

Add config for second repo to target
  $ cat >> config.toml << EOF
  > 
  > [[repo]]
  > org = "gh1"
  > name = "android2"
  > branch = "master"
  > EOF
  $ git add config.toml
  $ git commit -qm'add android2'
  $ git log  --format='%H %s%n%b'  $PREVIOUS_TARGET_REV master
  1f1a143c0cc819e8c77c098a1784c05224caa5f2 add android2
  
  $ target_rev

  $ cd ..


Create a fork of the project, create independent new strings in each.
  $ cd upstream/gh1/
  $ git init -q android2
  $ cd android2
  $ $TESTDIR/strings-xml app/src/main/res/values/strings.xml action_cancel=Cancel action_more=More
  $ $TESTDIR/l10n-toml --locales de he sr-Cyrl
  $ compare-locales --validate l10n.toml .
  en-x-moz-reference:
  unchanged         2
  unchanged_w       2
  0% of entries changed
  $ git add .
  $ git commit -qm'a2-c0'
  $ git log -n1 --format='%H'
  35b1a6a9cbfd7573ab34c81a697ba752f78d34e2
  $ cd ../../..

Convert to target
  $ python -mmozxchannel.git.process --pull --repo gh1/android2 --branch a2-q target

Validate some of the results
  $ cd target
  $ git log  --format='%H %s%n%b' $PREVIOUS_TARGET_REV a2-q
  50127005184bfb0394b07fb917c891c9710b16da a2-c0
  X-Channel-Revision: [master] gh1/android1@9cc0ec22e2f8085665c2297e3f76da1c6a80be11
  X-Channel-Converted-Revision: [master] gh1/android2@35b1a6a9cbfd7573ab34c81a697ba752f78d34e2
  
  $ git checkout master
  Switched to branch 'master'
  $ target_rev

Make a localizer commit
  $ $TESTDIR/strings-xml gh1/android2/app/src/main/res/values-de/strings.xml action_cancel=Abbrechen action_more=Mehr
  $ git add gh1/android2/app/src/main/res/values-de/strings.xml
  $ git commit -qm'Pontoon - de - android2 - c1'

Merge a2 into master
  $ git merge --no-ff -q -m'Merge android2 quarantine' a2-q
  $ git branch -qd a2-q
  $ git log -n1 --format='%H %s%n%b'
  c5da0ed22c8560d5937443672f8dae6f15a1d032 Merge android2 quarantine
  

  $ cd ..

Check the resulting graph
  $ cd target
  $ git log --graph --format='%s%n'
  *   Merge android2 quarantine
  |\  
  | | 
  | * a2-c0
  | | 
  * | Pontoon - de - android2 - c1
  |/  
  |   
  * add android2
  | 
  *   Merge android1 quarantine
  |\  
  | | 
  | * a1-c0
  |/  
  |   
  * add android1
    
  $ compare-locales -qq l10n.toml .
  de:
  missing           1
  missing_w         1
  changed           2
  changed_w         2
  66% of entries changed
  he:
  missing           3
  missing_w         3
  0% of entries changed
  sr-Cyrl:
  missing           3
  missing_w         3
  0% of entries changed
