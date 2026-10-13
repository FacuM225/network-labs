#!/bin/bash
set -e

# 1. Variables de entorno
CLIENT_NS="client_ns"
SERVER_NS="server_ns"
ROUTER_NS="router_ns"

VETH_C="veth-client"
VETH_RT_C="veth-rt-client"
VETH_S="veth-server"
VETH_RT_S="veth-rt-server"

# 2. Limpieza previa
echo "--> Limpiando entorno previo..."
ip netns del $CLIENT_NS 2>/dev/null || true
ip netns del $SERVER_NS 2>/dev/null || true
ip netns del $ROUTER_NS 2>/dev/null || true

# 3. Creación de Namespaces (Capa 2 aislada)
echo "--> Creando namespaces..."
ip netns add $CLIENT_NS
ip netns add $SERVER_NS
ip netns add $ROUTER_NS

# 4. Creación de enlaces físicos virtuales (veth pairs)
echo "--> Creando cables virtuales..."
ip link add $VETH_C type veth peer name $VETH_RT_C
ip link add $VETH_S type veth peer name $VETH_RT_S

# 5. Asignación de interfaces a cada namespace
echo "--> Asignando interfaces..."
ip link set $VETH_C netns $CLIENT_NS
ip link set $VETH_RT_C netns $ROUTER_NS
ip link set $VETH_S netns $SERVER_NS
ip link set $VETH_RT_S netns $ROUTER_NS

# 6. Encendido de interfaces
echo "--> Levantando interfaces..."
ip netns exec $CLIENT_NS ip link set lo up
ip netns exec $CLIENT_NS ip link set $VETH_C up

ip netns exec $SERVER_NS ip link set lo up
ip netns exec $SERVER_NS ip link set $VETH_S up

ip netns exec $ROUTER_NS ip link set lo up
ip netns exec $ROUTER_NS ip link set $VETH_RT_C up
ip netns exec $ROUTER_NS ip link set $VETH_RT_S up

# 7. Asignación de Direcciones IP (Capa 3)
echo "--> Asignando direcciones IP..."
ip netns exec $CLIENT_NS ip addr add 192.168.10.2/24 dev $VETH_C
ip netns exec $SERVER_NS ip addr add 192.168.20.2/24 dev $VETH_S
ip netns exec $ROUTER_NS ip addr add 192.168.10.1/24 dev $VETH_RT_C
ip netns exec $ROUTER_NS ip addr add 192.168.20.1/24 dev $VETH_RT_S

# 8. Rutas por defecto
echo "--> Configurando rutas estáticas..."
ip netns exec $CLIENT_NS ip route add default via 192.168.10.1
ip netns exec $SERVER_NS ip route add default via 192.168.20.1

# 9. Enrutamiento (IP Forwarding)
echo "--> Habilitando IP Forwarding en el router..."
ip netns exec $ROUTER_NS sysctl -w net.ipv4.ip_forward=1 > /dev/null

# 10. Seguridad y NAT (iptables)
echo "--> Aplicando reglas de Firewall y NAT..."
# Bloquear ICMP entre redes
ip netns exec $ROUTER_NS iptables -A FORWARD -p icmp -j DROP
# Enmascarar tráfico saliente hacia el servidor
ip netns exec $ROUTER_NS iptables -t nat -A POSTROUTING -s 192.168.10.0/24 -o $VETH_RT_S -j MASQUERADE

echo "--> Laboratorio desplegado"
