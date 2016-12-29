# odroidc2-irc-ledctrl
Using odroid-c2 as IR remote control extender for controlling garden led strip lights

## Overview


The goal of this project is to control the led light strips from my mobile phone.


I'm using LED strips from Dymond:

http://www.dymondgroup.be/?portfolio=splashproof-led-strip

And an odroid-c2 as controller:

http://www.hardkernel.com/main/products/prdt_info.php?g_code=G145457216438


This is how it works:

* The mobile phone browses a web page on the odroid-c2 web server.
* The web page shows several buttons, pressing one executes javascript code
* Javascript does HTTP GET on /cgi-bin/irsend.sh?button=GREEN
* The cgi-bin irsend shell script on odroid-c2 executes "irsend SEND_ONCE RCDymond GREEN"
* The irsend command uses /dev/lirc0 device from the lirc_gpioblaster kernel module to send a ir remote command
* A gpio is connected to an IR LED close to the IR receiver of the Dymond LED strip
* The LED controller strip controller receives the ir remote command and switches the LEDs to green


## Building entire project

```
git clone https://github.com/dinutine/odroidc2-irc-ledctrl.git
cd odroidc2-irc-ledctrl
./build.sh
```


## Step by step


### Building odroid-c2 image

Do a git clone of the buildroot git repo:

```
git clone https://github.com/buildroot/buildroot.git
cd buildroot
git checkout 2016.05
```
Edit the odroidc2_defconfig, add dropbear (sshd), lighttpd, libv4l (ir-keytable) and lirc (irsend) packages
```
nano configs/odroidc2_defconfig

# add these lines at the bottom of the file:
BR2_PACKAGE_LIRC_TOOLS=y
BR2_PACKAGE_LIBV4L=y
BR2_PACKAGE_LIBV4L_UTILS=y
BR2_PACKAGE_DROPBEAR=y
BR2_PACKAGE_LIGHTTPD=y
```

Build the flash image:
```
make odroidc2_defconfig
make
```

Flashing the sd card with the sdcard.img

(replace mmcblkx by the actual sdcard interface e.g. mmcblk0):
```
sudo dd if=output/images/sdcard.img of=/dev/mmcblkx
```

Put the sd card in your odroid-c2 and boot it.


### Fixed IP address

In my setup, I want the odroid-c2 to have a fixed IP address (in my case 192.168.0.47)

Create /etc/networking/interfaces on the odroid-c2:

```
auto lo
iface lo inet loopback

auto eth0
iface eth0 inet static
  address 192.168.0.47
  netmask 255.255.255.0
  gateway 192.168.0.1
```

### Create infra red control using GPIO and IR led

#### Schematic
Use the GPIO header on the odroid-c2 to connect an IR led.

I used pin 2,6 and 12 from the header:

http://odroid.com/dokuwiki/doku.php?id=en:c2_gpio_default


This is the schematic I used:

```
                      5V (pin 2)
                        |
                        |
                        _
                       | |
                       | |  300 ohm
                       | |
                       |_|
                        |
                      __|__
                      \   /
                       \ /   IR LED 940nm
                     ___|___
                        |
GPIO #238               |
(pin 12)                |
          _______     |/
    -----|_______|----|   NPN transistor
           10kohm     |\
                        |
                        |
                        |
                        |
                      __|__   GND (pin 6)
                       ///
```

This is what I ordered to implement this:
* http://www.digikey.be/product-detail/en/molex-llc/0850400012/WM4350-ND/2421281
* http://www.digikey.be/product-detail/en/chip-quik-inc/SBBTH1506-1/SBBTH1506-1-ND/5978222
* http://www.digikey.com/product-detail/en/everlight-electronics-co-ltd/IR333-A/1080-1080-ND/2675571


#### Testing the circuit.

The IR LED is invisible with the human eye, but the cameras on a mobile phone often don't have an IR filter.

