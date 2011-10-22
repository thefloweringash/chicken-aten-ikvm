#!/bin/sh
echo Chicken ssh-helper: $* >&2 &&
# If ssh dies unexpectedly, we want Chicken to see standard error get closed, so
# we prevent either the shell or /bin/cat from keeping it open.
exec /bin/cat $CHICKEN_NAMED 2>/dev/null
