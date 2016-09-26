
These files have been taken from the hardkernel repository:

```bash
git clone https://github.com/hardkernel/u-boot.git -b odroidxu3-v2012.07

#or

for file in bl1.bin.hardkernel bl2.bin.hardkernel sd_fusing.sh tzsw.bin.hardkernel u-boot.bin.hardkernel ; do
  curl -L -o ${file} "https://github.com/hardkernel/u-boot/blob/odroidxu3-v2012.07/sd_fuse/hardkernel/${file}?raw=true"
done
chmod +x ./sd_fusing.sh
./sd_fusing.sh /dev/mmcblk1

```