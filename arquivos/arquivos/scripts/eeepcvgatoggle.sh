#!/bin/bash

getXuser() {
       user=`finger| grep -m1 ":$displaynum " | awk '{print $1}'`
       if [ x"$user" = x"" ]; then
               user=`finger| grep -m1 ":$displaynum" | awk '{print $1}'`
       fi
       if [ x"$user" != x"" ]; then
               userhome=`getent passwd $user | cut -d: -f6`
               export XAUTHORITY=$userhome/.Xauthority
       else
               export XAUTHORITY=""
       fi
}
# end of getXuser from /usr/share/acpi-support/power-funcs
#

checkVGAStatus()
{
    status=`xrandr -q`

    if [ $(echo $status | grep -q "VGA connected (" ; echo $?) -eq 0 ]
    then
        return 0
    else
        if [ $(echo $status | grep -q "LVDS connected (" ; echo $?) -eq 0 ]
        then
            return 1
        else
            if [ $(echo $status | grep -q "VGA connected" ; echo $?) -eq 0 ]
            then
                return 2
            fi
        fi
    fi
}

for x in /tmp/.X11-unix/*; do
   displaynum=`echo $x | sed s#/tmp/.X11-unix/X##`
   getXuser;
   if [ x"$XAUTHORITY" != x"" ]; then
       export DISPLAY=":$displaynum"
       checkVGAStatus;

       case $? in
	   0 ) xrandr --output VGA --mode 800x600;; # VGA on
	   1 ) xrandr --output LVDS --mode 800x480; xrandr --output VGA --off;;  # LCD on, VGA off
           2 ) xrandr --output LVDS --off;; # LCD off
       esac

   fi
done