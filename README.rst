===================
Workshop Salt Model
===================

Reclass model for:

* 1x Salt master
* 3x OpenStack, OpenContrail control nodes
* 2x Openstack compute nodes
* 1x Ceilometer, Graphite metering nodes
* 1x Sensu monitoring node

Instructions
============

- Fork this repository
- Make customizations according to your environment:

  - ``classes/system/openssh/server/single.yml``

    - setup public SSH key
    - disable password auth
    - comment out root password

  - ``nodes/cfg01.workshop.cloudlab.cz.yml`` and
    ``classes/system/reclass/storage/system/workshop.yml``

    - fix IP addresses
    - fix domain

  - ``classes/system/openstack/common/workshop.yml``

    - fix passwords and keys
    - fix IP addresses

  - ``classes/billometer/server/single.yml`` - set password

  - ``classes/system/graphite`` - set password
