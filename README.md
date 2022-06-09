The proxy-scheduler is an file change intendent solution to control proxy services via docker containers (at the moment).

It has two parts, one for loadbalancer service which it is necessary for a backend proxy solution.

All the proxy services needed the proxy.json configuration file with proper content.

The proxy-scheduler use inotify kernel solution to watch changes and execute action in the proxy processes at all.

The proxy scheduler use Let's Encrypt service to certifying domains

## PROXY.JSON keys explanation ##

The proxy.json file must be filled in almost, exept two cases:
1. "PROXY_TYPE" must be filled when the loadbalancer service use Haproxy applications in the backend (the configuration generating is another)
2. "LETSENCRYPT_SERVICE_NAME": if it is empty, self signed certificates will made only

| KEY| VALUE|
|-|-|
| DOCKER_REGISTRY_URL| Docker image pathes, not mandatory|
| PROXY_TYPE| Filled as "haproxy" when it is a public loadbalancer|
| LETSENCRYPT_URL| Path for letsencrypt service image|
| LETSENCRYPT_SERVICE_NAME| Let's encrypt service name| 