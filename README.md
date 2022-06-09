The proxy-scheduler is an file change intendent solution to control proxy services via docker containers (at the moment).

It has two parts, one for loadbalancer service which it is necessary for a backend proxy solution.

All the proxy services needed the proxy.json configuration file with proper content.

The proxy-scheduler use inotify kernel solution to watch changes and execute action in the proxy processes at all.

Read carefuly the readmes for the proxy.json file and the domain.sample file also.