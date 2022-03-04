#!/bin/bash

HOST="---SET_YOUR_NIGHTSCOUT_HOSTNAME_HERE---"
SECRET="---SET_YOUR_NIGHTSCOUT_SECRET_HERE---"
UNIT="MMOLL" # MMOLL or MGDL

SGVFILE=".ns-latest-sgv.txt"
SGVFILEHIST=".ns-latest-sgv-5mins.txt"
#TIMEFILE=".ns-latest-sgv-time.txt"

CURTIME=$(date +%s)
MTIME=$(expr $CURTIME - 10 \* 60)
SGV="-1.0" #default value for allowing script to run when not initialized the SGVFILE.
SGVHIST=0.0

UPDATEEVERY=282

if test -f "$SGVFILE"; then
  MTIME=$(date +%s -r $SGVFILE)
  SGV=$(cat $SGVFILE)
fi

if test -f "$SGVFILEHIST"; then
  SGVHIST=$(cat $SGVFILEHIST)
fi

AGE=$(expr $CURTIME - $MTIME)
AGEMINUTES=$(expr $AGE / 60)
FOURMINUTESLATER=$(expr $MTIME + 4 \* 60)
DIFF=$(python -c "print('{:d}'.format(int(10*($SGV - $SGVHIST))))")
ARROW="🠒"
#echo $DIFF
if [ $DIFF -gt 12 ]; then
  ARROW="⇈"
elif [ $DIFF -gt 6 ]; then
  ARROW="🠑"
elif [ $DIFF -gt 2 ]; then
  ARROW="⬈"
elif [ $DIFF -ge -2 ]; then
  ARROW="🠒"
elif [ $DIFF -ge -6 ]; then
  ARROW="⬊"
elif [ $DIFF -ge -12 ]; then
  ARROW="🠓"
else
  ARROW="⇊"
fi

if [ "$AGE" -lt "$UPDATEEVERY" ]; then
  echo "$SGV $ARROW <span color='#090'>($AGEMINUTES)</span>"
else
  RESPONSE=$(wget --quiet -O- "$HOST/api/v1/entries/sgv.json?secret=$SECRET&count=1")
  if [ -z "$RESPONSE" ]; then
    echo "$SGV $ARROW <span color='#900'>($AGEMINUTES)</span>"
  else
    MGDL=$(echo "$RESPONSE" | jq '.[0].sgv')
    NSTIME=$(echo "$RESPONSE" | jq '.[0].dateString' | tr -d '"')
    NSTIME=$(date -d "$NSTIME" +%s)
    NSAHEAD=$(expr $NSTIME - $MTIME)

    if [ $UNIT == "MMOLL" ]; then
      MMOLL=$(python -c "print('{:.1f}'.format($MGDL / 18.018))")
      NEW_SGV=$MMOLL
    else
      NEW_SGV=$MGDL
    fi

    echo "$NEW_SGV $ARROW <span color='#990'>(U)</span>"
    if [ "$NSAHEAD" -gt 0 ]; then
    #if (( $(echo "$NEW_SGV != $SGV" | bc -l) )); then
      echo $NEW_SGV > $SGVFILE
      echo $SGV > $SGVFILEHIST
      NSTIME_FORMATTED=$(date -d @$NSTIME "+%Y%m%d%H%M.%S")
      #echo $NEW_MTIME
      # Set mtime of SGVFILE to NSTIME:
      touch -a -m -t $NSTIME_FORMATTED $SGVFILE
    fi
  fi
fi



