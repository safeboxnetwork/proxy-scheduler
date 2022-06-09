The proxy-scheduler is an file change intendent solution to control proxy services via docker containers (at the moment).

It has two parts, one for loadbalancer service which it is necessary for a backend proxy solution.

All the proxy services needed the proxy.json configuration file with proper content.

The proxy-scheduler use inotify kernel solution to watch changes and execute action in the proxy processes at all.

## PROXY.JSON keys explanation ##

The proxy.json file must be filled in almost, some cases like "PROXY_TYPE" must be filled when the loadbalancer service use Haproxy applications in the backend (the configuration generating is another)