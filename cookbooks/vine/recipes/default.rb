#
# Cookbook Name:: vine
# Recipe:: default
#
# Copyright 2010, Example Com
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
# 
#     http://www.apache.org/licenses/LICENSE-2.0
# 
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#

include_recipe "java"

case node[:vine][:cloudname]
when 'grenoble'
  node.set.vine.subnet = '10.180.0.0/14'
  node.set.vine.prefix = '10.180'
  node.set.vine.router_id = '1000017'
when 'lille'
  node.set.vine.subnet = '10.136.0.0/14'
  node.set.vine.prefix = '10.136'
  node.set.vine.router_id = '1000010'
when 'lyon'
  node.set.vine.subnet = '10.140.0.0/14'
  node.set.vine.prefix = '10.140'
  node.set.vine.router_id = '1000012'
when 'nancy'
  node.set.vine.subnet = '10.144.0.0/14'
  node.set.vine.prefix = '10.144'
  node.set.vine.router_id = '1000013'
when 'rennes'
  node.set.vine.subnet = '10.156.0.0/14'
  node.set.vine.prefix = '10.156'
  node.set.vine.router_id = '1000014'
when 'sophia'
  node.set.vine.subnet = '10.164.0.0/14'
  node.set.vine.prefix = '10.164'
  node.set.vine.router_id = '1000016'
when 'toulouse'
  node.set.vine.subnet = '10.160.0.0/14'
  node.set.vine.prefix = '10.160'
  node.set.vine.router_id = '1000015'
end

if node[:vine][:cloudname] == "lille"
  template "/root/ViNe.conf" do
    source "ViNe.conf"
    mode 0644
    variables(
      :subnet => node[:vine][:subnet],
      :router_id => node[:vine][:router_id],
      :router_ip => node[:ipaddress]
    )
  end
else
  template "/root/ViNe.conf" do
    source "ViNe_fulltunnel.conf"
    mode 0644
    variables(
      :subnet => node[:vine][:subnet],
      :router_id => node[:vine][:router_id],
      :router_ip => "#{node[:vine][:prefix]}.0.1",
      :queue_public_ip => node[:vine][:vine_router]
    )
  end
end

template "ViNe.nskt.conf" do
  source "ViNe.nskt.conf"
  mode 0644
  variables(
  )
end

template "ViNe.gndt.conf" do
  source "ViNe.gndt.conf"
  mode 0644
  variables(
    :queue_public_ip => node[:vine][:vine_router]
  )
end

template "ViNe.lndt.conf" do
  source "ViNe.lndt.conf"
  mode 0644
  variables(
    :prefix => node[:vine][:prefix]
  )
end

if node[:vine][:cloudname] == "lille"
  bash "Additionnal configuration for ViNe" do
    code <<-EOH
    ifconfig #{node[:network][:default_interface]}:0 #{node[:vine][:prefix]}.0.1 netmask 255.252.0.0
    route del -host 128.227.59.140 gw 10.136.0.2 # UF VR
    route del -host 198.202.120.100 gw 10.136.0.2 # SD VR
    route del -host  149.165.148.101 gw 10.136.0.2 # UC VR

    route add -host 128.227.59.140 gw 10.136.0.2 # UF VR
    route add -host 198.202.120.100 gw 10.136.0.2 # SD VR
    route add -host  149.165.148.101 gw 10.136.0.2 # UC VR
    EOH
  end
end

bash "Install ViNe" do
  cwd "/root"
  code <<-EOH
  kill `ps ax | grep VirtualRouter | grep -v grep | awk '{ print $1; }'`
  ifconfig #{node[:network][:default_interface]}:0 #{node[:vine][:prefix]}.0.1 netmask 255.252.0.0
  echo 1 > /proc/sys/net/ipv4/ip_forward
  /root/tunctl-1.5/tunctl -n -t tun0
  ifconfig tun0 #{node[:vine][:prefix]}.0.1
  route del -net 198.202.120.0 netmask 255.255.255.0 tun0
  route del -net 172.31.10.0 netmask 255.255.255.0 tun0
  route del -net 149.165.148.0 netmask 255.255.255.0 tun0

  route add -net 198.202.120.0 netmask 255.255.255.0 tun0
  route add -net 172.31.10.0 netmask 255.255.255.0 tun0
  route add -net 149.165.148.0 netmask 255.255.255.0 tun0

  export LD_LIBRARY_PATH=/usr/local/lib
  java -cp ViNe.jar:lib/log4j-1.2.15.jar:. vine.core.VirtualRouter > /var/log/vine.log 2>&1 &
  EOH
end
