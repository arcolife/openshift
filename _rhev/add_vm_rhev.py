#!/usr/bin/python

from ovirtsdk.api import API
from ovirtsdk.xml import params
import argparse,time

# parse arguments

parser = argparse.ArgumentParser(description="Script to create RHEV based virtual machines")

parser.add_argument("--url", help="RHEV_URL", required=True)
parser.add_argument("--rhevusername", help="RHEV username", required=True)
parser.add_argument("--rhevpassword", help="RHEV password", required=True)
parser.add_argument("--rhevcafile", help="Path to RHEV ca file", default="/etc/pki/ovirt-engine/ca.pem")
parser.add_argument("--memory", help="Memory size for RHEV VM, eg 2 means virtual machine will get 2GB of memory ", default=1)
parser.add_argument("--cluster", help="RHEV Cluster - in which cluster create vm", default="Default")
parser.add_argument("--vmtemplate", help="RHEV template")
parser.add_argument("--nicname", help="NIC name for vm", default="eth0")
parser.add_argument("--num", help="how many virtual machines to create", default=1)
parser.add_argument("--vmprefix", help=" virtual machine name prefix", required=True, default="myvirtmachine")
parser.add_argument("--disksize", help="disk size to attach to virtual machine in GB - passing 1 will create 1 GB disk "
                                       " and attach it to virtual machine, default is 1 GB ", default=1)
parser.add_argument("--vmcores", help="How many cores VM machine will have - default 1 ", default=1)
parser.add_argument("--vmsockets", help=" How many sockets VM machine will have - default 1 ", default=1)

parser.add_argument("--storagedomain", help="which storage domain to use for space when allocating storage for VM"
                                            " If not sure which one - check web interface and/or contact RHEV admin", required=True, default="iSCSI")
args = parser.parse_args()

url=args.url
rhevusarname = args.rhevusername
rhevpassword = args.rhevpassword
rhevcafile = args.rhevcafile
memory = args.memory
cluster = args.cluster
vmtemplate = args.vmtemplate
vmlistfile = args.vmlistfile
nicname = args.nicname
vmprefix = args.vmprefix
num = args.num
disksize = args.disksize
storagedomain = args.storagedomain
vmcores = args.vmcores
vmsockets = args.vmsockets

# basic configurations / functions

# api definition
api = API(url=url,username=rhevusarname, password=rhevpassword, ca_file=rhevcafile)

# todo : implement logger

# wait functions for RHEV allocated disk and RHEV machine itself

def wait_vm_state(vm_name, state):
    while api.vms.get(vm_name).status.state != state:
        time.sleep (1)

def wait_disk_state(disk_name, state):
    while api.disks.get(disk_name).status.state != state:
        time.sleep(1)

def create_vm(vmprefix,disksize, storagedomain,vmcores,vmsockets):
	print ("------------------------------------------------------")
	print ("Creating", num, "RHEV based virtual machines")
	print ("-------------------------------------------------------")
	for machine in range(0,int(num)):
		try:
			vm_name = str(vmprefix) + "_" + str(machine) + "_cores_" + str(vmcores) + "_sockets_" + str(vmsockets)
			vm_memory = int(memory)*1024*1024*1024
			vm_cluster = api.clusters.get(name=cluster)
			vm_template = api.templates.get(name=vmtemplate)
			vm_os = params.OperatingSystem(boot=[params.Boot(dev="hd")])
			cpu_params = params.CPU(topology=params.CpuTopology(sockets=vmsockets,cores=vmcores))
			vm_params = params.VM(name=vm_name,memory=vm_memory,cluster=vm_cluster,template=vm_template,os=vm_os,cpu=cpu_params)
			print ("creating virtual machine", vm_name)
			api.vms.add(vm=vm_params)
			api.vms.get(vm_name).nics.add(params.NIC(name=nicname, network=params.Network(name='ovirtmgmt'), interface='virtio'))
			print ("Virtual machine created: ", vm_name, "and it has parameters"," memory:", memory,"[GB]",
				   " cores:", vmcores,
				   " sockets", vmsockets,
				   " waiting on machine to unlock so we can attach disk to it")
			wait_vm_state(vm_name, "down")
			diskname = "disk_" + str(vmprefix) + str(machine)

			api.vms.get(vm_name).disks.add(params.Disk(name=diskname, storage_domains=params.StorageDomains(storage_domain=[api.storagedomains.get(name=storagedomain)]),
															size=int(disksize)*1024*1024*1024,
															status=None,
															interface='virtio',
															format='cow',
															sparse=True,
															bootable=False))
			# if disk is not in "OK" state ... wait here - we cannot start machine if this is not the case
			print ("Disk of size:",disksize,"GB originating from", storagedomain, "storage domain is attached to VM - but we cannot start machine before disk is in OK state"
				   " starting machine with disk attached to VM and same time having disk in Locked state will result in machine start failure")
			wait_disk_state(diskname,"ok")

			print ("Machine", vm_name, "is ready to be started")
			api.vms.get(vm_name).start()
			print ("Machine", vm_name, "started successfully, machine parameters are memory:",memory,"[GB]"
				   " cores:", vmcores,
				   " sockets", vmsockets,
				   " storage disk", disksize, "[GB]")
		except Exception as e:
			print ("Adding virtual machine '%s' failed: %s", vm_name, e)


create_vm(vmprefix, disksize, storagedomain, vmcores, vmsockets)
api.disconnect()