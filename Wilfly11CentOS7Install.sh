#!/bin/sh
#: Title       : WildflyCentOS7Install.sh
#: Date        : 2019-01-14
#: Author      : Kybernetes <correodelkybernetes@gmail.com>
#: Version     : 0.10
#: Description : Executable Dash shell script
#:             : Installs Wildfly v11 in a CentOS v7 installation
#: Options     :
#: Usage       : 1. Upload to server
#:             : 2. Upload wildfly-11.0.0.Final.tar.gz to the server
#:             : 3. Set global parameters
#:             : 4. Run
##
################################################################################
## Parameters ##
_WFINME=cas                ## Wildfly's instance name
_WFPDIR=/usr/share/wildfly ## All wildflys installations container
_WFHDIR=$_WFPDIR/$_WFINME  ## This instance home dir
_WFPOWN=wildfly            ## Wildfly process owner name
_WFPCKG=/tmp/wildfly-11.0.0.Final.tar.gz
##
################################################################################
## Add process owner ##
grupadd -r $_WFPOWN
useradd -rd "$_WFPDIR" -c "Wildfly process owner" $_WFPOWN
## Create home dir
install -vo $_WFPOWN -g $_WFPOWN -m 700 -d "$_WFPDIR"
## Sets password
strings </dev/urandom | head -n 3 | tr -d '\n' | passwd --stdin $_WFPOWN
##
################################################################################
## Install wildfly package ##
install -vo $_WFPOWN -g $_WFPOWN -m 755 -d "$_WFHDIR"
tar -xvzf "$_WFPCKG" -C "$_WFHDIR" --strip-components 1
chown -vR $_WFPOWN:$_WFPOWN "$_WFHDIR" 
##
################################################################################
## Create var dirs ##
install -vo $_WFPOWN -g $_WFPOWN -m 770 -d /var/log/wildfly/$_WFINME
install -vo $_WFPOWN -g $_WFPOWN -m 770 -d /var/run/wildfly
## Set temporary files
cat >/usr/lib/tmpfiles.d/wildfly.conf <<'EOF'
d /var/run/wildfly 0770 $_WFPOWN $_WFPOWN -
EOF
## Set new log dir path
ln -s /var/log/wildfly "$_WFHDIR"/standalone/log
chown -v wildfly:wildfly "$_WFHDIR"/standalone/log
##
################################################################################
## Systemd configuragion ##
awk \
'## Remove this line from file, and go to next input line
/Environment=LAUNCH_JBOSS_IN_BACKGROUND=1/{ next }
## Replace Environment filename and go to next input line
/EnvironmentFile=/{ gsub(/=.*/,"=/etc/wildfly/'$_WFINME'.conf"); print; next }
## Replace pidfile filename and go to next input line
/PIDFile=/{ gsub(/=.*/,"=/var/run/wildfly/'$_WFINME'.pid"); print; next }
## Replace launch script filename and go to next input line
/ExecStart=/{ gsub(/=.*/,"='"$_WFHDIR"'/bin/launch.sh"); print; next }
## Print each remaining lines only once
/.*/{ print; next }' \
"$_WFHDIR"/docs/contrib/scripts/systemd/wildfly.service \
>/etc/systemd/system/wildfly-$_WFINME.service
chmod -v 644 /etc/systemd/system/wildfly-$_WFINME.service
systemctl daemon-reload
systemctl enable wildfly-$_WFINME.service
##
################################################################################
## Set launch script ##
cat >"$_WFHDIR/bin/launch.sh" <<'EOF'
#!/bin/bash

if [ "x$WILDFLY_HOME" = "x" ]; then
    WILDFLY_HOME="/opt/wildfly"
fi

case "$1" in 
    [Dd][Oo][Mm][Aa][Ii][Nn])
    	$WILDFLY_HOME/bin/domain.sh -c "${2:-$WILDFLY_CONFIG}" \
                                    -b ${3:-$WILDFLY_BIND} ;;
    *) 
    	$WILDFLY_HOME/bin/standalone.sh -c "${2:-$WILDFLY_CONFIG}" \
                                        -b ${3:-$WILDFLY_BIND} ;;
esac
EOF
chown -v $_WFPOWN:$_WFPOWN "$_WFHDIR/bin/launch.sh"
chmod -v 750 "$_WFHDIR/bin/launch.sh"
## Set script environment
install -vo root -g root -m 755 -d /etc/wildfly
cat >/etc/wildfly/$_WFINME.conf <<'EOF'
# The selected Java's installatio path
JAVA_HOME=/usr/java/jdk1.8.0_202
# The wildfly instance installation path 
WILDFLY_HOME=/usr/share/wildfly/cas
# The configuration you want to run
WILDFLY_CONFIG=standalone.xml
# The mode you want to run
WILDFLY_MODE=standalone
# The address to bind to
WILDFLY_BIND=0.0.0.0
EOF
chmod -v 644 /etc/wildfly/$_WFINME.conf
##
################################################################################
## Cleanup ##
rm -vf "$_WFPCKG"
