# windows_powershell_upgrade
This repo contains an Ansible role that upgrades Powershell on Windows systems. It can be especially useful when you need to bootstrap Windows 7 SP1 or Windows 2008 R2 where powershell version 2.0 which is not supported by Ansible.
You can run this role as part of VMware template build role or packer role as part of CI/CD pipeline for building Windows templates.

> **_Note:_** This role is provided as an example only. Do not use this in production. You can fork/clone and add/remove steps for your environment based on your organization's security and operational requirements.

Requirements
------------

Any pre-requisites that may not be covered by Ansible itself or the role should be mentioned here. For instance, if the role uses the EC2 module, it may be a good idea to mention in this section that the boto package is required.

Role Variables
--------------

A description of the settable variables for this role should go here, including any variables that are in defaults/main.yml, vars/main.yml, and any variables that can/should be set via parameters to the role. Any variables that are read from other roles and/or the global scope (ie. hostvars, group vars, etc.) should be mentioned here as well.

Dependencies
------------

A list of roles that this role utilizes:

- oatakan.windows_hotfix

Example Playbook
----------------

Including an example of how to use your role (for instance, with variables passed in as parameters) is always nice for users too:

    - hosts: servers
      roles:
         - oatakan.windows_powershell_upgrade

KB2842230 URL sourcing notes
----------------------------

The old `s3.amazonaws.com/ansible-ci-files/...` links for `KB2842230` now return access denied.

Use Microsoft Update Catalog direct URLs from the Download dialog payload instead:

1. Open `https://www.catalog.update.microsoft.com/Search.aspx?q=2842230`.
1. Capture each `updateid` from the `goToDetails("...")` entries in page source.
1. POST to `https://www.catalog.update.microsoft.com/DownloadDialog.aspx` with:

  updateIDs=[{"size":0,"languages":"","uidInfo":"UPDATE_ID","updateID":"UPDATE_ID"}]

1. Read `downloadInformation[0].files[0].url` from the response HTML.

Current catalog state (2026-02):

- Windows 8 / Server 2012 (`os_6_2`): direct `.msu` URLs are available and used by default.
- Windows 7 / 2008 R2 (`os_6_1`) and Windows 2008 (`os_6_0`): no public catalog entries are currently listed for `KB2842230`; use an internal mirror if still required.

License
-------

MIT

Author Information
------------------

Orcun Atakan

