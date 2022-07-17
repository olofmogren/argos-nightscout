#!/bin/bash

HOST="---SET_YOUR_NIGHTSCOUT_HOSTNAME_HERE---"
SECRET="---SET_YOUR_NIGHTSCOUT_SECRET_HERE---"
UNIT="MMOLL" # MMOLL or MGDL

SGVFILE=".ns-latest-sgv.txt"
SGVFILEHIST=".ns-latest-sgv-5mins.txt"

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
  SGVHISTMTIME=$(date +%s -r $SGVFILE)
fi

AGE=$(expr $CURTIME - $MTIME)
AGEMINUTES=$(expr $AGE / 60)
FOURMINUTESLATER=$(expr $MTIME + 4 \* 60)

# DECIDE PRINTSGV, PRINTAGE, COLOR
if [ "$AGE" -lt "$UPDATEEVERY" ]; then
  PRINTSGV="$SGV"
  PRINTAGE="$AGEMINUTES"
  COLOR="#090"
else
  RESPONSE=$(wget --quiet -O- "$HOST/api/v1/entries/sgv.json?secret=$SECRET&count=1")
  if [ -z "$RESPONSE" ]; then
    PRINTSGV="$SGV"
    PRINTAGE="$AGEMINUTES"
    COLOR="#900"
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

    PRINTSGV="$NEW_SGV"
    PRINTAGE="U"
    COLOR="#990"
    if [ "$NSAHEAD" -gt 0 ]; then
      echo $NEW_SGV > $SGVFILE
      echo $SGV > $SGVFILEHIST
      SGVHIST="$SGV"
      NSTIME_FORMATTED=$(date -d @$NSTIME "+%Y%m%d%H%M.%S")
      # Set mtime of SGVFILE to NSTIME:
      touch -a -m -t $NSTIME_FORMATTED $SGVFILE
    fi
  fi
fi

# DECIDE DIFF
DIFF=$(python -c "print('{:d}'.format(int(0.5+10*($PRINTSGV - $SGVHIST))))")
ARROW="🠒"
#echo $DIFF
if [ $DIFF -gt 12 ]; then
  ARROW="⇈"
elif [ $DIFF -gt 6 ]; then
  ARROW="🠑"
elif [ $DIFF -gt 2 ]; then
  ARROW="↗"
elif [ $DIFF -ge -2 ]; then
  ARROW="🠒"
elif [ $DIFF -ge -6 ]; then
  ARROW="↘"
elif [ $DIFF -ge -12 ]; then
  ARROW="🠓"
else
  ARROW="⇊"
fi

#CHECK IF SGVHISTMTIME IS VALID FOR ARROW, IF NOT, REMOVE ARROW
if [ -z "$SGVHISTMTIME" ]; then
  #SGVHISTMTIME NOT SET
  ARROW=" "
else
  #SGVHISTMTIME SET
  SGVHISTAGE=$(expr $CURTIME - $SGVHISTMTIME)
  if [ "$SGVHISTAGE" -gt 600 ]; then
    #SGVHISTMTIME MORE THAN TEN MINUTES
    ARROW=" "
  fi
fi

echo "$PRINTSGV $ARROW <span color='$COLOR'>($PRINTAGE)</span>"

# SHOW THE DIFF IN A POPUP MENU
PRINTDIFF=$(python -c "print('{:.1f}'.format($DIFF/10.0))")
echo '---'
echo "Delta: $PRINTDIFF" 

