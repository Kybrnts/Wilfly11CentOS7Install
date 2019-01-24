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
## reate group
grupadd -r $_WFPOWN
## create account
useradd -rd "$_WFPDIR" -c "Wildfly process owner" $_WFPOWN
## Create home dir
install -vo $_WFPOWN -g $_WFPOWN -m 700 -d "$_WFPDIR"
## Sets password
strings </dev/urandom | head -n 3 | tr -d '\n' | passwd --stdin $_WFPOWN
##
################################################################################
## Install wildfly package ##
## Create WF home dir
install -vo $_WFPOWN -g $_WFPOWN -m 755 -d "$_WFHDIR"
## Unpack right below home dir
tar -xvzf "$_WFPCKG" -C "$_WFHDIR" --strip-components 1
## Set owner entire installation tree
chown -vR $_WFPOWN:$_WFPOWN "$_WFHDIR" 
##
################################################################################
## Create var dirs ##
## Directory for log
install -vo $_WFPOWN -g $_WFPOWN -m 770 -d /var/log/wildfly/$_WFINME
## Link /var/log directory with the one used by WF
ln -s /var/log/wildfly/$_WFINME "$_WFHDIR"/standalone/log
chown -v wildfly:wildfly "$_WFHDIR"/standalone/log
## Directory for pidfile
install -vo $_WFPOWN -g $_WFPOWN -m 770 -d /var/run/wildfly
## Set temporary files
cat >/usr/lib/tmpfiles.d/wildfly.conf <<EOF
d /var/run/wildfly 0770 root $_WFPOWN -
EOF
##
################################################################################
## Systemd configuragion ##
## Edit installation provided unit file in systemd config. directory
awk \
'## Change the description
/Description=/{ gsub(/=.*/,"=WildFly - '$_WFINME' instance"); print; next }
## Remove this line from file, and go to next input line
/Environment=LAUNCH_JBOSS_IN_BACKGROUND=1/{ next }
## Replace Environment filename and go to next input line
/EnvironmentFile=/{ gsub(/=.*/,"=/etc/wildfly/'$_WFINME'.conf"); print; next }
## Replace pidfile filename and go to next input line
/PIDFile=/{ gsub(/=.*/,"=/var/run/wildfly/'$_WFINME'.pid"); print; next }
## Replace launch script filename and go to next input line
/ExecStart=/{ gsub(/=.*/,"='"$_WFHDIR"'/bin/launch.sh"); print; next }
## Print each remaining line
/.*/{ print; next }' \
"$_WFHDIR"/docs/contrib/scripts/systemd/wildfly.service \
>/etc/systemd/system/wildfly-$_WFINME.service
## Set permissions
chmod -v 644 /etc/systemd/system/wildfly-$_WFINME.service
## Reload configuration
systemctl daemon-reload
## Enable service on startup
systemctl enable wildfly-$_WFINME.service
##
################################################################################
## Set launch script ##
## Create launch script
cat >"$_WFHDIR/bin/launch.sh" <<'EOF'
#!/bin/sh
set -- "${1:-$WILDFLY_MODE}" "${2:-$WILDFLY_CONFIG}"

if [ "x$WILDFLY_HOME" = "x" ]; then
    WILDFLY_HOME="/opt/wildfly"
fi
case "$1" in 
    [Dd][Oo][Mm][Aa][Ii][Nn])
    	$WILDFLY_HOME/bin/domain.sh -c "${2:-domain.xml}" ;;
    *) 
    	$WILDFLY_HOME/bin/standalone.sh -c "${2:-standalone.xml}" ;;
esac
EOF
## Set owner for launch script
chown -v $_WFPOWN:$_WFPOWN "$_WFHDIR/bin/launch.sh"
## Enable execution
chmod -v 750 "$_WFHDIR/bin/launch.sh"
## Set script environment creating a
install -vo root -g root -m 755 -d /etc/wildfly
cat >/etc/wildfly/$_WFINME.conf <<EOF
# How to launch Wildfly
LAUNCH_JBOSS_IN_BACKGROUND=1
# The Pidfile 
JBOSS_PIDFILE=/var/run/wildfly/$_WFINME.pid
# The selected Java's installatio path
JAVA_HOME=/usr/java/jdk1.8.0_202
# The wildfly instance installation path 
WILDFLY_HOME="$_WFHDIR"
# The configuration you want to run
WILDFLY_CONFIG=standalone.xml
# The mode you want to run
WILDFLY_MODE=standalone
EOF
## Set permissions
chmod -v 644 /etc/wildfly/$_WFINME.conf
##
################################################################################
## Cleanup ##
## Remove WF tarball from temporary location
rm -vf "$_WFPCKG"
