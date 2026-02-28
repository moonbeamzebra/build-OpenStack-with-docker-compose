
# entre autres :
# sur container nova-api
# Logs des 3 containers
nova-manage cell_v2 list_cells
openstack compute service list
openstack catalog list | grep compute

# Vérifier placement integration
### Pour l’instant vide → normal (pas de compute).
openstack resource provider list ### Pour l’instant vide → normal (pas de compute).
echo $?  ## doit retourner 0

# Vérifier hypervisors
### Vide → normal.
openstack hypervisor list
echo $?  ## doit retourner 0

# Vérifier services internes
# Très utile pour voir si quelque chose manque.
nova-status upgrade check
echo $?  ## doit retourner 0

# Vérifier transport
### Vide → normal (pas de compute).
nova-manage cell_v2 list_hosts
echo $?  ## doit retourner 0

curl http://localhost:8774

