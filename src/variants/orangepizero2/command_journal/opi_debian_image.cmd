# From image: Orangepizero2_3.0.6_debian_bullseye_server_linux5.16.17.7z

BASE_USER_PASSWORD=orangepi
BASE_USER=pi
password=$(perl -e 'printf("%s\n", crypt($ARGV[0], "password"))' "${BASE_USER_PASSWORD}")
useradd -m -p "${password}" -s /bin/bash "${BASE_USER}"
usermod -a -G sudo "${BASE_USER}"
#Make sure user pi / ${BASE_USER} has access to serial ports
usermod -a -G tty "${BASE_USER}"
usermod -a -G dialout "${BASE_USER}"

# allow pi / ${BASE_USER} user to run shutdown and service commands
echo "${BASE_USER} ALL=NOPASSWD: /sbin/shutdown" > /etc/sudoers.d/octoprint-shutdown
echo "${BASE_USER} ALL=NOPASSWD: /usr/sbin/service" > /etc/sudoers.d/octoprint-service

# vi /etc/ssh/sshd_config
# Change "PermitRootLogin yes" to "PermitRootLogin no"

apt update
apt-get -y --force-yes install python3 python3-virtualenv python3-dev git screen subversion cmake cmake-data avahi-daemon libavahi-compat-libdnssd1 libffi-dev libssl-dev libatlas3-base unzip
echo " - Reinstall iputils-ping"
apt-get install --reinstall iputils-ping

cd /home/"${BASE_USER}"
sudo -u "${BASE_USER}" python3 -m virtualenv --python=python3 oprint
sudo -u "${BASE_USER}" /home/"${BASE_USER}"/oprint/bin/pip install --upgrade pip

### Install and setup OctoPrint
OCTOPI_OCTOPRINT_PACKAGE="OctoPrint"
echo "--- Installing OctoPrint"
PIP_DEFAULT_TIMEOUT=60 sudo -u "${BASE_USER}" /home/"${BASE_USER}"/oprint/bin/pip install $OCTOPI_OCTOPRINT_PACKAGE
PIP_DEFAULT_TIMEOUT=60 sudo -u "${BASE_USER}" /home/"${BASE_USER}"/oprint/bin/pip install https://github.com/TheSpaghettiDetective/OctoPrint-Obico/archive/refs/heads/master.zip
sudo -u "${BASE_USER}" mkdir /home/"${BASE_USER}"/.octoprint

# scp ../filesystem/root/etc/systemd/system/octoprint.service to /etc/systemd/system/octoprint.service
systemctl enable octoprint.service

apt-get -y --force-yes install libjpeg62-turbo-dev
apt-get -y --force-yes --no-install-recommends install imagemagick ffmpeg libv4l-dev
OCTOPI_MJPGSTREAMER_ARCHIVE=https://github.com/jacksonliam/mjpg-streamer/archive/master.zip
wget $OCTOPI_MJPGSTREAMER_ARCHIVE -O mjpg-streamer.zip
unzip mjpg-streamer.zip
rm mjpg-streamer.zip
cd mjpg-streamer-master/mjpg-streamer-experimental
# As said in Makefile, it is just a wrapper around CMake.
# To apply -j option, we have to unwrap it.
build_dir=_build
mkdir -p $build_dir
pushd $build_dir
  cmake -DCMAKE_BUILD_TYPE=Release ..
popd

make -j $(nproc) -C $build_dir

install_dir=/opt/mjpg-streamer
mkdir -p $install_dir
install -m 755 $build_dir/mjpg_streamer $install_dir
find $build_dir -name "*.so" -type f -exec install -m 644 {} $install_dir \;

# copy bundled web folder
cp -a -r ./www $install_dir
chmod 755 $install_dir/www
chmod -R 644 $install_dir/www

# create our custom web folder and add a minimal index.html to it
mkdir $install_dir/www-octopi
cd $install_dir/www-octopi
cat <<EOT >> index.html
<html>
<head><title>mjpg_streamer test page</title></head>
<body>
<h1>Snapshot</h1>
<p>Refresh the page to refresh the snapshot</p>
<img src="./?action=snapshot" alt="Snapshot">
<h1>Stream</h1>
<img src="./?action=stream" alt="Stream">
</body>
</html>
EOT
cd /home/"${BASE_USER}"
rm -rf mjpg-streamer-master

# scp ../filesystem/root/etc/systemd/system/webcamd.service to /etc/systemd/system/webcamd.service
mkdir /root/bin
# scp ../filesystem/root/bin/webcamd to /root/bin/webcamd
systemctl enable webcamd.service

### Haproxy
echo "--- Installing haproxy"
apt-get -y --force-yes install ssl-cert haproxy
# scp ../filesystem/root/etc/haproxy/haproxy.2.x.cfg to /etc/haproxy/haproxy.cfg
# scp ../filesystem/root/etc/haproxy/errors to /etc/haproxy/

rm /etc/ssl/private/ssl-cert-snakeoil.key /etc/ssl/certs/ssl-cert-snakeoil.pem

# scp ../filesystem/root/etc/systemd/system/gencert.service to /etc/systemd/system/gencert.service
mkdir /root/bin
# scp ../filesystem/root/bin/gencert to /root/bin/gencert
systemctl enable gencert.service

### logrotatd
# scp -r ../filesystem/root/etc/logrotate.d to /etc/

### Janus
apt-get -y --force-yes install janus
systemctl disable janus

### Resize on initial boot
systemctl enable orangepi-resize-filesystem

#### Run as pi user
# scp ../filesystem/home/pi/.octoprint/config.yaml to /home/pi/.octoprint/config.yaml
# scp ../filesystem/home/pi/webcamd.txt to /home/pi/webcamd.txt
# Edit webcam.txt to for this line 'camera_usb_options="-r 640x480 -f 10 -d /dev/video1"'

