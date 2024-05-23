# Red Hat Ansible Automation Platform Demo

![eda-demo architecture](assets/eda-demo.png)

This repository contains the code to showcase a demo of Ansible Automation Platform on the following topics:

- Config as Code AAP management
- ServiceNow CMDB Dynamic inventory
- Event Driven Ansible and self Remediation
- ServiceNow ITSM integration

## Requirements

### AAP and EDA Controller

You can install a [Containerized Automation Platform and EDA controller](https://access.redhat.com/documentation/en-us/red_hat_ansible_automation_platform/2.4/html-single/containerized_ansible_automation_platform_installation_guide/index)

### Alertmanager

This demo contains a simple containerized Alertmanager that you can execute with `podman play kube`

1. Configure the Alertmanager istance: within the alertmanager configuration file `utils/alermanager/alertmanager/alertmanager.yml` you can set the `webhook_configs` url with the EDA Alertmanager receiver

2. Start the containerized instance

```
$ cd utils/alermanager/
$ podman play kube alertmanager-pod.yaml --start
$ podman logs -f alertmanager-alertmanager
```

The instance can be stopped with `podman play kube alertmanager-pod.yaml --down`

### Service Now instance

You can easily sign-up for a developer instance on [https://developer.servicenow.com/](https://developer.servicenow.com/)

## Configuration

Before executing the demo you have to create a var file based on the [config-as-code/vars-empty.yml](config-as-code/vars-empty.yml) file.

### Token Configuration

In order to connect AAP and the EDA controller you have to:

1) Generate a Token in AAP ( `Access / Users -> admin -> token -> Add`) with **write** scope
2) Import the Token into the EDA Controller (`Access / Users -> admin -> token -> Create Controller Token`)

Alternatively you can configure the token with the provided playbook:

```
$ cd config-as-code
$ ansible-playbook create_token.yml -e @var.yml
```

### Configuration deployment

Once the token is configured you can deploy the configuration just executing the `aap_configuration.yml` playbook:

```
$ ansible-playbook aap_configuration.yml -e @var.yml
```

This playbook creates all the needed resources in AAP:
- Job template `Setup AAP EDA Demo` triggering the `aap_configuration.yml` playbook
- Job templates `Demo EDA Webhook handler` and `Demo EDA Alertmanager handler` to handle the EDA events
- `servicenow.itsm` new credential type
- Automation Hub, Controller and Service Now credentials
- Service Now execution environment for the Dynamic inventory
- An inventory with an inventory source integrating the Service Now CMDB

## Demo

### ServiceNow CMDB Ansible Dynamic Inventory

#### Building the Execution Environment

The demo needs an Execution Environment (EE) containing the Ansible `servicenow.itsm` collection.
The demo is using the existing EE from `quay.io/pbertera/snow_ee:latest`.

Optionally you can build your own EE following the next steps.

##### Configure Ansible Galaxy:

- Get an offline token from https://console.redhat.com/ansible/automation-hub/token
- Add to `/etc/ansible/ansible.cfg` the automation hub and the token

```
[galaxy]
server_list = automation_hub

[galaxy_server.automation_hub]
url=https://console.redhat.com/api/automation-hub/content/published/
auth_url=https://sso.redhat.com/auth/realms/redhat-external/protocol/openid-connect/token
token=$TOKEN
```

More info on the Automation Hub [documentation](https://access.redhat.com/documentation/en-us/red_hat_ansible_automation_platform/2.4/html/getting_started_with_automation_hub/configure-hub-primary#proc-configure-automation-hub-server-cli)

##### Building the Execution Environment

1. Login on registry.redhat.io

```
$ podman login --log-level debug registry.redhat.io
```

2. Create the `Containerfile` into the context dir

```
$ cd ee
$ ansible-builder create -v 3
```

3. Build the EE

```
$ podman build -f context/Containerfile context --no-cache -t quay.io/pbertera/snow_ee:latest
```

4. Tag the image and push it to quay.io (or another registry)

```
$ podman login quay.io
$ podman push quay.io/pbertera/snow_ee:latest
$ cd ..
```

5. Configure the the `aap2_controller_execution_environment_image` variable into the [vars file](blob/main/config-as-code/vars-empty.yml) pointing to the right image

#### ServiceNow CMDB Inventory Sync

The playbook `aap_configuration.yml` configures the Dynamic inventory sync creating a new Inventory with a dynamic source pointing to the `scm_url` repository.
The file [now.yml](blob/main/now.yml) contains the sync configuration. For more information please consult the upstream [documentation](https://docs.ansible.com/ansible/8/collections/servicenow/servicenow/now_inventory.html#ansible-collections-servicenow-servicenow-now-inventory).

To demonstrate the Inventory Sync you can modify the hosts from the CMDB and trigger a new Ansible Inventory source synchronization.

### EDA: Webhook

The playbook `aap_configuration.yml` creates a RuleBook activation on EDA listening on port `5000`.
The activation executes the `rulebooks/eda-rulebook-webhook.yml` rulebook triggering the `webhook-handler.yml` playbook on AAP.

You can trigger the rulebook with the following curl request:

```
$ curl -X POST http://aap.demo.lab:5000 -d '{"name":"greeting","message":"hello test"}' -v
```

### EDA: Alermanager and ServiceNow ITSM integration

The playbook `aap_configuration.yml` creates a RuleBook activation on EDA listening on port `5001`.
The activation executes the `rulebooks/eda-rulebook-alertmanager.yml` rulebook triggering the `alertmanager-handler.yml` playbook on AAP.

The playbook creates a ticket when the alert is firing and closes the ticket when the alert is resolved.

You can fire and resolve the alert with the `utils/fire-alert.sh $ALERTMANAGER_URL` script 

## Kudos

This demo is mainly inspired by the great [kubealex](https://github.com/kubealex) work on another [EDA demo](https://github.com/kubealex/event-driven-automation)
