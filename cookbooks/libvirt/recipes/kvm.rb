#
# Cookbook Name:: libvirt
# Recipe:: kvm
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

case node[:platform]
when "debian"
  %w{ dnsmasq-base qemu-kvm libdevmapper-dev libgnutls-dev libxml2-dev python-dev }.each do |pkg|
    package pkg
  end
end

remote_file "#{Chef::Config[:file_cache_path]}/#{node[:libvirt][:src_name]}" do
  checksum node[:libvirt][:src_checksum]
  source node[:libvirt][:src_mirror]
end

bash "Install libvirt #{node[:libvirt][:src_version]}" do
  cwd "/tmp"
  code <<-EOH
  tar xzf #{node[:libvirt][:src_name]}
  cd libvirt-#{node[:libvirt][:src_version]} && ./configure --prefix=/usr/local --without-xen --with-python
  make -j #{@node[:cpu][:total] + 1}
  make install
  EOH
  creates "/usr/local/sbin/libvirtd"
end

group 'libvirt' do
end

bash "configure-ldso" do
  code "ldconfig"
end

bash "authorize-libvirt-group" do
  code '(sed -i -e \'s/^#unix_sock_group = "libvirt"/unix_sock_group = "libvirt"/\' /usr/local/etc/libvirt/libvirtd.conf;
    sed -i -e \'s/^#unix_sock_ro_perms = "0777"/unix_sock_ro_perms = "0777"/\' /usr/local/etc/libvirt/libvirtd.conf;
    sed -i -e \'s/^#unix_sock_rw_perms = "0770"/unix_sock_rw_perms = "0770"/\' /usr/local/etc/libvirt/libvirtd.conf;
    sed -i -e \'s/^#unix_sock_dir = "\\/var\\/run\\/libvirt"/unix_sock_dir = "\\/usr\\/local\\/var\\/run\\/libvirt"/\' /usr/local/etc/libvirt/libvirtd.conf)'
  not_if 'grep \'^unix_sock_group = "libvirt"\' /usr/local/etc/libvirt/libvirtd.conf'
end

service "libvirtd" do
  start_command "libvirtd -d"
  action [ :start ]
end
