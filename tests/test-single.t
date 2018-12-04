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
  $ mkdir gh1
  $ cd gh1
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
  $ cd ../..

Convert to target
  $ python -mprocess target

Validate some of the results
  $ cd target
  $ git log  --format='%H %s%n%b' ^d2b396073ea22d136cb636797a4bce9e02936681 master
  220c172534a238026314c7193053b96f304c522f c0
  X-Channel-Converted-Revision: [master] gh1/android1@28f8ea05feac63c5f3836603297a3bc9f3e2d544
  
  $ cd ..
  $ diff -q -x .git -r gh1/android1 target/gh1/android1

Add more content to upstream
  $ cd gh1/android1
  $ cat > README.md << EOF
  > This is just a file
  > EOF
  $ git add README.md
  $ git commit -qm'c1'
  $ $TESTDIR/strings-xml app/src/main/res/values/strings.xml \
  > action_cancel=Cancel \
  > action_ok=OK
  $ git commit -qam'c2'
  $ cd ../..

Convert to target
  $ python -mprocess target

Validate new results
  $ cd target
  $ git log  --format='%H %s%n%b' ^220c172534a238026314c7193053b96f304c522f master
  69ab3c00e0258372f46da0ec3e4426d9b733ae93 c2
  X-Channel-Converted-Revision: [master] gh1/android1@3f2cc03f88ccec09e1e2c57a1b785753fa382a57
  
