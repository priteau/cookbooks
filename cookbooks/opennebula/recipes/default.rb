#
# Cookbook Name:: opennebula
# Recipe:: default
#
# Copyright 2009, Example Com
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

package "scons"
package "xmlrpc-c-devel"

directory "/srv/cloud" do
  owner "root"
  group "root"
  mode "0755"
end

group "cloud" do
end

user "oneadmin" do
  gid "cloud"
  home "/srv/cloud/one"
end

remote_file "#{Chef::Config[:file_cache_path]}/#{node[:opennebula][:src_name]}" do
  checksum node[:opennebula][:src_checksum]
  source node[:opennebula][:src_mirror]
end

bash "Install OpenNebula #{node[:opennebula][:src_version]}" do
  cwd Chef::Config[:file_cache_path]
  code <<-EOH
  tar -xzf #{node[:opennebula][:src_name]}
  cd one-#{node[:opennebula][:src_version]}
  scons
  ./install.sh -d /srv/cloud/one -u oneadmin -g cloud
  EOH
  not_if "ls /srv/cloud/one/bin"
end
