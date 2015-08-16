#!/bin/sh
FAN_MIN=33;
FAN_LOW=42;
FAN_MAX=100;
CELSIUS_LOW=69;
CELSIUS_MAX=75;
CELSIUS_DIE=78;
DELAY=121;
while true; do
  if [ $(ps | grep "cgminer " | grep -v 'grep cgminer' | wc -l) -gt 0 ]; then
    temp1=$(cgminer-api stats | grep temp1] | awk '{print $3}');
    temp2=$(cgminer-api stats | grep temp2] | awk '{print $3}');
    fan1=$(cgminer-api stats | grep fan1] | awk '{print $3}');
    pwm=$(grep bitmain-fan-pwm /config/cgminer.conf | awk '{print $3}' | sed -e 's/[[:punct:]]//g');
    maxtemp=$(( $temp1 > $temp2 ? $temp1 : $temp2 ));
    if [ -z $maxtemp ]; then
      echo "ZOMBIE at " && date;
    else
      echo -n "TEMP: $maxtemp ($temp1:$temp2), FAN: $fan1 ($pwm%) at " && date;
      FAN_MOD=0;
      if [ $maxtemp -gt $CELSIUS_DIE ]; then
        FAN_MOD=-1;
      elif [ $maxtemp -gt $CELSIUS_MAX ]; then
        test $pwm -ne $FAN_MAX && FAN_MOD=$FAN_MAX;
      elif [ $maxtemp -gt $CELSIUS_LOW ]; then
        test $pwm -ne $FAN_LOW && FAN_MOD=$FAN_LOW;
      else
        test $pwm -ne $FAN_MIN && FAN_MOD=$FAN_MIN;
      fi;
      if [ $FAN_MOD -lt 0 ]; then
        echo 1 > /sys/class/gpio/gpio20/value && \
        sleep 3 && \
        echo 0 > /sys/class/gpio/gpio20/value;
        echo -n "DIE at " && date && \
        /etc/init.d/cgminer.sh stop > /dev/null 2>&1;
      elif [ $FAN_MOD -gt 0 ]; then
        test $pwm -lt $FAN_MOD && \
        echo 1 > /sys/class/gpio/gpio20/value && \
        sleep 1 && \
        echo 0 > /sys/class/gpio/gpio20/value;
        sed -i "/bitmain-fan-pwm/c\"bitmain-fan-pwm\" : \"$FAN_MOD\"," /config/cgminer.conf  && \
        echo -n "SET $FAN_MOD% at " && date && \
        /etc/init.d/cgminer.sh restart > /dev/null 2>&1;
      fi;
    fi;
  fi;
  sleep $DELAY;
done;
