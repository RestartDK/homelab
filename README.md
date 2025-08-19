# TODO

- [x] Need to add the dns server ip to be persistent
- [x] Add portainer to docker compose
- [x] Add dokploy on other server to caddy net
- [x] Setup dokploy
- [x] Add dokploy to glance.yml
- [x] Add dokploy to portainer
- [ ] Add ollama to big server
- [ ] Add grafana for data monitoring
- [ ] Move adguard config to this repo instead
- [ ] Setup DNS for second computer
- [ ] Setup other computer and deploy dokploy and gh self hosted runner
- [ ] Fix big computer and setup ssh keys for it and tailscale access.

# Planned for the future

- Automated configuration using ansible
- Proper CI/CD with github actions to apply changes to infra in one place
- K3s for automatic load balancing and better managmenet across computers

Hey.

This is my home server for the chateau.

Will update more soon :).

I just added 2 more computers.

# Additional configurations

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

# Limitations

- If you want to add a new service you need to add a new domain in the adguard dns rewrites for caddy to work
- No config on adguard home

# DNS

## Upstream DNS

```
https://dns10.quad9.net/dns-query
https://dns.adguard-dns.com/dns-query
https://cloudflare-dns.com/dns-query
https://dns.google/dns-query
https://dns10.quad9.net/dns-query
94.140.14.14
94.140.15.15
1.1.1.1
1.0.0.1
8.8.8.8
8.8.4.4
9.9.9.9
149.112.112.112
```