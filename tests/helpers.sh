export GIT_AUTHOR_NAME=test
export GIT_AUTHOR_EMAIL=test@example.com
export GIT_AUTHOR_DATE='Thu Jan 1 00:00:00 1970 +0000'
export GIT_COMMITTER_NAME=test
export GIT_COMMITTER_EMAIL=test@example.com
export GIT_COMMITTER_DATE='Thu Jan 1 00:00:00 1970 +0000'

export PYTHONPATH=$TESTDIR/../src
export PYTHONDONTWRITEBYTECODE=x

export X_CHANNEL_UPSTREAM=$CRAMTMP/$TESTFILE/upstream

PREVIOUS_TARGET_REV=
function target_rev() {
    PREVIOUS_TARGET_REV=`git log -n 1 --format="^%H"`;
}
