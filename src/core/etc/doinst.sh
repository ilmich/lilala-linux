config() {
  NEW="$1"
  OLD="$(dirname $NEW)/$(basename $NEW .new)"
  # If there's no config file by that name, mv it over:
  if [ ! -r $OLD ]; then
    mv $NEW $OLD
  elif [ "$(cat $OLD | md5sum)" = "$(cat $NEW | md5sum)" ]; then # toss the redundant copy
    rm $NEW
  fi
  # Otherwise, we leave the .new copy for the admin to consider...
}

config etc/HOSTNAME.new
config etc/fstab.new
config etc/group.new
config etc/hosts.new
config etc/rc.d/rc.init.new
config etc/inittab.new
config etc/mdev.conf.new
config etc/passwd.new
config etc/profile.new
config etc/syslog.conf.new
config etc/shells.new
config etc/services.new
