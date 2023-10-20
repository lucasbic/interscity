# Deploying InterSCity

Ansible scripts and support files to semi-automatically deploy InterSCity in a Docker Swarm environment. This uses our pre-built docker images for the main InterSCity components.

# Requirements

* At least one host, but two or more are recommended
* Host requirements
  - Debian GNU/Linux Bookworm
  - ssh access
    - Add you ssh public key to your user in remote hosts. [Here's an example](https://www.digitalocean.com/community/tutorials/how-to-configure-ssh-key-based-authentication-on-a-linux-server)
  - passwordless sudo permission
  - Python must be installed
* The machine which will perform the deployment (your workstation) must have Ansible 2.8 or greater installed
* Make sure to open the required ports for Docker Swarm to work. You can learn how to configure the firewall [here](https://www.digitalocean.com/community/tutorials/how-to-configure-the-linux-firewall-for-docker-swarm-on-ubuntu-16-04). The ports are:
  - TCP ports: `2376`, `2377` and `7946`
  - UDP ports: `7946` and `4789`

## Deployment target

These ansible playbooks and related files deploy the InterSCity containers according to what is defined in a given ansible `hosts` file. We provide a [Vagrantfile](https://www.vagrantup.com/) that creates 5 VMs using virtualbox and a corresponding [ansible hosts file](ansible/vagrant_hosts) that realizes the deployment to these virtual machines. It should be very easy to adapt this `hosts` file to deploy InterSCity on real servers or on a different setup. We also include alternate versions of these files, [Vagrantfile-standalone](Vagrantfile-standalone) and [ansible/standalone_vagrant_host](ansible/standalone_vagrant_host), that deploy all services/containers on a single VM.

Note that, since Virtual Box 6.1.24, [host addresses are limited to the range
192.168.56.0/21](https://www.virtualbox.org/manual/ch06.html#network_hostonly).
The provided files use different addresses, so you should modify your machine's
virtualbox configuration:

```shell
$ sudo mkdir -p /etc/vbox/
$ sudo touch /etc/vbox/networks.conf
$ sudo echo "* 10.0.0.0/8 192.168.0.0/16" >> /etc/vbox/networks.conf
$ sudo echo "* 2001::/64" >> /etc/vbox/networks.conf
```

## Configuration

When using this sample configuration with vagrant, you do not need to worry about adding your public key to the VMs; vagrant adds a default key for you (the corresponding private key is at `~/.vagrant.d/insecure_private_key`). With it, you may access the machines with `vagrant ssh macine-name`. The provided ansible scripts also depend on this default key (it is hardcoded in the sample hosts file). However, keep in mind that *this is insecure* and only suitable for local access.

1. Create your `hosts` file
   * You can check an example [here](ansible/vagrant_hosts)
     - It is important to note that if you use `localhost` or `127.0.0.1` you may find issues getting all the services up. Instead use other valid IP addresses on your network.
   * Each host must have a unique `swarm_node_name` variable defined
   * You'll use these names to set the roles of each node under the `swarm_labels` variable in the `swarm-manager` group
   * Valid labels are
     - `gateway` (at least one host must have this label as `true`)
     - `data` (at least one host must have this label `true`)
     - `common`
   * It is important that at least one host is in each of the following groups: `swarm-manager`; and `swarm-data-workers`
   * The remaining hosts must be members of the `swarm-workers` group
2. If you do *not* want automated backups, either comment out the `vault_password_file` line in [ansible.cfg](ansible/ansible.cfg) or create an empty `.vault-pass.txt` file (notice the dot), otherwise ansible will abort with an error.

   If you *do* want automated backups:
   * Change the `enabled_db_backups` variable on `group_vars/all` to `true`
   * Create a [Google service account](https://developers.google.com/identity/protocols/oauth2/service-account#creatinganaccount), if you don't have one
   * Download your private key as a json file and put it under `roles/setup-swarm-data-storage/templates/service-account.json`
     - You should use [Ansible Vault](https://docs.ansible.com/ansible/latest/user_guide/vault.html#encrypting-unencrypted-files) to encrypt that file; then, save the password in the `.vault-pass.txt` file (or modify the `vault_password_file` line in [ansible.cfg](ansible/ansible.cfg) to suit your needs)
   * Activate the [Google Drive API](https://console.developers.google.com/apis/library/drive.googleapis.com) for your project
   * To configure how often the backups will occur, you can change the values on the `Schedule backup with cron` task on `roles/setup-swarm-data-storage/tasks/db_backup.yml`
     - By default, the backup will be performed daily at 23:59.
3. Start the servers
   * If you are using the supplied configuration for vagrant VMs, this means calling `vagrant up`
4. Install Docker Swarm in the hosts
   * Within the ansible directory run:<br>
     `ansible-playbook setup-swarm.yml -i <vagrant_hosts | standalone_vagrant_host>`
     - this step performs, among other tasks, a full system upgrade. If you find an error while running it, please try to reboot the hosts and running it again
     - if this step hangs on the task `docker_swarm` for a while, stop it and run it again
5. Install the InterSCity docker containers and start the swarm
   * Within the ansible directory run:<br>
     `ansible-playbook deploy-swarm-stack.yml -i <vagrant_hosts | standalone_vagrant_host>`
     - This will bring up all services. It may take some time on the first run (around 5-10 minutes). You can track the progress further by accessing the manager host and running `docker service ls`.

For a single host/VM installation, the host must have both `gateway` and `data` labelled `true`.

## Checking for a correct deployment

Make sure you have access to your gateway host through ports `8000` and `8001`. Then, if necessary, you can replace `10.10.10.104` by your gateway host address and perform the following checks:

* `curl http://10.10.10.104:8001/upstreams`
  - should return 5 entries (all applications and the kong-api-gateway)
* `curl http://10.10.10.104:8001/apis`
  - should return 6 entries (all applications)
* `curl http://10.10.10.104:8000/catalog/resources`
* `curl http://10.10.10.104:8000/collector/resources/data`

You can also run the [integration tests](src/test/README.md) to verify everything works as expected.

## Removing services

The `kong-docs` is supposed to be a one-shot service. If you want to remove it after it successfully runs, you can log in the swarm manager and run:<br>
`sudo docker service remove interscity-platform_kong-docs`

## Troubleshooting

* **Force service deployment**
  - if a given service is taking too long to retry, on the swarm manager host you can force it with<br>
    `docker service update --force <SERVICE IDENTIFIER>`
* **Timeout (12s) waiting for privilege escalation prompt**
  - Add `-c paramiko` at the end of the ansible command

