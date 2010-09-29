#
# Cookbook Name:: nimbus
# Recipe:: controls
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

include_recipe "xen" if node[:nimbus][:controls][:hypervisor] == "xen"
include_recipe "libvirt::#{node[:nimbus][:controls][:hypervisor]}"

case node[:platform]
when "debian"
  %w{ bridge-utils dhcp3-server ebtables }.each do |pkg|
    package pkg
  end
end

group node[:nimbus][:controls][:group] do
end

user node[:nimbus][:controls][:user] do
  gid node[:nimbus][:controls][:group]
  home node[:nimbus][:controls][:location]
end

#directory node[:nimbus][:controls][:location] do
#  owner node[:nimbus][:controls][:user]
#  group node[:nimbus][:controls][:group]
#  mode 0755
#end

group "libvirt" do
  members [ 'nimbus' ]
end

directory "/tmp/nimbus" do
  owner "nimbus"
  group "nimbus"
  mode 0755
end

link node[:nimbus][:controls][:location] do
  to "/tmp/nimbus"
end

directory "#{node[:nimbus][:controls][:location]}/.ssh" do
  owner node[:nimbus][:controls][:user]
  group node[:nimbus][:controls][:group]
  mode 0700
end

bash "Configure SSH" do
  user node[:nimbus][:controls][:user]
  group node[:nimbus][:controls][:group]
  environment('HOME' => node[:nimbus][:controls][:location])
  code <<-EOH
  echo -n '#{node[:nimbus][:controls][:ssh_key]}' > #{node[:nimbus][:controls][:location]}/.ssh/id_rsa
  echo -n '#{node[:nimbus][:controls][:ssh_public_key]}' > #{node[:nimbus][:controls][:location]}/.ssh/id_rsa.pub
  echo -n '#{node[:nimbus][:controls][:ssh_public_key]}' > #{node[:nimbus][:controls][:location]}/.ssh/authorized_keys
  chmod 600 #{node[:nimbus][:controls][:location]}/.ssh/*
  EOH
end

%w{ config }.each do |ssh_file|
  remote_file "#{node[:nimbus][:controls][:location]}/.ssh/#{ssh_file}" do
    source ssh_file
    owner node[:nimbus][:controls][:user]
    group node[:nimbus][:controls][:group]
    mode 0600
  end
end

remote_file "#{Chef::Config[:file_cache_path]}/#{node[:nimbus][:controls][:src_name]}" do
  checksum node[:nimbus][:controls][:src_checksum]
  source node[:nimbus][:controls][:src_mirror]
end

# From tarball
#bash "Install Nimbus control agent" do
#  cwd "/tmp"
#  user node[:nimbus][:controls][:user]
#  group node[:nimbus][:controls][:group]
#  code <<-EOH
#  rm -rf #{node[:nimbus][:controls][:location]}/*
#  tar -xzf #{Chef::Config[:file_cache_path]}/#{node[:nimbus][:controls][:src_name]}
#  cp -R nimbus-controls-#{node[:nimbus][:controls][:src_version]}/workspace-control/* #{node[:nimbus][:controls][:location]}
#  EOH
#  creates "#{node[:nimbus][:controls][:location]}/bin/workspace-control.sh"
#end

