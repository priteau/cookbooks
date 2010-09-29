#
# Cookbook Name:: nimbus
# Recipe:: service
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

bash "Cleanup /nimbus" do
  code <<-EOH
  if [ -f #{node[:nimbus][:service][:location]}/bin/nimbusctl ]; then #{node[:nimbus][:service][:location]}/bin/nimbusctl stop; fi
  rm -rf /tmp/nimbus_install
  rm -rf #{node[:nimbus][:service][:location]}
  EOH
end

group node[:nimbus][:service][:group] do
end

user node[:nimbus][:service][:user] do
  gid node[:nimbus][:service][:group]
  home node[:nimbus][:service][:location]
end

directory "/tmp/nimbus_install" do
  owner node[:nimbus][:service][:user]
  group node[:nimbus][:service][:group]
  mode 0755
end

link node[:nimbus][:service][:location] do
  to "/tmp/nimbus_install"
end

include_recipe "java"

case node[:platform]
when "debian"
  %w{ ant sqlite3 sun-java6-jdk uuid-runtime }.each do |pkg|
    package pkg
  end
end

remote_file "#{Chef::Config[:file_cache_path]}/#{node[:nimbus][:service][:src_name]}" do
  checksum node[:nimbus][:service][:src_checksum]
  source node[:nimbus][:service][:src_mirror]
  owner node[:nimbus][:service][:user]
  group node[:nimbus][:service][:group]
end

# From source directory
bash "Install Nimbus #{node[:nimbus][:service][:src_version]}" do
  cwd "/tmp"
  user node[:nimbus][:service][:user]
  group node[:nimbus][:service][:group]
  environment('HOME' => node[:nimbus][:service][:location])
  code <<-EOH
  rm -rf nimbus
  cp -R ~priteau/nimbus nimbus
  cd nimbus
  mkdir tmp
  cp ~priteau/pip-0.7.2.tar.gz .
  cp ~priteau/setuptools-0.6c11-py2.5.egg .
  cp ~priteau/ws-core-4.0.8-bin.tar.gz tmp/
  cp ~priteau/cumulus-deps.tar.gz cumulus/deps
  tar -zxvf cumulus/deps/cumulus-deps.tar.gz -C cumulus/deps
  yes '' | ./install #{node[:nimbus][:service][:location]}
  EOH
end

# From tarball
#bash "Install Nimbus #{node[:nimbus][:service][:src_version]}" do
#  cwd "/tmp"
#  user node[:nimbus][:service][:user]
#  group node[:nimbus][:service][:group]
#  code <<-EOH
#  rm -rf nimbus-#{node[:nimbus][:service][:src_version]}-src
#  tar -xzf #{Chef::Config[:file_cache_path]}/#{node[:nimbus][:service][:src_name]}
#  cd nimbus-#{node[:nimbus][:service][:src_version]}-src
#  yes '' | ./install #{node[:nimbus][:service][:location]}
#  EOH
#  creates "#{node[:nimbus][:service][:location]}/bin/nimbusctl"
#end

template "#{node[:nimbus][:service][:location]}/services/etc/nimbus/workspace-service/ssh.conf" do
  source "ssh.conf"
  mode 0644
  owner node[:nimbus][:service][:user]
  group node[:nimbus][:service][:group]
  variables(
    :control_ssh_user => node[:nimbus][:controls][:user],
    :service_ssh_user => node[:nimbus][:service][:user],
    :service_node => node[:fqdn]
  )
end

bash "Remove existing pools" do
  user "nimbus"
  code <<-EOH
  rm -f #{node[:nimbus][:service][:location]}/services/etc/nimbus/workspace-service/{network,vmm}-pools/*
EOH
end

template "#{node[:nimbus][:service][:location]}/services/etc/nimbus/workspace-service/vmm-pools/pool" do
  source "vmm-pool"
  mode 0644
  owner node[:nimbus][:service][:user]
  group node[:nimbus][:service][:group]
  variables(
    :memory_request => node[:nimbus][:memory_request],
    :vmms => node[:nimbus][:service][:vmm_nodes]
  )
end

template "#{node[:nimbus][:service][:location]}/services/etc/nimbus/workspace-service/network-pools/public" do
  source "network"
  mode 0644
  owner node[:nimbus][:service][:user]
  group node[:nimbus][:service][:group]
  variables(
    :cloudname => node[:nimbus][:service][:cloudname],
    :dns => node[:nimbus][:service][:dns],
    :ip_addresses => node[:nimbus][:service][:ip_addresses],
    :gateway => node[:nimbus][:service][:gateway],
    :broadcast => node[:nimbus][:service][:broadcast],
    :netmask => node[:nimbus][:service][:netmask]
  )
end

template "#{node[:nimbus][:service][:location]}/services/etc/nimbus/elastic/elastic.conf" do
  source "elastic.conf"
  mode 0644
  owner node[:nimbus][:service][:user]
  group node[:nimbus][:service][:group]
  variables(
  )
end

bash "Disable fake mode" do
  user node[:nimbus][:service][:user]
  group node[:nimbus][:service][:group]
  code "sed -i -e 's/fake.mode=true/fake.mode=false/' #{node[:nimbus][:service][:location]}/services/etc/nimbus/workspace-service/other/common.conf"
  only_if { system "grep 'fake.mode=true' #{node[:nimbus][:service][:location]}/services/etc/nimbus/workspace-service/other/common.conf > /dev/null" }
end

directory "#{node[:nimbus][:service][:location]}/.ssh" do
  owner node[:nimbus][:service][:user]
  group node[:nimbus][:service][:group]
  mode 0700
end

bash "Configure SSH" do
  user node[:nimbus][:service][:user]
  group node[:nimbus][:service][:group]
  environment('HOME' => node[:nimbus][:service][:location])
  code <<-EOH
  echo -n '#{node[:nimbus][:service][:ssh_key]}' > #{node[:nimbus][:service][:location]}/.ssh/id_rsa
  echo -n '#{node[:nimbus][:service][:ssh_public_key]}' > #{node[:nimbus][:service][:location]}/.ssh/id_rsa.pub
  echo -n '#{node[:nimbus][:service][:ssh_public_key]}' > #{node[:nimbus][:service][:location]}/.ssh/authorized_keys
  chmod 600 #{node[:nimbus][:service][:location]}/.ssh/*
  EOH
end

%w{ config }.each do |ssh_file|
  remote_file "#{node[:nimbus][:service][:location]}/.ssh/#{ssh_file}" do
    source ssh_file
    owner node[:nimbus][:service][:user]
    group node[:nimbus][:service][:group]
    mode 0600
  end
end

template "#{node[:nimbus][:service][:location]}/services/etc/nimbus-context-broker/jndi-config.xml" do
  source "jndi-config.xml"
  mode 0600
  owner node[:nimbus][:service][:user]
  group node[:nimbus][:service][:group]
  variables(
    :service_location => node[:nimbus][:service][:location]
  )
end

template "#{node[:nimbus][:service][:location]}/services/etc/nimbus/workspace-service/metadata.conf" do
  source "metadata.conf"
  mode 0644
  owner node[:nimbus][:service][:user]
  group node[:nimbus][:service][:group]
  variables(
    :metadata_server => node[:ipaddress]
  )
end

bash "Increase number of parallel SSH sessions" do
  code <<-EOH
  echo "MaxStartups 1000" >> /etc/ssh/sshd_config
  /etc/init.d/ssh restart
  EOH
  not_if "grep 'MaxStartups 1000' /etc/ssh/sshd_config > /dev/null"
end

bash "Enable container debug" do
  user node[:nimbus][:service][:user]
  group node[:nimbus][:service][:group]
  code <<-EOH
  cat >> #{node[:nimbus][:service][:location]}/services/container-log4j.properties <<EOF
log4j.category.org.globus.workspace=DEBUG
log4j.category.org.nimbustools=DEBUG
EOF
  EOH
  not_if "grep 'log4j.category.org.globus.workspace=DEBUG' #{node[:nimbus][:service][:location]}/services/container-log4j.properties > /dev/null"
end

template "#{node[:nimbus][:service][:location]}/nimbus-setup.conf" do
  source "nimbus-setup.conf"
  mode 0644
  owner node[:nimbus][:service][:user]
  group node[:nimbus][:service][:group]
  variables(
    :ca_name => node[:nimbus][:ca_name],
    :service_node => node[:fqdn]
  )
end

bash "Install certificate information" do
  user node[:nimbus][:service][:user]
  group node[:nimbus][:service][:group]
  environment('HOME' => node[:nimbus][:service][:location])
  code <<-EOH
  find #{node[:nimbus][:service][:location]}/var/ca -type f -exec rm {} \\;
  rm -f #{node[:nimbus][:service][:location]}/var/{hostcert.pem,hostkey.pem,keystore.jks}
  echo -n '#{node[:nimbus][:ca_cert]}' > #{node[:nimbus][:service][:location]}/var/ca/ca-certs/#{node[:nimbus][:ca_name]}.pem
  echo -n '#{node[:nimbus][:ca_key]}' > #{node[:nimbus][:service][:location]}/var/ca/ca-certs/private-key-#{node[:nimbus][:ca_name]}.pem
  CERT_HASH=`openssl x509 -hash -noout < #{node[:nimbus][:service][:location]}/var/ca/ca-certs/#{node[:nimbus][:ca_name]}.pem`
  echo $CERT_HASH
  echo -n '#{node[:nimbus][:ca_cert]}' > #{node[:nimbus][:service][:location]}/var/ca/trusted-certs/$CERT_HASH.0
  cat > #{node[:nimbus][:service][:location]}/var/ca/trusted-certs/$CERT_HASH.signing_policy <<EOF
access_id_CA X509 '/C=US/ST=Several/L=Locality/O=Example/OU=Operations/CN=CA'
pos_rights globus CA:sign
cond_subjects globus '"*"'
EOF
  yes '' | #{node[:nimbus][:service][:location]}/bin/nimbus-configure
  #{node[:nimbus][:service][:location]}/bin/nimbus-new-user -g 04 -i 620c4a30-90ff-11df-b85b-002332c9497e -s "/C=US/ST=Several/L=Locality/O=Example/OU=Operations/CN=Pierre.Riteau@irisa.fr" -a vIKOIQa5tduXorYRxctyh -p TOZcDmPNFYPii8UTcGXrGiRaW4RNfzm2TcTvqZaNCz Pierre.Riteau@irisa.fr
  EOH
end

service "workspace_service" do
  start_command "su #{node[:nimbus][:service][:user]} sh -c '#{node[:nimbus][:service][:location]}/bin/nimbusctl start'"
  stop_command "su #{node[:nimbus][:service][:user]} sh -c '#{node[:nimbus][:service][:location]}/bin/nimbusctl stop'"
  status_command "su #{node[:nimbus][:service][:user]} sh -c '#{node[:nimbus][:service][:location]}/bin/nimbusctl status'"
  restart_command "su #{node[:nimbus][:service][:user]} sh -c '#{node[:nimbus][:service][:location]}/bin/nimbusctl restart'"
  supports [ :start, :stop, :status, :restart ]
  action [ :restart ]
end
