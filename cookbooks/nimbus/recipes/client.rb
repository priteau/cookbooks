#
# Cookbook Name:: nimbus
# Recipe:: client
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

group node[:nimbus][:client][:group] do
end

user node[:nimbus][:client][:user] do
  gid node[:nimbus][:client][:group]
  home node[:nimbus][:service][:location]
end

directory node[:nimbus][:service][:location] do
  owner node[:nimbus][:client][:user]
  group node[:nimbus][:client][:group]
  mode 0755
end

include_recipe "java"

remote_file "#{Chef::Config[:file_cache_path]}/#{node[:nimbus][:client][:src_name]}" do
  checksum node[:nimbus][:client][:src_checksum]
  source node[:nimbus][:client][:src_mirror]
end

# From tarball
bash "Install Nimbus cloud client" do
  user node[:nimbus][:client][:user]
  group node[:nimbus][:client][:group]
  cwd node[:nimbus][:client][:location]
  code <<-EOH
  tar -xzf #{Chef::Config[:file_cache_path]}/#{node[:nimbus][:client][:src_name]}
  EOH
  creates "#{node[:nimbus][:client][:location]}/nimbus-cloud-client-#{node[:nimbus][:client][:src_version]}/bin/cloud-client.sh"
end

# From source
#bash "Install Nimbus cloud client" do
#  user node[:nimbus][:client][:user]
#  group node[:nimbus][:client][:group]
#  cwd "/tmp"
#  code <<-EOH
#  rm -rf nimbus
#  cp -R ~priteau/nimbus .
#  cp ~priteau/ws-core-4.0.8-bin.tar.gz nimbus/cloud-client/
#  cd nimbus/cloud-client
#  bash builder/dist.sh
#  rm -rf #{node[:nimbus][:client][:location]}/nimbus-cloud-client-#{node[:nimbus][:client][:src_version]}
#  mv nimbus-cloud-client-#{node[:nimbus][:client][:src_version]} #{node[:nimbus][:client][:location]}/
#  EOH
#end

bash "Install root CA" do
  cwd node[:nimbus][:client][:location]
  code <<-EOH
    CERT_HASH=`echo -n '#{node[:nimbus][:ca_cert]}' | openssl x509 -hash -noout`
    echo -n '#{node[:nimbus][:ca_cert]}' > #{node[:nimbus][:client][:location]}/nimbus-cloud-client-#{node[:nimbus][:client][:src_version]}/lib/certs/$CERT_HASH.0
    chmod 644 #{node[:nimbus][:client][:location]}/nimbus-cloud-client-#{node[:nimbus][:client][:src_version]}/lib/certs/$CERT_HASH.0
    cat > #{node[:nimbus][:client][:location]}/nimbus-cloud-client-#{node[:nimbus][:client][:src_version]}/lib/certs/$CERT_HASH.signing_policy <<EOF
access_id_CA X509 '/C=US/ST=Several/L=Locality/O=Example/OU=Operations/CN=CA'
pos_rights globus CA:sign
cond_subjects globus '"*"'
EOF
  EOH
end

bash "Generate SSH credentials" do
  user node[:nimbus][:client][:user]
  group node[:nimbus][:client][:group]
  environment('HOME' => node[:nimbus][:client][:location])
  code <<-EOH
  umask 077
  mkdir -p #{node[:nimbus][:client][:location]}/.ssh
  echo -n '#{node[:nimbus][:client][:ssh_key]}' > #{node[:nimbus][:client][:location]}/.ssh/id_rsa
  echo -n '#{node[:nimbus][:client][:ssh_public_key]}' > #{node[:nimbus][:client][:location]}/.ssh/id_rsa.pub
  touch ~/.ssh/known_hosts
  egrep 'StrictHostKeyChecking[[:space:]]+no' ~/.ssh/config > /dev/null || echo 'StrictHostKeyChecking no' >> ~/.ssh/config
  EOH
end

node[:nimbus][:client][:clouds].each do |cloud|
  template "#{node[:nimbus][:client][:location]}/nimbus-cloud-client-#{node[:nimbus][:client][:src_version]}/conf/clouds/#{cloud[:name]}.properties" do
    source "cloud.properties"
    mode 0644
    owner node[:nimbus][:client][:user]
    group node[:nimbus][:client][:group]
    variables(
      :memory_request => node[:nimbus][:memory_request],
      :service_node => cloud[:service_node]
    )
  end
end

# Set up the default cloud configuration file
link "#{node[:nimbus][:client][:location]}/nimbus-cloud-client-#{node[:nimbus][:client][:src_version]}/conf/cloud.properties" do
  to "#{node[:nimbus][:client][:location]}/nimbus-cloud-client-#{node[:nimbus][:client][:src_version]}/conf/clouds/#{node[:nimbus][:client][:default_cloud]}.properties"
end

bash "Delete old nimbus configuration" do
  code "rm -f #{node[:nimbus][:client][:location]}/nimbus-cloud-client-#{node[:nimbus][:client][:src_version]}/conf/clouds/nimbus.properties"
end

bash "Install user certificate" do
  user node[:nimbus][:client][:user]
  group node[:nimbus][:client][:group]
  environment('HOME' => node[:nimbus][:client][:location])
  cwd node[:nimbus][:client][:location]
  code <<-EOH
  umask 077
  mkdir -p .globus
  echo -n "#{node[:nimbus][:user_cert]}" > .globus/usercert.pem
  echo -n "#{node[:nimbus][:user_key]}" > .globus/userkey.pem
  EOH
end