# From source directory
bash "Install Nimbus control agent" do
  cwd "/tmp"
  user node[:nimbus][:controls][:user]
  group node[:nimbus][:controls][:group]
  code <<-EOH
  rm -rf #{node[:nimbus][:controls][:location]}/*
  cp -R ~priteau/nimbus/control/* #{node[:nimbus][:controls][:location]}
  EOH
end

bash "sudoers" do
  code "(cat >> /etc/sudoers <<EOF
nimbus ALL=(root) NOPASSWD: #{node[:nimbus][:controls][:location]}/libexec/workspace-control/mount-alter.sh
nimbus ALL=(root) NOPASSWD: #{node[:nimbus][:controls][:location]}/libexec/workspace-control/dhcp-config.sh
nimbus ALL=(root) NOPASSWD: #{node[:nimbus][:controls][:location]}/libexec/workspace-control/xen-ebtables-config.sh
nimbus ALL=(root) NOPASSWD: #{node[:nimbus][:controls][:location]}/libexec/workspace-control/kvm-ebtables-config.sh
EOF
)"
end

template "#{node[:nimbus][:controls][:location]}/etc/workspace-control/kernels.conf" do
  source "kernels.conf"
  owner node[:nimbus][:controls][:user]
  group node[:nimbus][:controls][:group]
  mode 0644
  variables(
  )
end

template "#{node[:nimbus][:controls][:location]}/etc/workspace-control/main.conf" do
  source "main.conf"
  owner node[:nimbus][:controls][:user]
  group node[:nimbus][:controls][:group]
  mode 0644
  variables(
  )
end

template "#{node[:nimbus][:controls][:location]}/etc/workspace-control/networks.conf" do
  source "networks.conf"
  owner node[:nimbus][:controls][:user]
  group node[:nimbus][:controls][:group]
  mode 0644
  variables(
    :hypervisor => node[:nimbus][:controls][:hypervisor],
    :bridge => "#{node[:nimbus][:controls][:hypervisor] == 'xen' ? node[:network][:default_interface]: "br0"}",
    :interface => "#{node[:nimbus][:controls][:hypervisor] == 'xen' ? "p#{node[:network][:default_interface]}": node[:network][:default_interface]}"
  )
end

template "#{node[:nimbus][:controls][:location]}/etc/workspace-control/propagation.conf" do
  source "propagation.conf"
  owner node[:nimbus][:controls][:user]
  group node[:nimbus][:controls][:group]
  mode 0644
  variables(
    :scp_user => node[:nimbus][:service][:user]
  )
end

template "/etc/dhcp3/dhcpd.conf" do
  source "dhcpd.conf"
  owner node[:nimbus][:controls][:user]
  group node[:nimbus][:controls][:group]
  mode 0644
  variables(
    :network => node[:nimbus][:controls][:network],
    :netmask => node[:nimbus][:controls][:netmask]
  )
end

bash "dhcp-config.sh" do
  code "(cd #{node[:nimbus][:controls][:location]};
    sed -i -e 's/DHCPD_CONF=\"\\/etc\\/dhcpd.conf\"/DHCPD_CONF=\"\\/etc\\/dhcp3\\/dhcpd.conf\"/' libexec/workspace-control/dhcp-config.sh;
    sed -i -e 's/DHCPD_STOP=\"\\/etc\\/init.d\\/dhcpd stop\"/DHCPD_STOP=\"\\/etc\\/init.d\\/dhcp3-server stop\"/' libexec/workspace-control/dhcp-config.sh;
    sed -i -e 's/DHCPD_START=\"\\/etc\\/init.d\\/dhcpd start\"/DHCPD_START=\"\\/etc\\/init.d\\/dhcp3-server start\"/' libexec/workspace-control/dhcp-config.sh;
  )"
end

template "#{node[:nimbus][:controls][:location]}/etc/workspace-control/libvirt.conf" do
  source "libvirt.conf"
  owner node[:nimbus][:controls][:user]
  group node[:nimbus][:controls][:group]
  mode 0644
  variables(
    :hypervisor => "#{node[:nimbus][:controls][:hypervisor] == "xen"? "xen3": "kvm0"}"
  )
end

template "#{node[:nimbus][:controls][:location]}/etc/workspace-control/xen.conf" do
  source "xen.conf"
  owner node[:nimbus][:controls][:user]
  group node[:nimbus][:controls][:group]
  mode 0644
  variables(
  )
end

# XXX
bash "Fix setuid bits" do
  code "chmod u+s `which sudo`"
end

bash "Copy kernels" do
  code <<-EOH
  cp /boot/vmlinuz-2.6.26-2-xen-amd64 #{node[:nimbus][:controls][:location]}/var/workspace-control/kernels/
  cp /boot/initrd.img-2.6.26-2-xen-amd64 #{node[:nimbus][:controls][:location]}/var/workspace-control/kernels/vmlinuz-2.6.26-2-xen-amd64-initrd
  chown #{node[:nimbus][:controls][:user]}:#{node[:nimbus][:controls][:group]} #{node[:nimbus][:controls][:location]}/var/workspace-control/kernels/*
  EOH
end

bash "setup-bridge" do
  code <<-EOH
  sed -i -e 's/^.*#{node[:network][:default_interface]}.*$//' /etc/network/interfaces;
  cat >> /etc/network/interfaces <<EOF
auto br0
iface br0 inet dhcp
  bridge_ports #{node[:network][:default_interface]}
  bridge_fd 9
  bridge_hello 2
  bridge_maxage 12
  bridge_stp off
EOF
  /etc/init.d/networking restart
  EOH
  not_if "grep br0 /etc/network/interfaces > /dev/null 2>&1" || node[:nimbus][:controls][:hypervisor] == "xen"
end

bash "interface-alias" do
  code "ifconfig #{node[:network][:default_interface]}:0 #{node[:nimbus][:controls][:dhcpd_address]} netmask 255.252.0.0 up" if node[:nimbus][:controls][:hypervisor] == "xen"
  code "ifconfig br0:0 #{node[:nimbus][:controls][:dhcpd_address]} netmask 255.252.0.0 up" if node[:nimbus][:controls][:hypervisor] == "kvm"
end

bash "run-dhcpd" do
  code "/etc/init.d/dhcp3-server start"
end

bash "Increase number of parallel SSH sessions" do
  code <<-EOH
  echo "MaxStartups 1000" >> /etc/ssh/sshd_config
  /etc/init.d/ssh restart
  EOH
  not_if "grep 'MaxStartups 1000' /etc/ssh/sshd_config > /dev/null"
end
