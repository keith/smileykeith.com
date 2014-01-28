---
layout: post
title: "IPSEC/L2TP VPN on a Raspberry Pi running Arch Linux"
date: 2014-01-27 20:49
---

After you buy a Raspberry Pi, or two, you need to figure out what to use
them for. While you'll get a ton of *interesting* ideas, while I didn't
particularly find any of them more useful than as a [thought
exercise](http://arstechnica.com/information-technology/2012/12/10-raspberry-pi-creations-that-show-how-amazing-the-tiny-pc-can-be/),
making a VPN stood out as an actually useful configuration.

Originally when I got my (accidentally chosen) Model A, I spent a little
while going through [this
guide](http://willitscript.com/post/40357408648/using-your-pi-as-a-l2tp-vpn-server)
using Raspbian. That seemed to work fine until I recently purchased a
Model B to replace it and couldn't reproduce the configuration. I
decided to write the steps that I was finally able to use to get a
functional VPN running on Arch Linux.

I started out by following [this
guide](https://raymii.org/s/tutorials/IPSEC_L2TP_vpn_on_a_Raspberry_Pi_with_Arch_Linux.html)
hoping that it would get me a functioning VPN without too much work.
Most of this setup will be based on that article with some tweaks for
what I had to do to make the settings stick.  Unfortunately while it
worked after the setup the configuration did not persist after restart.
For this configuration, like I said earlier, this time around I wanted
to use the ARM version of Arch Linux rather than Raspbian for the
install. You can download the Raspberry Pi compatible Arch image from
their [downloads page](http://www.raspberrypi.org/downloads). I'm not
sure I would recommend Arch for people who haven't installed it before
or at least gotten through their [Beginners'
Guide](https://wiki.archlinux.org/index.php/Beginners'_Guide). The ARM
Image, and the normal image, don't come with a GUI, perfect for this use
of the Pi.

I'm not going to bother with making sure this works before restarting,
since that doesn't seem like much of an issue with actual usage. I
wouldn't recommend doing much configuration before doing this intial
setup. I did this the first time and after an hour of configuration my
VPN did not work correctly, I ended up nuking the work I had done and
starting over. Start by installing the necessary components.

```
pacman -Sy openswan xl2tpd ppp lsof python2
```

You need to do some configuration of the firewall and redirects:

```
echo "net.ipv4.ip_forward = 1" |  tee -a /etc/sysctl.conf
echo "net.ipv4.conf.all.accept_redirects = 0" |  tee -a /etc/sysctl.conf
echo "net.ipv4.conf.all.send_redirects = 0" |  tee -a /etc/sysctl.conf
echo "net.ipv4.conf.default.rp_filter = 0" |  tee -a /etc/sysctl.conf
echo "net.ipv4.conf.default.accept_source_route = 0" |  tee -a /etc/sysctl.conf
echo "net.ipv4.conf.default.send_redirects = 0" |  tee -a /etc/sysctl.conf
echo "net.ipv4.icmp_ignore_bogus_error_responses = 1" |  tee -a /etc/sysctl.conf
```

To make these settings persist we need to create a script that gets
launched by systemd each time we restart the system. As recommended in
the original article, and being a [Homebrew]() user I created the script
in `/usr/local/bin/vpn-boot.sh`:

```
#!/usr/bin/bash

iptables --table nat --append POSTROUTING --jump MASQUERADE

for vpn in /proc/sys/net/ipv4/conf/*; do
    echo 0 > $vpn/accept_redirects;
    echo 0 > $vpn/send_redirects;
done

sysctl -p
```

There are a few things that differ here to the original article. First
the hashbang path was changed since the default $PATH on the ARM version
of Arch didn't include `/bin`. I would run `which -a bash` on your
install to make sure this works for you. This obviously doesn't have
to be changed, but I think it's better in the long run. I also added
`sysctl -p` since these settings didn't seemed to be applied otherwise.
You must make this script executable with something like:

```
chmod +x /usr/local/bin/vpn-boot.sh
```

Since Arch uses systemd to this script has to be launched by creating a
service to be ran through systemd. You can create this file in
`/etc/systemd/system/vpnboot.service`

```
[Unit]
Description=VPN Settings at boot
After=netctl@eth0.service
Before=openswan.service xl2tpd.service

[Service]
ExecStart=/usr/local/bin/vpn-boot.sh

[Install]
WantedBy=multi-user.target
```

As you can see in this script I added a few things from the original
article. I wanted to make sure that the boot command would launch after
the network settings had been established and before the other VPN
software was launched. I'm not sure how much of these changes would be
required for systemd to do what I wanted it to but the order really
seemed to matter for me here. After you create this service enable it
within systemd with:

```
systemctl enable vpnboot.service
```

I also made some changes to `/etc/ipsec.conf` (note the comments in the
default file for some more info on these settings):

```
config setup
  dumpdir=/var/run/pluto/
  nat_traversal=yes
  virtual_private=%v4:10.0.0.0/8,%v4:192.168.0.0/16,%v4:172.16.0.0/12,%v4:25.0.0.0/8,%v6:fd00::/8,%v6:fe80::/10
  oe=off
  protostack=netkey
  plutoopts="--interface=eth0"

conn L2TP-PSK-noNAT
  authby=secret
  pfs=no
  auto=add
  keyingtries=3
  ikelifetime=8h
  keylife=1h
  type=transport
  # Your server's IP (I used my internal IP, assuming you're using NAT)
  left=172.16.1.90
  leftprotoport=17/1701
  right=%any
  rightprotoport=17/%any
  rightsubnetwithin=0.0.0.0/0
  dpddelay=10
  dpdtimeout=20
  dpdaction=clear
```

Then for the `/etc/ipsec.secrets` (use the same server IP address):

```
%SameIP%  %any: PSK "super random key"
```

The make systemd start openswan on boot as well:

```
systemctl enable openswan
```

I also edited the openswan service file in
`/etc/systemd/system/multi-user.target.wants`:

```
[Unit]
Description=Openswan daemon
After=netctl@eth0.service vpnboot.service
Before=xl2tpd.service

[Service]
Type=forking
ExecStart=/usr/lib/systemd/scripts/ipsec --start
ExecStop=/usr/lib/systemd/scripts/ipsec --stop
ExecReload=/usr/lib/systemd/scripts/ipsec --restart
Restart=always

[Install]
WantedBy=multi-user.target
```

As you can see I removed the original network dependency and added a new
dependency of [netctl's](https://wiki.archlinux.org/index.php/Netctl)
default network interface (we haven't enabled this yet).

Next for `/etc/xl2tpd/xl2tpd.conf`:

```
[global]
ipsec saref = yes
saref refinfo = 30

[lns default]
ip range = 172.16.1.70-172.16.1.89
local ip = 172.16.1.1
require authentication = yes
ppp debug = yes
pppoptfile = /etc/ppp/options.xl2tpd
length bit = yes
unix authentication = yes
```

Where `local ip` is the server's ip and the `ip range` is the range of
IP addresses you want to use for VPN clients. You need to enable this
service too with:

```
systemctl enable xl2tpd
```

I also edited the systemd file for xl2tpd at
`/etc/systemd/system/multi-user.target.wants/xl2tpd.service`:

```
[Unit]
Description=Level 2 Tunnel Protocol Daemon (L2TP)
After=syslog.target netctl@eth0.service openswan.service
Requires=openswan.service

[Service]
Type=simple
PIDFile=/run/xl2tpd/xl2tpd.pid
ExecStart=/usr/bin/xl2tpd -D
Restart=on-abort

[Install]
WantedBy=multi-user.target
```

The other guide also recommends creating the xl2tpd control folder with:

```
mkdir /var/run/xl2tpd/
```

No we need to create/edit `/etc/ppp/options.xl2tpd`:

```
ipcp-accept-local
ipcp-accept-remote
ms-dns 8.8.8.8
ms-dns 8.8.4.4
auth
mtu 1200
mru 1000
crtscts
hide-password
modem
name l2tpd
proxyarp
lcp-echo-interval 30
lcp-echo-failure 4
login
```

`/etc/pam.d/ppp`:

```
auth    required        pam_nologin.so
auth    required        pam_unix.so
account required        pam_unix.so
session required        pam_unix.so
```

`/etc/ppp/pap-secrets`:

```
*       l2tpd           ""              *
```

To enable the startup of the default netctl eth0 interface you need to
run:

```
netctl enable eth0
```

You'll probably want to disable any other netctl systemd functions that
are enabled by default. Check
`/etc/systemd/system/mutli-user.target.wants` to check for other
`netctl` profiles.

So at this point you should be able to enable VPN clients using the
super secret keys you enabled before and the username and passwords
you've created previously. You can create new users for specifically VPN
usage with something like this:

```
adduser vpnuser
usermod -s /sbin/nologin vpnuser
```

This disallows users from being able to be used for login which is
probably more secure for your VPN (although not required).

### Troubleshooting

Undoubtedly you'll have to deal with something that doesn't work exactly
how my setup works. The most useful things to seeing what was happening
were these:

```
netstat -tulpan
systemctl status openswan
systemctl status xl2tpd
journalctl -f
```

You can glance at some of the other guides to see what should be going
on. You probably shouldn't see any red in the `openswan` status and you
should see ports open under `pluto` with netstat. You can check out the
[ipsec manpage](http://linux.die.net/man/5/ipsec.conf) or the [openswan
wiki
page](https://github.com/xelerance/Openswan/wiki/L2tp-ipsec-configuration-using-openswan-and-xl2tpd)
for a little more information on some of the settings. Also I used [this
page](http://www.freedesktop.org/software/systemd/man/systemd.service.html)
for some more info on how systemd settings work. Please let me know if
there's anything here that could be done easier/better for this
configuration.
