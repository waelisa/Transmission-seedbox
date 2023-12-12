#!/bin/bash
#############################################################################################################################
# The MIT License (MIT)
# Wael Isa
# 12/12/2023
# https://www.wael.name/linux/install-script-for-transmission-seedbox/
# https://github.com/waelisa/Transmission-seedbox
#############################################################################################################################
# Transmission Ver 4.0.4
#############################################################################################################################
set -e
SCRIPT="$(readlink -e ""$0"")"

##  install dependencies and required compiling tools from standard repos
sudo apt-get update
sudo apt-get -y install build-essential checkinstall pkg-config libtool intltool libcurl4-openssl-dev libssl-dev libevent-dev
sudo sed -i 's/TRANSLATE=1/TRANSLATE=0/' /etc/checkinstallrc
#-uncomment if needed:
#sudo apt-get -y install natpmp-utils

##  download, compile and install Transmission 4.0.4
cd ~
sudo rm -rf transmission-4.0.4; rm -f transmission-4.0.4.tar.xz
wget https://github.com/transmission/transmission-releases/raw/master/transmission-4.0.4.tar.xz
xz -c -d transmission-4.0.4.tar.xz | tar -x
cd transmission-4.0.4
./configure; make
sudo checkinstall -y
cd ..
sudo rm -r transmission-4.0.4; rm transmission-4.0.4.tar.xz

##  add user transmission
if [ ! $(grep '^transmission:' /etc/passwd) ]; then
   sudo adduser --disabled-password --disabled-login --gecos "" transmission
fi

##  copy lines after #initdscript# as /etc/init.d/transmission-daemon, make it autostart
tail -n +$(($(grep -n "^#initdscript#" "$SCRIPT"|grep -Eo '^[^:]+')+1)) "$SCRIPT" | sudo tee /etc/init.d/transmission-daemon >/dev/null
sudo chmod +x /etc/init.d/transmission-daemon
sudo update-rc.d transmission-daemon defaults

sudo /etc/init.d/transmission-daemon start
sudo /etc/init.d/transmission-daemon stop
echo $'\n'$'\n'"Settings: /home/transmission/.config/transmission-daemon/settings.json"$'\n'

exit


#initdscript#  (from `https://trac.transmissionbt.com/wiki/Scripts/initd` 2015.03.31)
#!/bin/sh
### BEGIN INIT INFO
# Provides:          transmission-daemon
# Required-Start:    networking
# Required-Stop:     networking
# Default-Start:     2 3 5
# Default-Stop:      0 1 6
# Short-Description: Start the transmission BitTorrent daemon client.
### END INIT INFO

# Original Author: Lennart A. J�Rtte, based on Rob Howell's script
# Modified by Maarten Van Coile & others (on IRC)

# Do NOT "set -e"

#
# ----- CONFIGURATION -----
#
# For the default location Transmission uses, visit:
# http://trac.transmissionbt.com/wiki/ConfigFiles
# For a guide on how set the preferences, visit:
# http://trac.transmissionbt.com/wiki/EditConfigFiles
# For the available environement variables, visit:
# http://trac.transmissionbt.com/wiki/EnvironmentVariables
#
# The name of the user that should run Transmission.
# It's RECOMENDED to run Transmission in it's own user,
# by default, this is set to 'transmission'.
# For the sake of security you shouldn't set a password
# on this user
USERNAME=transmission


# ----- *ADVANCED* CONFIGURATION -----
# Only change these options if you know what you are doing!
#
# The folder where Transmission stores the config & web files.
# ONLY change this you have it at a non-default location
#TRANSMISSION_HOME="/var/config/transmission-daemon"
#TRANSMISSION_WEB_HOME="/usr/share/transmission/web"
#
# The arguments passed on to transmission-daemon.
# ONLY change this you need to, otherwise use the
# settings file as per above.
#TRANSMISSION_ARGS=""


# ----- END OF CONFIGURATION -----
#
# PATH should only include /usr/* if it runs after the mountnfs.sh script.
PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin
DESC="bittorrent client"
NAME=transmission-daemon
DAEMON=$(which $NAME)
PIDFILE=/var/run/$NAME.pid
SCRIPTNAME=/etc/init.d/$NAME

# Exit if the package is not installed
[ -x "$DAEMON" ] || exit 0

# Read configuration variable file if it is present
[ -r /etc/default/$NAME ] && . /etc/default/$NAME

# Load the VERBOSE setting and other rcS variables
[ -f /etc/default/rcS ] && . /etc/default/rcS

#
# Function that starts the daemon/service
#

do_start()
{
    # Export the configuration/web directory, if set
    if [ -n "$TRANSMISSION_HOME" ]; then
          export TRANSMISSION_HOME
    fi
    if [ -n "$TRANSMISSION_WEB_HOME" ]; then
          export TRANSMISSION_WEB_HOME
    fi

    # Return
    #   0 if daemon has been started
    #   1 if daemon was already running
    #   2 if daemon could not be started
    start-stop-daemon --chuid $USERNAME --start --pidfile $PIDFILE --make-pidfile \
            --exec $DAEMON --background --test -- -f $TRANSMISSION_ARGS > /dev/null \
            || return 1
    start-stop-daemon --chuid $USERNAME --start --pidfile $PIDFILE --make-pidfile \
            --exec $DAEMON --background -- -f $TRANSMISSION_ARGS \
            || return 2
}

#
# Function that stops the daemon/service
#
do_stop()
{
        # Return
        #   0 if daemon has been stopped
        #   1 if daemon was already stopped
        #   2 if daemon could not be stopped
        #   other if a failure occurred
        start-stop-daemon --stop --quiet --retry=TERM/10/KILL/5 --pidfile $PIDFILE --exec $DAEMON
        RETVAL="$?"
        [ "$RETVAL" = 2 ] && return 2

        # Wait for children to finish too if this is a daemon that forks
        # and if the daemon is only ever run from this initscript.
        # If the above conditions are not satisfied then add some other code
        # that waits for the process to drop all resources that could be
        # needed by services started subsequently.  A last resort is to
        # sleep for some time.

        start-stop-daemon --stop --quiet --oknodo --retry=0/30/KILL/5 --exec $DAEMON
        [ "$?" = 2 ] && return 2

        # Many daemons don't delete their pidfiles when they exit.
        rm -f $PIDFILE

        return "$RETVAL"
}

case "$1" in
  start)
        echo "Starting $DESC" "$NAME..."
        do_start
        case "$?" in
                0|1) echo "   Starting $DESC $NAME succeeded" ;;
                *)   echo "   Starting $DESC $NAME failed" ;;
        esac
        ;;
  stop)
        echo "Stopping $DESC $NAME..."
        do_stop
        case "$?" in
                0|1) echo "   Stopping $DESC $NAME succeeded" ;;
                *)   echo "   Stopping $DESC $NAME failed" ;;
        esac
        ;;
  restart|force-reload)
        #
        # If the "reload" option is implemented then remove the
        # 'force-reload' alias
        #
        echo "Restarting $DESC $NAME..."
        do_stop
        case "$?" in
          0|1)
                do_start
                case "$?" in
                    0|1) echo "   Restarting $DESC $NAME succeeded" ;;
                    *)   echo "   Restarting $DESC $NAME failed: couldn't start $NAME" ;;
                esac
                ;;
          *)
                echo "   Restarting $DESC $NAME failed: couldn't stop $NAME" ;;
        esac
        ;;
  *)
        echo "Usage: $SCRIPTNAME {start|stop|restart|force-reload}" >&2
        exit 3
        ;;
esac
