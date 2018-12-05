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
  $ $TESTDIR/l10n-toml --locales de he sr-Cyrl
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
  b499c97f447e5d6cb34603ce39ed25f034277c9a c0
  X-Channel-Converted-Revision: [master] gh1/android1@24ffe06b96b32d762df8262876b1d27da2a22c65
  
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
  e0fbb23763b49c6150238edc090eb1fd1fea9d49
  $ cd ../../..

Convert to target
  $ python -mmozxchannel.git.process --pull target

Validate new results
  $ cd target
  $ git log  --format='%H %s%n%b' ^b499c97f447e5d6cb34603ce39ed25f034277c9a master
  c7d96cce553fcf9517e36d1de86234c1d61304b8 c2
  X-Channel-Converted-Revision: [master] gh1/android1@e0fbb23763b49c6150238edc090eb1fd1fea9d49
  
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
  407a7be1aa9baf68ab30e122f4b08c78cf1eafba
  $ cd ../../..

Convert to target
  $ python -mmozxchannel.git.process --pull --branch=quarantine target

Validate new results
  $ cd target
  $ git log  --format='%H %s%n%b' ^c7d96cce553fcf9517e36d1de86234c1d61304b8 quarantine
  a9eb77950f49e826c4c4b71d4fa5268e0d6cc8b7 c3
  X-Channel-Converted-Revision: [master] gh1/android1@407a7be1aa9baf68ab30e122f4b08c78cf1eafba
  
Merge quarantine
  $ git checkout -q master
  $ git merge -q quarantine
  $ git checkout -q quarantine
  $ git branch -v
    master     a9eb779 c3
  * quarantine a9eb779 c3
  $ cd ..

Add a release fork
  $ cd upstream/gh1/android1
  $ git checkout -qb release e0fbb23763b49c6150238edc090eb1fd1fea9d49
  $ git checkout -q master
Modify development branch
  $ $TESTDIR/strings-xml app/src/main/res/values/strings.xml \
  > action_cancel=Cancel \
  > "action_submit=Submit it" \
  > action_other=Other
  $ git commit -qam'c4'
  $ git log -n1 --format='%H'
  487a9c4cf79c2dddc2064515c1103e02d00edac6
  $ git branch -v
  * master  487a9c4 c4
    release e0fbb23 c2
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
  $ git log  --format='%H %s%n%b' ^a9eb77950f49e826c4c4b71d4fa5268e0d6cc8b7 quarantine
  db72d42fbcc6103bbbde63567082fdc1f0412408 c4
  X-Channel-Converted-Revision: [master] gh1/android1@487a9c4cf79c2dddc2064515c1103e02d00edac6
  X-Channel-Revision: [release] gh1/android1@e0fbb23763b49c6150238edc090eb1fd1fea9d49
  
  f652d21ebe443597fcaaee8563b197489cd9d570 Add release
  
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
  db72d42fbcc6103bbbde63567082fdc1f0412408 c4
  X-Channel-Converted-Revision: [master] gh1/android1@487a9c4cf79c2dddc2064515c1103e02d00edac6
  X-Channel-Revision: [release] gh1/android1@e0fbb23763b49c6150238edc090eb1fd1fea9d49
  
  f652d21ebe443597fcaaee8563b197489cd9d570 Add release
  
  a9eb77950f49e826c4c4b71d4fa5268e0d6cc8b7 c3
  X-Channel-Converted-Revision: [master] gh1/android1@407a7be1aa9baf68ab30e122f4b08c78cf1eafba
  
  c7d96cce553fcf9517e36d1de86234c1d61304b8 c2
  X-Channel-Converted-Revision: [master] gh1/android1@e0fbb23763b49c6150238edc090eb1fd1fea9d49
  
  b499c97f447e5d6cb34603ce39ed25f034277c9a c0
  X-Channel-Converted-Revision: [master] gh1/android1@24ffe06b96b32d762df8262876b1d27da2a22c65
  
  d2b396073ea22d136cb636797a4bce9e02936681 Initial config
  
  $ git -C batched-target log --format='%H %s%n%b'
  086bfabd56b4ac5f954fe8b91375746f744ec08b c4
  X-Channel-Converted-Revision: [master] gh1/android1@487a9c4cf79c2dddc2064515c1103e02d00edac6
  X-Channel-Revision: [release] gh1/android1@e0fbb23763b49c6150238edc090eb1fd1fea9d49
  
  44aade6f379e42a7bf60d41cfad704d2e8e825db c3
  X-Channel-Converted-Revision: [master] gh1/android1@407a7be1aa9baf68ab30e122f4b08c78cf1eafba
  
  d3a1d9236bcff0313d6280e3cf8c95ef281c663f c2
  X-Channel-Converted-Revision: [master] gh1/android1@e0fbb23763b49c6150238edc090eb1fd1fea9d49
  
  fc94523050e8ee1706c4da7e84b0813639aecb0c c0
  X-Channel-Converted-Revision: [master] gh1/android1@24ffe06b96b32d762df8262876b1d27da2a22c65
  
  f9f62493b7c3550e514bdf0baed5b7eb8457f301 Initial config
  