So capture the IR LED with your mobile phone while toggling the LED:

```
echo 238 > /sys/class/gpio/export
echo out > /sys/class/gpio/gpio238/direction

# set the GPIO 238:
echo 1 > /sys/class/gpio/gpio238/value 

# reset the GPIO 238:
echo 0 > /sys/class/gpio/gpio238/value 
```

Remark:
This gpio might be in use by the gpioblaster module. (when you compiled including my skeleton)

do "rmmod lirc_gpioblaster" to free the gpio first

#### Lirc gpioblaster

Use the gpioblaster kernel module to be able to use the gpio as IRC transmitter:

https://wiki.openwrt.org/doc/howto/lirc-gpioblaster

Load the kernel modules:
```
insmod /lib/modules/3.14.29/kernel/drivers/media/rc/lirc_dev.ko
insmod /lib/modules/3.14.29/kernel/drivers/media/rc/lirc_gpioblaster.ko gpio_out_pin=238 invert=0
```
Now the /dev/lirc0 device is available and can be used by irsend

Remark:

/dev/lirc0 can also be called /dev/lirc1 depending on when the meson-ir.ko module is loaded.

In this tutorial I will always load lirc_gpioblaster.ko first and later load meson-ir.ko.

/dev/lirc0 is the home made IR transmitter using gpio 238

/dev/lirc1 is the on board IR receiver


### Recording the Dymond IR controller

To generate IR commands you need a configuration file containing the characteristics of the remote control protocol.

This configuration file can be generated using the irrecord command.

I used the on board IR receiver of the odroid-c2 to record the buttons of the Dymond remote control:

```
# load the meson-ir module
insmod /lib/modules/3.14.29/kernel/drivers/media/rc/meson-ir.ko
# start recording the remote
irrecord --disable-namespace --device=/dev/lirc1 Dymond
```

The resulting file can be found in:

skeleton/etc/lirc/lircd.conf.d/RCDymond.lircd.conf


### Testing the GPIO blaster remote control

```
# start the lirc daemon (when not already running):
/usr/sbin/lircd -d /dev/lirc0

# IR send command:
irsend SEND_ONCE RCDymond POWER
```


### Lighttpd and cgi irsend


Now adding cgi shell script to execute irsend:

in /usr/lib/cgi-bin/irsend.sh
```
#!/bin/sh
cat << EOF
Content-Type: text/plain

EOF
BUTTONNAME=$REQUEST_URI
#replace the equal sign by a space:
BUTTONNAME=`echo $BUTTONNAME | sed "s/=/ /"`
#now take the second word
BUTTONNAME=`echo $BUTTONNAME | cut -f 2 -d " "`
irsend SEND_ONCE RCDymond $BUTTONNAME
```

And add these line to /etc/lighttpd/lighttpd.conf:
```
$HTTP["scheme"] == "http" {
	alias.url = ("/cgi-bin/" => "/usr/lib/cgi-bin/")
	cgi.assign = (".sh" => "/bin/sh")
}
```

By typing this into your browser's address bar should set the leds to green

http://192.168.0.47/cgi-bin/irsend.sh?button=GREEN

### Creating web page and javascript

Create page in /var/www/index.html containing:
```
<!DOCTYPE html>
<html>
<head>
<title>Lounge LED Control</title>
<script type="text/javascript">

    function httpsend(method,url,data){
	var ipaddr = "192.168.0.47";
	var xhr = new XMLHttpRequest();
	xhr.open(method,'http://' + ipaddr + url, false);
	xhr.send(data);	
    }
	
    function irSend(button) {		
	httpsend('GET','/cgi-bin/irsend.sh?button=' + button,"");
    }
</script>
</head>
<body>
<button class="button" onclick="irSend('POWER')"  >ON</button>
</body>
</html>
```

Pressing the button will execute the cgi script and power the leds.

More extensive example (with all buttons and styling) can be found in skeleton/var/www/index.html

Done!



