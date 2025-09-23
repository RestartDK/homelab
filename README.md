# Homelab

## About the project

This repo is my config for my homelab running all my self-hosted instances that I plan to maintain and expand in the coming years.

I started this to learn more about devops, linux, and the power of taking control of your software.

## Planned for the future

- Find a better way to manage secrets for all the servers (duplicate .envs for all of them right now)
- Automated configuration using ansible
- Proper CI/CD with github actions to apply changes to infra in one place
- Ansible updates for fedora kernel, container updates, gpu updates with container runtime
- K3s for automatic load balancing and better managmenet across computers


## Additional configurations

- Provide sufficient privilleges for containers if you are running SELinux
- Opened up the ports 53, 80, 433 on my server for dns / http / https
- Manually set the dns of my server ip on my router with adguard home:
```
sudo nmcli connection modify "adguard-dns" ipv4.dns "192.168.200.69 1.1.1.1" ipv4.ignore-auto-dns yes
```
- There will be a problem a podman with the dns port with `advaark`, so you have to change the port binding of the built in dns in `/.config/containers/container.conf`:
```
[network]
dns_bind_port = 1153
```

## Limitations

- If you want to add a new service you need to add a new domain in the adguard dns rewrites for caddy to work
- No config on adguard home