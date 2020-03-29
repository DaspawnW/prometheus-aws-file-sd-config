# AWS EC2 instance autodiscovery for Prometheus metrics

The normal Prometheus ec2_sd_configs object is very limited and doesn't support extended discovery. This limits it for example to the specified list of ports inside the prometheus configuration file.

To overcome this issue the following discovery.sh script simply searches for ec2 instances tagged with the following Tag-Pattern:

Key: prom/scrape:<port>/<path>
Value: <name>

An example could be the node exporter:

Key: prom/scrape:9100/metrics
Value: node_exporter

This will produce the following file_sd_config:

[
 { 
   "targets": ["<private-ip-address>:<port>"], 
   "labels": {
      "instanceName": "<Name-Tag>",
      "instanceIp": "<private-ip-address>",
      "name": "<name>",
      "__metrics_path__": "<path>",
      "__address__": "<private-ip-address>:<port>"
   }
 }
]

This implementation is directly compatible with the Helm chart stable/prometheus as it also automatically updates the configmap with the file_sd_config output. The jimmidyson/configmap-reload docker image detects the change at the configmap and reloads prometheus.

The Dockerimage can be executed as a CronJob inside Kubernetes to continuously detect new Instances tagged with the prom/scrape Keys and start scraping them.
