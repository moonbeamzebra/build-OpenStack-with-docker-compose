

. admin-openrc.sh
openstack network agent list
openstack hypervisor list
#Découvrir les compute hosts
#Depuis le container nova-api :
nova-manage cell_v2 discover_hosts
openstack hypervisor list
openstack compute service list
openstack resource provider list
openstack catalog list

curl -L -O https://download.cirros-cloud.net/0.6.2/cirros-0.6.2-x86_64-disk.img
openstack image create "cirros-x86_64" \
  --file cirros-0.6.2-x86_64-disk.img \
  --disk-format qcow2 \
  --container-format bare \
  --public

curl -L -O https://download.cirros-cloud.net/0.6.2/cirros-0.6.2-aarch64-disk.img
openstack image create "cirros-arm64" \
  --file cirros-0.6.2-aarch64-disk.img \
  --disk-format qcow2 \
  --container-format bare \
  --public

openstack image list
openstack image show cirros-arm64
# ???? openstack image set cirros-arm64 --property hw_machine_type=virt
openstack image show cirros-arm64


openstack flavor create --ram 256 --disk 1 --vcpus 1 m1.micro
openstack keypair create mykey > mykey.pem
chmod 600 mykey.pem

openstack network create \
  --external \
  --provider-network-type flat \
  --provider-physical-network provider \
  public-net

openstack subnet create --network public-net \
  --no-dhcp \
  --allocation-pool start=192.168.86.235,end=192.168.86.254 \
  --gateway 192.168.86.1 \
  --dns-nameserver 8.8.8.8 \
  --subnet-range 192.168.86.0/24 public-subnet

openstack network create private-net
openstack subnet create --network private-net \
  --subnet-range 192.168.10.0/24 \
  --gateway 192.168.10.1 \
  --dns-nameserver 8.8.8.8 private-subnet

openstack router create router1
openstack router set router1 --external-gateway public-net
openstack router add subnet router1 private-subnet

openstack security group rule create --proto icmp default
openstack security group rule create --proto tcp --dst-port 22 default
#openstack security group rule create --protocol tcp --dst-port 22:22 --remote-ip 0.0.0.0/0 default


openstack server create \
  --flavor m1.micro \
  --image cirros-x86_64 \
  --network private-net \
  --security-group default \
  --key-name mykey \
  test-vm
openstack server show test-vm

openstack server create \
  --flavor m1.micro \
  --image cirros-arm64 \
  --network private-net \
  --security-group default \
  --key-name mykey \
  test-vm
openstack server show test-vm


#Assigner une Floating IP
#Créer une IP flottante :
openstack floating ip create public-net

#Associer à la VM :
openstack server add floating ip test-vm 192.168.86.249

openstack server show test-vm -c addresses
openstack port list --server test-vm

# Autoriser le PING
# openstack security group rule create --protocol icmp default
openstack security group rule list --protocol icmp default

# Autoriser le SSH
# openstack security group rule create --protocol tcp --dst-port 22 default
openstack security group rule list --protocol tcp default

# Lister les namespaces
ip netns list
# Regarder les IPs dans le namespace du routeur (souvent nommé qrouter-xxx)
sudo ip netns exec <nom_du_qrouter> ip addr

