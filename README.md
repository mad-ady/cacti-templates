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

You can see some sample graphs in the fortinet-adc folder.

