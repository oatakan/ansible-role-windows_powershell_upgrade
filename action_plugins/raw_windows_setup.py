# (c) 2024, Orcun Atakan <oatakan@gmail.com>
#
# Ansible is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
#
# Ansible is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with Ansible.  If not, see <http://www.gnu.org/licenses/>.
from __future__ import annotations

from ansible.plugins.action import ActionBase
import json, re


class ActionModule(ActionBase):
    TRANSFERS_FILES = False

    def run(self, tmp=None, task_vars=None):
        if task_vars is None:
            task_vars = dict()

        if self._task.environment and any(self._task.environment):
            self._display.warning('this module does not support the environment keyword')

        result = super(ActionModule, self).run(tmp, task_vars)
        del tmp  # tmp no longer has any effect

        if self._task.check_mode:
            # in --check mode, always skip this module execution
            result['skipped'] = True
            return result

        executable = self._task.args.get('executable', False)
        ps_commands = """
                $ErrorActionPreference = "Stop"
                function ConvertTo-JsonManual {
                    param (
                        [Parameter(Mandatory = $true)]
                        [hashtable]$Data
                    )
                    $json = "{"
                    foreach ($key in $Data.Keys) {
                        $value = $Data[$key]
                        if ($value -is [hashtable]) {
                            $value = ConvertTo-JsonManual -Data $value
                        } else {
                            $value = $value.ToString()
                            $value = '"' + $value + '"'
                        }
                        $json += '"' + $key + '":' + $value + ','
                    }
                    $json = $json.TrimEnd(',') + "}"
                    return $json
                }
                try {
                    $kernel_version = (Get-Item -Path "$env:SystemRoot\\System32\\kernel32.dll").VersionInfo.ProductVersion
                    $ps_version = "$($PSVersionTable.PSVersion.Major).$($PSVersionTable.PSVersion.Minor)"
                    $major_version = $kernel_version.Split('.')[0]
                    $facts = @{
                        ansible_kernel = $kernel_version
                        ansible_powershell_version = $ps_version
                        ansible_distribution_major_version = $major_version
                    }
                    $json_facts = ConvertTo-JsonManual -Data $facts
                    Write-Output $json_facts
                } catch {
                    # Output the error message in JSON format for Ansible to parse
                    $errorResult = @{
                        failed = $true
                        msg = $_.Exception.Message
                    }
                    $errorJson = ConvertTo-JsonManual -Data $errorResult
                    Write-Output $errorJson
                    exit 1
                }
                """
        result.update(self._low_level_execute_command(ps_commands, executable=executable))

        result['changed'] = False

        if 'rc' in result and result['rc'] != 0:
            result['failed'] = True
            result['msg'] = 'non-zero return code'

        # Process the output and set the facts
        try:
            stdout = result['stdout']
            if stdout.startswith('\ufeff'):
                stdout = stdout.encode('utf-8').decode('utf-8-sig')
            stdout = re.sub(r'[\r\n]+', '', stdout)
            facts = json.loads(stdout)
            result['ansible_facts'] = facts
            result['changed'] = False
        except json.JSONDecodeError as e:
            result['failed'] = True
            result['msg'] = f'Failed to parse JSON output: {e}'
            result['stdout'] = result.get('stdout', '')

        return result