# cacti-templates
Various templates for network devices for use within cacti

# Fortinet ADC load balancer - virtual servers #
Implements the SNMP MIB 1.3.6.1.4.1.12356.112.3.2.1 that describe the traffic that flows to specific virtual servers defined in the load balancer.

**Installation**
The files are located in the fortinet-adc folder.
```
1. Copy snmp_queries/*.xml to <cacti_dir>/resource/snmp_queries/
2. Import data_queries/*.xml to Cacti
3. Import data_templates/*.xml to Cacti
4. Import graph_templates/*.xml to Cacti
```

Note: due to a software bug if you get timeouts when trying to get the list of the virtual servers, switch your device to use SNMP v1 instead of v2. Cacti uses SNMPBulkWalk in V2 which is not supported correctly by the device.

You can see some sample graphs in the fortinet-adc folder.


# Alcatel-Lucent Omniswitch 6450 #
Implements the IP SLA SNMP MIBs 1.3.6.1.4.1.6486.800.1.2.1.55.1.1.3 for Layer 3 measurements and 1.3.6.1.4.1.6486.800.1.2.1.55.1.1.6 for Layer 2 measurements. The measurements are packet loss, RTT and jitter.

**Installation**
The files are located in the alcatel-lucent-omniswitch folder.
```
1. Copy scripts/*.pl  to <cacti_dir>/scripts/
2. Copy script_queries/*.xml to <cacti_dir>/resource/script_queries/
3. Import host_templates/*.xml to Cacti
```

You can see some sample graphs in the alcatel-lucent-omniswitch folder.

