#
# Copyright:: Copyright (c) 2018, Aerobase Inc
# License:: Apache License, Version 2.0
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

# Default location of install-dir is /opt/unifiedpush/. This path is set during build time.
# DO NOT change this value unless you are building your own Unifiedpush packages

os_helper = OsHelper.new(node)
db_helper = DBHelper.new(node)

account_helper = AccountHelper.new(node)
aerobase_user = account_helper.aerobase_user
aerobase_group = account_helper.aerobase_group

install_dir = node['package']['install-dir']
server_dir = node['unifiedpush']['aerobase-server']['dir']
cli_dir = "#{server_dir}/cli"
mssql_dir = "#{server_dir}/bin/mssql"

# These directories do not need to be writable for aerobase-server
[
  cli_dir,
  mssql_dir
].each do |dir_name|
  directory dir_name do
    owner aerobase_user
    group aerobase_group
    mode 0775
    recursive true
  end
end

aerobase_vars = node['unifiedpush']['aerobase-server'].to_hash
keycloak_vars = node['unifiedpush']['keycloak-server'].to_hash
global_vars = node['unifiedpush']['global'].to_hash
cassandra_enabled = node['unifiedpush']['cassandra']['enable']

# Prepare datasource cli config script
template "#{server_dir}/cli/aerobase-server-wildfly-ds.cli" do
  owner aerobase_user
  group aerobase_group
  mode 0755
  source "aerobase-server-wildfly-ds-cli.erb"
  variables(aerobase_vars)
end

# Prepare http cli config script
template "#{server_dir}/cli/aerobase-server-wildfly-http.cli" do
  owner aerobase_user
  group aerobase_group
  mode 0755
  source "aerobase-server-wildfly-http-cli.erb"
  variables(aerobase_vars)
end

# Prepare kc cli config script
template "#{server_dir}/cli/aerobase-server-wildfly-kc.cli" do
  owner aerobase_user
  group aerobase_group
  mode 0755
  source "aerobase-server-wildfly-kc-cli.erb"
  variables(keycloak_vars)
end

# Prepare jgroup cli config script
template "#{server_dir}/cli/aerobase-server-wildfly-jgroup.cli" do
  owner aerobase_user
  group aerobase_group
  mode 0755
  source "aerobase-server-wildfly-jgroup-cli.erb"
  variables(aerobase_vars)
end

# Prepare oauth2 cli config script
template "#{server_dir}/cli/unifiedpush-server-wildfly-oauth2.cli" do
  owner aerobase_user
  group aerobase_group
  mode 0755
  source "unifiedpush-server-wildfly-oauth2-cli.erb"
  variables(aerobase_vars.merge(global_vars))
end


if os_helper.is_windows?
  cli_cmd = "jboss-cli.bat"
  standalone_file = "conf.bat"
else
  cli_cmd = "jboss-cli.sh"
  standalone_file = "conf"
end

# Update configuration 
template "#{server_dir}/bin/standalone.#{standalone_file}" do
  owner aerobase_user
  group aerobase_group
  mode 0755
  source "wildfly-standalone.#{standalone_file}.erb"
  variables(aerobase_vars.merge({
      :cassandra_enabled => cassandra_enabled
    }
  ))
end

template "#{server_dir}/bin/service.bat" do
  owner aerobase_user
  group aerobase_group
  mode 0755
  source "wildfly-service.bat.erb"
  variables(aerobase_vars.merge(global_vars))
  only_if { os_helper.is_windows? }
end

# Execute cli scripts
execute 'Aerobase datasource cli script' do
  command "#{server_dir}/bin/#{cli_cmd} --file=#{server_dir}/cli/aerobase-server-wildfly-ds.cli"
end

execute 'Aerobase http/s cli script' do
  command "#{server_dir}/bin/#{cli_cmd} --file=#{server_dir}/cli/aerobase-server-wildfly-http.cli"
end

execute 'Aerobase kc cli script' do
  command "#{server_dir}/bin/#{cli_cmd} --file=#{server_dir}/cli/aerobase-server-wildfly-kc.cli"
end

execute 'UPS jgroup cli script' do
  command "#{server_dir}/bin/#{cli_cmd} --file=#{server_dir}/cli/aerobase-server-wildfly-jgroup.cli"
end

execute 'Aerobase oauth2 cli script' do
  command "#{server_dir}/bin/#{cli_cmd} --file=#{server_dir}/cli/unifiedpush-server-wildfly-oauth2.cli"
end

# Link apps/
link "#{server_dir}/standalone/deployments/unifiedpush-server.war" do
  to "#{install_dir}/embedded/apps/unifiedpush-server/unifiedpush-server.war"
end

# Copy MSSQL jdbc driver only if mssql is used
ruby_block 'copy_mssql_jdbc_driver' do
  block do
    FileUtils.cp_r "#{install_dir}/embedded/apps/mssql/.", "#{server_dir}/bin/mssql"
  end
  action :run
  only_if { db_helper.is_mssql? }
end
