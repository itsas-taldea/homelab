# Proxmox

[pve.proxmox.com/wiki: Host System Administration](https://pve.proxmox.com/wiki/Host_System_Administration) includes an
index of pages covering most of these topics.

To rotate the console/screen without having an X server (i.e. without ``xrandr``), such as when running [Proxmox](https://www.proxmox.com/), see [kernel.org/doc: The Framebuffer Console](https://www.kernel.org/doc/html/latest/fb/fbcon.html?highlight=console): `echo 3 > /sys/class/graphics/fbcon/rotate`.

## After installation

### Renaming a node

If the name of a node needs to be changed after installation, it must be done before creating any VM or container.
See [pve.proxmox.com/wiki: Renaming a PVE node](https://pve.proxmox.com/wiki/Renaming_a_PVE_node).

### Setup network

See [pve.proxmox.com/wiki: Network Configuration](https://pve.proxmox.com/wiki/Network_Configuration).

Edit `vi /etc/network/interfaces`.
Use the configuration from [Masquerading (NAT) with iptables](https://pve.proxmox.com/wiki/Network_Configuration#_masquerading_nat_with_tt_span_class_monospaced_iptables_span_tt) as a reference.

- The `/24` appendix (the subnet mask) in the address is necessary!

- When hardware changes (for instance, some PCI device is added or removed), the name of
  network interfaces might change.
  Hence, the network setup might need to be updated accordingly.
  See [freedesktop.org/wiki/Software/systemd: Predictable Network Interface Names](https://www.freedesktop.org/wiki/Software/systemd/PredictableNetworkInterfaceNames/).

- The IP that is shown in the terminal welcome message is read from `/etc/hosts`.

#### Setup DNS servers

Edit `/etc/resolv.conf`.

### Setup package repositories

See [pve.proxmox.com/wiki: Package Repositories](https://pve.proxmox.com/wiki/Package_Repositories).

* `mv /etc/apt/sources.list.d/pve-enterprise.list /etc/apt/sources.list.d/pve.list`
* `vi /etc/apt/sources.list.d/pve.list`
  * Comment the `pve-enterprise` repository and add the `pve-no-subscription` repository.

Since Proxmox VE 9, *deb822* format is used.
Add `Enabled: no` to disable the enterprise repository without removing it.

### Secure Proxmox VE API

See [pve.proxmox.com/pve-docs: pveproxy](https://pve.proxmox.com/pve-docs/pveproxy.8.html).

## Storage

When managing storage on Proxmox, there are two different abstractions to be dealt with.
On the one hand, disks need to be added to a host and they need to be partitioned/formatted.
On the other hand, the disks/partitions which are available on a host can be used in three different ways:

* managed manually,
* managed by Proxmox (see [pve.proxmox.com/wiki: Storage](https://pve.proxmox.com/wiki/Storage)), or
* managed by a VM (see [pve.proxmox.com/wiki: Passthrough Physical Disk to Virtual Machine (VM)](https://pve.proxmox.com/wiki/Passthrough_Physical_Disk_to_Virtual_Machine_(VM)).

### Mounting and fstab

If a partition is to be managed manually or by a VM, the filesystem needs to be mounted in order to access the content.
Should mounting be temporary, it can be done through `mount` and `umount`.
However, in order to preserve the mount and have it done automatically after boot/restart, it needs to be done by
editing `/etc/fstab`.

- If the partition is to be managed by a VM, first pass it through by ID and then edit the `/etc/fstab` inside the VM.

- In order to automatically mount a partition through fstab, it is recommended to use the UUID.
  That is because other identifiers might change depending on which disks are (dis)connected.
  Use `blkid` to get the UUID of the partition.
  For instance: `blkid /dev/nvme1n1p2`.
  Then, use it as e.g. `UUID=769d34f1-339c-4d31-b0d7-0b5442342ab0 /mnt/vault ext defaults 0 0` in `/etc/fstab`.
  Note that this does not apply to Logical Volumes (LVs), which are uniquely identified by name.

- Execute `mount -av` to load the new entry without restarting the system.

### Partitioning and resizing

As explained in [pve.proxmox.com/wiki: Host Bootloader > Partitioning Scheme Used by the Installer](https://pve.proxmox.com/wiki/Host_Bootloader#sysboot_installer_part_scheme),
the default Proxmox installer creates three partitions:

- 1 MB BIOS Boot Partition (gdisk type EF02)
- 512 MB EFI System Partition (ESP, gdisk type EF00)
- LVM partition spanning the remaining space.

As further detailed in [pve.proxmox.com/wiki: Logical Volume Manager (LVM)](https://pve.proxmox.com/wiki/Logical_Volume_Manager_(LVM)),
it creates one Volume Group (VG) named `pve`, and three Logical Volumes (LVs):

* root (EXT4)
* swap
* data (LVM-Thin Pool)

In Proxmox's storage, `data` is setup as type `LVM-Thin` to contain VM disk images and container volumes; and
`/var/lib/vz` (in `root`) is setup as type `Directory` to contain backups, ISO images and container templates.

Eventually, either `data` or `root` might run out of space and the storage will need to be extended.
Thanks to LVM providing an intermediate abstraction between physical partitions/disks/volumes and logical volumes, most tweaks can be done through `lvresize` (or `lvextend`) and, sometimes, `resize2fs`.

Some GUI tools such as `gparted` or Proxmox's web interface can provide information about the LVM volumes and groups.
Nevertheless, it is recommended to get the details through commands `lvscan`, `pvs`, `lvs`, `vgs`, `pvdisplay`,
`lvdisplay` and/or `vgdisplay`.

### Primary disk

Thin volumes cannot be reduced!
This is a limitation of LVM (for now).
In order to reduce the size of a thin pool, it needs to be removed and created again.
Should logical volumes be allocated in the pool, those need to be either removed or temporarily moved to another pool,
before removing it.
Proxmox does support moving disks of VMs from one pool to another, as long as both are managed through Proxmox's Storage.

Nonetheless, for small setups and for learning purposes, it is suggested to use a volume group and regular LVs instead of LVM-Thin.

#### Extend a thin pool

If an overflow occurs within the thin pool metadata, then the pool will be corrupted. LVM cannot recover from this.
Therefore, if a thin pool is to be extended, the metadata needs to be proportionally extended first.

See [pve.proxmox.com/wiki: Logical Volume Manager (LVM) > Resizing the thin pool](https://pve.proxmox.com/wiki/Logical_Volume_Manager_(LVM)#_resizing_the_thin_pool) and [pve.proxmox.com/wiki: LVM2 > Resize metadata pool](https://pve.proxmox.com/wiki/LVM2#Resize_metadata_pool).

The thin pool and the metadata can be resized at the same time:

```bash
lvresize --size +<size[\M,G,T]> --poolmetadatasize +<size[\M,G]> <VG>/<LVThin_pool>
```

However, in order to add all the free physical space in the volume group, it might be done in two steps:

```bash
lvresize --poolmetadatasize <size[\M,G,T]> <VG>/<LVThin_pool>
lvextend -l +100%FREE <VG>/<LVThin_pool>
```

#### Remove a thin pool and extend an ext4 volume

If another thin pool or volume group was added to Proxmox's storage, and assuming that no virtual disk is allocated in the *default*
`pve/data` pool, it can be removed in order to use the space on the main disk for `pve/root`:

```bash
lvremove pve/data
lvextend -l +100%FREE pve/root
resize2fs /dev/pve/root
```

Since the logical volume `pve/root` is using an ext4 filesystem, resizing it after extending (or before reducing) the volume
is required.
Otherwise, the filesystem will not be aware of the changes and nasty things can happen.

### Secondary disk(s)

If the primary disk is small to contain both the `root` volume and the VM disks, other disks might be added to the host
(and to Proxmox).

#### As additional physical volume(s) in an existing volume group

Adding physical volumes (partitions) from multiple disks to a the same volume group increases the bandwidth.
However, unless some disk redundancy is used underneath, a failure in one of the disks can break the data in the whole group.
Therefore, we try to keep volume groups associated with a single device.

Still, we might need to temporarily add a disk/partition to an existing volume group, in order to reorganise the content:

 ```bash
vgextend <VG> <PV>
```

When the disk is not required anymore, the physical partition/disk/volume can be removed from the volume group.
See [access.redhat.com/documentation: Cómo retirar un disco de un volumen lógico](https://access.redhat.com/documentation/es-es/red_hat_enterprise_linux/6/html/logical_volume_manager_administration/disk_remove_ex).

#### As a new volume group or as a thin pool

If a whole disk is to be used, Proxmox allows doing it graphically:

* Node > Disks > Wipe Disk
  * Node > Disks > LVM > Create: Volume Group
  * Node > Disks > LVM-Thin > Create: Thinpool

Alternatively, if only a partition of the disk is to be used, it needs to be done in the command-line:

```bash
# Fist, use a partitioning tool to create the partition and format it as LVM
gparted

# Create a new volume group with that physical volume
vgcreate <VG> <PV>

# Create a thin pool in the volume group
lvcreate -L <size[\M,G,T]> -T <VG>/<LVThin_pool>
```

In order to make it usable by Proxmox, add it through the web interface:
Datacener > Storage > Add.

After adding a new volume group or a thin pool in a separated disk, and moving all the VM disks through Proxmox's web interface, it
might be desirable to remove `pve/data` and grow `pve/root` as explained above.

### Passthrough physical disk to VM

See [pve.proxmox.com/wiki: Passthrough Physical Disk to Virtual Machine (VM)](https://pve.proxmox.com/wiki/Passthrough_Physical_Disk_to_Virtual_Machine_(VM)).
TL;DR:

- `ls -la /dev/disk/by-id`
- `qm set <VM_ID> -scsi<?> /dev/disk/by-id/<DISK_ID>`
- Restart the VM.

On Windows, additional drivers are required.
See [pve.proxmox.com/wiki: Paravirtualized Block Drivers for Windows](https://pve.proxmox.com/wiki/Paravirtualized_Block_Drivers_for_Windows).

## GPU

Proxmox requires a GPU in order to use a monitor for the installation and initial setup of the system.
It can then be managed through the web interface and/or through SSH.
The GPU might be removed from the host (or allocated exclusively to a VM) after network access is enabled.
Still, future configuration changes might produce failing reboots, which would prevent remote troubleshooting.
As a result, it is recommended to have a GPU dedicated to the host and a monitor connected to it.
Therefore, on machines without an integrated GPU, at least two GPUs are required so that one can be used by the host and
the other one can be passed to a VM.

### Passthrough PCI(e) GPU to VM

> [pve.proxmox.com/wiki: PCI(e) Passthrough](https://pve.proxmox.com/wiki/PCI(e)_Passthrough)
>
> *PCI(e) passthrough is a mechanism to give a virtual machine control over a PCI device from the host.*
> *This can have some advantages over using virtualized hardware, for example lower latency, higher performance, or more
> features (e.g., offloading).*
>
> *But, if you pass through a device to a virtual machine, you cannot use that device anymore on the host or in any
> other VM.*

> *When passing through a GPU, the best compatibility is reached when using q35 as machine type, OVMF (EFI for VMs)*
> *instead of SeaBIOS and PCIe instead of PCI. Note that if you want to use OVMF for GPU passthrough, the GPU needs to*
> *have an EFI capable ROM, otherwise use SeaBIOS instead.*

See also [pve.proxmox.com/wiki: Pci passthrough](https://pve.proxmox.com/wiki/Pci_passthrough).

* Enable IOMMU support in BIOS/UEFI.
* Edit the kernel commandline to add `intel_iommu=0`.
* Make sure vfio modules are loaded by adding them to `/etc/modules` and refreshing *initramfs*.
* Reboot.
* Verify IOMMU groups/isolation.
* Find the vendor and device IDs through `lspci -nn`:
* Create `/etc/modprobe.d/vfio.conf` (see [vfio.conf](orion.modprobe.d/vfio.conf)).

  * Optionally, blacklist the drivers (see [blacklist.nouveau.conf](orion.modprobe.d/blacklist.nouveau.conf)).

    * If using an AMD/ATI GPU for the host and NVIDIA GPUs to be passed through, `nouveau` can be *safely* blacklisted, because the host GPU is using `radeon`.
      However, if both the host and the VMs used NVIDIA GPUs, `nouveau` could not be blacklisted because it would be
      required by the host.

* Refresh *initramfs* again.

* Reboot and use `lspci -nnk` to check whether the devices are now using kernel driver `vfio-pci`.

* Last, add the device to the VM(s) through the Proxmox GUI or through `qm set` (see [pve.proxmox.com/wiki: PCI(e) Passthrough > VM Configuration](https://pve.proxmox.com/wiki/PCI(e)_Passthrough#qm_pci_passthrough_vm_config)).

## Install Windows 11 on a VM

* [Virtualize Windows 11 with Proxmox the Right Way! @ Techno Tim](https://www.youtube.com/watch?v=fupuTkkKPDU)
* [pve.proxmox.com/wiki: Paravirtualized Block Drivers for Windows](https://pve.proxmox.com/wiki/Paravirtualized_Block_Drivers_for_Windows)
* If masquerading is used, and unless a DHCP service is running on the subnet, installation will be blocked due to the
  lack of network connection.
  Open a command prompt with `Shit+F10` and bypass the requirement by executing command `OOBE\BYPASSNRO`.
  After installation, set the network address, mask, gateway and DNS manually.
