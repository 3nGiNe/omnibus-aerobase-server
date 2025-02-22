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

require 'openssl'

os_helper = OsHelper.new(node)

# Default location of install-dir is /opt/aerobase/. This path is set during build time.
# DO NOT change this value unless you are building your own Unifiedpush packages
server_dir = node['unifiedpush']['aerobase-server']['dir']
service_name = "Aerobase-Application-Server"

# Stop windows service before we try to override files.
include_recipe "aerobase::aerobase-server_stop"

if os_helper.is_windows?
  execute "#{server_dir}/bin/service.bat uninstall /name #{service_name}" do
    ignore_failure true
  end
end
